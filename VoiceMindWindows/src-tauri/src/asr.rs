use std::io::{Read, Write};
use std::sync::Arc;
use std::time::SystemTime;

use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::{self, Message}, MaybeTlsStream};
use tracing::{error, info, warn};
use uuid::Uuid;

// --- Binary protocol constants --- (for legacy Volcengine implementation)

const PROTOCOL_VERSION: u8 = 0b0001;
const HEADER_SIZE: u8 = 0b0001; // 1 × 4 = 4 bytes

// Message types (high nibble of byte 1)
const MSG_FULL_CLIENT_REQUEST: u8 = 0b0001;
const MSG_AUDIO_ONLY_REQUEST: u8 = 0b0010;
const MSG_FULL_SERVER_RESPONSE: u8 = 0b1001;
const MSG_ERROR_RESPONSE: u8 = 0b1111;

// Message-type specific flags (low nibble of byte 1)
const FLAG_NO_SEQUENCE: u8 = 0b0000;
const FLAG_POSITIVE_SEQUENCE: u8 = 0b0001;
const FLAG_LAST_NO_SEQUENCE: u8 = 0b0010;
const FLAG_NEGATIVE_SEQUENCE: u8 = 0b0011;

// Serialization (high nibble of byte 2)
const SERIAL_NONE: u8 = 0b0000;
const SERIAL_JSON: u8 = 0b0001;

// Compression (low nibble of byte 2)
const COMPRESS_NONE: u8 = 0b0000;
const COMPRESS_GZIP: u8 = 0b0001;

fn build_header(msg_type: u8, flags: u8, serial: u8, compress: u8) -> [u8; 4] {
    [
        (PROTOCOL_VERSION << 4) | HEADER_SIZE,
        (msg_type << 4) | flags,
        (serial << 4) | compress,
        0x00,
    ]
}

// --- Public types ---

// Volcengine Open Speech API config (legacy)
pub struct VolcengineConfig {
    pub app_id: String,      // X-Api-App-Key
    pub access_key: String,  // X-Api-Access-Key
    pub resource_id: String, // X-Api-Resource-Id
    pub language: String,
}

// Volcengine VeAnchor API config (new official)
#[allow(dead_code)]
pub struct VeAnchorConfig {
    pub app_id: String,          // AppKey
    pub access_key_id: String,   // AccessKey ID
    pub access_key_secret: String, // AccessKey Secret
    pub cluster: String,         // Cluster (e.g., cn-beijing)
    pub language: String,        // Language code
}

#[derive(Debug, Clone)]
pub struct AsrResult {
    pub text: String,
    pub is_final: bool,
    pub timestamp: i64,
}

pub type AsrResultCallback = Arc<dyn Fn(AsrResult) + Send + Sync>;

// --- Session ---

pub struct AsrSession {
    callback: AsrResultCallback,
    ws_writer: Option<
        futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<MaybeTlsStream<TcpStream>>,
            Message,
        >,
    >,
    sequence: i32,
}

impl AsrSession {
    pub fn new(callback: AsrResultCallback) -> Self {
        Self {
            callback,
            ws_writer: None,
            sequence: 0,
        }
    }

    /// Connect to Volcengine bigmodel streaming ASR and send the config frame.
    pub async fn connect(&mut self, config: &VolcengineConfig) -> Result<(), String> {
        let url = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async";
        let connect_id = Uuid::new_v4().to_string();

        info!(
            "Volcengine ASR connecting: app_id={}, resource_id={}, connect_id={}",
            config.app_id, config.resource_id, connect_id
        );

        // Use tungstenite's into_client_request to generate proper WebSocket headers
        use tokio_tungstenite::tungstenite::client::IntoClientRequest;
        let mut request = url
            .into_client_request()
            .map_err(|e| format!("Failed to create WS request: {}", e))?;

        // Add custom Volcengine auth headers
        let h = |v: &str| -> Result<tauri::http::HeaderValue, String> {
            tauri::http::HeaderValue::from_str(v).map_err(|e| format!("Invalid header value: {}", e))
        };
        request.headers_mut().insert("X-Api-App-Key", h(&config.app_id)?);
        request.headers_mut().insert("X-Api-Access-Key", h(&config.access_key)?);
        request.headers_mut().insert("X-Api-Resource-Id", h(&config.resource_id)?);
        request.headers_mut().insert("X-Api-Connect-Id", h(&connect_id)?);

        info!("Volcengine ASR request headers: {:?}", request.headers());

        let result = connect_async(request).await;
        let (ws_stream, resp) = result.map_err(|e| {
            let detail = format_ws_error(&e);
            error!("Volcengine ASR connect failed: {}", detail);
            format!("Volcengine ASR connect failed: {}", detail)
        })?;

        info!("Volcengine ASR connected, status={}", resp.status());

        if let Some(logid) = resp.headers().get("X-Tt-Logid") {
            info!("Volcengine ASR connected, logid={:?}", logid);
        }

        let (writer, mut reader) = ws_stream.split();
        self.ws_writer = Some(writer);

        // Send full-client-request (config frame)
        self.send_config_frame(config).await?;

        // Spawn background reader that forwards results to the callback
        let callback = self.callback.clone();
        tokio::spawn(async move {
            while let Some(msg) = reader.next().await {
                match msg {
                    Ok(Message::Binary(data)) => {
                        Self::handle_server_frame(&data, &callback);
                    }
                    Ok(Message::Text(text)) => {
                        warn!("Unexpected text frame from ASR: {}", text);
                    }
                    Ok(Message::Close(frame)) => {
                        info!("ASR WebSocket closed: {:?}", frame);
                        break;
                    }
                    Err(e) => {
                        error!("ASR WebSocket read error: {}", e);
                        break;
                    }
                    _ => {}
                }
            }
        });

        Ok(())
    }

    /// Send a chunk of PCM audio (16 kHz, 16-bit, mono).
    pub async fn send_audio(&mut self, audio_data: &[u8]) -> Result<(), String> {
        let writer = self.ws_writer.as_mut().ok_or("ASR not connected")?;

        self.sequence += 1;

        // Gzip compress the audio chunk
        let payload = gzip_compress(audio_data)?;

        // Header: audio-only request, positive sequence, no serialization, gzip
        let header = build_header(
            MSG_AUDIO_ONLY_REQUEST,
            FLAG_POSITIVE_SEQUENCE,
            SERIAL_NONE,
            COMPRESS_GZIP,
        );

        let payload_size = payload.len() as u32;
        let mut frame = Vec::with_capacity(4 + 4 + 4 + payload.len());
        frame.extend_from_slice(&header);
        frame.extend_from_slice(&self.sequence.to_be_bytes());
        frame.extend_from_slice(&payload_size.to_be_bytes());
        frame.extend_from_slice(&payload);

        writer
            .send(Message::Binary(frame))
            .await
            .map_err(|e| format!("Send audio failed: {}", e))?;

        Ok(())
    }

    /// Send the finish signal (last empty audio packet).
    pub async fn finish(&mut self) -> Result<(), String> {
        let writer = self.ws_writer.as_mut().ok_or("ASR not connected")?;

        // Last packet: flag LAST_NO_SEQUENCE, empty payload, no compression
        let header = build_header(
            MSG_AUDIO_ONLY_REQUEST,
            FLAG_LAST_NO_SEQUENCE,
            SERIAL_NONE,
            COMPRESS_NONE,
        );

        let mut frame = Vec::with_capacity(4 + 4);
        frame.extend_from_slice(&header);
        frame.extend_from_slice(&0u32.to_be_bytes()); // payload size = 0

        writer
            .send(Message::Binary(frame))
            .await
            .map_err(|e| format!("Send finish failed: {}", e))?;

        info!("Volcengine ASR finish signal sent (seq={})", self.sequence);
        Ok(())
    }

    // ---- internals ----

    async fn send_config_frame(&mut self, _config: &VolcengineConfig) -> Result<(), String> {
        let writer = self.ws_writer.as_mut().ok_or("ASR not connected")?;

        let payload_json = serde_json::json!({
            "user": {
                "uid": "voicemind-windows"
            },
            "audio": {
                "format": "pcm",
                "rate": 16000,
                "bits": 16,
                "channel": 1
            },
            "request": {
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "enable_ddc": true,
                "result_type": "single"
            }
        });

        let json_bytes = 
            serde_json::to_vec(&payload_json).map_err(|e| format!("Serialize config: {}", e))?;

        let payload = gzip_compress(&json_bytes)?;

        let header = build_header(
            MSG_FULL_CLIENT_REQUEST,
            FLAG_NO_SEQUENCE,
            SERIAL_JSON,
            COMPRESS_GZIP,
        );

        let payload_size = payload.len() as u32;
        let mut frame = Vec::with_capacity(4 + 4 + payload.len());
        frame.extend_from_slice(&header);
        frame.extend_from_slice(&payload_size.to_be_bytes());
        frame.extend_from_slice(&payload);

        writer
            .send(Message::Binary(frame))
            .await
            .map_err(|e| format!("Send config failed: {}", e))?;

        info!("Volcengine ASR config frame sent");
        // Server auto-assigns sequence 1 to the config frame, so audio must start at 2
        self.sequence = 1;
        Ok(())
    }

    fn handle_server_frame(data: &[u8], callback: &AsrResultCallback) {
        if data.len() < 4 {
            warn!("ASR frame too short ({} bytes)", data.len());
            return;
        }

        let msg_type = (data[1] >> 4) & 0x0F;
        let flags = data[1] & 0x0F;
        let compression = data[2] & 0x0F;

        match msg_type {
            MSG_FULL_SERVER_RESPONSE => {
                // Layout: header(4) + sequence(4) + payload_size(4) + payload
                if data.len() < 12 {
                    warn!("Server response header incomplete");
                    return;
                }

                let payload_size = 
                    u32::from_be_bytes([data[8], data[9], data[10], data[11]]) as usize;

                if data.len() < 12 + payload_size {
                    warn!(
                        "Server response payload incomplete: expected {}, got {}",
                        payload_size,
                        data.len() - 12
                    );
                    return;
                }

                let raw_payload = &data[12..12 + payload_size];

                let json_bytes = if compression == COMPRESS_GZIP {
                    match gzip_decompress(raw_payload) {
                        Ok(d) => d,
                        Err(e) => {
                            error!("Gzip decompress response: {}", e);
                            return;
                        }
                    }
                } else {
                    raw_payload.to_vec()
                };

                let values = match parse_response_json_values(&json_bytes) {
                    Ok(values) => values,
                    Err(e) => {
                        error!("Parse response JSON: {}", e);
                        return;
                    }
                };

                let is_final =
                    flags == FLAG_NEGATIVE_SEQUENCE || flags == FLAG_LAST_NO_SEQUENCE;

                for json in values {
                    // The server may return "result_code" at top level for errors
                    if let Some(code) = json.get("result_code").and_then(|c| c.as_i64()) {
                        if code != 0 {
                            let msg = json
                                .get("message")
                                .and_then(|m| m.as_str())
                                .unwrap_or("unknown");
                            error!("Volcengine ASR error code {}: {}", code, msg);
                            continue;
                        }
                    }

                    if let Some(result) = json.get("result") {
                        if let Some(text) = result.get("text").and_then(|t| t.as_str()) {
                            if !text.is_empty() {
                                callback(AsrResult {
                                    text: text.to_string(),
                                    is_final,
                                    timestamp: SystemTime::now()
                                        .duration_since(SystemTime::UNIX_EPOCH)
                                        .unwrap()
                                        .as_millis() as i64,
                                });
                            }
                        }
                    }
                }
            }
            MSG_ERROR_RESPONSE => {
                // Layout: header(4) + error_code(4) + msg_size(4) + msg
                if data.len() < 12 {
                    warn!("Error frame too short");
                    return;
                }
                let code = u32::from_be_bytes([data[4], data[5], data[6], data[7]]);
                let msg_size = u32::from_be_bytes([data[8], data[9], data[10], data[11]]) as usize;
                let msg = if data.len() >= 12 + msg_size {
                    String::from_utf8_lossy(&data[12..12 + msg_size]).to_string()
                } else {
                    "unknown".to_string()
                };
                error!("Volcengine ASR protocol error {}: {}", code, msg);
            }
            _ => {
                warn!("Unknown ASR message type: 0x{:X}", msg_type);
            }
        }
    }
}

fn parse_response_json_values(json_bytes: &[u8]) -> Result<Vec<serde_json::Value>, String> {
    let mut values = Vec::new();
    let stream = serde_json::Deserializer::from_slice(json_bytes).into_iter::<serde_json::Value>();

    for value in stream {
        match value {
            Ok(v) => values.push(v),
            Err(e) => return Err(e.to_string()),
        }
    }

    if values.is_empty() {
        return Err("empty JSON payload".to_string());
    }

    Ok(values)
}

// --- VeAnchor Session (new official Volcengine API) ---

#[allow(dead_code)]
pub struct VeAnchorSession {
    callback: AsrResultCallback,
    ws_writer: Option<
        futures_util::stream::SplitSink<
            tokio_tungstenite::WebSocketStream<MaybeTlsStream<TcpStream>>,
            Message,
        >,
    >,
    task_id: String,
}

#[allow(dead_code)]
impl VeAnchorSession {
    pub fn new(callback: AsrResultCallback) -> Self {
        Self {
            callback,
            ws_writer: None,
            task_id: Uuid::new_v4().to_string(),
        }
    }

    /// Connect to Volcengine VeAnchor streaming ASR
    pub async fn connect(&mut self, config: &VeAnchorConfig) -> Result<(), String> {
        // Volcengine VeAnchor WebSocket endpoint
        let url = "wss://sami.bytedance.com/api/v1/ws";
        
        info!(
            "VeAnchor ASR connecting: app_id={}, cluster={}",
            config.app_id, config.cluster
        );

        // Create WebSocket request with proper headers
        use tokio_tungstenite::tungstenite::client::IntoClientRequest;
        let mut request = url
            .into_client_request()
            .map_err(|e| format!("Failed to create WS request: {}", e))?;

        // Add Volcengine auth headers
        let h = |v: &str| -> Result<tauri::http::HeaderValue, String> {
            tauri::http::HeaderValue::from_str(v).map_err(|e| format!("Invalid header value: {}", e))
        };
        
        // Note: According to Volcengine docs, you need to generate a proper token
        // For now, we'll use a placeholder - in production, you need to implement proper token generation
        request.headers_mut().insert("SAMI-Token", h("your_token")?);
        request.headers_mut().insert("appkey", h(&config.app_id)?);

        info!("VeAnchor ASR request headers: {:?}", request.headers());

        let result = connect_async(request).await;
        match &result {
            Ok((_, resp)) => {
                info!("VeAnchor ASR connected, status={}, headers={:?}", resp.status(), resp.headers());
            }
            Err(e) => {
                error!("VeAnchor ASR connect error: {:?}", e);
            }
        }
        let (ws_stream, _) = result.map_err(|e| format!("VeAnchor ASR connect failed: {}", e))?;

        let (writer, mut reader) = ws_stream.split();
        self.ws_writer = Some(writer);

        // Send StartTask control message
        self.send_start_task(config).await?;

        // Spawn background reader that forwards results to the callback
        let callback = self.callback.clone();
        tokio::spawn(async move {
            while let Some(msg) = reader.next().await {
                match msg {
                    Ok(Message::Text(text)) => {
                        Self::handle_veanchor_text_message(&text, &callback);
                    }
                    Ok(Message::Binary(data)) => {
                        // For TTS, this would contain audio data
                        // For ASR, we might receive binary audio data or other payloads
                        info!("Received binary message from VeAnchor: {} bytes", data.len());
                    }
                    Ok(Message::Close(frame)) => {
                        info!("VeAnchor WebSocket closed: {:?}", frame);
                        break;
                    }
                    Err(e) => {
                        error!("VeAnchor WebSocket read error: {}", e);
                        break;
                    }
                    _ => {}
                }
            }
        });

        Ok(())
    }

    /// Send a chunk of PCM audio (16 kHz, 16-bit, mono).
    pub async fn send_audio(&mut self, audio_data: &[u8]) -> Result<(), String> {
        let writer = self.ws_writer.as_mut().ok_or("ASR not connected")?;

        // For VeAnchor, we send audio data as binary messages
        // The format depends on the specific ASR API
        writer
            .send(Message::Binary(audio_data.to_vec()))
            .await
            .map_err(|e| format!("Send audio failed: {}", e))?;

        Ok(())
    }

    /// Send the finish signal
    pub async fn finish(&mut self) -> Result<(), String> {
        let writer = self.ws_writer.as_mut().ok_or("ASR not connected")?;

        // Send FinishTask control message
        let finish_msg = serde_json::json!({
            "task_id": self.task_id,
            "appkey": "your_appkey",
            "namespace": "ASR",
            "event": "FinishTask"
        });

        let finish_msg_bytes = serde_json::to_vec(&finish_msg)
            .map_err(|e| format!("Serialize finish message: {}", e))?;

        writer
            .send(Message::Text(String::from_utf8_lossy(&finish_msg_bytes).to_string()))
            .await
            .map_err(|e| format!("Send finish failed: {}", e))?;

        info!("VeAnchor ASR finish signal sent");
        Ok(())
    }

    // ---- internals ----

    async fn send_start_task(&mut self, config: &VeAnchorConfig) -> Result<(), String> {
        let writer = self.ws_writer.as_mut().ok_or("ASR not connected")?;

        // Create StartTask message according to Volcengine spec
        let start_msg = serde_json::json!({
            "task_id": self.task_id,
            "appkey": config.app_id,
            "namespace": "ASR",
            "event": "StartTask",
            "payload": serde_json::json!({
                "audio": {
                    "format": "pcm",
                    "rate": 16000,
                    "bits": 16,
                    "channel": 1
                },
                "request": {
                    "model_name": "your_asr_model", // Replace with actual model name
                    "language": config.language,
                    "enable_itn": true,
                    "enable_punc": true
                }
            }).to_string()
        });

        let start_msg_bytes = serde_json::to_vec(&start_msg)
            .map_err(|e| format!("Serialize start message: {}", e))?;

        writer
            .send(Message::Text(String::from_utf8_lossy(&start_msg_bytes).to_string()))
            .await
            .map_err(|e| format!("Send start task failed: {}", e))?;

        info!("VeAnchor ASR start task message sent");
        Ok(())
    }

    fn handle_veanchor_text_message(text: &str, callback: &AsrResultCallback) {
        let msg: serde_json::Value = match serde_json::from_str(text) {
            Ok(v) => v,
            Err(e) => {
                error!("Parse VeAnchor message: {}", e);
                return;
            }
        };

        // Handle different event types
        if let Some(event) = msg.get("event").and_then(|e| e.as_str()) {
            match event {
                "TaskStarted" => {
                    info!("VeAnchor task started: {:?}", msg);
                }
                "TaskFinished" => {
                    info!("VeAnchor task finished: {:?}", msg);
                    // Extract final result from payload
                    if let Some(payload_str) = msg.get("payload").and_then(|p| p.as_str()) {
                        if let Ok(payload) = serde_json::from_str::<serde_json::Value>(payload_str) {
                            if let Some(text) = payload.get("text").and_then(|t| t.as_str()) {
                                callback(AsrResult {
                                    text: text.to_string(),
                                    is_final: true,
                                    timestamp: SystemTime::now()
                                        .duration_since(SystemTime::UNIX_EPOCH)
                                        .unwrap()
                                        .as_millis() as i64,
                                });
                            }
                        }
                    }
                }
                "RecognitionResult" => {
                    // Handle intermediate recognition results
                    if let Some(payload_str) = msg.get("payload").and_then(|p| p.as_str()) {
                        if let Ok(payload) = serde_json::from_str::<serde_json::Value>(payload_str) {
                            if let Some(text) = payload.get("text").and_then(|t| t.as_str()) {
                                callback(AsrResult {
                                    text: text.to_string(),
                                    is_final: false,
                                    timestamp: SystemTime::now()
                                        .duration_since(SystemTime::UNIX_EPOCH)
                                        .unwrap()
                                        .as_millis() as i64,
                                });
                            }
                        }
                    }
                }
                _ => {
                    info!("VeAnchor event: {} - {:?}", event, msg);
                }
            }
        }
    }
}

// --- Provider ---

pub struct VolcengineProvider {
    config: VolcengineConfig,
}

impl VolcengineProvider {
    pub fn new(config: VolcengineConfig) -> Self {
        Self { config }
    }

    pub fn create_session(&self, callback: AsrResultCallback) -> AsrSession {
        AsrSession::new(callback)
    }

    pub async fn connect_session(&self, session: &mut AsrSession) -> Result<(), String> {
        session.connect(&self.config).await
    }

    /// Test connection to Volcengine ASR by performing a WebSocket handshake.
    /// Returns Ok(()) if successful, or Err with detailed diagnostic message.
    pub async fn test_connection(&self) -> Result<String, String> {
        let url = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async";
        let connect_id = Uuid::new_v4().to_string();

        info!(
            "Volcengine ASR test_connection: app_id={}, resource_id={}, connect_id={}",
            self.config.app_id, self.config.resource_id, connect_id
        );

        use tokio_tungstenite::tungstenite::client::IntoClientRequest;
        let mut request = url
            .into_client_request()
            .map_err(|e| format!("Failed to create WS request: {}", e))?;

        let h = |v: &str| -> Result<tauri::http::HeaderValue, String> {
            tauri::http::HeaderValue::from_str(v).map_err(|e| format!("Invalid header value: {}", e))
        };
        request.headers_mut().insert("X-Api-App-Key", h(&self.config.app_id)?);
        request.headers_mut().insert("X-Api-Access-Key", h(&self.config.access_key)?);
        request.headers_mut().insert("X-Api-Resource-Id", h(&self.config.resource_id)?);
        request.headers_mut().insert("X-Api-Connect-Id", h(&connect_id)?);

        let result = connect_async(request).await;
        match result {
            Ok((_ws, resp)) => {
                let logid = resp.headers().get("X-Tt-Logid")
                    .and_then(|v| v.to_str().ok())
                    .unwrap_or("unknown");
                Ok(format!("连接成功 (status={}, logid={})", resp.status(), logid))
            }
            Err(e) => {
                let detail = format_ws_error(&e);
                Err(format!("连接失败: {}", detail))
            }
        }
    }

    /// One-shot recognition: connect, stream audio in chunks, finish, return final text.
    pub async fn recognize(
        &self,
        audio_data: &[u8],
        _sample_rate: u32,
        _channels: u32,
    ) -> Result<String, String> {
        let (tx, rx) = tokio::sync::oneshot::channel();
        let tx = Arc::new(tokio::sync::Mutex::new(Some(tx)));
        let final_text = Arc::new(tokio::sync::Mutex::new(String::new()));

        let cb_tx = tx.clone();
        let cb_text = final_text.clone();

        let callback: AsrResultCallback = Arc::new(move |result| {
            // Accumulate partial results; on final, send the text
            if !result.text.is_empty() {
                *cb_text.try_lock().unwrap() = result.text.clone();
            }
            if result.is_final {
                let text = result.text.clone();
                if let Ok(mut guard) = cb_tx.try_lock() {
                    if let Some(t) = guard.take() {
                        let _ = t.send(text);
                    }
                }
            }
        });

        let mut session = self.create_session(callback);
        session.connect(&self.config).await?;

        // Stream audio in ~200 ms chunks (16000 Hz × 2 bytes × 0.2 s = 6400 bytes)
        let chunk_size = 6400;
        for chunk in audio_data.chunks(chunk_size) {
            session.send_audio(chunk).await?;
            // Mimic real-time pacing (200 ms) so the server can process incrementally
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        }

        session.finish().await?;

        // Wait up to 30 s for the final result
        let result = tokio::time::timeout(std::time::Duration::from_secs(30), rx)
            .await
            .map_err(|_| "Volcengine ASR timed out".to_string())?
            .map_err(|_| "Volcengine ASR channel closed without result".to_string())?;

        Ok(result)
    }
}

// --- VeAnchor Provider (new official) ---

#[allow(dead_code)]
pub struct VeAnchorProvider {
    config: VeAnchorConfig,
}

#[allow(dead_code)]
impl VeAnchorProvider {
    pub fn new(config: VeAnchorConfig) -> Self {
        Self { config }
    }

    pub fn create_session(&self, callback: AsrResultCallback) -> VeAnchorSession {
        VeAnchorSession::new(callback)
    }

    /// One-shot recognition using VeAnchor API
    pub async fn recognize(
        &self,
        audio_data: &[u8],
        _sample_rate: u32,
        _channels: u32,
    ) -> Result<String, String> {
        let (tx, rx) = tokio::sync::oneshot::channel();
        let tx = Arc::new(tokio::sync::Mutex::new(Some(tx)));
        let final_text = Arc::new(tokio::sync::Mutex::new(String::new()));

        let cb_tx = tx.clone();
        let cb_text = final_text.clone();

        let callback: AsrResultCallback = Arc::new(move |result| {
            // Accumulate partial results; on final, send the text
            if !result.text.is_empty() {
                *cb_text.try_lock().unwrap() = result.text.clone();
            }
            if result.is_final {
                let text = result.text.clone();
                if let Ok(mut guard) = cb_tx.try_lock() {
                    if let Some(t) = guard.take() {
                        let _ = t.send(text);
                    }
                }
            }
        });

        let mut session = self.create_session(callback);
        session.connect(&self.config).await?;

        // Stream audio in chunks
        let chunk_size = 6400; // ~200ms at 16kHz 16-bit mono
        for chunk in audio_data.chunks(chunk_size) {
            session.send_audio(chunk).await?;
            tokio::time::sleep(std::time::Duration::from_millis(50)).await;
        }

        session.finish().await?;

        // Wait up to 30 s for the final result
        let result = tokio::time::timeout(std::time::Duration::from_secs(30), rx)
            .await
            .map_err(|_| "VeAnchor ASR timed out".to_string())?
            .map_err(|_| "VeAnchor ASR channel closed without result".to_string())?;

        Ok(result)
    }
}

// --- Helpers ---

fn gzip_compress(data: &[u8]) -> Result<Vec<u8>, String> {
    let mut encoder = GzEncoder::new(Vec::new(), Compression::fast());
    encoder
        .write_all(data)
        .map_err(|e| format!("Gzip compress: {}", e))?;
    encoder
        .finish()
        .map_err(|e| format!("Gzip finish: {}", e))
}

fn gzip_decompress(data: &[u8]) -> Result<Vec<u8>, String> {
    let mut decoder = GzDecoder::new(data);
    let mut buf = Vec::new();
    decoder
        .read_to_end(&mut buf)
        .map_err(|e| format!("Gzip decompress: {}", e))?;
    Ok(buf)
}

/// Extract detailed error info from a tungstenite WebSocket connect error.
fn format_ws_error(e: &tungstenite::Error) -> String {
    match e {
        tungstenite::Error::Http(resp) => {
            let status = resp.status();
            let body = resp.body()
                .as_ref()
                .map(|bytes| String::from_utf8_lossy(bytes).to_string())
                .unwrap_or_else(|| "(empty body)".to_string());
            let headers: String = resp.headers().iter()
                .filter(|(k, _)| !k.as_str().starts_with("x-tt-"))
                .map(|(k, v)| format!("{}={}", k, v.to_str().unwrap_or("?")))
                .collect::<Vec<_>>()
                .join("; ");
            format!("HTTP {} | headers: [{}] | body: {}", status, headers, body)
        }
        other => format!("{:?}", other),
    }
}
