#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod asr;
mod bonjour;
mod commands;
mod events;
mod injection;
mod network;
mod pairing;
mod settings;
mod speech;

use std::sync::Arc;
use tokio::sync::Mutex;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Emitter, Manager, WindowEvent,
};
use tracing::{error, info};
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
    pub asr_provider: Arc<Mutex<Option<asr::VeAnchorProvider>>>,
    pub inbound_data_records: Arc<Mutex<std::collections::VecDeque<crate::commands::InboundDataRecord>>>,
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

            // Set app handle for connection manager and start WebSocket server
            let conn_mgr = app.state::<AppState>().connection_manager.clone();
            let pairing_mgr = app.state::<AppState>().pairing_manager.clone();
            let history_store = app.state::<AppState>().history_store.clone();
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
                match conn_mgr_guard.start_server(server_port, pairing_mgr, history_store.clone()).await {
                    Ok(_) => {
                        info!("WebSocket server started on port {}", server_port);
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
            if !init_settings.asr.access_key_id.is_empty() {
                let provider = asr::VeAnchorProvider::new(asr::VeAnchorConfig {
                    app_id: init_settings.asr.app_id.clone(),
                    access_key_id: init_settings.asr.access_key_id.clone(),
                    access_key_secret: init_settings.asr.access_key_secret.clone(),
                    cluster: init_settings.asr.cluster.clone(),
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

            let _tray = TrayIconBuilder::new()
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

            // Try to show main window after setup
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                tokio::time::sleep(tokio::time::Duration::from_millis(1000)).await;
                if let Some(window) = app_handle.get_webview_window("main") {
                    info!("Attempting to show main window...");
                    match window.show() {
                        Ok(_) => info!("Main window shown successfully"),
                        Err(e) => error!("Failed to show main window: {}", e),
                    }
                    let _ = window.set_focus();
                }
            });

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
        ])
        .run(tauri::generate_context!());

    if let Err(e) = result {
        error!("Error running VoiceMind: {}", e);
        std::process::exit(1);
    }
}
