use std::sync::{Arc, Mutex};
use tokio::sync::mpsc;

pub struct VeAnchorConfig {
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,
    pub language: String,
}

#[derive(Debug, Clone)]
pub struct AsrResult {
    pub text: String,
    pub is_final: bool,
    pub timestamp: i64,
}

pub type AsrResultCallback = Box<dyn Fn(AsrResult) + Send + Sync>;

pub struct AsrSession {
    // 占位结构，后续实现
}

impl AsrSession {
    pub fn new(_callback: AsrResultCallback) -> Self {
        todo!()
    }
    pub fn send_audio(&self, _audio_data: &[u8]) -> Result<(), String> {
        todo!()
    }
    pub fn finish(&self) -> Result<(), String> {
        todo!()
    }
}

pub struct VeAnchorProvider {
    config: VeAnchorConfig,
}

impl VeAnchorProvider {
    pub fn new(config: VeAnchorConfig) -> Self {
        Self { config }
    }
    pub fn create_session(&self, callback: AsrResultCallback) -> Result<AsrSession, String> {
        Ok(AsrSession::new(callback))
    }
}
