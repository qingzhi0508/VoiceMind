#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod asr;
mod bonjour;
mod commands;
mod injection;
mod network;
mod pairing;
mod settings;
mod speech;

use std::sync::{Arc, Mutex};
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager, WindowEvent,
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
}

fn setup_logging() {
    let log_dir = dirs::data_local_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("VoiceMind")
        .join("logs");

    std::fs::create_dir_all(&log_dir).ok();

    let file_appender = RollingFileAppender::new(Rotation::DAILY, log_dir, "voicemind.log");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer().with_writer(non_blocking))
        .with(tracing_subscriber::EnvFilter::new("info"))
        .init();

    // Keep guard alive
    std::mem::forget(_guard);
}

fn main() {
    setup_logging();

    info!("VoiceMind Windows starting...");

    let result = tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            info!("Setting up VoiceMind...");

            let state = AppState {
                pairing_manager: Arc::new(Mutex::new(pairing::PairingManager::new())),
                connection_manager: Arc::new(Mutex::new(network::ConnectionManager::new())),
                history_store: Arc::new(Mutex::new(speech::HistoryStore::new())),
                settings_store: Arc::new(Mutex::new(settings::SettingsStore::new())),
                bonjour_service: Arc::new(Mutex::new(None)),
                asr_provider: Arc::new(Mutex::new(None)),
            };

            app.manage(state);

            // Get settings for initialization
            let settings = state.settings_store.lock().unwrap().get();
            let hostname = get_hostname();

            // Initialize Bonjour service if enabled
            if settings.bonjour.enabled {
                let hostname = hostname.clone();
                let port = settings.server_port;
                let bonjour_service_arc = state.bonjour_service.clone();
                tokio::spawn(async move {
                    let mut service = bonjour::BonjourService::new(&hostname, port);
                    if let Err(e) = service.start().await {
                        error!("Failed to start Bonjour: {}", e);
                    } else {
                        info!("Bonjour service started on port {}", port);
                        let mut bonjour = bonjour_service_arc.lock().unwrap();
                        *bonjour = Some(service);
                    }
                });
            }

            // Initialize ASR provider if configured
            if !settings.asr.access_key_id.is_empty() {
                let provider = asr::VeAnchorProvider::new(asr::VeAnchorConfig {
                    app_id: settings.asr.app_id.clone(),
                    access_key_id: settings.asr.access_key_id.clone(),
                    access_key_secret: settings.asr.access_key_secret.clone(),
                    cluster: settings.asr.cluster.clone(),
                    language: settings.asr.asr_language.clone(),
                });
                let mut asr = state.asr_provider.lock().unwrap();
                *asr = Some(provider);
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
        ])
        .run(tauri::generate_context!());

    if let Err(e) = result {
        error!("Error running VoiceMind: {}", e);
        std::process::exit(1);
    }
}
