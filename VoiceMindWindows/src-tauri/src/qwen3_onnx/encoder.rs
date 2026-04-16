use ndarray::{Array1, Array2, Array3};
use ort::session::Session;
use ort::value::Tensor;
use std::path::Path;
use std::sync::Mutex;

/// Two-stage ONNX encoder: Conv2D stem + Transformer.
pub struct Encoder {
    session_conv: Mutex<Session>,
    session_transformer: Mutex<Session>,
    hidden_dim: usize,
    d_model: usize,
    tokens_per_chunk: usize,
}

impl Encoder {
    pub fn new(model_dir: &Path) -> Result<Self, String> {
        let session_conv = Session::builder()
            .map_err(|e| format!("Session builder error: {}", e))?
            .commit_from_file(model_dir.join("encoder_conv.onnx"))
            .map_err(|e| format!("Failed to load encoder_conv.onnx: {}", e))?;

        let session_transformer = Session::builder()
            .map_err(|e| format!("Session builder error: {}", e))?
            .commit_from_file(model_dir.join("encoder_transformer.onnx"))
            .map_err(|e| format!("Failed to load encoder_transformer.onnx: {}", e))?;

        Ok(Self {
            session_conv: Mutex::new(session_conv),
            session_transformer: Mutex::new(session_transformer),
            hidden_dim: 896,
            d_model: 1024,
            tokens_per_chunk: 13,
        })
    }

    /// Run encoder on chunked mel input.
    pub fn encode(&self, mel_chunks: &Array3<f32>) -> Result<Array2<f32>, String> {
        let num_chunks = mel_chunks.shape()[0];

        // Run encoder_conv - extract data while lock is held
        let conv_arr = {
            let input_tensor = Tensor::from_array(mel_chunks.clone())
                .map_err(|e| format!("Encoder conv tensor create error: {}", e))?;
            let inputs = ort::inputs!["padded_mel_chunks" => input_tensor];

            let mut conv_session = self.session_conv.lock().map_err(|e| format!("Lock error: {}", e))?;
            let outputs = conv_session
                .run(inputs)
                .map_err(|e| format!("Encoder conv run error: {}", e))?;

            let (shape, data) = outputs["conv_output"]
                .try_extract_tensor::<f32>()
                .map_err(|e| format!("Encoder conv output extract error: {}", e))?;

            let d: Vec<usize> = shape.iter().map(|&d| d as usize).collect();
            if d.len() != 3 {
                return Err(format!("Expected 3D conv output, got {}D", d.len()));
            }

            Array3::from_shape_vec((d[0], d[1], d[2]), data.to_vec())
                .map_err(|e| format!("Conv output reshape error: {}", e))?
        };

        // Reshape to [total_tokens, hidden_dim]
        let total_tokens = num_chunks * self.tokens_per_chunk;
        let mut features = Array2::<f32>::zeros((total_tokens, self.hidden_dim));

        for c in 0..num_chunks {
            for t in 0..self.tokens_per_chunk {
                let idx = c * self.tokens_per_chunk + t;
                for h in 0..self.hidden_dim {
                    if t < conv_arr.shape()[2] && h < conv_arr.shape()[1] {
                        features[[idx, h]] = conv_arr[[c, h, t]];
                    }
                }
            }
        }

        let attention_mask = Array1::<f32>::ones(total_tokens);

        // Run encoder_transformer - extract data while lock is held
        let encoded = {
            let hidden_tensor = Tensor::from_array(features.clone())
                .map_err(|e| format!("Hidden tensor create error: {}", e))?;
            let mask_tensor = Tensor::from_array(attention_mask)
                .map_err(|e| format!("Mask tensor create error: {}", e))?;

            let transformer_inputs = ort::inputs![
                "hidden_states" => hidden_tensor,
                "attention_mask" => mask_tensor
            ];

            let mut transformer_session = self.session_transformer.lock().map_err(|e| format!("Lock error: {}", e))?;
            let transformer_outputs = transformer_session
                .run(transformer_inputs)
                .map_err(|e| format!("Encoder transformer run error: {}", e))?;

            let (out_shape, out_data) = transformer_outputs[0]
                .try_extract_tensor::<f32>()
                .map_err(|e| format!("Encoder transformer output extract error: {}", e))?;

            let out_dims: Vec<usize> = out_shape.iter().map(|&d| d as usize).collect();
            if out_dims.len() != 2 {
                return Err(format!("Expected 2D encoder output, got {}D", out_dims.len()));
            }

            Array2::from_shape_vec((out_dims[0], out_dims[1]), out_data.to_vec())
                .map_err(|e| format!("Encoder output reshape error: {}", e))?
        };

        Ok(encoded)
    }
}
