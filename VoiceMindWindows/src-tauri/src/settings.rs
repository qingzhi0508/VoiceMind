use serde::{Deserialize, Serialize};
use std::sync::Mutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub language: String,
    pub injection_method: String,
    pub server_port: u16,
    pub hotkey: String,
    pub bonjour: BonjourSettings,
    pub asr: AsrSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BonjourSettings {
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AsrSettings {
    pub provider: String,
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,
    pub asr_language: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            language: "zh-CN".to_string(),
            injection_method: "keyboard".to_string(),
            server_port: 8765,
            hotkey: "".to_string(),
            bonjour: BonjourSettings { enabled: true },
            asr: AsrSettings {
                provider: "".to_string(),
                app_id: "".to_string(),
                access_key_id: "".to_string(),
                access_key_secret: "".to_string(),
                cluster: "".to_string(),
                asr_language: "zh-CN".to_string(),
            },
        }
    }
}

pub struct SettingsStore {
    settings: Settings,
    storage_path: std::path::PathBuf,
}

impl SettingsStore {
    pub fn new() -> Self {
        let storage_path = dirs::data_local_dir()
            .unwrap_or_else(|| std::path::PathBuf::from("."))
            .join("VoiceMind")
            .join("settings.json");

        let mut store = Self {
            settings: Settings::default(),
            storage_path,
        };
        store.load();
        store
    }

    pub fn load(&mut self) {
        if let Ok(data) = std::fs::read_to_string(&self.storage_path) {
            if let Ok(settings) = serde_json::from_str::<Settings>(&data) {
                self.settings = settings;
            }
        }
    }

    pub fn save(&self) -> Result<(), String> {
        if let Some(parent) = self.storage_path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
        }
        let data = serde_json::to_string_pretty(&self.settings)
            .map_err(|e| format!("Failed to serialize settings: {}", e))?;
        std::fs::write(&self.storage_path, data)
            .map_err(|e| format!("Failed to write settings: {}", e))?;
        Ok(())
    }

    pub fn get(&self) -> Settings {
        self.settings.clone()
    }

    pub fn update(&mut self, settings: Settings) -> Result<(), String> {
        self.settings = settings;
        self.save()
    }

    pub fn get_language(&self) -> String {
        self.settings.language.clone()
    }

    pub fn set_language(&mut self, language: String) -> Result<(), String> {
        self.settings.language = language;
        self.save()
    }

    pub fn get_injection_method(&self) -> String {
        self.settings.injection_method.clone()
    }

    pub fn set_injection_method(&mut self, method: String) -> Result<(), String> {
        self.settings.injection_method = method;
        self.save()
    }

    pub fn get_server_port(&self) -> u16 {
        self.settings.server_port
    }

    pub fn set_server_port(&mut self, port: u16) -> Result<(), String> {
        self.settings.server_port = port;
        self.save()
    }

    pub fn get_hotkey(&self) -> String {
        self.settings.hotkey.clone()
    }

    pub fn set_hotkey(&mut self, hotkey: String) -> Result<(), String> {
        self.settings.hotkey = hotkey;
        self.save()
    }
}
