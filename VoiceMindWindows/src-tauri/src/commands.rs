use crate::{asr, AppState, speech::HistoryItem};
use serde::{Deserialize, Serialize};
use tauri::{Manager, PhysicalPosition, Position, State};
use std::net::UdpSocket;
use tracing::info;

#[cfg(windows)]
use windows::Win32::{
    Foundation::POINT,
    Graphics::Gdi::ClientToScreen,
    UI::WindowsAndMessaging::{GetCursorPos, GetGUIThreadInfo, GUITHREADINFO},
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InboundDataRecord {
    pub id: String,
    pub timestamp: String,
    pub title: String,
    pub detail: String,
    pub category: String,  // "voice" | "pairing"
    pub severity: String,  // "info" | "warning" | "error"
}

#[derive(Debug, Clone, Serialize)]
pub struct OverlayAnchor {
    pub x: i32,
    pub y: i32,
    pub source: String,
}

fn is_valid_local_ip(ip: &str) -> bool {
    // Filter out invalid/loopback/link-local IPs
    // Real network IPs (including 172.20.x.x, 192.168.x.x, 10.x.x.x) are accepted
    ip != "127.0.0.1"
        && ip != "0.0.0.0"
        && !ip.starts_with("127.")     // Loopback
        && !ip.starts_with("169.254.")  // Link-local (not routable)
}

fn is_private_ipv4(ip: &str) -> bool {
    ip.starts_with("10.")
        || ip.starts_with("192.168.")
        || ip.starts_with("172.16.")
        || ip.starts_with("172.17.")
        || ip.starts_with("172.18.")
        || ip.starts_with("172.19.")
        || ip.starts_with("172.20.")
        || ip.starts_with("172.21.")
        || ip.starts_with("172.22.")
        || ip.starts_with("172.23.")
        || ip.starts_with("172.24.")
        || ip.starts_with("172.25.")
        || ip.starts_with("172.26.")
        || ip.starts_with("172.27.")
        || ip.starts_with("172.28.")
        || ip.starts_with("172.29.")
        || ip.starts_with("172.30.")
        || ip.starts_with("172.31.")
}

fn is_likely_virtual_interface(name_lower: &str) -> bool {
    name_lower.contains("loopback")
        || name_lower.contains("isatap")
        || name_lower.contains("teredo")
        || name_lower.contains("vethernet")
        || name_lower.contains("hyper-v")
        || name_lower.contains("wsl")
        || name_lower.contains("docker")
        || name_lower.contains("virtual")
        || name_lower.contains("meta")
        || name_lower.contains("vmware")
        || name_lower.contains("virtualbox")
        || name_lower.contains("tap")
        || name_lower.contains("tun")
        || name_lower.contains("tunnel")
        || name_lower.contains("vpn")
        || name_lower.contains("tailscale")
        || name_lower.contains("zerotier")
        || name_lower.contains("wireguard")
        || name_lower.contains("ktconnect")
}

fn parse_interface_state_line(line: &str) -> Option<(String, bool)> {
    let trimmed = line.trim();
    let trimmed_lower = trimmed.to_lowercase();
    if !(trimmed_lower.starts_with("enabled")
        || trimmed_lower.starts_with("disabled")
        || trimmed_lower.starts_with("宸插惎鐢?")
        || trimmed_lower.starts_with("宸叉柇寮€"))
    {
        return None;
    }

    // netsh "show interface" output includes four columns and interface names can contain spaces.
    let tokens: Vec<&str> = trimmed.split_whitespace().collect();
    if tokens.len() < 4 {
        return None;
    }

    let is_connected = !trimmed_lower.contains("disconnected")
        && !trimmed_lower.contains("宸叉柇寮€");
    let name = tokens[3..].join(" ").trim().to_string();
    if name.is_empty() {
        return None;
    }
    Some((name, is_connected))
}

fn get_local_ip() -> Option<String> {
    // Try multiple methods to get a valid LAN IP, in order of preference

    // Method 1: Enumerate network interfaces (Windows) - most reliable
    info!("get_local_ip: trying enumerate_adapters");
    if let Some(ip) = enumerate_adapters() {
        info!("get_local_ip: enumerate_adapters returned: {}", ip);
        return Some(ip);
    }

    // Method 2: UDP socket connection (fallback, may return virtual IP)
    if let Ok(socket) = UdpSocket::bind("0.0.0.0:0") {
        if socket.connect("8.8.8.8:80").is_ok() {
            if let Ok(ip) = socket.local_addr() {
                let ip_str = ip.ip().to_string();
                if is_valid_local_ip(&ip_str) {
                    info!("get_local_ip: found valid IP via UDP: {}", ip_str);
                    return Some(ip_str);
                } else {
                    info!("get_local_ip: UDP returned invalid IP: {}", ip_str);
                }
            }
        }
    }

    // Method 3: Try connecting to a different address (114.114.114.114 - DNS)
    if let Ok(socket) = UdpSocket::bind("0.0.0.0:0") {
        if socket.connect("114.114.114.114:80").is_ok() {
            if let Ok(ip) = socket.local_addr() {
                let ip_str = ip.ip().to_string();
                if is_valid_local_ip(&ip_str) {
                    info!("get_local_ip: found valid IP via 114.114.114.114: {}", ip_str);
                    return Some(ip_str);
                }
            }
        }
    }

    info!("get_local_ip: all methods failed");
    None
}

#[cfg(windows)]
fn enumerate_adapters() -> Option<String> {
    use std::os::windows::process::CommandExt;
    use std::process::Command;

    const CREATE_NO_WINDOW: u32 = 0x08000000;

    // First, get the list of interfaces with their admin states
    let interface_output = Command::new("netsh")
        .args(["interface", "show", "interface"])
        .creation_flags(CREATE_NO_WINDOW)
        .output();

    // Build a map of interface name -> connected state
    let mut interface_connected: std::collections::HashMap<String, bool> = std::collections::HashMap::new();

    if let Ok(output) = interface_output {
        let stdout = String::from_utf8_lossy(&output.stdout);
        info!("netsh interface show interface output:\n{}", stdout);

        for line in stdout.lines() {
            if let Some((name, is_connected)) = parse_interface_state_line(line) {
                interface_connected.insert(name.clone(), is_connected);
                info!("Interface '{}' connected={} (robust parse)", name, is_connected);
                continue;
            }
            let trimmed = line.trim();
            let trimmed_lower = trimmed.to_lowercase();
            // Check for both English and Chinese states
            if trimmed_lower.starts_with("enabled") || trimmed_lower.starts_with("disabled")
                || trimmed_lower.starts_with("已启用") || trimmed_lower.starts_with("已断开")
            {
                // Check if connected (not disconnected)
                let is_connected = !trimmed_lower.contains("disconnected")
                    && !trimmed_lower.contains("已断开");

                // Extract interface name - it's typically at the end
                let name = trimmed.split_whitespace().last().unwrap_or("").trim().to_string();
                if !name.is_empty() {
                    interface_connected.insert(name.clone(), is_connected);
                    info!("Interface '{}' connected={}", name, is_connected);
                }
            }
        }
    }

    // Use netsh to get interface IP addresses
    let output = Command::new("netsh")
        .args(["interface", "ipv4", "show", "addresses"])
        .creation_flags(CREATE_NO_WINDOW)
        .output()
        .ok()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    info!("netsh ipv4 show addresses output:\n{}", stdout);

    // Collect all valid interfaces with their info
    #[derive(Debug)]
    struct InterfaceInfo {
        name: String,
        ip: Option<String>,
        has_gateway: bool,
        interface_metric: u32,
        is_connected: bool,
    }

    let mut interfaces: Vec<InterfaceInfo> = Vec::new();
    let mut current_name = String::new();
    let mut current_ip: Option<String> = None;
    let mut current_gateway = false;
    let mut current_metric: u32 = u32::MAX;

    for line in stdout.lines() {
        let trimmed = line.trim();
        let trimmed_lower = trimmed.to_lowercase();

        // Interface name line
        let is_interface_line = trimmed.starts_with("Interface \"")
            || trimmed.starts_with("Interface '")
            || (trimmed.starts_with("接口 \"") && trimmed.contains("的配置"));

        if is_interface_line {
            // Save previous interface
            if !current_name.is_empty() && current_ip.is_some() {
                let is_connected = interface_connected.get(&current_name).copied().unwrap_or(true);
                interfaces.push(InterfaceInfo {
                    name: current_name.clone(),
                    ip: current_ip.clone(),
                    has_gateway: current_gateway,
                    interface_metric: current_metric,
                    is_connected,
                });
            }

            // Reset for new interface
            current_name = if let Some(start) = trimmed.find('"').map(|i| i + 1) {
                if let Some(end) = trimmed[start..].find('"') {
                    trimmed[start..start + end].to_string()
                } else {
                    String::new()
                }
            } else if let Some(start) = trimmed.find('\'').map(|i| i + 1) {
                if let Some(end) = trimmed[start..].find('\'') {
                    trimmed[start..start + end].to_string()
                } else {
                    String::new()
                }
            } else {
                String::new()
            };

            current_ip = None;
            current_gateway = false;
            current_metric = u32::MAX;
            continue;
        }

        let name_lower = current_name.to_lowercase();

        // Skip obviously virtual interfaces and empty names
        if is_likely_virtual_interface(&name_lower) || current_name.is_empty() {
            continue;
        }

        // Check for Interface Metric
        if trimmed_lower.contains("interfacemetric") && trimmed.contains(':') {
            if let Some(metric_str) = trimmed.split(':').last().map(|s| s.trim()) {
                if let Ok(metric) = metric_str.parse::<u32>() {
                    current_metric = metric;
                }
            }
        }

        // Check for default gateway
        if (trimmed_lower.starts_with("default gateway") || trimmed_lower.starts_with("默认网关"))
            && trimmed.contains(':')
        {
            if let Some(gateway) = trimmed.split(':').last().map(|s| s.trim()) {
                if !gateway.is_empty() && gateway != "None" && !gateway.contains("::") {
                    current_gateway = true;
                }
            }
        }

        // Check for IP address
        if (trimmed_lower.starts_with("ip address") || trimmed_lower.starts_with("ip 地址"))
            && trimmed.contains(':')
        {
            if let Some(ip) = trimmed.split(':').last().map(|s| s.trim()) {
                if ip.contains('.') && !ip.starts_with("0.") && !ip.is_empty() && ip != "0.0.0.0" {
                    current_ip = Some(ip.to_string());
                }
            }
        }
    }

    // Don't forget the last interface
    if !current_name.is_empty() && current_ip.is_some() {
        let is_connected = interface_connected.get(&current_name).copied().unwrap_or(true);
        interfaces.push(InterfaceInfo {
            name: current_name,
            ip: current_ip,
            has_gateway: current_gateway,
            interface_metric: current_metric,
            is_connected,
        });
    }

    // Filter: only consider connected interfaces with gateways
    // Also filter out interfaces with virtual/benchmarking IPs (198.18.x.x)
    interfaces.retain(|i| {
        let ip_lower = i.ip.as_ref().unwrap_or(&String::new()).to_lowercase();
        i.has_gateway
            && i.is_connected
            && i.interface_metric != u32::MAX
            && !ip_lower.starts_with("198.18.")
            && !ip_lower.starts_with("198.19.")
    });

    info!("enumerate_adapters: found {} valid connected interfaces with gateways", interfaces.len());
    for (i, intf) in interfaces.iter().enumerate() {
        info!("  {}. '{}' - IP: {:?}, has_gateway: {}, metric: {}, connected: {}",
              i + 1, intf.name, intf.ip, intf.has_gateway, intf.interface_metric, intf.is_connected);
    }

    // Prefer private LAN IP + non-virtual interface, then metric.
    interfaces.sort_by_key(|i| {
        let ip = i.ip.as_deref().unwrap_or("");
        let private_rank = if is_private_ipv4(ip) { 0 } else { 1 };
        let virtual_rank = if is_likely_virtual_interface(&i.name.to_lowercase()) { 1 } else { 0 };
        (private_rank, virtual_rank, i.interface_metric)
    });

    // Select the interface with lowest metric (currently active network)
    if let Some(intf) = interfaces.first() {
        let ip = intf.ip.as_deref().unwrap_or("");
        info!(
            "enumerate_adapters: selected interface '{}' with IP {} (metric: {}, private_lan: {}, virtual_like: {})",
            intf.name,
            ip,
            intf.interface_metric,
            is_private_ipv4(ip),
            is_likely_virtual_interface(&intf.name.to_lowercase())
        );
        return intf.ip.clone();
    }

    info!("enumerate_adapters: no eligible interface found after filtering");
    None
}

/// Extract IPv4 address from an adapter block of ipconfig output
fn extract_ipv4_from_block(block: &str) -> Option<String> {
    for line in block.lines() {
        let trimmed = line.trim();
        if trimmed.contains("IPv4") && trimmed.contains(":") {
            if let Some(ip) = trimmed.split(':').last().map(|s| s.trim().to_string()) {
                if !ip.is_empty()
                    && ip != "0.0.0.0"
                    && !ip.starts_with("127.")
                    && !ip.starts_with("169.254.")
                    && !ip.starts_with("198.18.")
                    && !ip.starts_with("198.19.")
                {
                    return Some(ip);
                }
            }
        }
    }
    None
}

#[cfg(not(windows))]
fn enumerate_adapters() -> Option<String> {
    None
}

fn get_hostname() -> String {
    hostname::get()
        .map(|h| h.to_string_lossy().to_string())
        .unwrap_or_else(|_| "VoiceMind Windows".to_string())
}

fn build_pairing_qr_payload(ip: Option<&str>, port: u16, code: &str) -> Result<String, String> {
    let ip = ip.ok_or_else(|| "Unable to determine local IP address".to_string())?;
    let device_name = get_hostname();
    let device_id = format!("windows-{}", device_name.to_lowercase().replace(' ', "-"));
    info!(
        "build_pairing_qr_payload: ip={}, port={}, code={}, device_name={}, device_id={}",
        ip, port, code, device_name, device_id
    );

    serde_json::to_string(&serde_json::json!({
        "ip": ip,
        "port": port,
        "deviceId": device_id,
        "deviceName": device_name,
        "pairingCode": code
    }))
    .map_err(|e| format!("Failed to serialize QR payload: {}", e))
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AsrConfig {
    pub provider: String,
    pub app_id: String,
    #[serde(alias = "access_key_id")]
    pub access_key: String,
    #[serde(default)]
    pub access_key_secret: String,
    #[serde(alias = "cluster")]
    pub resource_id: String,
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
    info!(
        "get_pairing_qr_code: pairing_mode={}, code={}, port={}, selected_ip={:?}",
        manager.is_pairing_mode(),
        code,
        port,
        ip
    );
    
    let qr_content = build_pairing_qr_payload(ip.as_deref(), port, &code)?;

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
    
    let qr_content = build_pairing_qr_payload(ip.as_deref(), port, &code)?;

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
    if let Some(selected_ip) = ip.as_deref() {
        tracing::info!(
            "Start pairing network diagnostic - selected_ip={}, private_lan={}",
            selected_ip,
            is_private_ipv4(selected_ip)
        );
    }
    tracing::info!("QR content length: {}", qr_content.len());

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
    let conn_mgr = state.connection_manager.lock().await;
    let session_id = conn_mgr.start_listening().await?;
    tracing::info!("Start listening requested, session: {}", session_id);
    Ok(serde_json::json!({
        "success": true,
        "session_id": session_id,
        "message": null
    }))
}

#[tauri::command]
pub async fn stop_listening(state: State<'_, AppState>) -> Result<serde_json::Value, String> {
    let conn_mgr = state.connection_manager.lock().await;
    let session_id = conn_mgr.stop_listening().await?;
    tracing::info!("Stop listening requested, session: {}", session_id);
    Ok(serde_json::json!({
        "success": true,
        "session_id": session_id,
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
pub async fn start_service(state: State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut conn_mgr = state.connection_manager.lock().await;
    let settings = state.settings_store.lock().await;
    let port = settings.get().server_port;
    drop(settings);

    let pairing_mgr = state.pairing_manager.clone();
    let history_store = state.history_store.clone();
    let asr_provider = state.asr_provider.clone();
    let settings_store = state.settings_store.clone();
    conn_mgr.start_server(port, pairing_mgr, history_store, asr_provider, settings_store).await?;
    tracing::info!("Service started on port {}", port);
    Ok(serde_json::json!({ "success": true, "port": port }))
}

#[tauri::command]
pub async fn stop_service(state: State<'_, AppState>) -> Result<serde_json::Value, String> {
    let mut conn_mgr = state.connection_manager.lock().await;
    conn_mgr.stop_server().await?;
    tracing::info!("Service stopped");
    Ok(serde_json::json!({ "success": true }))
}

#[tauri::command]
pub async fn get_service_status(state: State<'_, AppState>) -> Result<bool, String> {
    let conn_mgr = state.connection_manager.lock().await;
    Ok(conn_mgr.is_running())
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
    let mut manager = state.pairing_manager.lock().await;
    manager.reload_paired_devices();
    let devices = manager.get_paired_devices();
    tracing::info!("Returning {} paired devices", devices.len());
    Ok(devices)
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

    if s.asr.access_key.is_empty() {
        return Ok(None);
    }

    Ok(Some(AsrConfig {
        provider: s.asr.provider.clone(),
        app_id: s.asr.app_id.clone(),
        access_key: s.asr.access_key.clone(),
        access_key_secret: s.asr.access_key_secret.clone(),
        resource_id: s.asr.resource_id.clone(),
        asr_language: s.asr.asr_language.clone(),
    }))
}

#[tauri::command]
pub async fn save_asr_config(state: State<'_, AppState>, config: AsrConfig) -> Result<(), String> {
    let mut settings = state.settings_store.lock().await;
    let mut s = settings.get();

    // Clone values before moving into s.asr
    let app_id = config.app_id.clone();
    let access_key = config.access_key.clone();
    let resource_id = config.resource_id.clone();
    let asr_language = config.asr_language.clone();

    s.asr.provider = config.provider;
    s.asr.app_id = app_id.clone();
    s.asr.access_key = access_key.clone();
    s.asr.access_key_secret = config.access_key_secret;
    s.asr.resource_id = resource_id.clone();
    s.asr.asr_language = asr_language.clone();

    settings.update(s)?;
    tracing::info!("ASR config saved");

    // Update runtime ASR provider
    drop(settings);
    let mut asr_provider = state.asr_provider.lock().await;
    *asr_provider = Some(asr::VolcengineProvider::new(asr::VolcengineConfig {
        app_id,
        access_key,
        resource_id,
        language: asr_language,
    }));

    Ok(())
}

#[tauri::command]
pub async fn set_history_retention(state: State<'_, AppState>, days: u32) -> Result<(), String> {
    {
        let mut settings = state.settings_store.lock().await;
        let mut s = settings.get();
        s.history_retention_days = days;
        settings.update(s)?;
    }
    {
        let mut store = state.history_store.lock().await;
        store.cleanup_expired_with_days(days);
        store.save();
    }
    tracing::info!("History retention set to {} days", days);
    Ok(())
}

#[tauri::command]
pub async fn check_local_asr() -> Result<bool, String> {
    // Windows SAPI is available on all modern Windows versions
    Ok(true)
}

#[tauri::command]
pub async fn get_accessibility_status() -> Result<String, String> {
    Ok("granted".to_string())
}

#[tauri::command]
pub async fn open_accessibility_settings() -> Result<(), String> {
    std::process::Command::new("cmd")
        .args(["/C", "start", "ms-settings:easeofaccess-keyboard"])
        .spawn()
        .map_err(|e| format!("Failed to open settings: {}", e))?;
    Ok(())
}

#[tauri::command]
pub async fn get_inbound_data_records(state: State<'_, AppState>) -> Result<Vec<InboundDataRecord>, String> {
    let records = state.inbound_data_records.lock().await;
    Ok(records.iter().cloned().collect())
}

#[tauri::command]
pub async fn clear_inbound_data_records(state: State<'_, AppState>) -> Result<(), String> {
    let mut records = state.inbound_data_records.lock().await;
    records.clear();
    Ok(())
}

#[tauri::command]
pub fn get_version(app: tauri::AppHandle) -> String {
    app.config().version.clone().unwrap_or_else(|| "0.0.0".to_string())
}

#[tauri::command]
pub async fn test_asr_connection(state: State<'_, AppState>) -> Result<String, String> {
    let provider_guard = state.asr_provider.lock().await;
    match provider_guard.as_ref() {
        Some(provider) => provider.test_connection().await,
        None => Err("ASR provider not configured. Please set App ID, Access Key and Resource ID first.".to_string()),
    }
}

#[tauri::command]
pub fn show_overlay_window(app: tauri::AppHandle) -> Result<(), String> {
    let _ = sync_overlay_window(app.clone());
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;
    crate::overlay::show_native_overlay(&window);
    Ok(())
}

#[tauri::command]
pub fn hide_overlay_window(app: tauri::AppHandle) -> Result<(), String> {
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;
    crate::overlay::hide_native_overlay(&window);
    Ok(())
}

#[tauri::command]
pub fn sync_overlay_window(app: tauri::AppHandle) -> Result<OverlayAnchor, String> {
    let anchor = get_overlay_anchor();
    let window = app
        .get_webview_window("overlay")
        .ok_or_else(|| "Overlay window not found".to_string())?;
    window
        .set_position(Position::Physical(PhysicalPosition::new(anchor.x, anchor.y)))
        .map_err(|e| e.to_string())?;
    Ok(anchor)
}

#[cfg(windows)]
fn get_overlay_anchor() -> OverlayAnchor {
    const OVERLAY_WIDTH: i32 = 560;
    const HORIZONTAL_OFFSET: i32 = 28;
    const VERTICAL_OFFSET: i32 = 16;

    unsafe {
        let mut gui_info = GUITHREADINFO {
            cbSize: std::mem::size_of::<GUITHREADINFO>() as u32,
            ..Default::default()
        };
        if GetGUIThreadInfo(0, &mut gui_info).is_ok() && !gui_info.hwndCaret.0.is_null() {
            let mut caret_origin = POINT {
                x: gui_info.rcCaret.left,
                y: gui_info.rcCaret.bottom,
            };
            if ClientToScreen(gui_info.hwndCaret, &mut caret_origin as *mut POINT).as_bool() {
                return OverlayAnchor {
                    x: caret_origin.x - HORIZONTAL_OFFSET,
                    y: caret_origin.y + VERTICAL_OFFSET,
                    source: "caret".to_string(),
                };
            }
        }

        let mut cursor = POINT::default();
        if GetCursorPos(&mut cursor).is_ok() {
            return OverlayAnchor {
                x: cursor.x - (OVERLAY_WIDTH / 2),
                y: cursor.y + VERTICAL_OFFSET,
                source: "cursor".to_string(),
            };
        }
    }

    OverlayAnchor {
        x: 120,
        y: 120,
        source: "fallback".to_string(),
    }
}

#[cfg(not(windows))]
fn get_overlay_anchor() -> OverlayAnchor {
    OverlayAnchor {
        x: 120,
        y: 120,
        source: "fallback".to_string(),
    }
}

/* ===== Qwen3 ASR Commands ===== */

#[tauri::command]
pub async fn check_qwen3_asr(_state: State<'_, AppState>) -> Result<crate::qwen_asr::Qwen3CheckResult, String> {
    let binary_available = crate::qwen_asr::check_binary_available().is_ok();
    let models = vec![
        crate::qwen_asr::get_model_info("0.6b"),
        crate::qwen_asr::get_model_info("1.7b"),
    ];
    Ok(crate::qwen_asr::Qwen3CheckResult {
        binary_available,
        models,
    })
}

#[tauri::command]
pub async fn get_qwen3_models() -> Result<Vec<crate::qwen_asr::QwenModelInfo>, String> {
    Ok(vec![
        crate::qwen_asr::get_model_info("0.6b"),
        crate::qwen_asr::get_model_info("1.7b"),
    ])
}

#[tauri::command]
pub async fn download_qwen3_model(model_size: String, app: tauri::AppHandle) -> Result<(), String> {
    if model_size != "0.6b" && model_size != "1.7b" {
        return Err("Invalid model size. Use '0.6b' or '1.7b'".to_string());
    }
    crate::qwen_asr::download_model(&model_size, app).await
}

#[tauri::command]
pub async fn delete_qwen3_model(model_size: String) -> Result<(), String> {
    if model_size != "0.6b" && model_size != "1.7b" {
        return Err("Invalid model size. Use '0.6b' or '1.7b'".to_string());
    }
    crate::qwen_asr::delete_model(&model_size)
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Qwen3AsrConfigPayload {
    pub model_size: String,
    pub language: String,
}

#[tauri::command]
pub async fn save_qwen3_asr_config(state: State<'_, AppState>, config: Qwen3AsrConfigPayload) -> Result<(), String> {
    let mut store = state.settings_store.lock().await;
    let mut settings = store.get();
    settings.qwen3_asr.model_size = config.model_size;
    settings.qwen3_asr.language = config.language;
    store.update(settings)?;
    tracing::info!("Qwen3 ASR config saved");
    Ok(())
}

#[tauri::command]
pub async fn download_qwen3_binary(app: tauri::AppHandle) -> Result<(), String> {
    crate::qwen_asr::download_qwen3_binary(app).await
}
