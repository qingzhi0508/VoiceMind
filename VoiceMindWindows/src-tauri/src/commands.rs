use crate::{asr, AppState, speech::HistoryItem};
use serde::{Deserialize, Serialize};
use tauri::State;
use std::net::UdpSocket;

fn get_local_ip() -> Option<String> {
    let socket = UdpSocket::bind("0.0.0.0:0").ok()?;
    socket.connect("8.8.8.8:80").ok()?;
    socket.local_addr().ok()?.ip().to_string().into()
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AsrConfig {
    pub provider: String,
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,
    pub asr_language: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PairingQRCode {
    pub qr_content: String,
    pub pairing_code: String,
    pub expires_in: u64,
    pub ip: Option<String>,
    pub port: u16,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct PairedDevice {
    pub id: String,
    pub name: String,
    pub last_seen: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ConnectionStatus {
    pub connected: bool,
    pub name: Option<String>,
    pub device_id: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PairingStatus {
    pub is_pairing_mode: bool,
    pub current_code: Option<String>,
    pub is_locked: bool,
    pub lockout_remaining_secs: Option<u64>,
    pub remaining_attempts: u32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StartPairingResult {
    pub success: bool,
    pub pairing_code: String,
    pub qr_content: String,
    pub message: Option<String>,
    pub ip: Option<String>,
    pub port: u16,
}

#[tauri::command]
pub async fn get_pairing_qr_code(state: State<'_, AppState>) -> Result<PairingQRCode, String> {
    let mut manager = state.pairing_manager.lock().await;

    if manager.is_locked() {
        return Err("Too many failed attempts. Please try again later.".to_string());
    }

    manager.start_pairing_mode();

    let code = manager.get_current_code();
    let port = manager.get_port();
    let expires_in = 120u64;
    let ip = get_local_ip();
    
    let qr_content = match &ip {
        Some(ip_addr) => format!("voicemind://pair?ip={}&port={}&code={}", ip_addr, port, code),
        None => format!("voicemind://pair?port={}&code={}", port, code),
    };

    use qrcode::QrCode;
    use qrcode::render::svg;
    
    let qr_code = QrCode::new(qr_content.as_bytes())
        .map_err(|e| format!("Failed to generate QR code: {}", e))?;
    
    let svg_string = qr_code.render::<svg::Color>()
        .min_dimensions(200, 200)
        .build();
    
    let base64_image = base64::Engine::encode(
        &base64::engine::general_purpose::STANDARD,
        svg_string.as_bytes()
    );

    Ok(PairingQRCode {
        qr_content: format!("data:image/svg+xml;base64,{}", base64_image),
        pairing_code: code,
        expires_in,
        ip: ip.clone(),
        port,
    })
}

#[tauri::command]
pub async fn start_pairing(state: State<'_, AppState>) -> Result<StartPairingResult, String> {
    let mut manager = state.pairing_manager.lock().await;

    if manager.is_locked() {
        let remaining = manager.get_lockout_remaining_secs().unwrap_or(0);
        return Ok(StartPairingResult {
            success: false,
            pairing_code: String::new(),
            qr_content: String::new(),
            message: Some(format!("Too many failed attempts. Try again in {} seconds.", remaining)),
            ip: None,
            port: 0,
        });
    }

    manager.start_pairing_mode();

    let code = manager.get_current_code();
    let port = manager.get_port();
    let ip = get_local_ip();
    
    let qr_content = match &ip {
        Some(ip_addr) => format!("voicemind://pair?ip={}&port={}&code={}", ip_addr, port, code),
        None => format!("voicemind://pair?port={}&code={}", port, code),
    };

    use qrcode::QrCode;
    use qrcode::render::svg;
    
    let qr_code = QrCode::new(qr_content.as_bytes())
        .map_err(|e| format!("Failed to generate QR code: {}", e))?;
    
    let svg_string = qr_code.render::<svg::Color>()
        .min_dimensions(200, 200)
        .build();
    
    let base64_image = base64::Engine::encode(
        &base64::engine::general_purpose::STANDARD,
        svg_string.as_bytes()
    );

    tracing::info!("Start pairing - generated code: {}, ip: {:?}, port: {}", code, ip, port);

    Ok(StartPairingResult {
        success: true,
        pairing_code: code,
        qr_content: format!("data:image/svg+xml;base64,{}", base64_image),
        message: None,
        ip: ip.clone(),
        port,
    })
}

#[tauri::command]
pub async fn stop_pairing(state: State<'_, AppState>) -> Result<(), String> {
    let mut manager = state.pairing_manager.lock().await;
    manager.stop_pairing_mode();
    Ok(())
}

#[tauri::command]
pub async fn start_listening(state: State<'_, AppState>) -> Result<serde_json::Value, String> {
    // Placeholder - requires network enhancements
    // In the meantime, return a success message
    let session_id = uuid::Uuid::new_v4().to_string();
    tracing::info!("Start listening requested, session: {}", session_id);
    Ok(serde_json::json!({
        "success": true,
        "session_id": session_id,
        "message": null
    }))
}

#[tauri::command]
pub async fn stop_listening(state: State<'_, AppState>) -> Result<serde_json::Value, String> {
    // Placeholder - requires network enhancements
    tracing::info!("Stop listening requested");
    Ok(serde_json::json!({
        "success": true,
        "message": null
    }))
}

#[tauri::command]
pub async fn get_listening_status(state: State<'_, AppState>) -> Result<bool, String> {
    let manager = state.connection_manager.lock().await;
    let status = manager.get_connected_device().await;
    Ok(status.is_some())
}

#[tauri::command]
pub async fn get_pairing_status(state: State<'_, AppState>) -> Result<PairingStatus, String> {
    let mut manager = state.pairing_manager.lock().await;

    Ok(PairingStatus {
        is_pairing_mode: manager.is_pairing_mode(),
        current_code: if manager.is_pairing_mode() { Some(manager.get_current_code()) } else { None },
        is_locked: manager.is_locked(),
        lockout_remaining_secs: manager.get_lockout_remaining_secs(),
        remaining_attempts: manager.get_remaining_attempts(),
    })
}

#[tauri::command]
pub async fn confirm_pairing(state: State<'_, AppState>, device_id: String, device_name: String) -> Result<bool, String> {
    let mut manager = state.pairing_manager.lock().await;

    // Verify there's a pending device
    if !manager.is_pairing_mode() {
        return Err("Not in pairing mode".to_string());
    }

    manager.confirm_pairing(&device_id, &device_name);
    Ok(true)
}

#[tauri::command]
pub async fn get_paired_devices(state: State<'_, AppState>) -> Result<Vec<PairedDevice>, String> {
    let manager = state.pairing_manager.lock().await;
    Ok(manager.get_paired_devices())
}

#[tauri::command]
pub async fn remove_paired_device(state: State<'_, AppState>, id: String) -> Result<(), String> {
    let mut manager = state.pairing_manager.lock().await;
    manager.remove_device(&id);
    Ok(())
}

#[tauri::command]
pub async fn get_connection_status(state: State<'_, AppState>) -> Result<Option<ConnectionStatus>, String> {
    let manager = state.connection_manager.lock().await;
    Ok(manager.get_connected_device().await)
}

#[tauri::command]
pub async fn get_history(state: State<'_, AppState>) -> Result<Vec<HistoryItem>, String> {
    let store = state.history_store.lock().await;
    Ok(store.get_all())
}

#[tauri::command]
pub async fn clear_history(state: State<'_, AppState>) -> Result<(), String> {
    let mut store = state.history_store.lock().await;
    store.clear();
    Ok(())
}

#[tauri::command]
pub async fn delete_history_item(state: State<'_, AppState>, id: String) -> Result<(), String> {
    let mut store = state.history_store.lock().await;
    store.delete(&id);
    Ok(())
}

#[tauri::command]
pub async fn get_settings(state: State<'_, AppState>) -> Result<crate::settings::Settings, String> {
    let store = state.settings_store.lock().await;
    Ok(store.get())
}

#[tauri::command]
pub async fn save_settings(state: State<'_, AppState>, settings: crate::settings::Settings) -> Result<(), String> {
    let mut store = state.settings_store.lock().await;
    store.update(settings)?;
    tracing::info!("Settings saved");
    Ok(())
}

#[tauri::command]
pub async fn get_server_port(state: State<'_, AppState>) -> Result<u16, String> {
    let manager = state.pairing_manager.lock().await;
    Ok(manager.get_port())
}

#[tauri::command]
pub async fn set_server_port(state: State<'_, AppState>, port: u16) -> Result<(), String> {
    let mut manager = state.pairing_manager.lock().await;
    manager.set_port(port);
    Ok(())
}

#[tauri::command]
pub async fn get_asr_config(state: State<'_, AppState>) -> Result<Option<AsrConfig>, String> {
    let settings = state.settings_store.lock().await;
    let s = settings.get();

    if s.asr.access_key_id.is_empty() {
        return Ok(None);
    }

    Ok(Some(AsrConfig {
        provider: s.asr.provider.clone(),
        app_id: s.asr.app_id.clone(),
        access_key_id: s.asr.access_key_id.clone(),
        access_key_secret: s.asr.access_key_secret.clone(),
        cluster: s.asr.cluster.clone(),
        asr_language: s.asr.asr_language.clone(),
    }))
}

#[tauri::command]
pub async fn save_asr_config(state: State<'_, AppState>, config: AsrConfig) -> Result<(), String> {
    let mut settings = state.settings_store.lock().await;
    let mut s = settings.get();

    // Clone values before moving into s.asr
    let app_id = config.app_id.clone();
    let access_key_id = config.access_key_id.clone();
    let access_key_secret = config.access_key_secret.clone();
    let cluster = config.cluster.clone();
    let asr_language = config.asr_language.clone();

    s.asr.provider = config.provider;
    s.asr.app_id = app_id.clone();
    s.asr.access_key_id = access_key_id.clone();
    s.asr.access_key_secret = access_key_secret.clone();
    s.asr.cluster = cluster.clone();
    s.asr.asr_language = asr_language.clone();

    settings.update(s)?;
    tracing::info!("ASR config saved");

    // Update runtime ASR provider
    drop(settings);
    let mut asr_provider = state.asr_provider.lock().await;
    *asr_provider = Some(asr::VeAnchorProvider::new(asr::VeAnchorConfig {
        app_id,
        access_key_id,
        access_key_secret,
        cluster,
        language: asr_language,
    }));

    Ok(())
}
