use crate::commands::ConnectionStatus;
use crate::events::EventEmitter;
use crate::injection;
use crate::pairing::PairingManager;
use base64::{engine::general_purpose::STANDARD, Engine};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::tcp::{OwnedReadHalf, OwnedWriteHalf};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{Mutex, RwLock};
use tracing::{error, info, warn};
use uuid::Uuid;

const HEARTBEAT_INTERVAL_SECS: u64 = 30;
const CONNECTION_TIMEOUT_SECS: u64 = 60;

#[derive(Debug, Clone, PartialEq)]
pub enum ConnectionState {
    Pending,
    Pairing,
    Paired,
    Listening,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MessageType {
    PairConfirm,
    PairSuccess,
    StartListen,
    StopListen,
    Result,
    TextMessage,
    PartialResult,
    Ping,
    Pong,
    Error,
    AudioStart,
    AudioData,
    AudioEnd,
}

impl MessageType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::PairConfirm => "pairConfirm",
            Self::PairSuccess => "pairSuccess",
            Self::StartListen => "startListen",
            Self::StopListen => "stopListen",
            Self::Result => "result",
            Self::TextMessage => "textMessage",
            Self::PartialResult => "partialResult",
            Self::Ping => "ping",
            Self::Pong => "pong",
            Self::Error => "error",
            Self::AudioStart => "audioStart",
            Self::AudioData => "audioData",
            Self::AudioEnd => "audioEnd",
        }
    }

    pub fn from_str(value: &str) -> Option<Self> {
        match value {
            "pairConfirm" => Some(Self::PairConfirm),
            "pairSuccess" => Some(Self::PairSuccess),
            "startListen" => Some(Self::StartListen),
            "stopListen" => Some(Self::StopListen),
            "result" => Some(Self::Result),
            "textMessage" => Some(Self::TextMessage),
            "partialResult" => Some(Self::PartialResult),
            "ping" => Some(Self::Ping),
            "pong" => Some(Self::Pong),
            "error" => Some(Self::Error),
            "audioStart" => Some(Self::AudioStart),
            "audioData" => Some(Self::AudioData),
            "audioEnd" => Some(Self::AudioEnd),
            _ => None,
        }
    }
}

mod payload_base64 {
    use super::*;
    use serde::{Deserializer, Serializer};

    pub fn serialize<S>(bytes: &Vec<u8>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&STANDARD.encode(bytes))
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        STANDARD.decode(value).map_err(serde::de::Error::custom)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Envelope {
    #[serde(rename = "type")]
    pub type_: String,
    #[serde(with = "payload_base64")]
    pub payload: Vec<u8>,
    pub timestamp: f64,
    #[serde(rename = "deviceId")]
    pub device_id: String,
    pub hmac: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PairConfirmPayload {
    pub short_code: String,
    pub ios_name: String,
    pub ios_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PairSuccessPayload {
    pub shared_secret: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StartListenPayload {
    pub session_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StopListenPayload {
    pub session_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResultPayload {
    pub session_id: String,
    pub text: String,
    pub language: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TextMessagePayload {
    pub session_id: String,
    pub text: String,
    pub language: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PartialResultPayload {
    pub session_id: String,
    pub text: String,
    pub language: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PingPayload {
    pub nonce: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PongPayload {
    pub nonce: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorPayload {
    pub code: String,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioStartPayload {
    pub session_id: String,
    pub language: String,
    pub sample_rate: u32,
    pub channels: u32,
    pub format: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioDataPayload {
    pub session_id: String,
    #[serde(with = "payload_base64")]
    pub audio_data: Vec<u8>,
    pub sequence_number: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioEndPayload {
    pub session_id: String,
}

pub struct Connection {
    pub id: String,
    pub device_id: Option<String>,
    pub device_name: Option<String>,
    pub state: ConnectionState,
    pub writer: Arc<Mutex<OwnedWriteHalf>>,
    pub last_pong: Instant,
    pub secret_key: Option<String>,
    pub current_session_id: Option<String>,
}

pub struct ConnectionManager {
    server_port: u16,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    running: bool,
    event_emitter: Arc<Mutex<EventEmitter>>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            server_port: 8765,
            connections: Arc::new(RwLock::new(HashMap::new())),
            running: false,
            event_emitter: Arc::new(Mutex::new(EventEmitter::new())),
        }
    }

    pub fn set_app_handle(&self, handle: tauri::AppHandle) {
        if let Ok(mut emitter_guard) = self.event_emitter.try_lock() {
            emitter_guard.set_app_handle(handle);
        } else {
            let emitter = self.event_emitter.clone();
            tokio::spawn(async move {
                emitter.lock().await.set_app_handle(handle);
            });
        }
    }

    pub async fn start_server(&mut self, port: u16, pairing_manager: Arc<Mutex<PairingManager>>) -> Result<(), String> {
        self.server_port = port;
        let addr = format!("0.0.0.0:{port}");
        let listener = TcpListener::bind(&addr)
            .await
            .map_err(|e| format!("Failed to bind to {addr}: {e}"))?;

        self.running = true;
        info!("VoiceMind TCP server listening on {}", addr);

        let connections = self.connections.clone();
        let emitter = self.event_emitter.clone();
        tokio::spawn(async move {
            loop {
                match listener.accept().await {
                    Ok((stream, peer_addr)) => {
                        info!("Accepted TCP connection from {}", peer_addr);
                        let conn_id = Uuid::new_v4().to_string();
                        let connections = connections.clone();
                        let pairing_manager = pairing_manager.clone();
                        let emitter = emitter.clone();
                        tokio::spawn(async move {
                            if let Err(err) = handle_connection(conn_id, stream, connections, pairing_manager, emitter).await {
                                error!("Connection handling failed: {}", err);
                            }
                        });
                    }
                    Err(err) => {
                        error!("Accept failed: {}", err);
                    }
                }
            }
        });

        Ok(())
    }

    pub async fn get_connected_device(&self) -> Option<ConnectionStatus> {
        let connections = self.connections.read().await;
        connections.values().find_map(|conn| {
            if matches!(conn.state, ConnectionState::Paired | ConnectionState::Listening) {
                Some(ConnectionStatus {
                    connected: true,
                    name: conn.device_name.clone(),
                    device_id: conn.device_id.clone(),
                })
            } else {
                None
            }
        })
    }

    pub async fn start_listening(&self) -> Result<String, String> {
        let target = {
            let connections = self.connections.read().await;
            connections.iter().find_map(|(id, conn)| {
                if matches!(conn.state, ConnectionState::Paired | ConnectionState::Listening) {
                    Some((id.clone(), conn.secret_key.clone()))
                } else {
                    None
                }
            })
        };

        let (conn_id, secret_key) = target.ok_or_else(|| "No paired iPhone connected".to_string())?;
        let secret_key = secret_key.ok_or_else(|| "Missing shared secret for paired device".to_string())?;
        let session_id = Uuid::new_v4().to_string();
        let payload = StartListenPayload { session_id: session_id.clone() };

        send_envelope_to_connection(
            &conn_id,
            MessageType::StartListen,
            &payload,
            &windows_device_id(),
            Some(&secret_key),
            &self.connections,
        )
        .await?;

        let mut connections = self.connections.write().await;
        if let Some(conn) = connections.get_mut(&conn_id) {
            conn.state = ConnectionState::Listening;
            conn.current_session_id = Some(session_id.clone());
        }

        Ok(session_id)
    }

    pub async fn stop_listening(&self) -> Result<String, String> {
        let target = {
            let connections = self.connections.read().await;
            connections.iter().find_map(|(id, conn)| {
                if matches!(conn.state, ConnectionState::Listening) {
                    Some((id.clone(), conn.secret_key.clone(), conn.current_session_id.clone()))
                } else {
                    None
                }
            })
        };

        let (conn_id, secret_key, session_id) = target.ok_or_else(|| "No active listening session".to_string())?;
        let secret_key = secret_key.ok_or_else(|| "Missing shared secret for paired device".to_string())?;
        let session_id = session_id.unwrap_or_else(|| Uuid::new_v4().to_string());
        let payload = StopListenPayload { session_id: session_id.clone() };

        send_envelope_to_connection(
            &conn_id,
            MessageType::StopListen,
            &payload,
            &windows_device_id(),
            Some(&secret_key),
            &self.connections,
        )
        .await?;

        let mut connections = self.connections.write().await;
        if let Some(conn) = connections.get_mut(&conn_id) {
            conn.state = ConnectionState::Paired;
            conn.current_session_id = None;
        }

        Ok(session_id)
    }
}

impl Default for ConnectionManager {
    fn default() -> Self {
        Self::new()
    }
}

async fn handle_connection(
    conn_id: String,
    stream: TcpStream,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: Arc<Mutex<PairingManager>>,
    event_emitter: Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let (reader, writer) = stream.into_split();
    let writer = Arc::new(Mutex::new(writer));

    {
        let mut conns = connections.write().await;
        conns.insert(
            conn_id.clone(),
            Connection {
                id: conn_id.clone(),
                device_id: None,
                device_name: None,
                state: ConnectionState::Pending,
                writer: writer.clone(),
                last_pong: Instant::now(),
                secret_key: None,
                current_session_id: None,
            },
        );
    }

    let heartbeat_connections = connections.clone();
    let heartbeat_conn_id = conn_id.clone();
    let heartbeat_emitter = event_emitter.clone();
    tokio::spawn(async move {
        heartbeat_loop(heartbeat_conn_id, heartbeat_connections, heartbeat_emitter).await;
    });

    let result = read_loop(&conn_id, reader, &connections, &pairing_manager, &event_emitter).await;

    let disconnected = {
        let mut conns = connections.write().await;
        conns.remove(&conn_id)
    };

    if let Some(conn) = disconnected {
        info!("Connection {} closed", conn.id);
        if matches!(conn.state, ConnectionState::Paired | ConnectionState::Listening) {
            let emitter = event_emitter.lock().await;
            emitter.emit_connection_changed(false, conn.device_name, conn.device_id);
        }
    }

    result
}

async fn read_loop(
    conn_id: &str,
    mut reader: OwnedReadHalf,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    loop {
        let mut length_buf = [0_u8; 4];
        if let Err(err) = reader.read_exact(&mut length_buf).await {
            return Err(format!("Failed reading frame length: {}", err));
        }
        let length = u32::from_be_bytes(length_buf) as usize;
        if length == 0 || length > 10_000_000 {
            return Err(format!("Invalid frame length: {}", length));
        }

        let mut payload = vec![0_u8; length];
        reader
            .read_exact(&mut payload)
            .await
            .map_err(|e| format!("Failed reading frame body: {}", e))?;

        let envelope: Envelope =
            serde_json::from_slice(&payload).map_err(|e| format!("Invalid envelope JSON: {}", e))?;
        process_message(conn_id, envelope, connections, pairing_manager, event_emitter).await?;
    }
}

async fn process_message(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let message_type =
        MessageType::from_str(&envelope.type_).ok_or_else(|| format!("Unknown message type: {}", envelope.type_))?;

    if message_type != MessageType::PairConfirm {
        hydrate_existing_paired_connection(conn_id, &envelope, connections, pairing_manager, event_emitter).await?;
    }

    match message_type {
        MessageType::PairConfirm => handle_pair_confirm(conn_id, envelope, connections, pairing_manager, event_emitter).await,
        MessageType::Ping => handle_ping(conn_id, envelope, connections).await,
        MessageType::Pong => handle_pong(conn_id, connections).await,
        MessageType::Result => handle_result(conn_id, envelope, connections, event_emitter).await,
        MessageType::TextMessage => handle_text_message(conn_id, envelope, connections, event_emitter).await,
        MessageType::PartialResult => handle_partial_result(conn_id, envelope, event_emitter).await,
        MessageType::AudioStart => handle_audio_start(conn_id, envelope, connections).await,
        MessageType::AudioData => handle_audio_data(conn_id, envelope).await,
        MessageType::AudioEnd => handle_audio_end(conn_id, envelope, connections).await,
        MessageType::Error => handle_error(envelope).await,
        MessageType::PairSuccess | MessageType::StartListen | MessageType::StopListen => Ok(()),
    }
}

async fn hydrate_existing_paired_connection(
    conn_id: &str,
    envelope: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let device_id = envelope.device_id.clone();
    let (secret, device_name) = {
        let manager = pairing_manager.lock().await;
        (
            manager.get_device_secret(&device_id),
            manager.get_device_name(&device_id),
        )
    };

    let Some(secret) = secret else {
        return Ok(());
    };

    let expected_hmac = generate_hmac_for_envelope(
        MessageType::from_str(&envelope.type_).ok_or_else(|| format!("Unknown message type: {}", envelope.type_))?,
        &envelope.payload,
        envelope.timestamp,
        &envelope.device_id,
        &secret,
    );

    if envelope.hmac.as_deref() != Some(expected_hmac.as_str()) {
        warn!(
            "Invalid HMAC for device {} message {}",
            envelope.device_id,
            envelope.type_
        );
        return Err(format!("Invalid HMAC for device {}", envelope.device_id));
    }

    let mut just_promoted = false;
    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            let was_connected = matches!(conn.state, ConnectionState::Paired | ConnectionState::Listening);
            conn.device_id = Some(device_id.clone());
            conn.device_name = device_name.clone();
            conn.secret_key = Some(secret);
            conn.last_pong = Instant::now();
            if !matches!(conn.state, ConnectionState::Listening) {
                conn.state = ConnectionState::Paired;
            }
            just_promoted = !was_connected;
        }
    }

    if just_promoted {
        let emitter = event_emitter.lock().await;
        emitter.emit_connection_changed(true, device_name, Some(device_id));
    }

    Ok(())
}

async fn handle_pair_confirm(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let payload: PairConfirmPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid pairConfirm payload: {}", e))?;

    let mut manager = pairing_manager.lock().await;
    if manager.is_locked() {
        return send_error_to_connection(
            conn_id,
            "locked",
            "Too many failed attempts. Please try again later.",
            connections,
        )
        .await;
    }

    if !manager.is_valid_code(&payload.short_code) {
        manager.record_failed_attempt();
        return send_error_to_connection(
            conn_id,
            "invalid_code",
            "Invalid pairing code.",
            connections,
        )
        .await;
    }

    let secret_key = manager.confirm_pairing(&payload.ios_id, &payload.ios_name);
    drop(manager);

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.device_id = Some(payload.ios_id.clone());
            conn.device_name = Some(payload.ios_name.clone());
            conn.secret_key = Some(secret_key.clone());
            conn.state = ConnectionState::Paired;
        }
    }

    let response = PairSuccessPayload { shared_secret: secret_key };
    send_envelope_to_connection(
        conn_id,
        MessageType::PairSuccess,
        &response,
        &windows_device_id(),
        None,
        connections,
    )
    .await?;

    let emitter = event_emitter.lock().await;
    emitter.emit_connection_changed(true, Some(payload.ios_name), Some(payload.ios_id));
    Ok(())
}

async fn handle_ping(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: PingPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid ping payload: {}", e))?;
    let secret = {
        let conns = connections.read().await;
        conns.get(conn_id).and_then(|conn| conn.secret_key.clone())
    };

    let response = PongPayload { nonce: payload.nonce };
    send_envelope_to_connection(
        conn_id,
        MessageType::Pong,
        &response,
        &windows_device_id(),
        secret.as_deref(),
        connections,
    )
    .await
}

async fn handle_pong(
    conn_id: &str,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        conn.last_pong = Instant::now();
    }
    Ok(())
}

async fn handle_result(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let payload: ResultPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid result payload: {}", e))?;
    info!(
        "Received result from {} session {}: {}",
        envelope.device_id,
        payload.session_id,
        payload.text
    );
    let device_name = {
        let conns = connections.read().await;
        conns.get(conn_id).and_then(|conn| conn.device_name.clone())
    };

    inject_text(&payload.text);
    let emitter = event_emitter.lock().await;
    emitter.emit_recognition_result(payload.text, payload.language, payload.session_id, device_name);
    Ok(())
}

async fn handle_text_message(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let payload: TextMessagePayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid textMessage payload: {}", e))?;
    info!(
        "Received text message from {} session {}: {}",
        envelope.device_id,
        payload.session_id,
        payload.text
    );
    let device_name = {
        let conns = connections.read().await;
        conns.get(conn_id).and_then(|conn| conn.device_name.clone())
    };

    inject_text(&payload.text);
    let emitter = event_emitter.lock().await;
    emitter.emit_recognition_result(payload.text, payload.language, payload.session_id, device_name);
    Ok(())
}

async fn handle_partial_result(
    _conn_id: &str,
    envelope: Envelope,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let payload: PartialResultPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid partialResult payload: {}", e))?;
    let emitter = event_emitter.lock().await;
    emitter.emit_partial_result(payload.text, payload.language, payload.session_id);
    Ok(())
}

async fn handle_audio_start(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: AudioStartPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid audioStart payload: {}", e))?;
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        conn.state = ConnectionState::Listening;
        conn.current_session_id = Some(payload.session_id);
    }
    Ok(())
}

async fn handle_audio_data(_conn_id: &str, envelope: Envelope) -> Result<(), String> {
    let _payload: AudioDataPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid audioData payload: {}", e))?;
    Ok(())
}

async fn handle_audio_end(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let _payload: AudioEndPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid audioEnd payload: {}", e))?;
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        conn.state = ConnectionState::Paired;
        conn.current_session_id = None;
    }
    Ok(())
}

async fn handle_error(envelope: Envelope) -> Result<(), String> {
    let payload: ErrorPayload =
        serde_json::from_slice(&envelope.payload).map_err(|e| format!("Invalid error payload: {}", e))?;
    warn!("iOS error: {} - {}", payload.code, payload.message);
    Ok(())
}

async fn heartbeat_loop(
    conn_id: String,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: Arc<Mutex<EventEmitter>>,
) {
    loop {
        tokio::time::sleep(Duration::from_secs(HEARTBEAT_INTERVAL_SECS)).await;

        let snapshot = {
            let conns = connections.read().await;
            conns.get(&conn_id).map(|conn| {
                (
                    conn.state.clone(),
                    conn.last_pong,
                    conn.secret_key.clone(),
                    conn.device_name.clone(),
                    conn.device_id.clone(),
                )
            })
        };

        let Some((state, last_pong, secret_key, device_name, device_id)) = snapshot else {
            return;
        };

        if !matches!(state, ConnectionState::Paired | ConnectionState::Listening) {
            continue;
        }

        if last_pong.elapsed() > Duration::from_secs(CONNECTION_TIMEOUT_SECS) {
            warn!("Connection {} heartbeat timed out", conn_id);
            let mut conns = connections.write().await;
            conns.remove(&conn_id);
            let emitter = event_emitter.lock().await;
            emitter.emit_connection_changed(false, device_name, device_id);
            return;
        }

        let Some(secret_key) = secret_key else {
            continue;
        };

        let payload = PingPayload { nonce: Uuid::new_v4().to_string() };
        if let Err(err) = send_envelope_to_connection(
            &conn_id,
            MessageType::Ping,
            &payload,
            &windows_device_id(),
            Some(&secret_key),
            &connections,
        )
        .await
        {
            warn!("Heartbeat ping failed for {}: {}", conn_id, err);
        }
    }
}

async fn send_envelope_to_connection<T: Serialize>(
    conn_id: &str,
    message_type: MessageType,
    payload: &T,
    device_id: &str,
    secret_key: Option<&str>,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload_bytes = serde_json::to_vec(payload).map_err(|e| format!("Failed to encode payload: {}", e))?;
    let timestamp = unix_seconds_now();
    let hmac = secret_key.map(|secret| {
        generate_hmac_for_envelope(message_type, &payload_bytes, timestamp, device_id, secret)
    });

    let envelope = Envelope {
        type_: message_type.as_str().to_string(),
        payload: payload_bytes,
        timestamp,
        device_id: device_id.to_string(),
        hmac,
    };

    let frame = serde_json::to_vec(&envelope).map_err(|e| format!("Failed to encode envelope: {}", e))?;
    let length = (frame.len() as u32).to_be_bytes();

    let writer = {
        let conns = connections.read().await;
        conns.get(conn_id)
            .map(|conn| conn.writer.clone())
            .ok_or_else(|| format!("Connection not found: {}", conn_id))?
    };

    let mut writer = writer.lock().await;
    writer
        .write_all(&length)
        .await
        .map_err(|e| format!("Failed to write frame length: {}", e))?;
    writer
        .write_all(&frame)
        .await
        .map_err(|e| format!("Failed to write frame body: {}", e))?;
    Ok(())
}

async fn send_error_to_connection(
    conn_id: &str,
    code: &str,
    message: &str,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload = ErrorPayload {
        code: code.to_string(),
        message: message.to_string(),
    };
    send_envelope_to_connection(
        conn_id,
        MessageType::Error,
        &payload,
        &windows_device_id(),
        None,
        connections,
    )
    .await
}

fn inject_text(text: &str) {
    let injector = injection::TextInjector::new(injection::InjectionMethod::Keyboard);
    if let Err(err) = injector.inject(text) {
        error!("Keyboard injection failed: {}", err);
        let clipboard_injector = injection::TextInjector::new(injection::InjectionMethod::Clipboard);
        if let Err(clipboard_err) = clipboard_injector.inject(text) {
            error!("Clipboard injection failed: {}", clipboard_err);
        }
    }
}

fn unix_seconds_now() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs_f64()
}

fn generate_hmac_for_envelope(
    message_type: MessageType,
    payload: &[u8],
    unix_timestamp: f64,
    device_id: &str,
    secret_key: &str,
) -> String {
    use hmac::{Hmac, Mac};
    use sha2::Sha256;

    type HmacSha256 = Hmac<Sha256>;

    let message = format!(
        "{}{}{}{}",
        message_type.as_str(),
        STANDARD.encode(payload),
        unix_timestamp,
        device_id
    );

    let mut mac = HmacSha256::new_from_slice(secret_key.as_bytes()).expect("HMAC accepts any key size");
    mac.update(message.as_bytes());
    let bytes = mac.finalize().into_bytes();
    bytes.iter().map(|b| format!("{:02x}", b)).collect()
}

fn windows_device_id() -> String {
    let hostname = hostname::get()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_else(|_| "windows".to_string());
    format!("windows-{}", hostname.to_lowercase().replace(' ', "-"))
}
