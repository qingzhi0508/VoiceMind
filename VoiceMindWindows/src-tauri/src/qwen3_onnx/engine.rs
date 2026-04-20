use ndarray::Array2;
use std::path::Path;
use std::time::Instant;

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
        let total_start = Instant::now();

        let t = Instant::now();
        let mel = MelSpectrogram::new(16000);
        tracing::info!("[ONNX load] MelSpectrogram: {:.2}s", t.elapsed().as_secs_f64());

        let t = Instant::now();
        let tokenizer = Qwen3Tokenizer::from_file(&model_dir.join("tokenizer.json"))?;
        tracing::info!("[ONNX load] Tokenizer: {:.2}s", t.elapsed().as_secs_f64());

        let t = Instant::now();
        let encoder = Encoder::new(model_dir)?;
        tracing::info!("[ONNX load] Encoder (conv + transformer): {:.2}s", t.elapsed().as_secs_f64());

        let t = Instant::now();
        let decoder = Decoder::new(model_dir)?;
        tracing::info!("[ONNX load] Decoder (init + step): {:.2}s", t.elapsed().as_secs_f64());

        // Load embed_tokens.bin (FP32, vocab_size * d_model * 4 bytes)
        let t = Instant::now();
        let embed_path = model_dir.join("embed_tokens.bin");
        let embed_data = std::fs::read(&embed_path)
            .map_err(|e| format!("Failed to read embed_tokens.bin: {}", e))?;
        tracing::info!("[ONNX load] embed_tokens.bin read from disk: {:.2}s ({} bytes)", t.elapsed().as_secs_f64(), embed_data.len());

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

        // Bulk conversion: chunks_exact(4) → f32::from_le_bytes, then reshape.
        // ~100x faster than the old 155M-iteration nested loop.
        let t_parse = Instant::now();
        let f32_vec: Vec<f32> = embed_data[..expected_size]
            .chunks_exact(4)
            .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
            .collect();
        let embed_tokens = Array2::from_shape_vec((vocab_size, d_model), f32_vec)
            .map_err(|e| format!("embed_tokens reshape error: {}", e))?;
        tracing::info!("[ONNX load] embed_tokens parsed + reshaped: {:.2}s", t_parse.elapsed().as_secs_f64());

        tracing::info!("[ONNX load] Total engine load: {:.2}s", total_start.elapsed().as_secs_f64());

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
