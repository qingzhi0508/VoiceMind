use crate::commands::ConnectionStatus;
use crate::events::EventEmitter;
use crate::pairing::PairingManager;
use base64::{engine::general_purpose::STANDARD, Engine};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
#[cfg(windows)]
use std::os::windows::process::CommandExt;
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
const AUDIO_STREAM_IDLE_TIMEOUT_SECS: u64 = 3;

/// Offset in seconds between Unix epoch (1970-01-01) and Apple reference date (2001-01-01).
/// iOS/macOS JSONEncoder encodes Date as timeIntervalSinceReferenceDate by default,
/// but HMAC is computed with timeIntervalSince1970. We add this offset when verifying
/// incoming messages and subtract when serializing outgoing messages.
const APPLE_EPOCH_OFFSET: f64 = 978307200.0;

struct StreamingCloudAsrState {
    session: Arc<Mutex<crate::asr::AsrSession>>,
    final_rx: tokio::sync::oneshot::Receiver<String>,
    latest_text: Arc<std::sync::Mutex<String>>,
}

/// State for VAD-based segmented Qwen3 recognition.
struct Qwen3VadState {
    vad: crate::vad::VadSession,
    /// Current speech segment audio buffer (accumulated during speech).
    current_chunk: Vec<u8>,
    /// Accumulated text from all completed segment recognitions (shared with background tasks).
    accumulated_text: Arc<std::sync::Mutex<String>>,
    /// Pending recognition task handles.
    pending_tasks: Vec<tokio::task::JoinHandle<()>>,
    /// Model size for qwen_asr.
    model_size: String,
    /// Audio sample rate.
    sample_rate: u32,
    /// Audio channels.
    channels: u32,
}

/// State for ONNX-based streaming Qwen3 recognition.
#[allow(dead_code)]
struct Qwen3OnnxState {
    engine: Arc<tokio::sync::Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>,
    audio_buffer: Arc<tokio::sync::Mutex<Vec<f32>>>,
    interval_handle: Option<tokio::task::JoinHandle<()>>,
    last_partial: Arc<std::sync::Mutex<String>>,
    cancel_token: tokio_util::sync::CancellationToken,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ConnectionState {
    Pending,
    #[allow(dead_code)]
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
    Keyword,
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
            Self::Keyword => "keyword",
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
            "keyword" => Some(Self::Keyword),
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

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeywordPayload {
    pub action: KeywordAction,
    pub session_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum KeywordAction {
    #[serde(rename = "confirm")]
    Confirm,
    #[serde(rename = "undo")]
    Undo,
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
    pub last_audio_activity: Option<Instant>,
    streaming_cloud_asr: Option<StreamingCloudAsrState>,
    qwen3_vad: Option<Qwen3VadState>,
    /// Background task that polls VAD recognition results for partial display
    qwen3_vad_poll_task: Option<tokio::task::JoinHandle<()>>,
    qwen3_onnx_state: Option<Qwen3OnnxState>,
    pub audio_buffer: Vec<u8>,
    pub audio_sample_rate: u32,
    pub audio_channels: u32,
}

pub struct ConnectionManager {
    server_port: u16,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    running: bool,
    event_emitter: Arc<Mutex<EventEmitter>>,
    shutdown_tx: Option<tokio::sync::mpsc::Sender<()>>,
    pairing_manager: Option<Arc<Mutex<PairingManager>>>,
    history_store: Option<Arc<Mutex<crate::speech::HistoryStore>>>,
    asr_provider: Option<Arc<Mutex<Option<crate::asr::VolcengineProvider>>>>,
    settings_store: Option<Arc<Mutex<crate::settings::SettingsStore>>>,
    qwen3_onnx_engine: Option<Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>>,
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self {
            server_port: 8765,
            connections: Arc::new(RwLock::new(HashMap::new())),
            running: false,
            event_emitter: Arc::new(Mutex::new(EventEmitter::new())),
            shutdown_tx: None,
            pairing_manager: None,
            history_store: None,
            asr_provider: None,
            settings_store: None,
            qwen3_onnx_engine: None,
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

    pub fn set_onnx_engine(&mut self, engine: Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>) {
        self.qwen3_onnx_engine = Some(engine);
    }

    pub async fn start_server(
        &mut self,
        port: u16,
        pairing_manager: Arc<Mutex<PairingManager>>,
        history_store: Arc<Mutex<crate::speech::HistoryStore>>,
        asr_provider: Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
        settings_store: Arc<Mutex<crate::settings::SettingsStore>>,
    ) -> Result<(), String> {
        if self.running { return Ok(()); }
        self.server_port = port;
        self.pairing_manager = Some(pairing_manager.clone());
        self.history_store = Some(history_store.clone());
        self.asr_provider = Some(asr_provider.clone());
        self.settings_store = Some(settings_store.clone());
        let onnx_engine = self.qwen3_onnx_engine.clone();
        let addr = format!("0.0.0.0:{port}");
        let listener = TcpListener::bind(&addr)
            .await
            .map_err(|e| format!("Failed to bind to {addr}: {e}"))?;

        let (shutdown_tx, mut shutdown_rx) = tokio::sync::mpsc::channel::<()>(1);
        self.shutdown_tx = Some(shutdown_tx);
        self.running = true;
        info!("VoiceMind TCP server listening on {}", addr);

        let connections = self.connections.clone();
        let emitter = self.event_emitter.clone();
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    result = listener.accept() => {
                        match result {
                            Ok((stream, peer_addr)) => {
                                info!("Accepted TCP connection from {}", peer_addr);
                                let conn_id = Uuid::new_v4().to_string();
                                let connections = connections.clone();
                                let pairing_manager = pairing_manager.clone();
                                let emitter = emitter.clone();
                                let history_store = history_store.clone();
                                let asr_provider = asr_provider.clone();
                                let settings_store = settings_store.clone();
                                let onnx_engine_clone = onnx_engine.as_ref().map(|e| e.clone());
                                tokio::spawn(async move {
                                    if let Err(err) = handle_connection(
                                        conn_id,
                                        stream,
                                        connections,
                                        pairing_manager,
                                        emitter,
                                        history_store,
                                        asr_provider,
                                        settings_store,
                                        onnx_engine_clone,
                                    )
                                    .await
                                    {
                                        error!("Connection handling failed: {}", err);
                                    }
                                });
                            }
                            Err(err) => {
                                error!("Accept failed: {}", err);
                            }
                        }
                    }
                    _ = shutdown_rx.recv() => {
                        info!("Server shutdown signal received");
                        break;
                    }
                }
            }
        });

        Ok(())
    }

    pub async fn stop_server(&mut self) -> Result<(), String> {
        if !self.running { return Ok(()); }
        // Send shutdown signal
        if let Some(tx) = self.shutdown_tx.take() {
            let _ = tx.send(()).await;
        }
        // Close all connections
        let mut connections = self.connections.write().await;
        connections.clear();
        self.running = false;
        // Emit disconnected event
        let emitter = self.event_emitter.lock().await;
        emitter.emit_connection_changed(false, None, None);
        info!("Server stopped");
        Ok(())
    }

    pub fn is_running(&self) -> bool {
        self.running
    }

    pub async fn get_connected_device(&self) -> Option<ConnectionStatus> {
        let connections = self.connections.read().await;
        info!("get_connected_device: checking {} connections", connections.len());
        for (id, conn) in connections.iter() {
            info!("  conn {}: state={:?}, device_id={:?}, device_name={:?}", id, conn.state, conn.device_id, conn.device_name);
        }
        let result = connections.values().find_map(|conn| {
            if matches!(
                conn.state,
                ConnectionState::Paired | ConnectionState::Listening
            ) {
                Some(ConnectionStatus {
                    connected: true,
                    name: conn.device_name.clone(),
                    device_id: conn.device_id.clone(),
                })
            } else {
                None
            }
        });
        info!("get_connected_device result: {:?}", result);
        result
    }

    pub async fn start_listening(&self) -> Result<String, String> {
        let target = {
            let connections = self.connections.read().await;
            connections.iter().find_map(|(id, conn)| {
                if matches!(
                    conn.state,
                    ConnectionState::Paired | ConnectionState::Listening
                ) {
                    Some((id.clone(), conn.secret_key.clone()))
                } else {
                    None
                }
            })
        };

        let (conn_id, secret_key) =
            target.ok_or_else(|| "No paired iPhone connected".to_string())?;
        let secret_key =
            secret_key.ok_or_else(|| "Missing shared secret for paired device".to_string())?;
        let session_id = Uuid::new_v4().to_string();
        let payload = StartListenPayload {
            session_id: session_id.clone(),
        };

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
            conn.last_audio_activity = Some(Instant::now());
            conn.streaming_cloud_asr = None;
        }

        Ok(session_id)
    }

    pub async fn stop_listening(&self) -> Result<String, String> {
        let target = {
            let connections = self.connections.read().await;
            connections.iter().find_map(|(id, conn)| {
                if matches!(conn.state, ConnectionState::Listening) {
                    Some((
                        id.clone(),
                        conn.secret_key.clone(),
                        conn.current_session_id.clone(),
                    ))
                } else {
                    None
                }
            })
        };

        let (conn_id, secret_key, session_id) =
            target.ok_or_else(|| "No active listening session".to_string())?;
        let secret_key =
            secret_key.ok_or_else(|| "Missing shared secret for paired device".to_string())?;
        let session_id = session_id.unwrap_or_else(|| Uuid::new_v4().to_string());
        let payload = StopListenPayload {
            session_id: session_id.clone(),
        };

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
            conn.last_audio_activity = None;
            conn.streaming_cloud_asr = None;
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
    history_store: Arc<Mutex<crate::speech::HistoryStore>>,
    asr_provider: Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: Arc<Mutex<crate::settings::SettingsStore>>,
    onnx_engine: Option<Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>>,
) -> Result<(), String> {
    info!("handle_connection START: conn_id={}", conn_id);
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
                last_audio_activity: None,
                streaming_cloud_asr: None,
                qwen3_vad: None,
                qwen3_vad_poll_task: None,
                qwen3_onnx_state: None,
                audio_buffer: Vec::new(),
                audio_sample_rate: 16000,
                audio_channels: 1,
            },
        );
    }

    let heartbeat_connections = connections.clone();
    let heartbeat_conn_id = conn_id.clone();
    let heartbeat_emitter = event_emitter.clone();
    tokio::spawn(async move {
        heartbeat_loop(heartbeat_conn_id, heartbeat_connections, heartbeat_emitter).await;
    });

    let stream_watchdog_connections = connections.clone();
    let stream_watchdog_conn_id = conn_id.clone();
    let stream_watchdog_emitter = event_emitter.clone();
    tokio::spawn(async move {
        audio_stream_watchdog_loop(
            stream_watchdog_conn_id,
            stream_watchdog_connections,
            stream_watchdog_emitter,
        )
        .await;
    });

    let result = read_loop(
        &conn_id,
        reader,
        &connections,
        &pairing_manager,
        &event_emitter,
        &history_store,
        &asr_provider,
        &settings_store,
        onnx_engine.as_ref(),
    )
    .await;

    let disconnected = {
        let mut conns = connections.write().await;
        conns.remove(&conn_id)
    };

    if let Some(conn) = disconnected {
        info!("Connection {} closed", conn.id);
        // Abort Qwen3 VAD poll task if running
        if let Some(handle) = conn.qwen3_vad_poll_task {
            handle.abort();
        }
        // Cancel ONNX streaming interval if running
        if let Some(onnx_state) = conn.qwen3_onnx_state {
            onnx_state.cancel_token.cancel();
            if let Some(h) = onnx_state.interval_handle {
                h.abort();
            }
        }
        if matches!(conn.state, ConnectionState::Listening) {
            if let Some(session_id) = conn.current_session_id.clone() {
                let emitter = event_emitter.lock().await;
                emitter.emit_listening_stopped(session_id);
                drop(emitter);
            }
        }
        if matches!(
            conn.state,
            ConnectionState::Paired | ConnectionState::Listening
        ) {
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
    history_store: &Arc<Mutex<crate::speech::HistoryStore>>,
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
    onnx_engine: Option<&Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>>,
) -> Result<(), String> {
    loop {
        let mut length_buf = [0_u8; 4];
        if let Err(err) = reader.read_exact(&mut length_buf).await {
            warn!("read_loop {}: Failed reading frame length: {}", conn_id, err);
            return Err(format!("Failed reading frame length: {}", err));
        }
        let length = u32::from_be_bytes(length_buf) as usize;
        if length == 0 || length > 10_000_000 {
            warn!("read_loop {}: Invalid frame length: {}", conn_id, length);
            return Err(format!("Invalid frame length: {}", length));
        }

        let mut payload = vec![0_u8; length];
        reader
            .read_exact(&mut payload)
            .await
            .map_err(|e| format!("Failed reading frame body: {}", e))?;

        let envelope: Envelope = serde_json::from_slice(&payload)
            .map_err(|e| {
                // Log raw payload for debugging
                let raw_str = String::from_utf8_lossy(&payload);
                warn!("read_loop {}: Invalid envelope JSON: {}. Raw payload: {}", conn_id, e, raw_str);
                format!("Invalid envelope JSON: {}", e)
            })?;
        process_message(
            conn_id,
            envelope,
            connections,
            pairing_manager,
            event_emitter,
            history_store,
            asr_provider,
            settings_store,
            onnx_engine,
        )
        .await?;
    }
}

async fn process_message(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    history_store: &Arc<Mutex<crate::speech::HistoryStore>>,
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
    onnx_engine: Option<&Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>>,
) -> Result<(), String> {
    let message_type = MessageType::from_str(&envelope.type_)
        .ok_or_else(|| format!("Unknown message type: {}", envelope.type_))?;

    // Skip INFO logging for high-frequency audio data frames
    if message_type != MessageType::AudioData {
        info!(
            "process_message: conn_id={}, type={}, device_id={:?}",
            conn_id, envelope.type_, envelope.device_id
        );
    }

    if message_type != MessageType::PairConfirm {
        hydrate_existing_paired_connection(
            conn_id,
            &envelope,
            connections,
            pairing_manager,
            event_emitter,
            asr_provider,
            settings_store,
        )
        .await?;
    }

    match message_type {
        MessageType::PairConfirm => {
            handle_pair_confirm(
                conn_id,
                envelope,
                connections,
                pairing_manager,
                event_emitter,
                asr_provider,
                settings_store,
            )
            .await
        }
        MessageType::Ping => handle_ping(conn_id, envelope, connections).await,
        MessageType::Pong => handle_pong(conn_id, connections).await,
        MessageType::Result => handle_result(conn_id, envelope, connections, event_emitter, history_store).await,
        MessageType::TextMessage => {
            handle_text_message(conn_id, envelope, connections, event_emitter, history_store).await
        }
        MessageType::PartialResult => handle_partial_result(conn_id, envelope, event_emitter).await,
        MessageType::AudioStart => handle_audio_start(conn_id, envelope, connections, event_emitter, asr_provider, settings_store, onnx_engine).await,
        MessageType::AudioData => handle_audio_data(conn_id, envelope, connections, event_emitter).await,
        MessageType::AudioEnd => handle_audio_end(conn_id, envelope, connections, event_emitter, history_store, asr_provider, settings_store, onnx_engine).await,
        MessageType::Keyword => handle_keyword(envelope).await,
        MessageType::Error => handle_error(envelope).await,
        MessageType::PairSuccess => {
            info!("Received PairSuccess from conn_id={} - pairing completed on iOS side", conn_id);
            Ok(())
        }
        MessageType::StartListen | MessageType::StopListen => {
            info!("Received {} from conn_id={}", envelope.type_, conn_id);
            Ok(())
        }
    }
}

async fn prewarm_cloud_asr_if_needed(
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
    reason: &str,
) {
    let asr_engine = {
        let settings = settings_store.lock().await;
        settings.get().asr_engine.clone()
    };

    if asr_engine != "cloud" {
        return;
    }

    let provider_guard = asr_provider.lock().await;
    let Some(provider) = provider_guard.as_ref() else {
        warn!("Skipping cloud ASR prewarm ({}): provider not configured", reason);
        return;
    };

    info!("Prewarming cloud ASR session ({})", reason);
    let callback: crate::asr::AsrResultCallback = Arc::new(|_| {});
    let mut session = provider.create_session(callback);

    match tokio::time::timeout(Duration::from_secs(8), provider.connect_session(&mut session)).await {
        Ok(Ok(())) => {
            let _ = tokio::time::timeout(Duration::from_secs(3), session.finish()).await;
            info!("Cloud ASR prewarm completed ({})", reason);
        }
        Ok(Err(e)) => warn!("Cloud ASR prewarm failed ({}): {}", reason, e),
        Err(_) => warn!("Cloud ASR prewarm timed out ({})", reason),
    }
}

async fn hydrate_existing_paired_connection(
    conn_id: &str,
    envelope: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
) -> Result<(), String> {
    let device_id = envelope.device_id.clone();
    info!("hydrate_existing_paired_connection: conn_id={}, device_id={}, type={}",
          conn_id, device_id, envelope.type_);

    let message_type = MessageType::from_str(&envelope.type_)
        .ok_or_else(|| format!("Unknown message type: {}", envelope.type_))?;
    let provided_hmac = envelope
        .hmac
        .as_deref()
        .ok_or_else(|| format!("Missing HMAC for device {}", envelope.device_id))?;

    let existing_connection = {
        let conns = connections.read().await;
        conns
            .get(conn_id)
            .map(|conn| (conn.secret_key.clone(), conn.device_name.clone()))
    };

    if let Some((Some(secret), device_name)) = existing_connection {
        info!("hydrate: found existing connection with secret_key for conn_id={}", conn_id);
        let expected_hmac = generate_hmac_for_envelope(
            message_type,
            &envelope.payload,
            envelope.timestamp + APPLE_EPOCH_OFFSET,
            &envelope.device_id,
            &secret,
        );

        if provided_hmac != expected_hmac {
            warn!(
                "Invalid HMAC for already-authenticated connection {}",
                conn_id
            );
            return Err(format!("Invalid HMAC for device {}", envelope.device_id));
        }

        let just_promoted = promote_authenticated_connection(
            conn_id,
            device_id.clone(),
            device_name.clone(),
            secret,
            connections,
        )
        .await;

        if just_promoted {
            let emitter = event_emitter.lock().await;
            emitter.emit_connection_changed(true, device_name, Some(device_id));
            drop(emitter);
            let asr_provider = asr_provider.clone();
            let settings_store = settings_store.clone();
            tokio::spawn(async move {
                prewarm_cloud_asr_if_needed(&asr_provider, &settings_store, "rehydrate-existing").await;
            });
        }

        return Ok(());
    }

    info!("hydrate: no existing connection secret, checking pairing_manager");
    let (secret, device_name, migrated_from_device_id) = {
        let mut manager = pairing_manager.lock().await;

        if let Some(secret) = manager.get_device_secret(&device_id) {
            info!("hydrate: found device_secret in manager for device_id={}", device_id);
            let expected_hmac = generate_hmac_for_envelope(
                message_type,
                &envelope.payload,
                envelope.timestamp + APPLE_EPOCH_OFFSET,
                &envelope.device_id,
                &secret,
            );

            info!("HMAC verified for device_id={}", device_id);

            if provided_hmac != expected_hmac {
                warn!(
                    "Invalid HMAC for paired device {} message {}",
                    envelope.device_id, envelope.type_
                );
                return Err(format!("Invalid HMAC for device {}", envelope.device_id));
            }

            manager.update_last_seen(&device_id);
            (secret, manager.get_device_name(&device_id), None)
        } else {
            info!("hydrate: device_id={} not in paired_devices, searching by HMAC", device_id);
            let paired_devices = manager.get_paired_device_records();
            info!("hydrate: total paired devices: {}", paired_devices.len());

            let matching_device = paired_devices
                .into_iter()
                .find(|device| {
                    generate_hmac_for_envelope(
                        message_type,
                        &envelope.payload,
                        envelope.timestamp + APPLE_EPOCH_OFFSET,
                        &envelope.device_id,
                        &device.secret_key,
                    ) == provided_hmac
                });

            let Some(previous_device) = matching_device else {
                warn!(
                    "No paired device found for incoming device id {}. This may be a new device trying to connect before pairing completes.",
                    device_id
                );
                return Err(format!("Unknown paired device {}. Device may need to pair first.", envelope.device_id));
            };

            let migrated_device = manager
                .migrate_device_id(&previous_device.id, &device_id)
                .unwrap_or_else(|| previous_device.clone());

            (
                migrated_device.secret_key,
                Some(migrated_device.name),
                Some(previous_device.id),
            )
        }
    };

    let just_promoted = promote_authenticated_connection(
        conn_id,
        device_id.clone(),
        device_name.clone(),
        secret,
        connections,
    )
    .await;

    if let Some(previous_device_id) = migrated_from_device_id {
        warn!(
            "Recovered paired device {} as {} on connection {}",
            previous_device_id, device_id, conn_id
        );
    }

    if just_promoted {
        let emitter = event_emitter.lock().await;
        emitter.emit_connection_changed(true, device_name, Some(device_id));
        drop(emitter);
        let asr_provider = asr_provider.clone();
        let settings_store = settings_store.clone();
        tokio::spawn(async move {
            prewarm_cloud_asr_if_needed(&asr_provider, &settings_store, "rehydrate-paired").await;
        });
    }

    Ok(())
}

async fn promote_authenticated_connection(
    conn_id: &str,
    device_id: String,
    device_name: Option<String>,
    secret: String,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> bool {
    let mut just_promoted = false;

    let mut conns = connections.write().await;

    // Clean up any stale connection from the same device_id
    let stale_ids: Vec<String> = conns
        .iter()
        .filter(|(id, conn)| {
            *id != conn_id
                && conn.device_id.as_deref() == Some(device_id.as_str())
        })
        .map(|(id, _)| id.clone())
        .collect();
    for stale_id in &stale_ids {
        info!("Removing stale connection {} for reconnected device {}", stale_id, device_id);
        conns.remove(stale_id);
    }

    if let Some(conn) = conns.get_mut(conn_id) {
        let was_connected = matches!(
            conn.state,
            ConnectionState::Paired | ConnectionState::Listening
        );
        conn.device_id = Some(device_id);
        conn.device_name = device_name;
        conn.secret_key = Some(secret);
        conn.last_pong = Instant::now();
        if !matches!(conn.state, ConnectionState::Listening) {
            conn.state = ConnectionState::Paired;
        }
        conn.last_audio_activity = None;
        just_promoted = !was_connected;
    }

    just_promoted
}

async fn handle_pair_confirm(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    pairing_manager: &Arc<Mutex<PairingManager>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
) -> Result<(), String> {
    info!("Handling pairConfirm message from connection {}", conn_id);
    let payload: PairConfirmPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid pairConfirm payload: {}", e))?;

    info!(
        "PairConfirm payload: ios_id={}, ios_name={}, short_code={}",
        payload.ios_id, payload.ios_name, payload.short_code
    );

    let mut manager = pairing_manager.lock().await;

    // Debug: log pairing mode state
    info!("Pairing mode active: {}, current code: {}",
          manager.is_pairing_mode(),
          manager.get_current_code());

    if manager.is_locked() {
        warn!("Pairing locked due to too many failed attempts");
        return send_error_to_connection(
            conn_id,
            "locked",
            "Too many failed attempts. Please try again later.",
            connections,
        )
        .await;
    }

    if !manager.is_valid_code(&payload.short_code) {
        warn!("Invalid pairing code: {} (expected: {})", payload.short_code, manager.get_current_code());
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
    info!(
        "Pairing CONFIRMED! secret_key generated for device {} ({})",
        payload.ios_name, payload.ios_id
    );
    drop(manager);

    {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.device_id = Some(payload.ios_id.clone());
            conn.device_name = Some(payload.ios_name.clone());
            conn.secret_key = Some(secret_key.clone());
            conn.state = ConnectionState::Paired;
            info!(
                "Connection {} updated: device_id={:?}, device_name={:?}, state=Paired",
                conn_id, conn.device_id, conn.device_name
            );
        } else {
            warn!(
                "Connection {} not found when updating pairing state",
                conn_id
            );
        }
    }

    let response = PairSuccessPayload {
        shared_secret: secret_key.clone(),
    };
    info!("Sending PairSuccess response with shared_secret to conn_id={}", conn_id);
    send_envelope_to_connection(
        conn_id,
        MessageType::PairSuccess,
        &response,
        &windows_device_id(),
        None,
        connections,
    )
    .await?;

    info!("PairSuccess sent successfully, emitting connection-changed event");
    let emitter = event_emitter.lock().await;
    emitter.emit_connection_changed(true, Some(payload.ios_name.clone()), Some(payload.ios_id));
    drop(emitter);
    let asr_provider = asr_provider.clone();
    let settings_store = settings_store.clone();
    tokio::spawn(async move {
        prewarm_cloud_asr_if_needed(&asr_provider, &settings_store, "pair-confirm").await;
    });
    info!("Pairing flow completed for device {}", payload.ios_name);
    Ok(())
}

async fn handle_ping(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: PingPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid ping payload: {}", e))?;
    let secret = {
        let conns = connections.read().await;
        conns.get(conn_id).and_then(|conn| conn.secret_key.clone())
    };

    let response = PongPayload {
        nonce: payload.nonce,
    };
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
    history_store: &Arc<Mutex<crate::speech::HistoryStore>>,
) -> Result<(), String> {
    let payload: ResultPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid result payload: {}", e))?;
    info!(
        "Received result from {} session {}: {}",
        envelope.device_id, payload.session_id, payload.text
    );
    let device_name = {
        let conns = connections.read().await;
        conns.get(conn_id).and_then(|conn| conn.device_name.clone())
    };

    // Save to history
    {
        let mut store = history_store.lock().await;
        store.add(payload.text.clone(), device_name.clone().unwrap_or_else(|| "iOS".to_string()), Some(payload.session_id.clone()));
    }

    inject_text(&payload.text);
    let emitter = event_emitter.lock().await;
    emitter.emit_recognition_result(
        payload.text,
        payload.language,
        payload.session_id,
        device_name,
    );
    Ok(())
}

async fn handle_text_message(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    history_store: &Arc<Mutex<crate::speech::HistoryStore>>,
) -> Result<(), String> {
    let payload: TextMessagePayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid textMessage payload: {}", e))?;
    info!(
        "Received text message from {} session {}: {}",
        envelope.device_id, payload.session_id, payload.text
    );

    let device_name = {
        let conns = connections.read().await;
        if let Some(conn) = conns.get(conn_id) {
            info!(
                "Connection {} state: {:?}, device_name: {:?}",
                conn_id, conn.state, conn.device_name
            );
            conn.device_name.clone()
        } else {
            warn!(
                "Connection {} not found when handling text message",
                conn_id
            );
            None
        }
    };

    // Save to history
    {
        let mut store = history_store.lock().await;
        store.add(payload.text.clone(), device_name.clone().unwrap_or_else(|| "iOS".to_string()), Some(payload.session_id.clone()));
    }

    info!("Injecting text: {}", payload.text);
    inject_text(&payload.text);
    info!("Text injection completed");

    let emitter = event_emitter.lock().await;
    emitter.emit_recognition_result(
        payload.text,
        payload.language,
        payload.session_id,
        device_name,
    );
    info!("Recognition result event emitted");
    Ok(())
}

async fn handle_partial_result(
    _conn_id: &str,
    envelope: Envelope,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let payload: PartialResultPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid partialResult payload: {}", e))?;
    let emitter = event_emitter.lock().await;
    emitter.emit_partial_result(payload.text, payload.language, payload.session_id);
    Ok(())
}

async fn handle_audio_start(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
    onnx_engine: Option<&Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>>,
) -> Result<(), String> {
    let payload: AudioStartPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid audioStart payload: {}", e))?;

    let device_name = {
        let conns = connections.read().await;
        conns.get(conn_id).and_then(|conn| conn.device_name.clone())
    };

    let asr_engine = {
        let settings = settings_store.lock().await;
        settings.get().asr_engine.clone()
    };

    let streaming_cloud_asr = if asr_engine == "cloud" {
        let provider_guard = asr_provider.lock().await;
        if let Some(provider) = provider_guard.as_ref() {
            let (tx, rx) = tokio::sync::oneshot::channel();
            let final_tx = Arc::new(std::sync::Mutex::new(Some(tx)));
            let latest_text = Arc::new(std::sync::Mutex::new(String::new()));
            let latest_text_clone = latest_text.clone();
            let session_id = payload.session_id.clone();
            let emitter_arc = event_emitter.clone();

            let callback: crate::asr::AsrResultCallback = Arc::new(move |result| {
                if result.text.trim().is_empty() {
                    return;
                }

                if let Ok(mut latest) = latest_text_clone.lock() {
                    *latest = result.text.clone();
                }

                if let Ok(emitter) = emitter_arc.try_lock() {
                    emitter.emit_partial_result(
                        result.text.clone(),
                        "zh-CN".to_string(),
                        session_id.clone(),
                    );
                }

                if result.is_final {
                    if let Ok(mut sender) = final_tx.lock() {
                        if let Some(tx) = sender.take() {
                            let _ = tx.send(result.text.clone());
                        }
                    }
                }
            });

            let mut session = provider.create_session(callback);
            provider.connect_session(&mut session).await?;
            Some(StreamingCloudAsrState {
                session: Arc::new(Mutex::new(session)),
                final_rx: rx,
                latest_text,
            })
        } else {
            None
        }
    } else {
        None
    };

    // Start Qwen3 VAD segmented recognition when using qwen3_local engine
    let (qwen3_vad, qwen3_vad_poll_task) = if asr_engine == "qwen3_local" {
        let (model_size, _language) = {
            let settings = settings_store.lock().await;
            let s = settings.get();
            (s.qwen3_asr.model_size.clone(), s.qwen3_asr.language.clone())
        };

        // Verify binary exists upfront
        if let Err(e) = crate::qwen_asr::check_binary_available() {
            warn!("Qwen3-ASR binary not found: {}", e);
            (None, None)
        } else {
            let vad_config = crate::vad::VadConfig::default();

            let vad_state = Qwen3VadState {
                vad: crate::vad::VadSession::new(vad_config),
                current_chunk: Vec::new(),
                accumulated_text: Arc::new(std::sync::Mutex::new(String::new())),
                pending_tasks: Vec::new(),
                model_size: model_size.clone(),
                sample_rate: payload.sample_rate,
                channels: payload.channels,
            };

            // No separate poll task needed — recognition results are emitted
            // directly from spawned per-segment tasks via event_emitter.
            info!("Qwen3 VAD segmented recognition initialized for model {}", model_size);
            (Some(vad_state), None)
        }
    } else {
        (None, None)
    };

    // Start ONNX streaming recognition when using qwen3_onnx engine
    let qwen3_onnx_state = if asr_engine == "qwen3_onnx" {
        if let Some(engine_arc) = onnx_engine {
            // Auto-load engine if not loaded but model is downloaded
            {
                let engine_guard = engine_arc.lock().await;
                if engine_guard.is_none() {
                    drop(engine_guard);
                    if crate::qwen3_onnx::model::is_onnx_model_downloaded("0.6b") {
                        let model_dir = crate::qwen3_onnx::model::get_onnx_model_dir("0.6b");
                        info!("ONNX engine not loaded, auto-loading from {}...", model_dir.display());
                        match tokio::task::spawn_blocking(move || {
                            crate::qwen3_onnx::engine::Qwen3AsrEngine::new(&model_dir)
                        }).await {
                            Ok(Ok(engine)) => {
                                let mut guard = engine_arc.lock().await;
                                *guard = Some(engine);
                                info!("ONNX engine auto-loaded successfully");
                            }
                            Ok(Err(e)) => {
                                warn!("Auto-load ONNX engine failed: {}", e);
                                let emitter = event_emitter.lock().await;
                                emitter.emit_error("asr_onnx_load_failed".to_string(), format!("Failed to load ONNX engine: {}", e), true);
                            }
                            Err(e) => {
                                warn!("Auto-load ONNX engine task error: {}", e);
                                let emitter = event_emitter.lock().await;
                                emitter.emit_error("asr_onnx_load_failed".to_string(), format!("Task error: {}", e), true);
                            }
                        }
                    } else {
                        let emitter = event_emitter.lock().await;
                        emitter.emit_error("asr_onnx_not_loaded".to_string(), "ONNX model not downloaded. Please download in settings first.".to_string(), true);
                    }
                }
            }

            // Now check if engine is loaded (either was already or just auto-loaded)
            let engine_guard = engine_arc.lock().await;
            if engine_guard.is_none() {
                None
            } else {
                let audio_buffer = Arc::new(tokio::sync::Mutex::new(Vec::new()));
                let cancel_token = tokio_util::sync::CancellationToken::new();
                let last_partial = Arc::new(std::sync::Mutex::new(String::new()));
                let engine_ref = engine_arc.clone();
                let session_id = payload.session_id.clone();

                let buf = audio_buffer.clone();
                let last_p = last_partial.clone();
                let cancel = cancel_token.clone();
                let emitter_arc = event_emitter.clone();

                let handle = tokio::spawn(async move {
                    let mut interval = tokio::time::interval(std::time::Duration::from_millis(500));
                    loop {
                        tokio::select! {
                            _ = cancel.cancelled() => break,
                            _ = interval.tick() => {
                                let buf_guard = buf.lock().await;
                                let len = buf_guard.len();
                                if len < 4800 { continue; }
                                let pcm = buf_guard.clone();
                                drop(buf_guard);

                                let engine_guard = engine_ref.lock().await;
                                if let Some(ref engine) = *engine_guard {
                                    match engine.transcribe(&pcm, 16000) {
                                        Ok(text) if !text.is_empty() => {
                                            let should_emit = {
                                                let mut last = last_p.lock().unwrap();
                                                if *last != text {
                                                    *last = text.clone();
                                                    true
                                                } else {
                                                    false
                                                }
                                            };
                                            if should_emit {
                                                let emitter = emitter_arc.lock().await;
                                                emitter.emit_partial_result(text, "auto".to_string(), session_id.clone());
                                            }
                                        }
                                        Ok(_) => {}
                                        Err(e) => { eprintln!("ONNX inference error: {}", e); }
                                    }
                                }
                            }
                        }
                    }
                });

                info!("Qwen3 ONNX streaming recognition initialized");
                Some(Qwen3OnnxState {
                    engine: engine_arc.clone(),
                    audio_buffer,
                    interval_handle: Some(handle),
                    last_partial,
                    cancel_token,
                })
            }
        } else {
            let emitter = event_emitter.lock().await;
            emitter.emit_error("asr_onnx_not_loaded".to_string(), "ONNX engine not loaded. Please load it in settings first.".to_string(), true);
            None
        }
    } else {
        None
    };

    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        conn.state = ConnectionState::Listening;
        conn.current_session_id = Some(payload.session_id.clone());
        conn.last_audio_activity = Some(Instant::now());
        conn.streaming_cloud_asr = streaming_cloud_asr;
        conn.qwen3_vad = qwen3_vad;
        conn.qwen3_vad_poll_task = qwen3_vad_poll_task;
        conn.qwen3_onnx_state = qwen3_onnx_state;
        conn.audio_buffer.clear();
        conn.audio_sample_rate = payload.sample_rate;
        conn.audio_channels = payload.channels;
    }

    // Emit listening-started event to frontend
    let emitter = event_emitter.lock().await;
    emitter.emit_listening_started(payload.session_id, device_name);

    Ok(())
}

async fn handle_audio_data(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
) -> Result<(), String> {
    let payload: AudioDataPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid audioData payload: {}", e))?;

    let (streaming_session, vad_events, onnx_audio_data) = {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            conn.audio_buffer.extend_from_slice(&payload.audio_data);
            conn.last_audio_activity = Some(Instant::now());
            let cloud = conn.streaming_cloud_asr
                .as_ref()
                .map(|state| state.session.clone());

            // Run VAD on incoming audio for Qwen3 segmented recognition
            let vad_evts = if let Some(ref mut vad_state) = conn.qwen3_vad {
                let events = vad_state.vad.feed(&payload.audio_data);
                // Always accumulate audio in current_chunk regardless of VAD state
                vad_state.current_chunk.extend_from_slice(&payload.audio_data);
                events
            } else {
                Vec::new()
            };

            // Feed audio to ONNX streaming buffer
            let onnx_buf = if let Some(ref onnx_state) = conn.qwen3_onnx_state {
                Some(onnx_state.audio_buffer.clone())
            } else {
                None
            };

            (cloud, vad_evts, onnx_buf)
        } else {
            (None, Vec::new(), None)
        }
    };

    // Feed audio data to ONNX buffer
    if let Some(onnx_buf) = onnx_audio_data {
        let f32_samples: Vec<f32> = payload.audio_data.chunks(2)
            .filter_map(|c| if c.len() == 2 {
                Some(i16::from_le_bytes([c[0], c[1]]) as f32 / 32768.0)
            } else {
                None
            })
            .collect();
        onnx_buf.lock().await.extend(f32_samples);
    }

    if let Some(session) = streaming_session {
        let mut guard = session.lock().await;
        guard.send_audio(&payload.audio_data).await?;
    }

    // Process VAD events: on SpeechEnd, spawn recognition for the completed segment
    for event in vad_events {
        match event {
            crate::vad::VadEvent::SpeechStart => {
                info!("VAD detected speech start");
            }
            crate::vad::VadEvent::SpeechEnd { audio } => {
                info!("VAD detected speech end, segment size: {} bytes", audio.len());

                // Extract segment data and reset current_chunk
                let (segment_audio, model_size, sample_rate, channels, accumulated, session_id) = {
                    let mut conns = connections.write().await;
                    if let Some(conn) = conns.get_mut(conn_id) {
                        if let Some(ref mut vad_state) = conn.qwen3_vad {
                            let audio = std::mem::take(&mut vad_state.current_chunk);
                            let ms = vad_state.model_size.clone();
                            let sr = vad_state.sample_rate;
                            let ch = vad_state.channels;
                            let acc = vad_state.accumulated_text.clone();
                            let sid = conn.current_session_id.clone().unwrap_or_default();
                            (audio, ms, sr, ch, acc, sid)
                        } else {
                            continue;
                        }
                    } else {
                        continue;
                    }
                };

                // Use the VAD-detected segment audio (not current_chunk which is all audio)
                let audio_to_recognize = if audio.is_empty() {
                    segment_audio
                } else {
                    audio
                };

                let emitter_arc = event_emitter.clone();
                let handle = tokio::spawn(async move {
                    match recognize_chunk(
                        &audio_to_recognize,
                        sample_rate,
                        channels,
                        &model_size,
                    ).await {
                        Ok(text) if !text.trim().is_empty() => {
                            info!("VAD segment recognized: {}", text);

                            // Append to accumulated text
                            let new_accumulated = {
                                let mut acc = accumulated.lock().unwrap();
                                if !acc.is_empty() {
                                    acc.push_str(&text);
                                } else {
                                    *acc = text.clone();
                                }
                                acc.clone()
                            };

                            // Emit partial result with accumulated text
                            let emitter = emitter_arc.lock().await;
                            emitter.emit_partial_result(
                                new_accumulated,
                                "zh-CN".to_string(),
                                session_id,
                            );
                        }
                        Ok(_) => {
                            info!("VAD segment: empty recognition result");
                        }
                        Err(e) => {
                            warn!("VAD segment recognition failed: {}", e);
                        }
                    }
                });

                // Store the task handle
                {
                    let mut conns = connections.write().await;
                    if let Some(conn) = conns.get_mut(conn_id) {
                        if let Some(ref mut vad_state) = conn.qwen3_vad {
                            vad_state.pending_tasks.push(handle);
                        }
                    }
                }
            }
        }
    }

    Ok(())
}

async fn handle_audio_end(
    conn_id: &str,
    envelope: Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    history_store: &Arc<Mutex<crate::speech::HistoryStore>>,
    asr_provider: &Arc<Mutex<Option<crate::asr::VolcengineProvider>>>,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
    onnx_engine: Option<&Arc<Mutex<Option<crate::qwen3_onnx::engine::Qwen3AsrEngine>>>>,
) -> Result<(), String> {
    let payload: AudioEndPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid audioEnd payload: {}", e))?;

    // Extract audio buffer and device info
    let (audio_data, sample_rate, channels, device_name, session_id, secret_key, ios_device_id, streaming_cloud_asr, qwen3_vad_state, qwen3_vad_poll_task, qwen3_onnx_state) = {
        let mut conns = connections.write().await;
        let conn = conns.get_mut(conn_id).ok_or("Connection not found")?;
        conn.state = ConnectionState::Paired;
        let sid = conn.current_session_id.clone().unwrap_or(payload.session_id.clone());
        conn.current_session_id = None;
        conn.last_audio_activity = None;
        let streaming = conn.streaming_cloud_asr.take();
        let vad = conn.qwen3_vad.take();
        let poll_task = conn.qwen3_vad_poll_task.take();
        let onnx = conn.qwen3_onnx_state.take();
        let buf = std::mem::take(&mut conn.audio_buffer);
        let sr = conn.audio_sample_rate;
        let ch = conn.audio_channels;
        let dn = conn.device_name.clone();
        let sk = conn.secret_key.clone();
        let did = conn.device_id.clone();
        (buf, sr, ch, dn, sid, sk, did, streaming, vad, poll_task, onnx)
    };

    // Stop the VAD poll task if running
    if let Some(handle) = qwen3_vad_poll_task {
        handle.abort();
    }

    // Emit listening-stopped event
    let emitter = event_emitter.lock().await;
    emitter.emit_listening_stopped(session_id.clone());
    drop(emitter);

    if audio_data.is_empty() {
        return Ok(());
    }

    // Determine which ASR engine to use
    let asr_engine = {
        let settings = settings_store.lock().await;
        settings.get().asr_engine.clone()
    };

    let text_result = if let Some(mut streaming_state) = streaming_cloud_asr {
        {
            let mut session = streaming_state.session.lock().await;
            session.finish().await?;
        }

        match tokio::time::timeout(Duration::from_secs(10), &mut streaming_state.final_rx).await {
            Ok(Ok(text)) if !text.trim().is_empty() => Ok(text),
            Ok(Ok(_)) | Ok(Err(_)) | Err(_) => {
                let latest = streaming_state
                    .latest_text
                    .lock()
                    .map(|value| value.clone())
                    .unwrap_or_default();
                if latest.trim().is_empty() {
                    Err("Cloud ASR streaming finished without final result".to_string())
                } else {
                    Ok(latest)
                }
            }
        }
    } else if asr_engine == "cloud" {
        // Cloud ASR via Volcengine
        let provider_guard = asr_provider.lock().await;
        match provider_guard.as_ref() {
            Some(provider) => {
                info!(
                    "Cloud ASR: sending {} bytes ({}Hz, {}ch) to Volcengine",
                    audio_data.len(), sample_rate, channels
                );
                let result = provider.recognize(&audio_data, sample_rate, channels).await;
                if let Err(ref e) = result {
                    let emitter2 = event_emitter.lock().await;
                    emitter2.emit_error("asr_cloud_failed".to_string(), format!("火山引擎识别失败: {}", e), true);
                }
                result
            }
            None => {
                let msg = "火山引擎 ASR 未配置，请先在「语音」页面填写 App ID、Access Key 和 Resource ID";
                warn!("{}", msg);
                let emitter2 = event_emitter.lock().await;
                emitter2.emit_error("asr_not_configured".to_string(), msg.to_string(), true);
                Err(msg.to_string())
            }
        }
    } else if asr_engine == "qwen3_local" {
        // Qwen3 local ASR — VAD segmented recognition
        if let Some(mut vad_state) = qwen3_vad_state {
            // Flush any remaining audio in the VAD
            if let Some(crate::vad::VadEvent::SpeechEnd { audio }) = vad_state.vad.flush() {
                if !audio.is_empty() {
                    info!("VAD flush: final segment {} bytes", audio.len());
                    // Take any remaining current_chunk too
                    let remaining = std::mem::take(&mut vad_state.current_chunk);
                    let audio_to_use = if audio.len() > remaining.len() { audio } else { remaining };

                    let model_size = vad_state.model_size.clone();
                    let sr = vad_state.sample_rate;
                    let ch = vad_state.channels;
                    let acc = vad_state.accumulated_text.clone();

                    match recognize_chunk(&audio_to_use, sr, ch, &model_size).await {
                        Ok(text) if !text.trim().is_empty() => {
                            let mut acc_guard = acc.lock().unwrap();
                            if !acc_guard.is_empty() {
                                acc_guard.push_str(&text);
                            } else {
                                *acc_guard = text;
                            }
                        }
                        Ok(_) => {}
                        Err(e) => warn!("VAD flush segment recognition failed: {}", e),
                    }
                }
            }

            // Wait for all pending recognition tasks to complete (30s timeout)
            let deadline = tokio::time::Instant::now() + Duration::from_secs(30);
            for task in vad_state.pending_tasks.drain(..) {
                if tokio::time::timeout_at(deadline, task).await.is_err() {
                    warn!("Timeout waiting for VAD recognition task");
                }
            }

            // Collect accumulated text from all segments
            let accumulated = vad_state.accumulated_text.lock().unwrap().clone();
            if !accumulated.trim().is_empty() {
                info!("Qwen3 VAD segmented recognition completed: {}", accumulated);
                Ok(accumulated)
            } else {
                // Fallback to full cold-start recognition
                warn!("VAD segmented recognition empty, falling back to cold start");
                recognize_qwen3_local(&audio_data, sample_rate, channels, settings_store, event_emitter, &session_id).await
            }
        } else {
            // No VAD state — fallback to cold start
            warn!("Qwen3 VAD state not available, using cold start");
            recognize_qwen3_local(&audio_data, sample_rate, channels, settings_store, event_emitter, &session_id).await
        }
    } else if asr_engine == "qwen3_onnx" {
        // Qwen3 ONNX streaming recognition — finalize
        let mut onnx_text = String::new();
        if let Some(onnx_state) = qwen3_onnx_state {
            onnx_state.cancel_token.cancel();
            if let Some(h) = onnx_state.interval_handle {
                let _ = h.await;
            }
            let buf = onnx_state.audio_buffer.lock().await;
            if !buf.is_empty() {
                let pcm = buf.clone();
                drop(buf);
                let engine_guard = onnx_state.engine.lock().await;
                if let Some(ref engine) = *engine_guard {
                    match engine.transcribe(&pcm, 16000) {
                        Ok(text) if !text.is_empty() => {
                            onnx_text = text;
                        }
                        Ok(_) => {}
                        Err(e) => {
                            let emitter2 = event_emitter.lock().await;
                            emitter2.emit_error("asr_onnx_failed".to_string(), format!("ONNX final inference error: {}", e), true);
                        }
                    }
                }
            }
        }
        if !onnx_text.trim().is_empty() {
            Ok(onnx_text)
        } else if let Some(engine_arc) = onnx_engine {
            // Fallback: transcribe raw PCM from audio_buffer
            let f32_samples: Vec<f32> = audio_data.chunks(2)
                .filter_map(|c| if c.len() == 2 {
                    Some(i16::from_le_bytes([c[0], c[1]]) as f32 / 32768.0)
                } else {
                    None
                })
                .collect();
            let engine_guard = engine_arc.lock().await;
            if let Some(ref engine) = *engine_guard {
                match engine.transcribe(&f32_samples, 16000) {
                    Ok(text) if !text.trim().is_empty() => Ok(text),
                    Ok(_) => Err("ONNX recognition returned empty".to_string()),
                    Err(e) => Err(format!("ONNX recognition failed: {}", e)),
                }
            } else {
                Err("ONNX engine not loaded".to_string())
            }
        } else {
            Err("ONNX engine not available".to_string())
        }
    } else {
        // Local ASR via SAPI
        let result = recognize_local(&audio_data, sample_rate, channels);
        if let Err(ref e) = result {
            let emitter2 = event_emitter.lock().await;
            emitter2.emit_error("asr_local_failed".to_string(), format!("本地语音识别失败: {}", e), true);
        }
        result
    };

    match text_result {
        Ok(ref t) if !t.trim().is_empty() => {
            info!("ASR result: {}", t);
            crate::injection::inject_text_with_fallback(t).ok();
            let mut store = history_store.lock().await;
            store.add(
                t.clone(),
                device_name.clone().unwrap_or_else(|| "iOS".to_string()),
                Some(session_id.clone()),
            );
            let emitter = event_emitter.lock().await;
            emitter.emit_recognition_result(
                t.clone(),
                "zh-CN".to_string(),
                session_id.clone(),
                device_name.clone(),
            );
            drop(emitter);

            // Send result back to iPhone so it shows confirm/undo buttons
            let result_payload = ResultPayload {
                session_id: session_id.clone(),
                text: t.clone(),
                language: "zh-CN".to_string(),
            };
            let sender_device_id = ios_device_id.unwrap_or_else(|| envelope.device_id.clone());
            if let Err(e) = send_envelope_to_connection(
                conn_id,
                MessageType::Result,
                &result_payload,
                &sender_device_id,
                secret_key.as_deref(),
                connections,
            ).await {
                warn!("Failed to send result back to iPhone: {}", e);
            }
        }
        Ok(_) => {
            info!("ASR: empty result");
        }
        Err(e) => {
            warn!("ASR failed: {}", e);
        }
    }

    Ok(())
}

fn recognize_local(audio_data: &[u8], sample_rate: u32, channels: u32) -> Result<String, String> {
    info!(
        "Local ASR: processing {} bytes ({}Hz, {}ch)",
        audio_data.len(), sample_rate, channels
    );

    let wav_path = std::env::temp_dir().join("voicemind_local_asr.wav");
    write_wav_file(&wav_path, audio_data, sample_rate, channels)?;
    let text = recognize_with_sapi(&wav_path);
    let _ = std::fs::remove_file(&wav_path);
    text
}

fn write_wav_file(path: &std::path::Path, pcm_data: &[u8], sample_rate: u32, channels: u32) -> Result<(), String> {
    use std::io::Write;
    let data_len = pcm_data.len() as u32;
    let file = std::fs::File::create(path).map_err(|e| e.to_string())?;
    let mut writer = std::io::BufWriter::new(file);
    let bits_per_sample: u16 = 16;
    let byte_rate = sample_rate * channels * (bits_per_sample as u32 / 8);
    let block_align = (channels * (bits_per_sample as u32 / 8)) as u16;
    // RIFF header
    writer.write_all(b"RIFF").map_err(|e| e.to_string())?;
    writer.write_all(&(36 + data_len).to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(b"WAVE").map_err(|e| e.to_string())?;
    // fmt chunk
    writer.write_all(b"fmt ").map_err(|e| e.to_string())?;
    writer.write_all(&16u32.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&1u16.to_le_bytes()).map_err(|e| e.to_string())?; // PCM
    writer.write_all(&(channels as u16).to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&sample_rate.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&byte_rate.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&block_align.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&bits_per_sample.to_le_bytes()).map_err(|e| e.to_string())?;
    // data chunk
    writer.write_all(b"data").map_err(|e| e.to_string())?;
    writer.write_all(&data_len.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(pcm_data).map_err(|e| e.to_string())?;
    Ok(())
}

fn recognize_with_sapi(wav_path: &std::path::Path) -> Result<String, String> {
    let path_str = wav_path.to_string_lossy().to_string();
    let script = format!(
        r#"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Speech
$rec = New-Object System.Speech.Recognition.SpeechRecognitionEngine
$grammar = New-Object System.Speech.Recognition.DictationGrammar
$rec.LoadGrammar($grammar)
$rec.SetInputToWaveFile("{}")
$result = $rec.Recognize([System.TimeSpan]::FromSeconds(15))
if ($result -and $result.Text) {{ Write-Output $result.Text }} else {{ Write-Output "" }}
"#,
        path_str.replace("\\", "\\\\").replace("\"", "\\\"")
    );
    let output = std::process::Command::new("powershell")
        .args(["-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-Command", &script])
        .creation_flags(0x08000000) // CREATE_NO_WINDOW
        .output()
        .map_err(|e| format!("PowerShell execution failed: {}", e))?;

    let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
    info!("SAPI recognition output: {:?}, stderr: {:?}", text, String::from_utf8_lossy(&output.stderr));
    if text.is_empty() {
        return Err("No recognition result".to_string());
    }
    Ok(text)
}

/// Recognize a single audio segment from VAD using qwen_asr.exe.
/// Writes a temp WAV, runs the binary with --stream --silent, and returns the text.
async fn recognize_chunk(
    audio: &[u8],
    sample_rate: u32,
    channels: u32,
    model_size: &str,
) -> Result<String, String> {
    use tokio::io::AsyncBufReadExt;

    let binary_path = crate::qwen_asr::check_binary_available()?;
    let model_dir = crate::qwen_asr::get_model_dir(model_size);

    if !crate::qwen_asr::get_model_info(model_size).downloaded {
        return Err(format!("Qwen3 model {} not downloaded", model_size));
    }

    // Write temp WAV file
    let wav_path = std::env::temp_dir().join(format!(
        "qwen3_vad_{}.wav",
        uuid::Uuid::new_v4()
    ));
    crate::qwen_asr::write_wav_file(&wav_path, audio, sample_rate, channels)?;

    let model_dir_str = model_dir.to_string_lossy().to_string();
    let wav_str = wav_path.to_string_lossy().to_string();

    let mut cmd = crate::qwen_asr::prepare_command(&binary_path);
    cmd.arg("-d").arg(&model_dir_str)
        .arg("-i").arg(&wav_str)
        .arg("--stream")
        .arg("--silent")
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped());

    let mut child = cmd.spawn()
        .map_err(|e| format!("Failed to spawn qwen_asr: {}", e))?;

    let stdout = child.stdout.take().ok_or("Failed to capture stdout")?;
    let reader = tokio::io::BufReader::new(stdout);
    let mut lines = reader.lines();

    let mut final_text = String::new();

    while let Some(line) = lines.next_line().await.map_err(|e| format!("Read error: {}", e))? {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        // Try JSON output
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(trimmed) {
            if let Some(text) = json.get("text").and_then(|t| t.as_str()) {
                if !text.is_empty() {
                    final_text = text.to_string();
                }
            }
        } else {
            // Plain text
            if !trimmed.is_empty() {
                final_text = trimmed.to_string();
            }
        }
    }

    let _ = child.wait().await;
    let _ = std::fs::remove_file(&wav_path);

    if final_text.trim().is_empty() {
        Err("No recognition result for VAD segment".to_string())
    } else {
        Ok(final_text)
    }
}

async fn recognize_qwen3_local(
    audio_data: &[u8],
    sample_rate: u32,
    channels: u32,
    settings_store: &Arc<Mutex<crate::settings::SettingsStore>>,
    event_emitter: &Arc<Mutex<EventEmitter>>,
    session_id: &str,
) -> Result<String, String> {
    info!(
        "Qwen3 local ASR: processing {} bytes ({}Hz, {}ch)",
        audio_data.len(), sample_rate, channels
    );

    let (model_size, language) = {
        let settings = settings_store.lock().await;
        let s = settings.get();
        (s.qwen3_asr.model_size.clone(), s.qwen3_asr.language.clone())
    };

    let config = crate::qwen_asr::QwenAsrConfig {
        model_size: model_size.clone(),
        model_dir: crate::qwen_asr::get_model_dir(&model_size),
        language,
    };

    // Verify binary exists
    if let Err(e) = crate::qwen_asr::check_binary_available() {
        let msg = format!("Qwen3-ASR 二进制文件未找到: {}", e);
        warn!("{}", msg);
        let emitter2 = event_emitter.lock().await;
        emitter2.emit_error("qwen3_binary_missing".to_string(), msg.clone(), true);
        return Err(msg);
    }

    let emitter = event_emitter.lock().await;
    let result = crate::qwen_asr::recognize_streaming(
        audio_data, sample_rate, channels, &config, &emitter, session_id,
    ).await;

    drop(emitter);

    if let Err(ref e) = result {
        let emitter2 = event_emitter.lock().await;
        emitter2.emit_error("asr_qwen3_failed".to_string(), format!("Qwen3 识别失败: {}", e), true);
    }

    result
}

async fn handle_error(envelope: Envelope) -> Result<(), String> {
    let payload: ErrorPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid error payload: {}", e))?;
    warn!("iOS error: {} - {}", payload.code, payload.message);
    Ok(())
}

async fn handle_keyword(envelope: Envelope) -> Result<(), String> {
    let payload: KeywordPayload = serde_json::from_slice(&envelope.payload)
        .map_err(|e| format!("Invalid keyword payload: {}", e))?;

    match payload.action {
        KeywordAction::Confirm => {
            info!("Keyword confirm (session={})", payload.session_id);
            crate::injection::simulate_return_key();
        }
        KeywordAction::Undo => {
            info!("Keyword undo (session={})", payload.session_id);
            crate::injection::simulate_undo();
        }
    }
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
            let disconnected = conns.remove(&conn_id);
            drop(conns);
            let emitter = event_emitter.lock().await;
            if let Some(conn) = disconnected.as_ref() {
                if matches!(conn.state, ConnectionState::Listening) {
                    if let Some(session_id) = conn.current_session_id.clone() {
                        emitter.emit_listening_stopped(session_id);
                    }
                }
            }
            emitter.emit_connection_changed(false, device_name, device_id);
            return;
        }

        let Some(secret_key) = secret_key else {
            continue;
        };

        let payload = PingPayload {
            nonce: Uuid::new_v4().to_string(),
        };
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

async fn audio_stream_watchdog_loop(
    conn_id: String,
    connections: Arc<RwLock<HashMap<String, Connection>>>,
    event_emitter: Arc<Mutex<EventEmitter>>,
) {
    loop {
        tokio::time::sleep(Duration::from_secs(1)).await;

        let stale_session_id = {
            let mut conns = connections.write().await;
            let Some(conn) = conns.get_mut(&conn_id) else {
                return;
            };

            if !matches!(conn.state, ConnectionState::Listening) {
                continue;
            }

            let Some(last_audio_activity) = conn.last_audio_activity else {
                continue;
            };

            if last_audio_activity.elapsed() <= Duration::from_secs(AUDIO_STREAM_IDLE_TIMEOUT_SECS) {
                continue;
            }

            warn!(
                "Connection {} audio stream idle timeout; ending session {:?}",
                conn_id,
                conn.current_session_id
            );
            conn.state = ConnectionState::Paired;
            conn.last_audio_activity = None;
            conn.audio_buffer.clear();
            if let Some(handle) = conn.qwen3_vad_poll_task.take() {
                handle.abort();
            }
            conn.current_session_id.take()
        };

        if let Some(session_id) = stale_session_id {
            let emitter = event_emitter.lock().await;
            emitter.emit_listening_stopped(session_id);
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
    let payload_bytes =
        serde_json::to_vec(payload).map_err(|e| format!("Failed to encode payload: {}", e))?;
    let unix_timestamp = unix_seconds_now();
    // HMAC uses Unix epoch seconds (matches iOS timeIntervalSince1970),
    // but JSON timestamp uses Apple reference time (matches iOS JSONEncoder default).
    let hmac = secret_key.map(|secret| {
        generate_hmac_for_envelope(message_type, &payload_bytes, unix_timestamp, device_id, secret)
    });

    let envelope = Envelope {
        type_: message_type.as_str().to_string(),
        payload: payload_bytes,
        timestamp: unix_timestamp - APPLE_EPOCH_OFFSET,
        device_id: device_id.to_string(),
        hmac,
    };

    let frame =
        serde_json::to_vec(&envelope).map_err(|e| format!("Failed to encode envelope: {}", e))?;
    let length = (frame.len() as u32).to_be_bytes();

    let writer = {
        let conns = connections.read().await;
        conns
            .get(conn_id)
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
    // Use Auto to let the injector detect the best method (clipboard for terminals/browsers)
    crate::injection::inject_text_with_fallback(text).ok();
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

    let payload_b64 = STANDARD.encode(payload);
    let message = format!(
        "{}{}{}{}",
        message_type.as_str(),
        payload_b64,
        unix_timestamp,
        device_id
    );

    info!("HMAC message: type={}, payload_b64={}..., ts={}, device_id={}",
          message_type.as_str(),
          &payload_b64[..payload_b64.len().min(40)],
          unix_timestamp,
          device_id);

    let mut mac =
        HmacSha256::new_from_slice(secret_key.as_bytes()).expect("HMAC accepts any key size");
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
