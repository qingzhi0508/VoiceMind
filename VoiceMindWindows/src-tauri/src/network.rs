use crate::pairing::PairingManager;
use crate::commands::ConnectionStatus;
use crate::asr::{AsrSession, AsrResult, VeAnchorProvider};
use crate::injection;
use crate::events::EventEmitter;
use futures_util::{SinkExt, StreamExt};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tauri::AppHandle;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{Mutex, RwLock};
use tokio_tungstenite::{accept_async, tungstenite::Message};
use tracing::{error, info, warn};
use uuid::Uuid;

type HmacSha256 = Hmac<Sha256>;

const HEARTBEAT_INTERVAL_SECS: u64 = 30;
const CONNECTION_TIMEOUT_SECS: u64 = 60;

/// Message types matching iOS protocol
#[derive(Debug, Clone, PartialEq)]
pub enum MessageType {
    PairRequest,
    PairConfirm,
    PairSuccess,
    StartListen,
    StopListen,
    AudioStart,
    AudioData,
    AudioEnd,
    Result,
    PartialResult,
    Ping,
    Pong,
    Error,
}

impl MessageType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::PairRequest => "pairRequest",
            Self::PairConfirm => "pairConfirm",
            Self::PairSuccess => "pairSuccess",
            Self::StartListen => "startListen",
            Self::StopListen => "stopListen",
            Self::AudioStart => "audioStart",
            Self::AudioData => "audioData",
            Self::AudioEnd => "audioEnd",
            Self::Result => "result",
            Self::PartialResult => "partialResult",
            Self::Ping => "ping",
            Self::Pong => "pong",
            Self::Error => "error",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "pairRequest" => Some(Self::PairRequest),
            "pairConfirm" => Some(Self::PairConfirm),
            "pairSuccess" => Some(Self::PairSuccess),
            "startListen" => Some(Self::StartListen),
            "stopListen" => Some(Self::StopListen),
            "audioStart" => Some(Self::AudioStart),
            "audioData" => Some(Self::AudioData),
            "audioEnd" => Some(Self::AudioEnd),
            "result" => Some(Self::Result),
            "partialResult" => Some(Self::PartialResult),
            "ping" => Some(Self::Ping),
            "pong" => Some(Self::Pong),
            "error" => Some(Self::Error),
            _ => None,
        }
    }
}

/// Message envelope structure matching iOS protocol
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Envelope {
    pub id: String,
    #[serde(rename = "type")]
    pub type_: String,
    pub payload: serde_json::Value,
    #[serde(default)]
    pub timestamp: Option<u64>,
    #[serde(default)]
    pub device_id: Option<String>,
    #[serde(default)]
    pub hmac: Option<String>,
}

/// Payload structures
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PairRequestPayload {
    pub short_code: String,
    pub mac_name: String,
    pub mac_id: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PairConfirmPayload {
    pub short_code: String,
    pub ios_name: String,
    pub ios_id: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PairSuccessPayload {
    pub shared_secret: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct StartListenPayload {
    pub session_id: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct StopListenPayload {
    pub session_id: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AudioStartPayload {
    pub session_id: String,
    pub language: String,
    pub sample_rate: u32,
    pub channels: u32,
    pub format: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AudioDataPayload {
    pub session_id: String,
    #[serde(with = "base64serde")]
    pub audio_data: Vec<u8>,
    pub sequence_number: u32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AudioEndPayload {
    pub session_id: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ResultPayload {
    pub session_id: String,
    pub text: String,
    pub language: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PartialResultPayload {
    pub session_id: String,
    pub text: String,
    pub language: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PingPayload {
    pub nonce: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct PongPayload {
    pub nonce: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ErrorPayload {
    pub code: String,
    pub message: String,
}

// Custom base64 serialization for audio data
mod base64serde {
    use base64::{Engine, engine::general_purpose::STANDARD};
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S>(bytes: &Vec<u8>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let encoded = STANDARD.encode(bytes);
        serializer.serialize_str(&encoded)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        STANDARD.decode(&s).map_err(serde::de::Error::custom)
    }
}

/// Connection state
#[derive(Debug, Clone)]
pub enum ConnectionState {
    Pending,       // Newly connected, waiting for pairing
    Pairing,       // In pairing process
    Paired,        // Successfully paired
    Listening,     // Currently listening for audio
}

pub struct Connection {
    pub id: String,
    pub device_id: Option<String>,
    pub device_name: Option<String>,
    pub state: ConnectionState,
    pub writer: Arc<Mutex<Option<futures_util::stream::SplitSink<TokioWebSocket, Message>>>>,
    pub last_pong: Option<Instant>,
    pub secret_key: Option<String>,
    pub asr_session: Option<AsrSession>,
    pub event_emitter: Arc<Mutex<EventEmitter>>,
}

pub type TokioWebSocket = tokio_tungstenite::WebSocketStream<TcpStream>;

pub struct ConnectionManager {
    server_port: u16,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    listener: Option<Arc<Mutex<TcpListener>>>,
    running: bool,
    event_emitter: Arc<Mutex<EventEmitter>>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            server_port: 8765,
            connections: Arc::new(RwLock::new(HashMap::new())),
            listener: None,
            running: false,
            event_emitter: Arc::new(Mutex::new(EventEmitter::new())),
        }
    }

    pub fn set_app_handle(&self, handle: AppHandle) {
        // Use try_lock to avoid blocking in async context
        if let Ok(mut emitter_guard) = self.event_emitter.try_lock() {
            emitter_guard.set_app_handle(handle);
        } else {
            // If we can't get the lock immediately, spawn a task to do it
            let emitter = self.event_emitter.clone();
            tokio::spawn(async move {
                let mut emitter_guard = emitter.lock().await;
                emitter_guard.set_app_handle(handle);
            });
        }
    }

    pub async fn start_server(&mut self, port: u16, pairing_manager: Arc<Mutex<PairingManager>>) -> Result<(), String> {
        self.server_port = port;
        let addr = format!("0.0.0.0:{}", port);

        let listener = TcpListener::bind(&addr)
            .await
            .map_err(|e| format!("Failed to bind to {}: {}", addr, e))?;

        info!("WebSocket server listening on {}", addr);
        self.running = true;

        let listener_arc = Arc::new(Mutex::new(listener));
        self.listener = Some(listener_arc.clone());
        let connections = self.connections.clone();
        let running = Arc::new(std::sync::atomic::AtomicBool::new(true));

        // Accept connections in background
        tokio::spawn(async move {
            while running.load(std::sync::atomic::Ordering::Relaxed) {
                let listener = listener_arc.clone();
                let listener_guard = listener.lock().await;
                match listener_guard.accept().await {
                    Ok((stream, peer_addr)) => {
                        info!("New connection from: {}", peer_addr);

                        // Check if we already have a paired connection
                        let has_paired = {
                            let conns = connections.read().await;
                            conns.values().any(|c| matches!(c.state, ConnectionState::Paired))
                        };

                        if has_paired {
                            info!("Rejecting new connection - already have a paired device");
                            // Send rejection and close
                            if let Ok(ws) = accept_async(stream).await {
                                let (mut write, _) = ws.split();
                                let rejection = serde_json::json!({
                                    "id": Uuid::new_v4().to_string(),
                                    "type": "error",
                                    "payload": { "code": "ALREADY_PAIRED", "message": "Only one device can be connected at a time" }
                                });
                                write.send(Message::Text(rejection.to_string())).await.ok();
                                write.close().await.ok();
                            }
                            continue;
                        }

                        let connections = connections.clone();
                        let pairing_manager = pairing_manager.clone();

                        tokio::spawn(async move {
                            if let Err(e) = handle_connection(stream, connections, pairing_manager).await {
                                error!("Connection error: {}", e);
                            }
                        });
                    }
                    Err(e) => {
                        error!("Failed to accept connection: {}", e);
                    }
                }
            }
        });

        Ok(())
    }

    pub fn stop_server(&mut self) {
        self.running = false;
        self.listener = None;
        info!("WebSocket server stopped");
    }

    pub async fn get_connected_device(&self) -> Option<ConnectionStatus> {
        let connections = self.connections.read().await;
        for conn in connections.values() {
            if matches!(conn.state, ConnectionState::Paired | ConnectionState::Listening) {
                return Some(ConnectionStatus {
                    connected: true,
                    name: conn.device_name.clone(),
                    device_id: conn.device_id.clone(),
                });
            }
        }
        None
    }

    pub async fn broadcast(&self, message: &str) -> Result<(), String> {
        let connections = self.connections.read().await;
        for conn in connections.values() {
            if let Some(ref mut writer) = *conn.writer.lock().await {
                writer.send(Message::Text(message.to_string())).await.ok();
            }
        }
        Ok(())
    }

    pub async fn send_to_device(&self, device_id: &str, message: &str) -> Result<(), String> {
        let connections = self.connections.read().await;
        if let Some(conn) = connections.get(device_id) {
            if let Some(ref mut writer) = *conn.writer.lock().await {
                writer.send(Message::Text(message.to_string())).await.map_err(|e| e.to_string())?;
            }
        }
        Ok(())
    }

    pub async fn disconnect_device(&self, device_id: &str) {
        let mut connections = self.connections.write().await;
        if let Some(conn) = connections.get_mut(device_id) {
            if let Some(ref mut writer) = *conn.writer.lock().await {
                let close_msg = Message::Close(None);
                writer.send(close_msg).await.ok();
            }
        }
    }
}

impl Default for ConnectionManager {
    fn default() -> Self {
        Self::new()
    }
}

async fn handle_connection(
    stream: TcpStream,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: Arc<Mutex<PairingManager>>,
) -> Result<(), String> {
    let ws_stream = accept_async(stream)
        .await
        .map_err(|e| format!("WebSocket handshake failed: {}", e))?;

    let (writer, mut reader) = ws_stream.split();
    let conn_id = Uuid::new_v4().to_string();
    let connect_time = Instant::now();

    // Add connection in pending state
    {
        let mut conns = connections.write().await;
        conns.insert(conn_id.clone(), Connection {
            id: conn_id.clone(),
            device_id: None,
            device_name: None,
            state: ConnectionState::Pending,
            writer: Arc::new(Mutex::new(Some(writer))),
            last_pong: None,
            secret_key: None,
            asr_session: None,
            event_emitter: Arc::new(Mutex::new(EventEmitter::new())),
        });
    }

    info!("Connection {} established", conn_id);

    // Spawn heartbeat task
    let heartbeat_conn_id = conn_id.clone();
    let heartbeat_connections = connections.clone();
    let heartbeat_running = Arc::new(std::sync::atomic::AtomicBool::new(true));
    let heartbeat_running_cleanup = heartbeat_running.clone();

    let heartbeat_handle = tokio::spawn(async move {
        while heartbeat_running.load(std::sync::atomic::Ordering::Relaxed) {
            tokio::time::sleep(Duration::from_secs(HEARTBEAT_INTERVAL_SECS)).await;

            if !heartbeat_running.load(std::sync::atomic::Ordering::Relaxed) {
                break;
            }

            let conns = heartbeat_connections.read().await;
            if let Some(conn) = conns.get(&heartbeat_conn_id) {
                // Check for stale connection (no pong received)
                if let Some(last_pong) = conn.last_pong {
                    if last_pong.elapsed() > Duration::from_secs(CONNECTION_TIMEOUT_SECS) {
                        warn!("Connection {} heartbeat timeout", heartbeat_conn_id);
                        heartbeat_running.store(false, std::sync::atomic::Ordering::Relaxed);
                        break;
                    }
                }

                // Send ping
                let ping_msg = serde_json::json!({
                    "id": Uuid::new_v4().to_string(),
                    "type": "ping",
                    "payload": { "nonce": Uuid::new_v4().to_string() }
                });

                // Get writer Arc clone first to release conn borrow
                let writer_arc = conn.writer.clone();
                drop(conns);
                // Then lock and send
                let mut writer_lock = writer_arc.lock().await;
                if let Some(ref mut writer) = *writer_lock {
                    writer.send(Message::Text(ping_msg.to_string())).await.ok();
                }
            } else {
                break;
            }
        }
    });

    // Handle messages
    while let Some(msg) = reader.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                if let Err(e) = process_message(&conn_id, &text, &connections, &pairing_manager).await {
                    warn!("Error processing message from {}: {}", conn_id, e);
                }
            }
            Ok(Message::Binary(data)) => {
                if let Err(e) = process_binary_message(&conn_id, &data, &connections, &pairing_manager).await {
                    warn!("Error processing binary message from {}: {}", conn_id, e);
                }
            }
            Ok(Message::Close(_)) => {
                info!("Connection {} closed by client", conn_id);
                break;
            }
            Ok(Message::Ping(data)) => {
                // Auto-respond to ping with pong
                let conns = connections.read().await;
                if let Some(conn) = conns.get(&conn_id) {
                    let writer_arc = conn.writer.clone();
                    drop(conns);
                    let mut writer_lock = writer_arc.lock().await;
                    if let Some(ref mut writer) = *writer_lock {
                        writer.send(Message::Pong(data)).await.ok();
                    }
                }
            }
            Ok(Message::Pong(_)) => {
                // Update last pong time
                let mut conns = connections.write().await;
                if let Some(conn) = conns.get_mut(&conn_id) {
                    conn.last_pong = Some(Instant::now());
                }
            }
            Err(e) => {
                error!("Error reading message from {}: {}", conn_id, e);
                break;
            }
            _ => {}
        }

        // Check connection age
        if connect_time.elapsed() > Duration::from_secs(CONNECTION_TIMEOUT_SECS * 2) {
            warn!("Connection {} timed out", conn_id);
            break;
        }
    }

    // Cleanup
    heartbeat_running_cleanup.store(false, std::sync::atomic::Ordering::Relaxed);
    heartbeat_handle.abort();

    {
        let mut conns = connections.write().await;
        let should_emit = {
            if let Some(conn) = conns.get(&conn_id) {
                info!("Connection {} ({}) disconnected", conn_id, conn.device_name.as_deref().unwrap_or("unknown"));
                matches!(conn.state, ConnectionState::Paired | ConnectionState::Listening)
            } else {
                false
            }
        };
        
        if should_emit {
            if let Some(conn) = conns.get(&conn_id) {
                let emitter = conn.event_emitter.clone();
                let device_name = conn.device_name.clone();
                let emitter_guard = emitter.lock().await;
                emitter_guard.emit_connection_changed(false, device_name, None);
            }
        }
        
        conns.remove(&conn_id);
    }

    Ok(())
}

async fn process_message(
    conn_id: &str,
    text: &str,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
) -> Result<(), String> {
    let msg: Envelope = serde_json::from_str(text)
        .map_err(|e| format!("Invalid JSON: {}", e))?;

    let msg_type = MessageType::from_str(&msg.type_).ok_or("Unknown message type")?;

    info!("Processing message type: {:?} from connection {}", msg_type, conn_id);

    match msg_type {
        MessageType::PairRequest => {
            handle_pair_request(conn_id, &msg, connections, pairing_manager).await?;
        }
        MessageType::PairConfirm => {
            handle_pair_confirm(conn_id, &msg, connections, pairing_manager).await?;
        }
        MessageType::PairSuccess => {
            handle_pair_success(conn_id, &msg, connections, pairing_manager).await?;
        }
        MessageType::StartListen => {
            handle_start_listen(conn_id, &msg, connections).await?;
        }
        MessageType::StopListen => {
            handle_stop_listen(conn_id, &msg, connections).await?;
        }
        MessageType::AudioStart => {
            handle_audio_start(conn_id, &msg, connections, &None).await?;
        }
        MessageType::AudioData => {
            handle_audio_data(conn_id, &msg, connections).await?;
        }
        MessageType::AudioEnd => {
            handle_audio_end(conn_id, &msg, connections).await?;
        }
        MessageType::Ping => {
            handle_ping(conn_id, &msg, connections).await?;
        }
        MessageType::Pong => {
            handle_pong(conn_id, connections).await?;
        }
        MessageType::Result | MessageType::PartialResult => {
            // Forward results to the frontend via event
            info!("Received {:?} from device", msg_type);
            
            // Extract result data
            if let Some(obj) = msg.payload.as_object() {
                let text = obj.get("text").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let language = obj.get("language").and_then(|v| v.as_str()).unwrap_or("zh-CN").to_string();
                let session_id = obj.get("session_id").and_then(|v| v.as_str()).unwrap_or("").to_string();
                
                // Get device name
                let device_name = {
                    let conns = connections.read().await;
                    conns.get(conn_id).and_then(|c| c.device_name.clone())
                };
                
                // Emit appropriate event
                let conns = connections.read().await;
                if let Some(conn) = conns.get(conn_id) {
                    let emitter = conn.event_emitter.clone();
                    drop(conns);
                    
                    let emitter_guard = emitter.lock().await;
                    if msg_type == MessageType::Result {
                        emitter_guard.emit_recognition_result(text, language, session_id, device_name);
                    } else {
                        emitter_guard.emit_partial_result(text, language, session_id);
                    }
                }
            }
        }
        MessageType::Error => {
            if let Some(payload) = msg.payload.as_object() {
                let code = payload.get("code").and_then(|v| v.as_str()).unwrap_or("UNKNOWN");
                let message = payload.get("message").and_then(|v| v.as_str()).unwrap_or("Unknown error");
                error!("Device error: {} - {}", code, message);
            }
        }
    }

    Ok(())
}

async fn process_binary_message(
    conn_id: &str,
    data: &[u8],
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    _pairing_manager: &Arc<Mutex<PairingManager>>,
) -> Result<(), String> {
    // Binary messages are typically audio data
    let conns = connections.read().await;
    if let Some(conn) = conns.get(conn_id) {
        if matches!(conn.state, ConnectionState::Listening) {
            // Forward audio data to speech recognition
            info!("Received {} bytes of audio data from {}", data.len(), conn_id);
        }
    }
    Ok(())
}

async fn handle_pair_request(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
) -> Result<(), String> {
    let payload: PairRequestPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid pairRequest payload: {}", e))?;

    info!("Pair request: device={}, code={}", payload.mac_id, payload.short_code);

    let mut manager = pairing_manager.lock().await;

    // Check if pairing is locked due to failed attempts
    if manager.is_locked() {
        let response = serde_json::json!({
            "id": Uuid::new_v4().to_string(),
            "type": "error",
            "payload": { "code": "LOCKED", "message": "Too many failed attempts. Please try again later." }
        });
        send_to_connection(conn_id, &response.to_string(), connections).await;
        return Err("Pairing is locked".to_string());
    }

    // Verify the pairing code
    if !manager.is_valid_code(&payload.short_code) {
        manager.record_failed_attempt();
        let remaining = manager.get_remaining_attempts();

        let response = serde_json::json!({
            "id": Uuid::new_v4().to_string(),
            "type": "error",
            "payload": {
                "code": "INVALID_CODE",
                "message": format!("Invalid pairing code. {} attempts remaining", remaining)
            }
        });
        send_to_connection(conn_id, &response.to_string(), connections).await;
        return Err("Invalid pairing code".to_string());
    }

    // Store pending device info
    manager.set_pending_device(payload.mac_id.clone(), payload.mac_name.clone());

    // Update connection state
    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.device_id = Some(payload.mac_id.clone());
            conn.device_name = Some(payload.mac_name.clone());
            conn.state = ConnectionState::Pairing;
        }
    }

    // Send pair confirm response
    let response = serde_json::json!({
        "id": Uuid::new_v4().to_string(),
        "type": "pairConfirm",
        "payload": {
            "short_code": payload.short_code,
            "ios_name": payload.mac_name,
            "ios_id": payload.mac_id
        }
    });
    send_to_connection(conn_id, &response.to_string(), connections).await;

    Ok(())
}

async fn handle_pair_confirm(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
) -> Result<(), String> {
    let payload: PairConfirmPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid pairConfirm payload: {}", e))?;

    let mut manager = pairing_manager.lock().await;

    // Get the secret key generated for this pairing
    let secret_key = manager.confirm_pairing(&payload.ios_id, &payload.ios_name);

    // Update connection with secret key
    let device_name = payload.ios_name.clone();
    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.secret_key = Some(secret_key.clone());
            conn.state = ConnectionState::Paired;
            conn.device_name = Some(device_name.clone());
            
            // Emit connection-changed event
            let emitter = conn.event_emitter.clone();
            drop(conns);
            
            let emitter_guard = emitter.lock().await;
            emitter_guard.emit_connection_changed(true, Some(device_name.clone()), Some(payload.ios_id.clone()));
        }
    }

    // Send pair success
    let response = serde_json::json!({
        "id": Uuid::new_v4().to_string(),
        "type": "pairSuccess",
        "payload": {
            "shared_secret": secret_key
        }
    });
    send_to_connection(conn_id, &response.to_string(), connections).await;

    info!("Device {} paired successfully", payload.ios_name);

    Ok(())
}

async fn handle_pair_success(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
) -> Result<(), String> {
    // Pair success received from iOS device - pairing is complete
    let payload: PairSuccessPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid pairSuccess payload: {}", e))?;

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.state = ConnectionState::Paired;
            conn.secret_key = Some(payload.shared_secret);
        }
    }

    info!("Pairing confirmed with shared secret");

    Ok(())
}

async fn handle_start_listen(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: StartListenPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid startListen payload: {}", e))?;

    let session_id = payload.session_id.clone();
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        if matches!(conn.state, ConnectionState::Paired) {
            conn.state = ConnectionState::Listening;
            info!("Device {} started listening, session: {}", conn.device_name.as_deref().unwrap_or("?"), session_id);
            
            // Emit listening-started event
            let emitter = conn.event_emitter.clone();
            let device_name = conn.device_name.clone();
            
            let emitter_guard = emitter.lock().await;
            emitter_guard.emit_listening_started(session_id.clone(), device_name);
        }
    }

    Ok(())
}

async fn handle_stop_listen(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: StopListenPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid stopListen payload: {}", e))?;

    let session_id = payload.session_id.clone();
    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            if matches!(conn.state, ConnectionState::Listening) {
                conn.state = ConnectionState::Paired;
                info!("Device {} stopped listening, session: {}", conn.device_name.as_deref().unwrap_or("?"), session_id);
                
                // Emit listening-stopped event
                let emitter = conn.event_emitter.clone();
                drop(conns);
                
                let emitter_guard = emitter.lock().await;
                emitter_guard.emit_listening_stopped(session_id);
            }
        }
    }

    Ok(())
}

async fn handle_audio_start(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    asr_provider: &Option<VeAnchorProvider>,
) -> Result<(), String> {
    let payload: AudioStartPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid audioStart payload: {}", e))?;

    info!("Audio stream started: session={}, lang={}, rate={}, channels={}, format={}",
        payload.session_id, payload.language, payload.sample_rate, payload.channels, payload.format);

    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        conn.state = ConnectionState::Listening;

        // Create ASR session if provider is available
        if let Some(provider) = asr_provider {
            let callback = {
                move |result: AsrResult| {
                    if result.is_final && !result.text.is_empty() {
                        info!("ASR final result: {}", result.text);

                        // Create injector based on settings (default to keyboard)
                        let injector = injection::TextInjector::new(injection::InjectionMethod::Keyboard);

                        // Perform text injection
                        if let Err(e) = injector.inject(&result.text) {
                            error!("Text injection failed: {}", e);
                            // Fallback to clipboard if keyboard fails
                            let clipboard_injector = injection::TextInjector::new(injection::InjectionMethod::Clipboard);
                            if let Err(e2) = clipboard_injector.inject(&result.text) {
                                error!("Clipboard injection also failed: {}", e2);
                            }
                        } else {
                            info!("Text injected successfully");
                        }
                    }
                }
            };

            match provider.create_session(Arc::new(callback)) {
                Ok(session) => {
                    conn.asr_session = Some(session);
                    info!("ASR session created for connection {}", conn_id);
                }
                Err(e) => {
                    error!("Failed to create ASR session: {}", e);
                }
            }
        }
    }

    Ok(())
}

async fn handle_audio_data(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: AudioDataPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid audioData payload: {}", e))?;

    // Forward to ASR if session exists
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        if let Some(ref mut session) = conn.asr_session {
            if let Err(e) = session.send_audio(&payload.audio_data).await {
                warn!("Failed to send audio to ASR: {}", e);
            }
        }
    }

    Ok(())
}

async fn handle_audio_end(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: AudioEndPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid audioEnd payload: {}", e))?;

    info!("Audio stream ended: session={}", payload.session_id);

    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        // Finish ASR session
        if let Some(ref mut session) = conn.asr_session {
            if let Err(e) = session.finish().await {
                error!("Failed to finish ASR session: {}", e);
            }
        }
        conn.asr_session = None;
        conn.state = ConnectionState::Paired;
    }

    Ok(())
}

async fn handle_ping(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: PingPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid ping payload: {}", e))?;

    // Respond with pong using the same nonce
    let response = serde_json::json!({
        "id": Uuid::new_v4().to_string(),
        "type": "pong",
        "payload": {
            "nonce": payload.nonce
        }
    });
    send_to_connection(conn_id, &response.to_string(), connections).await;

    Ok(())
}

async fn handle_pong(
    conn_id: &str,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        conn.last_pong = Some(Instant::now());
    }
    Ok(())
}

async fn send_to_connection(
    conn_id: &str,
    message: &str,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) {
    let conns = connections.read().await;
    if let Some(conn) = conns.get(conn_id) {
        if let Some(ref mut writer) = *conn.writer.lock().await {
            writer.send(Message::Text(message.to_string())).await.ok();
        }
    }
}

/// Verify HMAC signature for a message
pub fn verify_hmac(message: &str, signature: &str, key: &str) -> bool {
    let Ok(mut mac) = HmacSha256::new_from_slice(key.as_bytes()) else {
        return false;
    };
    mac.update(message.as_bytes());

    let Ok(decoded_sig) = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, signature) else {
        return false;
    };

    mac.verify_slice(&decoded_sig).is_ok()
}

/// Generate HMAC signature for a message
pub fn generate_hmac(message: &str, key: &str) -> String {
    let mut mac = HmacSha256::new_from_slice(key.as_bytes()).expect("HMAC can take key of any size");
    mac.update(message.as_bytes());
    let result = mac.finalize();
    base64::Engine::encode(&base64::engine::general_purpose::STANDARD, result.into_bytes())
}
