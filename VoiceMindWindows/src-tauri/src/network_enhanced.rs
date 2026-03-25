// 增强版网络通信模块 - 添加发送控制消息和事件通知功能

use crate::pairing::PairingManager;
use crate::commands::ConnectionStatus;
use crate::asr::{AsrSession, AsrResult, VeAnchorProvider};
use crate::injection;
use crate::speech::HistoryItem;
use futures_util::{SinkExt, StreamExt};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tauri::{AppHandle, Emitter};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{Mutex, RwLock};
use tokio_tungstenite::{accept_async, tungstenite::Message};
use tracing::{error, info, warn};
use uuid::Uuid;

type HmacSha256 = Hmac<Sha256>;

const HEARTBEAT_INTERVAL_SECS: u64 = 30;
const CONNECTION_TIMEOUT_SECS: u64 = 60;

/// 增强的连接管理器，支持事件通知
pub struct EnhancedConnectionManager {
    server_port: u16,
    connections: Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    listener: Option<Arc<Mutex<TcpListener>>>,
    running: bool,
    app_handle: Option<AppHandle>,
}

pub struct EnhancedConnection {
    pub id: String,
    pub device_id: Option<String>,
    pub device_name: Option<String>,
    pub state: EnhancedConnectionState,
    pub writer: Arc<Mutex<Option<futures_util::stream::SplitSink<TokioWebSocket, Message>>>>,
    pub last_pong: Option<Instant>,
    pub secret_key: Option<String>,
    pub asr_session: Option<AsrSession>,
    pub current_session_id: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum EnhancedConnectionState {
    Pending,
    Pairing,
    Paired,
    Listening,
}

pub type TokioWebSocket = tokio_tungstenite::WebSocketStream<TcpStream>;

impl EnhancedConnectionManager {
    pub fn new() -> Self {
        Self {
            server_port: 8765,
            connections: Arc::new(RwLock::new(HashMap::new())),
            listener: None,
            running: false,
            app_handle: None,
        }
    }

    pub fn set_app_handle(&mut self, handle: AppHandle) {
        self.app_handle = Some(handle);
    }

    pub async fn start_server(&mut self, port: u16, pairing_manager: Arc<Mutex<PairingManager>>) -> Result<(), String> {
        self.server_port = port;
        let addr = format!("0.0.0.0:{}", port);

        let listener = TcpListener::bind(&addr)
            .await
            .map_err(|e| format!("Failed to bind to {}: {}", addr, e))?;

        info!("Enhanced WebSocket server listening on {}", addr);
        self.running = true;

        let listener_arc = Arc::new(Mutex::new(listener));
        self.listener = Some(listener_arc.clone());
        let connections = self.connections.clone();
        let running = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let app_handle = self.app_handle.clone();

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
                            conns.values().any(|c| matches!(c.state, EnhancedConnectionState::Paired))
                        };

                        if has_paired {
                            info!("Rejecting new connection - already have a paired device");
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
                        let app_handle = app_handle.clone();

                        tokio::spawn(async move {
                            if let Err(e) = handle_enhanced_connection(stream, connections, pairing_manager, app_handle).await {
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
        info!("Enhanced WebSocket server stopped");
    }

    pub async fn get_connected_device(&self) -> Option<ConnectionStatus> {
        let connections = self.connections.read().await;
        for conn in connections.values() {
            if matches!(conn.state, EnhancedConnectionState::Paired | EnhancedConnectionState::Listening) {
                return Some(ConnectionStatus {
                    connected: true,
                    name: conn.device_name.clone(),
                    device_id: conn.device_id.clone(),
                });
            }
        }
        None
    }

    /// 发送开始聆听消息给iOS设备
    pub async fn start_listening(&self, session_id: String) -> Result<(), String> {
        let connections = self.connections.read().await;
        
        for (conn_id, conn) in connections.iter() {
            if matches!(conn.state, EnhancedConnectionState::Paired) {
                let message = serde_json::json!({
                    "id": Uuid::new_v4().to_string(),
                    "type": "startListen",
                    "payload": {
                        "session_id": session_id
                    }
                });
                
                if let Some(ref mut writer) = *conn.writer.lock().await {
                    writer.send(Message::Text(message.to_string())).await.map_err(|e| e.to_string())?;
                    info!("Sent startListen to device {}, session: {}", conn_id, session_id);
                    
                    // Update connection state
                    drop(writer);
                    drop(connections);
                    
                    let mut conns = self.connections.write().await;
                    if let Some(c) = conns.get_mut(conn_id) {
                        c.state = EnhancedConnectionState::Listening;
                        c.current_session_id = Some(session_id);
                    }
                    
                    return Ok(());
                }
            }
        }
        
        Err("No paired device connected".to_string())
    }

    /// 发送停止聆听消息给iOS设备
    pub async fn stop_listening(&self) -> Result<(), String> {
        let connections = self.connections.read().await;
        
        for (conn_id, conn) in connections.iter() {
            if matches!(conn.state, EnhancedConnectionState::Listening) {
                let session_id = conn.current_session_id.clone().unwrap_or_else(|| Uuid::new_v4().to_string());
                
                let message = serde_json::json!({
                    "id": Uuid::new_v4().to_string(),
                    "type": "stopListen",
                    "payload": {
                        "session_id": session_id
                    }
                });
                
                if let Some(ref mut writer) = *conn.writer.lock().await {
                    writer.send(Message::Text(message.to_string())).await.map_err(|e| e.to_string())?;
                    info!("Sent stopListen to device {}", conn_id);
                    
                    // Update connection state
                    drop(writer);
                    drop(connections);
                    
                    let mut conns = self.connections.write().await;
                    if let Some(c) = conns.get_mut(conn_id) {
                        c.state = EnhancedConnectionState::Paired;
                        c.current_session_id = None;
                    }
                    
                    return Ok(());
                }
            }
        }
        
        Err("No listening device".to_string())
    }
}

async fn handle_enhanced_connection(
    stream: TcpStream,
    connections: Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    pairing_manager: Arc<Mutex<PairingManager>>,
    app_handle: Option<AppHandle>,
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
        conns.insert(conn_id.clone(), EnhancedConnection {
            id: conn_id.clone(),
            device_id: None,
            device_name: None,
            state: EnhancedConnectionState::Pending,
            writer: Arc::new(Mutex::new(Some(writer))),
            last_pong: None,
            secret_key: None,
            asr_session: None,
            current_session_id: None,
        });
    }

    info!("Enhanced connection {} established", conn_id);

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
                if let Some(last_pong) = conn.last_pong {
                    if last_pong.elapsed() > Duration::from_secs(CONNECTION_TIMEOUT_SECS) {
                        warn!("Connection {} heartbeat timeout", heartbeat_conn_id);
                        heartbeat_running.store(false, std::sync::atomic::Ordering::Relaxed);
                        break;
                    }
                }

                let ping_msg = serde_json::json!({
                    "id": Uuid::new_v4().to_string(),
                    "type": "ping",
                    "payload": { "nonce": Uuid::new_v4().to_string() }
                });

                let writer_arc = conn.writer.clone();
                drop(conns);
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
                if let Err(e) = process_enhanced_message(&conn_id, &text, &connections, &pairing_manager, &app_handle).await {
                    warn!("Error processing message from {}: {}", conn_id, e);
                }
            }
            Ok(Message::Binary(data)) => {
                // Binary audio data handling
                info!("Received {} bytes of binary audio data", data.len());
            }
            Ok(Message::Close(_)) => {
                info!("Connection {} closed by client", conn_id);
                break;
            }
            Ok(Message::Ping(data)) => {
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
        if let Some(conn) = conns.get(&conn_id) {
            info!("Enhanced connection {} ({}) disconnected", conn_id, conn.device_name.as_deref().unwrap_or("unknown"));
            
            // Emit disconnection event
            if let Some(ref handle) = app_handle {
                handle.emit("connection-changed", serde_json::json!({
                    "connected": false,
                    "name": conn.device_name.clone(),
                    "listening": false
                })).ok();
            }
        }
        conns.remove(&conn_id);
    }

    Ok(())
}

async fn process_enhanced_message(
    conn_id: &str,
    text: &str,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    #[derive(Debug, serde::Deserialize)]
    struct Envelope {
        #[serde(rename = "type")]
        pub type_: String,
        pub payload: serde_json::Value,
    }

    let msg: Envelope = serde_json::from_str(text)
        .map_err(|e| format!("Invalid JSON: {}", e))?;

    info!("Processing enhanced message type: {} from connection {}", msg.type_, conn_id);

    match msg.type_.as_str() {
        "pairRequest" => {
            handle_enhanced_pair_request(conn_id, &msg.payload, connections, pairing_manager, app_handle).await?;
        }
        "pairConfirm" => {
            handle_enhanced_pair_confirm(conn_id, &msg.payload, connections, pairing_manager, app_handle).await?;
        }
        "pairSuccess" => {
            // Pair success from iOS
            info!("Pairing successful from iOS");
        }
        "startListen" => {
            handle_enhanced_start_listen(conn_id, &msg.payload, connections, app_handle).await?;
        }
        "stopListen" => {
            handle_enhanced_stop_listen(conn_id, &msg.payload, connections, app_handle).await?;
        }
        "result" => {
            handle_enhanced_result(conn_id, &msg.payload, connections, app_handle).await?;
        }
        "partialResult" => {
            handle_enhanced_partial_result(conn_id, &msg.payload, connections, app_handle).await?;
        }
        "audioStart" => {
            info!("Audio stream started");
        }
        "audioEnd" => {
            info!("Audio stream ended");
        }
        "ping" => {
            let nonce = msg.payload.get("nonce").and_then(|v| v.as_str()).unwrap_or("");
            send_pong(conn_id, nonce, connections).await;
        }
        "pong" => {
            let mut conns = connections.write().await;
            if let Some(conn) = conns.get_mut(conn_id) {
                conn.last_pong = Some(Instant::now());
            }
        }
        "error" => {
            if let Some(code) = msg.payload.get("code").and_then(|v| v.as_str()) {
                if let Some(message) = msg.payload.get("message").and_then(|v| v.as_str()) {
                    error!("Device error: {} - {}", code, message);
                }
            }
        }
        _ => {
            warn!("Unknown message type: {}", msg.type_);
        }
    }

    Ok(())
}

async fn handle_enhanced_pair_request(
    conn_id: &str,
    payload: &serde_json::Value,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    let short_code = payload.get("short_code").and_then(|v| v.as_str()).unwrap_or("");
    let mac_id = payload.get("mac_id").and_then(|v| v.as_str()).unwrap_or("");
    let mac_name = payload.get("mac_name").and_then(|v| v.as_str()).unwrap_or("Unknown");

    info!("Pair request: device={}, code={}", mac_id, short_code);

    let mut manager = pairing_manager.lock().await;

    if manager.is_locked() {
        let response = serde_json::json!({
            "id": Uuid::new_v4().to_string(),
            "type": "error",
            "payload": { "code": "LOCKED", "message": "Too many failed attempts" }
        });
        send_to_enhanced_connection(conn_id, &response.to_string(), connections).await;
        return Err("Pairing is locked".to_string());
    }

    if !manager.is_valid_code(short_code) {
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
        send_to_enhanced_connection(conn_id, &response.to_string(), connections).await;
        return Err("Invalid pairing code".to_string());
    }

    manager.set_pending_device(mac_id.to_string(), mac_name.to_string());

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.device_id = Some(mac_id.to_string());
            conn.device_name = Some(mac_name.to_string());
            conn.state = EnhancedConnectionState::Pairing;
        }
    }

    let response = serde_json::json!({
        "id": Uuid::new_v4().to_string(),
        "type": "pairConfirm",
        "payload": {
            "short_code": short_code,
            "ios_name": mac_name,
            "ios_id": mac_id
        }
    });
    send_to_enhanced_connection(conn_id, &response.to_string(), connections).await;

    Ok(())
}

async fn handle_enhanced_pair_confirm(
    conn_id: &str,
    payload: &serde_json::Value,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    let ios_id = payload.get("ios_id").and_then(|v| v.as_str()).unwrap_or("");
    let ios_name = payload.get("ios_name").and_then(|v| v.as_str()).unwrap_or("Unknown iPhone");

    let mut manager = pairing_manager.lock().await;
    let secret_key = manager.confirm_pairing(ios_id, ios_name);

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.secret_key = Some(secret_key.clone());
            conn.state = EnhancedConnectionState::Paired;
        }
    }

    let response = serde_json::json!({
        "id": Uuid::new_v4().to_string(),
        "type": "pairSuccess",
        "payload": {
            "shared_secret": secret_key
        }
    });
    send_to_enhanced_connection(conn_id, &response.to_string(), connections).await;

    info!("Device {} paired successfully", ios_name);

    // Emit connection event
    if let Some(ref handle) = app_handle {
        handle.emit("connection-changed", serde_json::json!({
            "connected": true,
            "name": ios_name,
            "listening": false
        })).ok();
    }

    Ok(())
}

async fn handle_enhanced_start_listen(
    conn_id: &str,
    payload: &serde_json::Value,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    let session_id = payload.get("session_id").and_then(|v| v.as_str()).unwrap_or("");

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            if matches!(conn.state, EnhancedConnectionState::Paired) {
                conn.state = EnhancedConnectionState::Listening;
                conn.current_session_id = Some(session_id.to_string());
                info!("Device {} started listening, session: {}", conn.device_name.as_deref().unwrap_or("?"), session_id);
            }
        }
    }

    // Emit listening started event
    if let Some(ref handle) = app_handle {
        let device_name = {
            let conns = connections.read().await;
            conns.get(conn_id).and_then(|c| c.device_name.clone())
        };
        
        handle.emit("listening-started", serde_json::json!({
            "session_id": session_id,
            "device_name": device_name.unwrap_or_default()
        })).ok();
    }

    Ok(())
}

async fn handle_enhanced_stop_listen(
    conn_id: &str,
    payload: &serde_json::Value,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    let session_id = payload.get("session_id").and_then(|v| v.as_str()).unwrap_or("");

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            if matches!(conn.state, EnhancedConnectionState::Listening) {
                conn.state = EnhancedConnectionState::Paired;
                conn.current_session_id = None;
                info!("Device {} stopped listening, session: {}", conn.device_name.as_deref().unwrap_or("?"), session_id);
            }
        }
    }

    // Emit listening stopped event
    if let Some(ref handle) = app_handle {
        handle.emit("listening-stopped", serde_json::json!({
            "session_id": session_id
        })).ok();
    }

    Ok(())
}

async fn handle_enhanced_result(
    conn_id: &str,
    payload: &serde_json::Value,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    let session_id = payload.get("session_id").and_then(|v| v.as_str()).unwrap_or("");
    let text = payload.get("text").and_then(|v| v.as_str()).unwrap_or("");
    let language = payload.get("language").and_then(|v| v.as_str()).unwrap_or("zh-CN");

    info!("Received recognition result: {} (session: {})", text, session_id);

    // Inject text
    let injector = injection::TextInjector::new(injection::InjectionMethod::Keyboard);
    if let Err(e) = injector.inject(text) {
        error!("Text injection failed: {}", e);
        // Fallback to clipboard
        let clipboard_injector = injection::TextInjector::new(injection::InjectionMethod::Clipboard);
        if let Err(e2) = clipboard_injector.inject(text) {
            error!("Clipboard injection also failed: {}", e2);
        }
    } else {
        info!("Text injected successfully");
    }

    // Emit recognition result event
    if let Some(ref handle) = app_handle {
        let device_name = {
            let conns = connections.read().await;
            conns.get(conn_id).and_then(|c| c.device_name.clone())
        };
        
        handle.emit("recognition-result", serde_json::json!({
            "session_id": session_id,
            "text": text,
            "language": language,
            "device_name": device_name.unwrap_or_default(),
            "source": "ios"
        })).ok();
    }

    Ok(())
}

async fn handle_enhanced_partial_result(
    conn_id: &str,
    payload: &serde_json::Value,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
    app_handle: &Option<AppHandle>,
) -> Result<(), String> {
    let session_id = payload.get("session_id").and_then(|v| v.as_str()).unwrap_or("");
    let text = payload.get("text").and_then(|v| v.as_str()).unwrap_or("");
    let language = payload.get("language").and_then(|v| v.as_str()).unwrap_or("zh-CN");

    info!("Received partial result: {} (session: {})", text, session_id);

    // Emit partial result event
    if let Some(ref handle) = app_handle {
        handle.emit("partial-result", serde_json::json!({
            "session_id": session_id,
            "text": text,
            "language": language
        })).ok();
    }

    Ok(())
}

async fn send_pong(conn_id: &str, nonce: &str, connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>) {
    let response = serde_json::json!({
        "id": Uuid::new_v4().to_string(),
        "type": "pong",
        "payload": {
            "nonce": nonce
        }
    });
    send_to_enhanced_connection(conn_id, &response.to_string(), connections).await;
}

async fn send_to_enhanced_connection(
    conn_id: &str,
    message: &str,
    connections: &Arc<RwLock<HashMap<String, EnhancedConnection>>>,
) {
    let conns = connections.read().await;
    if let Some(conn) = conns.get(conn_id) {
        if let Some(ref mut writer) = *conn.writer.lock().await {
            writer.send(Message::Text(message.to_string())).await.ok();
        }
    }
}

impl Default for EnhancedConnectionManager {
    fn default() -> Self {
        Self::new()
    }
}
