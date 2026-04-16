#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod asr;
mod bonjour;
mod commands;
mod events;
mod injection;
mod network;
mod overlay;
mod pairing;
mod qwen_asr;
pub mod qwen3_onnx;
mod settings;
mod speech;
mod vad;

use std::sync::Arc;
use tokio::sync::Mutex;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Emitter, Manager, WebviewUrl, WebviewWindowBuilder, WindowEvent,
};
use tracing::{error, info, warn};
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn get_hostname() -> String {
    hostname::get()
        .map(|h| h.to_string_lossy().to_string())
        .unwrap_or_else(|_| "Unknown".to_string())
}

pub struct AppState {
    pub pairing_manager: Arc<Mutex<pairing::PairingManager>>,
    pub connection_manager: Arc<Mutex<network::ConnectionManager>>,
    pub history_store: Arc<Mutex<speech::HistoryStore>>,
    pub settings_store: Arc<Mutex<settings::SettingsStore>>,
    pub bonjour_service: Arc<Mutex<Option<bonjour::BonjourService>>>,
    pub asr_provider: Arc<Mutex<Option<asr::VolcengineProvider>>>,
    pub inbound_data_records: Arc<Mutex<std::collections::VecDeque<crate::commands::InboundDataRecord>>>,
}

/// Ensure Windows Firewall has an inbound rule allowing TCP connections to this app.
/// This is critical for iOS devices to connect during pairing. Without it, the packaged
/// release build silently fails because Windows blocks incoming connections to new binaries.
#[cfg(windows)]
fn ensure_firewall_rule(port: u16) {
    use std::os::windows::process::CommandExt;
    use std::process::Command;

    const CREATE_NO_WINDOW: u32 = 0x08000000;
    const RULE_NAME: &str = "VoiceMind";

    // Step 1: Check if rule already exists
    let check = Command::new("netsh")
        .args(["advfirewall", "firewall", "show", "rule", &format!("name={}", RULE_NAME)])
        .creation_flags(CREATE_NO_WINDOW)
        .output();

    if let Ok(output) = check {
        let stdout = String::from_utf8_lossy(&output.stdout).to_lowercase();
        // "no rules" or empty output means rule doesn't exist
        if stdout.contains("voicemind") && !stdout.contains("no rules") {
            info!("Firewall rule '{}' already exists", RULE_NAME);
            return;
        }
    }

    info!("Firewall rule '{}' not found, adding...", RULE_NAME);

    let exe_path = match std::env::current_exe() {
        Ok(p) => p.to_string_lossy().to_string(),
        Err(e) => {
            warn!("Cannot determine exe path for firewall rule: {}", e);
            return;
        }
    };

    // Step 2: Try direct add (works if running as admin)
    let result = Command::new("netsh")
        .args([
            "advfirewall", "firewall", "add", "rule",
            &format!("name={}", RULE_NAME),
            "dir=in",
            "action=allow",
            "enable=yes",
            &format!("program={}", exe_path),
            "protocol=tcp",
            &format!("localport={}", port),
        ])
        .creation_flags(CREATE_NO_WINDOW)
        .output();

    if let Ok(ref output) = result {
        if output.status.success() {
            info!("Firewall rule '{}' added successfully", RULE_NAME);
            return;
        }
        // If direct add failed (likely access denied), try elevated
        let stderr = String::from_utf8_lossy(&output.stderr);
        warn!("Direct firewall add failed: {}", stderr);
    }

    // Step 3: Elevated add via PowerShell (triggers UAC prompt once)
    if let Ok(temp) = std::env::var("TEMP") {
        let script_path = std::path::Path::new(&temp).join("voicemind_firewall.cmd");
        let script = format!(
            "@echo off\r\nnetsh advfirewall firewall add rule name=VoiceMind dir=in action=allow enable=yes program=\"{}\" protocol=tcp localport={}\r\ndel \"%~f0\"",
            exe_path, port
        );

        if std::fs::write(&script_path, &script).is_ok() {
            let script_str = script_path.to_string_lossy().to_string();
            let ps_cmd = format!(
                "Start-Process -FilePath '{}' -Verb RunAs -Wait",
                script_str
            );
            let _ = Command::new("powershell")
                .args(["-NoProfile", "-WindowStyle", "Hidden", "-Command", &ps_cmd])
                .creation_flags(CREATE_NO_WINDOW)
                .spawn();
            info!("Elevated firewall rule add initiated (UAC prompt may appear)");
        }
    }
}

fn setup_logging() {
    let log_dir = std::path::PathBuf::from(".").join("logs");

    // Try to create log directory, but don't fail if it doesn't work
    if let Err(e) = std::fs::create_dir_all(&log_dir) {
        eprintln!("Warning: Could not create log directory: {}", e);
    }

    let file_appender = RollingFileAppender::new(Rotation::DAILY, &log_dir, "voicemind.log");
    let (non_blocking, guard) = tracing_appender::non_blocking(file_appender);

    // Use stdout for console output + file for persistent logs
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::fmt::layer()
                .with_writer(std::io::stdout)  // Console output
                .with_ansi(true)
        )
        .with(
            tracing_subscriber::fmt::layer()
                .with_writer(non_blocking)  // File output
                .with_ansi(false)
        )
        .with(tracing_subscriber::EnvFilter::new("info"))
        .init();

    // Keep guard alive for the lifetime of the program
    Box::leak(Box::new(guard));
}

fn main() {
    setup_logging();

    info!("VoiceMind Windows starting...");

    // Wait a bit for system to be ready
    std::thread::sleep(std::time::Duration::from_millis(500));

    let result = tauri::Builder::default()
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            info!("Setting up VoiceMind...");

            // Create temporary settings for initialization
            let init_settings = settings::SettingsStore::new().get();
            let hostname = get_hostname();

            let state = AppState {
                pairing_manager: Arc::new(Mutex::new(pairing::PairingManager::new())),
                connection_manager: Arc::new(Mutex::new(network::ConnectionManager::new())),
                history_store: Arc::new(Mutex::new(speech::HistoryStore::new())),
                settings_store: Arc::new(Mutex::new(settings::SettingsStore::new())),
                bonjour_service: Arc::new(Mutex::new(None)),
                asr_provider: Arc::new(Mutex::new(None)),
                inbound_data_records: Arc::new(Mutex::new(std::collections::VecDeque::new())),
            };

            // Manage state first before accessing it
            app.manage(state);

            let overlay_window = WebviewWindowBuilder::new(
                app,
                "overlay",
                WebviewUrl::App("overlay.html".into()),
            )
            .title("VoiceMind Overlay")
            .visible(false)
            .decorations(false)
            .resizable(false)
            .skip_taskbar(true)
            .always_on_top(true)
            .transparent(true)
            .shadow(false)
            .focused(false)
            .inner_size(560.0, 104.0)
            .build()?;
            let _ = overlay_window.set_ignore_cursor_events(true);
            overlay::apply_native_overlay_style(&overlay_window);

            // Set app handle for connection manager and start WebSocket server
            let conn_mgr = app.state::<AppState>().connection_manager.clone();
            let pairing_mgr = app.state::<AppState>().pairing_manager.clone();
            let history_store = app.state::<AppState>().history_store.clone();
            let asr_provider = app.state::<AppState>().asr_provider.clone();
            let settings_store = app.state::<AppState>().settings_store.clone();
            let app_handle = app.handle().clone();
            let server_port = init_settings.server_port;
            
            tauri::async_runtime::spawn(async move {
                // Set app handle first
                {
                    let conn_guard = conn_mgr.lock().await;
                    conn_guard.set_app_handle(app_handle);
                }
                
                // Start WebSocket server
                let mut conn_mgr_guard = conn_mgr.lock().await;
                match conn_mgr_guard.start_server(server_port, pairing_mgr, history_store.clone(), asr_provider, settings_store).await {
                    Ok(_) => {
                        info!("WebSocket server started on port {}", server_port);
                        // Ensure Windows Firewall allows incoming connections
                        ensure_firewall_rule(server_port);
                    }
                    Err(e) => {
                        error!("Failed to start WebSocket server: {}", e);
                    }
                }
            });

            // Initialize Bonjour service if enabled
            if init_settings.bonjour.enabled {
                let hostname = hostname.clone();
                let port = init_settings.server_port;
                let bonjour_service_arc = app.state::<AppState>().bonjour_service.clone();
                tauri::async_runtime::spawn(async move {
                    let mut service = bonjour::BonjourService::new(&hostname, port);
                    if let Err(e) = service.start().await {
                        error!("Failed to start Bonjour: {}", e);
                    } else {
                        info!("Bonjour service started on port {}", port);
                        let mut bonjour = bonjour_service_arc.lock().await;
                        *bonjour = Some(service);
                    }
                });
            }

            // Initialize ASR provider if configured
            if !init_settings.asr.access_key.is_empty() {
                let provider = asr::VolcengineProvider::new(asr::VolcengineConfig {
                    app_id: init_settings.asr.app_id.clone(),
                    access_key: init_settings.asr.access_key.clone(),
                    resource_id: init_settings.asr.resource_id.clone(),
                    language: init_settings.asr.asr_language.clone(),
                });
                let asr_provider_arc = app.state::<AppState>().asr_provider.clone();
                tauri::async_runtime::spawn(async move {
                    let mut asr = asr_provider_arc.lock().await;
                    *asr = Some(provider);
                });
                info!("ASR provider initialized");
            }

            // Setup system tray
            let quit_item = MenuItem::with_id(app, "quit", "Quit VoiceMind", true, None::<&str>)?;
            let show_item = MenuItem::with_id(app, "show", "Show Window", true, None::<&str>)?;
            let pair_item = MenuItem::with_id(app, "pair", "Start Pairing", true, None::<&str>)?;

            let menu = Menu::with_items(app, &[&show_item, &pair_item, &quit_item])?;

            let tray_img = image::load_from_memory(include_bytes!("../icons/32x32.png"))
                .expect("Failed to load tray icon image");
            let rgba = tray_img.to_rgba8();
            let (w, h) = rgba.dimensions();
            let icon = tauri::image::Image::new_owned(rgba.into_raw(), w, h);
            let _tray = TrayIconBuilder::new()
                .icon(icon)
                .menu(&menu)
                .tooltip("VoiceMind - iPhone as Microphone")
                .on_menu_event(|app, event| {
                    match event.id.as_ref() {
                        "quit" => {
                            info!("Quit requested from tray");
                            app.exit(0);
                        }
                        "show" => {
                            if let Some(window) = app.get_webview_window("main") {
                                window.show().ok();
                                window.set_focus().ok();
                            }
                        }
                        "pair" => {
                            if let Some(window) = app.get_webview_window("main") {
                                window.show().ok();
                                window.set_focus().ok();
                                window.emit("start-pairing", ()).ok();
                            }
                        }
                        _ => {}
                    }
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            window.show().ok();
                            window.set_focus().ok();
                        }
                    }
                })
                .build(app)?;

            info!("VoiceMind setup complete");

            // Show main window immediately
            info!("Attempting to get main window...");
            if let Some(window) = app.get_webview_window("main") {
                info!("Main window found, attempting to show...");
                match window.show() {
                    Ok(_) => info!("Main window shown successfully"),
                    Err(e) => error!("Failed to show main window: {}", e),
                }
                info!("Attempting to set focus...");
                match window.set_focus() {
                    Ok(_) => info!("Main window focused successfully"),
                    Err(e) => error!("Failed to set focus: {}", e),
                }
                info!("Attempting to set title...");
                match window.set_title("VoiceMind") {
                    Ok(_) => info!("Main window title set successfully"),
                    Err(e) => error!("Failed to set title: {}", e),
                }
                info!("Attempting to set size...");
                match window.set_size(tauri::Size::Logical(tauri::LogicalSize {
                    width: 1100.0,
                    height: 750.0,
                })) {
                    Ok(_) => info!("Main window size set successfully"),
                    Err(e) => error!("Failed to set size: {}", e),
                }
                info!("Attempting to center window...");
                match window.center() {
                    Ok(_) => info!("Main window centered successfully"),
                    Err(e) => error!("Failed to center window: {}", e),
                }
                info!("Main window settings updated");
            } else {
                error!("Main window not found");
            }
            
            // Log WebView2 status
            info!("WebView2 runtime status: Checking...");
            let webview2_status = std::env::var("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS").unwrap_or_else(|_| "Not set".to_string());
            info!("WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS: {}", webview2_status);

            Ok(())
        })
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                // Hide window instead of closing
                window.hide().ok();
                api.prevent_close();
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_pairing_qr_code,
            commands::start_pairing,
            commands::stop_pairing,
            commands::get_pairing_status,
            commands::confirm_pairing,
            commands::get_paired_devices,
            commands::remove_paired_device,
            commands::get_connection_status,
            commands::get_history,
            commands::clear_history,
            commands::delete_history_item,
            commands::get_settings,
            commands::save_settings,
            commands::get_server_port,
            commands::set_server_port,
            commands::get_asr_config,
            commands::save_asr_config,
            commands::start_listening,
            commands::stop_listening,
            commands::get_listening_status,
            commands::get_accessibility_status,
            commands::open_accessibility_settings,
            commands::get_inbound_data_records,
            commands::clear_inbound_data_records,
            commands::set_history_retention,
            commands::start_service,
            commands::stop_service,
            commands::get_service_status,
            commands::check_local_asr,
            commands::test_asr_connection,
            commands::get_version,
            commands::show_overlay_window,
            commands::hide_overlay_window,
            commands::sync_overlay_window,
            commands::check_qwen3_asr,
            commands::get_qwen3_models,
            commands::download_qwen3_model,
            commands::delete_qwen3_model,
            commands::save_qwen3_asr_config,
            commands::download_qwen3_binary,
        ])
        .run(tauri::generate_context!());

    if let Err(e) = result {
        error!("Error running VoiceMind: {}", e);
        std::process::exit(1);
    }
}
