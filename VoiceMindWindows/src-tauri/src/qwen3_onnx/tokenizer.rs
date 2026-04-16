use tokenizers::Tokenizer as HfTokenizer;

/// BPE tokenizer wrapper for Qwen3-ASR.
pub struct Qwen3Tokenizer {
    inner: HfTokenizer,
    audio_pad_token_id: u32,
}

impl Qwen3Tokenizer {
    pub fn from_file(path: &std::path::Path) -> Result<Self, String> {
        let inner = HfTokenizer::from_file(path).map_err(|e| format!("Failed to load tokenizer: {}", e))?;
        Ok(Self {
            inner,
            audio_pad_token_id: 151676,
        })
    }

    pub fn encode(&self, text: &str) -> Vec<u32> {
        let encoding = self.inner.encode(text, false).unwrap();
        encoding.get_ids().to_vec()
    }

    pub fn decode(&self, ids: &[u32]) -> Result<String, String> {
        self.inner.decode(ids, true).map_err(|e| e.to_string())
    }

    pub fn get_audio_pad_token_id(&self) -> u32 {
        self.audio_pad_token_id
    }

    pub fn vocab_size(&self) -> u32 {
        151936
    }
}
