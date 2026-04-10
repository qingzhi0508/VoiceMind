use std::io::{Read, Write};
use std::sync::Arc;
use std::time::SystemTime;

use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::Message, MaybeTlsStream};
use tracing::{error, info, warn};
use uuid::Uuid;

// --- Binary protocol constants ---

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

pub struct VolcengineConfig {
    pub app_id: String,      // X-Api-App-Key
    pub access_key: String,  // X-Api-Access-Key
    pub resource_id: String, // X-Api-Resource-Id
    pub language: String,
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
        let url = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel";
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
        match &result {
            Ok((_, resp)) => {
                info!("Volcengine ASR connected, status={}, headers={:?}", resp.status(), resp.headers());
            }
            Err(e) => {
                error!("Volcengine ASR connect error: {:?}", e);
            }
        }
        let (ws_stream, resp) = result.map_err(|e| format!("Volcengine ASR connect failed: {}", e))?;

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

                let json: serde_json::Value = match serde_json::from_slice(&json_bytes) {
                    Ok(v) => v,
                    Err(e) => {
                        error!("Parse response JSON: {}", e);
                        return;
                    }
                };

                let is_final =
                    flags == FLAG_NEGATIVE_SEQUENCE || flags == FLAG_LAST_NO_SEQUENCE;

                // The server may return "result_code" at top level for errors
                if let Some(code) = json.get("result_code").and_then(|c| c.as_i64()) {
                    if code != 0 {
                        let msg = json
                            .get("message")
                            .and_then(|m| m.as_str())
                            .unwrap_or("unknown");
                        error!("Volcengine ASR error code {}: {}", code, msg);
                        return;
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
