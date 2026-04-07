use serde::Serialize;
use tauri::{AppHandle, Emitter};
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

pub struct EventEmitter {
    app_handle: Option<AppHandle>,
}

impl EventEmitter {
    pub fn new() -> Self {
        Self {
            app_handle: None,
        }
    }

    pub fn set_app_handle(&mut self, handle: AppHandle) {
        self.app_handle = Some(handle);
    }

    pub fn emit_connection_changed(&self, connected: bool, device_name: Option<String>, device_id: Option<String>) {
        if let Some(ref handle) = self.app_handle {
            let event = ConnectionChangedEvent {
                connected,
                device_name,
                device_id,
            };
            
            if let Err(e) = handle.emit("connection-changed", event) {
                error!("Failed to emit connection-changed event: {}", e);
            } else {
                info!("Emitted connection-changed event: connected={}", connected);
            }
        }
    }

    pub fn emit_listening_started(&self, session_id: String, device_name: Option<String>) {
        if let Some(ref handle) = self.app_handle {
            let event = ListeningStartedEvent {
                session_id,
                device_name,
            };
            
            if let Err(e) = handle.emit("listening-started", event) {
                error!("Failed to emit listening-started event: {}", e);
            } else {
                info!("Emitted listening-started event");
            }
        }
    }

    pub fn emit_listening_stopped(&self, session_id: String) {
        if let Some(ref handle) = self.app_handle {
            let event = ListeningStoppedEvent {
                session_id,
            };
            
            if let Err(e) = handle.emit("listening-stopped", event) {
                error!("Failed to emit listening-stopped event: {}", e);
            } else {
                info!("Emitted listening-stopped event");
            }
        }
    }

    pub fn emit_recognition_result(&self, text: String, language: String, session_id: String, device_name: Option<String>) {
        if let Some(ref handle) = self.app_handle {
            let event = RecognitionResultEvent {
                text,
                language,
                session_id,
                device_name,
            };
            
            if let Err(e) = handle.emit("recognition-result", event) {
                error!("Failed to emit recognition-result event: {}", e);
            } else {
                info!("Emitted recognition-result event");
            }
        }
    }

    pub fn emit_partial_result(&self, text: String, language: String, session_id: String) {
        if let Some(ref handle) = self.app_handle {
            let event = PartialResultEvent {
                text,
                language,
                session_id,
            };
            
            if let Err(e) = handle.emit("partial-result", event) {
                error!("Failed to emit partial-result event: {}", e);
            } else {
                info!("Emitted partial-result event");
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
        }
    }

    pub fn emit_service_state_changed(&self, running: bool) {
        if let Some(ref handle) = self.app_handle {
            let _ = handle.emit("service-state-changed", serde_json::json!({ "running": running }));
        }
    }

    pub fn emit_new_inbound_data(&self, record: &crate::commands::InboundDataRecord) {
        if let Some(ref handle) = self.app_handle {
            let _ = handle.emit("new-inbound-data", record);
        }
    }
}

impl Default for EventEmitter {
    fn default() -> Self {
        Self::new()
    }
}
