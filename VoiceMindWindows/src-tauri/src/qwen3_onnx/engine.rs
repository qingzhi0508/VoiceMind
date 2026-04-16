use ndarray::Array2;
use std::path::Path;

use super::audio::MelSpectrogram;
use super::decoder::Decoder;
use super::encoder::Encoder;
use super::tokenizer::Qwen3Tokenizer;

/// High-level ONNX inference engine for Qwen3-ASR.
/// Whisper-rs style: create once, call transcribe() for inference.
pub struct Qwen3AsrEngine {
    mel: MelSpectrogram,
    encoder: Encoder,
    decoder: Decoder,
    tokenizer: Qwen3Tokenizer,
    embed_tokens: Array2<f32>,
}

impl Qwen3AsrEngine {
    /// Load all ONNX sessions + embeddings + tokenizer.
    /// ~3-5 seconds, ~2.5 GB RAM for 0.6B model.
    pub fn new(model_dir: &Path) -> Result<Self, String> {
        let mel = MelSpectrogram::new(16000);
        let tokenizer = Qwen3Tokenizer::from_file(&model_dir.join("tokenizer.json"))?;
        let encoder = Encoder::new(model_dir)?;
        let decoder = Decoder::new(model_dir)?;

        // Load embed_tokens.bin (FP32, vocab_size * d_model * 4 bytes)
        let embed_path = model_dir.join("embed_tokens.bin");
        let embed_data = std::fs::read(&embed_path)
            .map_err(|e| format!("Failed to read embed_tokens.bin: {}", e))?;

        let vocab_size = 151936;
        let d_model = 1024;
        let expected_size = vocab_size * d_model * 4; // f32 = 4 bytes

        if embed_data.len() < expected_size {
            return Err(format!(
                "embed_tokens.bin too small: {} < {}",
                embed_data.len(),
                expected_size
            ));
        }

        // Parse FP32 little-endian
        let mut embed_tokens = Array2::<f32>::zeros((vocab_size, d_model));
        let mut offset = 0;
        for i in 0..vocab_size {
            for j in 0..d_model {
                let bytes = [
                    embed_data[offset],
                    embed_data[offset + 1],
                    embed_data[offset + 2],
                    embed_data[offset + 3],
                ];
                embed_tokens[[i, j]] = f32::from_le_bytes(bytes);
                offset += 4;
            }
        }

        Ok(Self {
            mel,
            encoder,
            decoder,
            tokenizer,
            embed_tokens,
        })
    }

    /// Full pipeline: PCM f32 → mel → encode → decode → text.
    pub fn transcribe(&self, pcm: &[f32], _sample_rate: u32) -> Result<String, String> {
        if pcm.len() < 4800 {
            return Err("Audio too short (< 0.3s)".into());
        }

        // 1. Compute mel spectrogram
        let mel_output = self.mel.compute(pcm);

        // 2. Chunk mel into 100-frame blocks
        let mel_chunks = self.mel.chunk_mel(&mel_output);

        // 3. Encode audio
        let audio_tokens = self.encoder.encode(&mel_chunks)?;

        // 4. Decode to text
        let text = self.decoder.decode(&audio_tokens, &self.embed_tokens, &self.tokenizer)?;

        Ok(text)
    }
}

// Make it safe to share across threads via Arc
unsafe impl Send for Qwen3AsrEngine {}
unsafe impl Sync for Qwen3AsrEngine {}
