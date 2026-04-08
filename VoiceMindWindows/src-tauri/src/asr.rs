use std::sync::Arc;
use std::time::SystemTime;
use base64::{Engine, engine::general_purpose::STANDARD};
use futures_util::{SinkExt, StreamExt};
use hmac::{Hmac, Mac};
use tauri::http::Request;
use sha2::Sha256;
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::Message, MaybeTlsStream};
use uuid::Uuid;
use tracing::info;

type HmacSha256 = Hmac<Sha256>;

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

pub type AsrResultCallback = Arc<dyn Fn(AsrResult) + Send + Sync>;

pub struct AsrSession {
    callback: AsrResultCallback,
    ws_writer: Option<futures_util::stream::SplitSink<tokio_tungstenite::WebSocketStream<MaybeTlsStream<TcpStream>>, Message>>,
}

impl AsrSession {
    pub fn new(callback: AsrResultCallback) -> Self {
        Self {
            callback,
            ws_writer: None,
        }
    }

    /// 连接到火山引擎并开始识别会话
    pub async fn connect(&mut self, config: &VeAnchorConfig) -> Result<(), String> {
        let url = "wss://openspeech.bytedance.com";

        // 生成认证 token (简化版本，实际需要 HMAC 签名)
        let token = self.generate_token(config)?;

        let request = Request::builder()
            .uri(url)
            .header("Authorization", format!("Bearer {}", token))
            .header("X-Tt-Logid", Uuid::new_v4().to_string())
            .header("Content-Type", "application/json")
            .body(())
            .map_err(|e| format!("Failed to build request: {}", e))?;

        let (ws_stream, _) = connect_async(request)
            .await
            .map_err(|e| format!("Failed to connect to ASR server: {}", e))?;

        let (writer, mut reader) = ws_stream.split();
        self.ws_writer = Some(writer);

        // 发送开始请求
        self.send_start_request(config).await?;

        // 启动读取响应任务
        let callback = self.callback.clone();
        tokio::spawn(async move {
            while let Some(msg) = reader.next().await {
                if let Ok(Message::Text(text)) = msg {
                    if let Some(result) = Self::parse_response(&text) {
                        callback(result);
                    }
                }
            }
        });

        Ok(())
    }

    /// 发送音频数据
    pub async fn send_audio(&mut self, audio_data: &[u8]) -> Result<(), String> {
        let writer = self.ws_writer.as_mut()
            .ok_or("Not connected")?;

        let audio_base64 = STANDARD.encode(audio_data);
        let payload = serde_json::json!({
            "type": "audio",
            "payload": {
                "data": audio_base64,
                "format": "pcm",
                "rate": 16000,
                "channels": 1,
                "bits": 16
            }
        });

        writer.send(Message::Text(payload.to_string()))
            .await
            .map_err(|e| format!("Failed to send audio: {}", e))?;

        Ok(())
    }

    /// 结束识别会话
    pub async fn finish(&mut self) -> Result<(), String> {
        if let Some(writer) = self.ws_writer.as_mut() {
            let payload = serde_json::json!({
                "type": "finish"
            });
            writer.send(Message::Text(payload.to_string()))
                .await
                .map_err(|e| format!("Failed to send finish: {}", e))?;
        }
        Ok(())
    }

    fn generate_token(&self, config: &VeAnchorConfig) -> Result<String, String> {
        // 火山引擎认证需要生成 HMAC 签名
        // 简化版本 - 实际需要按照火山引擎文档实现
        let timestamp = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let auth_string = format!("{}:{}", config.app_id, timestamp);

        let mut mac = HmacSha256::new_from_slice(config.access_key_secret.as_bytes())
            .map_err(|e| format!("HMAC error: {}", e))?;
        mac.update(auth_string.as_bytes());

        let result = mac.finalize();
        let signature = STANDARD.encode(result.into_bytes());

        Ok(format!("{}.{}.{}", config.app_id, timestamp, signature))
    }

    async fn send_start_request(&mut self, config: &VeAnchorConfig) -> Result<(), String> {
        let writer = self.ws_writer.as_mut()
            .ok_or("Not connected")?;

        let payload = serde_json::json!({
            "type": "start",
            "payload": {
                "appid": config.app_id,
                "cluster": config.cluster,
                "language": config.language,
                "sample_rate": 16000,
                "format": "pcm"
            }
        });

        writer.send(Message::Text(payload.to_string()))
            .await
            .map_err(|e| format!("Failed to send start request: {}", e))?;

        info!("ASR start request sent");
        Ok(())
    }

    fn parse_response(text: &str) -> Option<AsrResult> {
        let json: serde_json::Value = serde_json::from_str(text).ok()?;
        let resp_type = json.get("type")?.as_str()?;

        if resp_type == "result" {
            let payload = json.get("payload")?;
            let text = payload.get("text")?.as_str()?.to_string();
            let is_final = payload.get("is_final")?.as_bool().unwrap_or(true);

            Some(AsrResult {
                text,
                is_final,
                timestamp: SystemTime::now()
                    .duration_since(SystemTime::UNIX_EPOCH)
                    .unwrap()
                    .as_millis() as i64,
            })
        } else {
            None
        }
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
