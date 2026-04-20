use ndarray::{Array1, Array2, Array3};
use ort::session::builder::GraphOptimizationLevel;
use ort::session::Session;
use ort::value::Tensor;
use std::borrow::Cow;
use std::path::Path;
use std::sync::Mutex;
use std::time::Instant;

use super::tokenizer::Qwen3Tokenizer;

const EOS_TOKEN_ID: u32 = 151645;
const MAX_DECODE_STEPS: usize = 2048;

/// Autoregressive decoder: init (prefill) + step loop.
pub struct Decoder {
    session_init: Mutex<Session>,
    session_step: Mutex<Session>,
    num_layers: usize,
}

impl Decoder {
    pub fn new(model_dir: &Path) -> Result<Self, String> {
        let t = Instant::now();
        let session_init = Session::builder()
            .map_err(|e| format!("Session builder error: {}", e))?
            .with_optimization_level(GraphOptimizationLevel::Disable)
            .map_err(|e| format!("Set optimization level error: {}", e))?
            .commit_from_file(model_dir.join("decoder_init.int8.onnx"))
            .map_err(|e| format!("Failed to load decoder_init.int8.onnx: {}", e))?;
        tracing::info!("[ONNX load] Decoder init session: {:.2}s", t.elapsed().as_secs_f64());

        let t = Instant::now();
        let session_step = Session::builder()
            .map_err(|e| format!("Session builder error: {}", e))?
            .with_optimization_level(GraphOptimizationLevel::Disable)
            .map_err(|e| format!("Set optimization level error: {}", e))?
            .commit_from_file(model_dir.join("decoder_step.int8.onnx"))
            .map_err(|e| format!("Failed to load decoder_step.int8.onnx: {}", e))?;
        tracing::info!("[ONNX load] Decoder step session: {:.2}s", t.elapsed().as_secs_f64());

        Ok(Self {
            session_init: Mutex::new(session_init),
            session_step: Mutex::new(session_step),
            num_layers: 28,
        })
    }

    /// Run autoregressive decoding.
    pub fn decode(
        &self,
        audio_tokens: &Array2<f32>,
        embed_tokens: &Array2<f32>,
        tokenizer: &Qwen3Tokenizer,
    ) -> Result<String, String> {
        let audio_pad_id = tokenizer.get_audio_pad_token_id() as usize;

        // Build prompt
        let system_tokens = tokenizer.encode("<|im_start|>user\n");
        let suffix_tokens = tokenizer.encode("<|im_end|><|im_start|>assistant\n");
        let num_audio_tokens = audio_tokens.nrows();

        let mut input_ids: Vec<u32> = system_tokens;
        let audio_start_pos = input_ids.len();
        input_ids.extend(std::iter::repeat(audio_pad_id as u32).take(num_audio_tokens));
        let audio_end_pos = input_ids.len();
        input_ids.extend(suffix_tokens);

        let seq_len = input_ids.len();
        let d_model = embed_tokens.ncols();

        // Build input embeddings
        let mut input_embeds = Array2::<f32>::zeros((seq_len, d_model));
        for (i, &token_id) in input_ids.iter().enumerate() {
            if i >= audio_start_pos && i < audio_end_pos {
                let audio_idx = i - audio_start_pos;
                for (d, val) in audio_tokens.row(audio_idx).iter().enumerate() {
                    input_embeds[[i, d]] = *val;
                }
            } else {
                let tid = token_id as usize;
                if tid < embed_tokens.nrows() {
                    for (d, val) in embed_tokens.row(tid).iter().enumerate() {
                        input_embeds[[i, d]] = *val;
                    }
                }
            }
        }

        let position_ids_arr = Array1::from_iter((0..seq_len).map(|i| i as i64));

        // Run decoder_init - extract all data while lock is held
        let (first_token, mut kv_cache) = {
            let embed_tensor = Tensor::from_array(input_embeds)
                .map_err(|e| format!("Decoder init embed tensor error: {}", e))?;
            let pos_tensor = Tensor::from_array(position_ids_arr)
                .map_err(|e| format!("Decoder init pos tensor error: {}", e))?;

            let init_inputs = ort::inputs![
                "input_embeds" => embed_tensor,
                "position_ids" => pos_tensor
            ];

            let mut init_session = self.session_init.lock().map_err(|e| format!("Lock error: {}", e))?;
            let init_outputs = init_session
                .run(init_inputs)
                .map_err(|e| format!("Decoder init run error: {}", e))?;

            // Extract logits data
            let (logits_shape, logits_data) = init_outputs["logits"]
                .try_extract_tensor::<f32>()
                .map_err(|e| format!("Logits extract error: {}", e))?;
            let logits_vec = logits_data.to_vec();
            let logits_dims: Vec<usize> = logits_shape.iter().map(|&d| d as usize).collect();
            let vocab_size = *logits_dims.last().unwrap_or(&0);

            let kv = self.extract_kv_cache_from(&init_outputs);

            // Pick first token from last position
            let last_row_start = (seq_len - 1) * vocab_size;
            let first = logits_vec[last_row_start..]
                .iter()
                .enumerate()
                .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                .map(|(idx, _)| idx as u32)
                .unwrap_or(0);

            (first, kv)
        };

        let mut generated_tokens = vec![first_token];
        let mut current_token = first_token;

        // Autoregressive loop
        for step in 0..MAX_DECODE_STEPS {
            if current_token == EOS_TOKEN_ID {
                break;
            }

            let mut token_embed = Array2::<f32>::zeros((1, d_model));
            let tid = current_token as usize;
            if tid < embed_tokens.nrows() {
                for (d, val) in embed_tokens.row(tid).iter().enumerate() {
                    token_embed[[0, d]] = *val;
                }
            }

            let step_pos = Array1::from_vec(vec![(seq_len + step) as i64]);

            // Run decoder step - extract data while lock is held
            let (next_token, new_kv) = {
                let step_embed_tensor = Tensor::from_array(token_embed)
                    .map_err(|e| format!("Step embed tensor error: {}", e))?;
                let step_pos_tensor = Tensor::from_array(step_pos)
                    .map_err(|e| format!("Step pos tensor error: {}", e))?;

                let mut step_inputs: Vec<(Cow<'_, str>, ort::session::SessionInputValue)> = ort::inputs![
                    "input_embeds" => step_embed_tensor,
                    "position_ids" => step_pos_tensor
                ];

                self.add_kv_cache_inputs(&mut step_inputs, &kv_cache)?;

                let mut step_session = self.session_step.lock().map_err(|e| format!("Lock error: {}", e))?;
                let step_outputs = step_session
                    .run(step_inputs)
                    .map_err(|e| format!("Decoder step {} run error: {}", step, e))?;

                let (_, logits_data) = step_outputs["logits"]
                    .try_extract_tensor::<f32>()
                    .map_err(|e| format!("Step logits extract error: {}", e))?;
                let logits_vec = logits_data.to_vec();

                let new_kv = self.extract_kv_cache_from(&step_outputs);

                let next = logits_vec
                    .iter()
                    .enumerate()
                    .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                    .map(|(idx, _)| idx as u32)
                    .unwrap_or(0);

                (next, new_kv)
            };

            generated_tokens.push(next_token);
            current_token = next_token;
            kv_cache = new_kv;
        }

        if generated_tokens.last() == Some(&EOS_TOKEN_ID) {
            generated_tokens.pop();
        }

        tokenizer.decode(&generated_tokens)
    }

    fn extract_kv_cache_from(
        &self,
        outputs: &ort::session::SessionOutputs,
    ) -> Vec<Array3<f32>> {
        let mut cache = Vec::new();
        for layer in 0..self.num_layers {
            let key_name = format!("present_keys.{}", layer);
            let val_name = format!("present_values.{}", layer);

            if let Some(key_val) = outputs.get(key_name.as_str()) {
                if let Ok((shape, data)) = key_val.try_extract_tensor::<f32>() {
                    let dims: Vec<usize> = shape.iter().map(|&d| d as usize).collect();
                    if dims.len() == 3 {
                        if let Ok(arr) = Array3::from_shape_vec((dims[0], dims[1], dims[2]), data.to_vec()) {
                            cache.push(arr);
                        }
                    }
                }
            }
            if let Some(val_val) = outputs.get(val_name.as_str()) {
                if let Ok((shape, data)) = val_val.try_extract_tensor::<f32>() {
                    let dims: Vec<usize> = shape.iter().map(|&d| d as usize).collect();
                    if dims.len() == 3 {
                        if let Ok(arr) = Array3::from_shape_vec((dims[0], dims[1], dims[2]), data.to_vec()) {
                            cache.push(arr);
                        }
                    }
                }
            }
        }
        cache
    }

    fn add_kv_cache_inputs(
        &self,
        inputs: &mut Vec<(Cow<'_, str>, ort::session::SessionInputValue)>,
        kv_cache: &[Array3<f32>],
    ) -> Result<(), String> {
        for (layer, chunk) in kv_cache.chunks(2).enumerate() {
            if chunk.len() == 2 {
                let key_tensor = Tensor::from_array(chunk[0].clone())
                    .map_err(|e| format!("KV key tensor error layer {}: {}", layer, e))?;
                let val_tensor = Tensor::from_array(chunk[1].clone())
                    .map_err(|e| format!("KV val tensor error layer {}: {}", layer, e))?;

                inputs.push((Cow::Owned(format!("past_keys.{}", layer)), key_tensor.into()));
                inputs.push((Cow::Owned(format!("past_values.{}", layer)), val_tensor.into()));
            }
        }
        Ok(())
    }
}
