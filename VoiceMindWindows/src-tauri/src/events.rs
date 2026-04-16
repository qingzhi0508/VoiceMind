use serde::Serialize;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter, Manager};
use tracing::{error, info};

#[derive(Debug, Clone, Serialize)]
pub struct ConnectionChangedEvent {
    pub connected: bool,
    pub device_name: Option<String>,
    pub device_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ListeningStartedEvent {
    pub session_id: String,
    pub device_name: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ListeningStoppedEvent {
    pub session_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct RecognitionResultEvent {
    pub text: String,
    pub language: String,
    pub session_id: String,
    pub device_name: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct PartialResultEvent {
    pub text: String,
    pub language: String,
    pub session_id: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ErrorEvent {
    pub code: String,
    pub message: String,
    pub recoverable: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct OverlayStateEvent {
    pub mode: String,
    pub title: String,
    pub text: String,
}

pub struct EventEmitter {
    app_handle: Option<AppHandle>,
    active_overlay_session: Mutex<Option<String>>,
}

impl EventEmitter {
    pub fn new() -> Self {
        Self {
            app_handle: None,
            active_overlay_session: Mutex::new(None),
        }
    }

    pub fn set_app_handle(&mut self, handle: AppHandle) {
        self.app_handle = Some(handle);
    }

    fn emit_overlay_state(&self, mode: &str, title: String, text: String) {
        if let Some(ref handle) = self.app_handle {
            let payload = OverlayStateEvent {
                mode: mode.to_string(),
                title,
                text,
            };

            if let Some(window) = handle.get_webview_window("overlay") {
                let _ = crate::commands::sync_overlay_window(handle.clone());
                crate::overlay::show_native_overlay(&window);

                if let Ok(payload_json) = serde_json::to_string(&payload) {
                    let script = format!(
                        "window.__overlayUpdate && window.__overlayUpdate({});",
                        payload_json
                    );
                    let _ = window.eval(&script);
                }
            }

            if let Err(e) = handle.emit_to("overlay", "overlay-state", payload) {
                error!("Failed to emit overlay-state event: {}", e);
            }
        }
    }

    fn hide_overlay(&self) {
        if let Some(ref handle) = self.app_handle {
            if let Some(window) = handle.get_webview_window("overlay") {
                crate::overlay::hide_native_overlay(&window);
            }
        }
    }

    fn set_active_overlay_session(&self, session_id: Option<String>) {
        if let Ok(mut guard) = self.active_overlay_session.lock() {
            *guard = session_id;
        }
    }

    fn is_active_overlay_session(&self, session_id: &str) -> bool {
        self.active_overlay_session
            .lock()
            .ok()
            .and_then(|guard| guard.clone())
            .as_deref()
            == Some(session_id)
    }

    pub fn emit_connection_changed(
        &self,
        connected: bool,
        device_name: Option<String>,
        device_id: Option<String>,
    ) {
        if let Some(ref handle) = self.app_handle {
            let event = ConnectionChangedEvent {
                connected,
                device_name: device_name.clone(),
                device_id,
            };

            if let Err(e) = handle.emit("connection-changed", event) {
                error!("Failed to emit connection-changed event: {}", e);
            } else {
                info!("Emitted connection-changed event: connected={}", connected);
            }

            self.hide_overlay();
        }
    }

    pub fn emit_listening_started(&self, session_id: String, device_name: Option<String>) {
        if let Some(ref handle) = self.app_handle {
            let event = ListeningStartedEvent {
                session_id: session_id.clone(),
                device_name: device_name.clone(),
            };

            if let Err(e) = handle.emit("listening-started", event) {
                error!("Failed to emit listening-started event: {}", e);
            } else {
                info!("Emitted listening-started event");
            }

            self.set_active_overlay_session(Some(session_id.clone()));
            self.emit_overlay_state(
                "state-listening",
                "正在识别...".to_string(),
                "正在识别...".to_string(),
            );
        }
    }

    pub fn emit_listening_stopped(&self, session_id: String) {
        if let Some(ref handle) = self.app_handle {
            let event = ListeningStoppedEvent { session_id };

            if let Err(e) = handle.emit("listening-stopped", event) {
                error!("Failed to emit listening-stopped event: {}", e);
            } else {
                info!("Emitted listening-stopped event");
            }

            self.set_active_overlay_session(None);
            self.hide_overlay();
        }
    }

    pub fn emit_recognition_result(
        &self,
        text: String,
        language: String,
        session_id: String,
        device_name: Option<String>,
    ) {
        if let Some(ref handle) = self.app_handle {
            let event = RecognitionResultEvent {
                text: text.clone(),
                language,
                session_id,
                device_name,
            };

            if let Err(e) = handle.emit("recognition-result", event) {
                error!("Failed to emit recognition-result event: {}", e);
            } else {
                info!("Emitted recognition-result event");
            }

            self.set_active_overlay_session(None);
            self.hide_overlay();
        }
    }

    pub fn emit_partial_result(&self, text: String, language: String, session_id: String) {
        if let Some(ref handle) = self.app_handle {
            let event = PartialResultEvent {
                text: text.clone(),
                language,
                session_id: session_id.clone(),
            };

            if let Err(e) = handle.emit("partial-result", event) {
                error!("Failed to emit partial-result event: {}", e);
            } else {
                info!("Emitted partial-result event");
            }

            if !text.trim().is_empty() && self.is_active_overlay_session(&session_id) {
                self.emit_overlay_state("state-listening", "正在识别...".to_string(), text);
            }
        }
    }

    pub fn emit_error(&self, code: String, message: String, recoverable: bool) {
        if let Some(ref handle) = self.app_handle {
            let event = ErrorEvent {
                code: code.clone(),
                message: message.clone(),
                recoverable,
            };

            if let Err(e) = handle.emit("error", event) {
                error!("Failed to emit error event: {}", e);
            } else {
                info!("Emitted error event: {}", code);
            }

            self.set_active_overlay_session(None);
            self.hide_overlay();
        }
    }

    #[allow(dead_code)]
    pub fn emit_service_state_changed(&self, running: bool) {
        if let Some(ref handle) = self.app_handle {
            let _ = handle.emit("service-state-changed", serde_json::json!({ "running": running }));
        }
    }

    #[allow(dead_code)]
    pub fn emit_new_inbound_data(&self, record: &crate::commands::InboundDataRecord) {
        if let Some(ref handle) = self.app_handle {
            let _ = handle.emit("new-inbound-data", record);
        }
    }

    #[allow(dead_code)]
    pub fn emit_qwen3_download_progress(&self, progress: crate::qwen_asr::Qwen3DownloadProgress) {
        if let Some(ref handle) = self.app_handle {
            let _ = handle.emit("qwen3-download-progress", progress);
        }
    }
}

impl Default for EventEmitter {
    fn default() -> Self {
        Self::new()
    }
}
