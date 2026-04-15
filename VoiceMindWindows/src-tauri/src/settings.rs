use serde::{Deserialize, Serialize};

fn default_theme() -> String { "system".to_string() }
fn default_retention_days() -> u32 { 30 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub language: String,
    pub injection_method: String,
    pub server_port: u16,
    pub hotkey: String,
    #[serde(default = "default_theme")]
    pub theme: String,
    #[serde(default = "default_retention_days")]
    pub history_retention_days: u32,
    #[serde(default)]
    pub asr_engine: String,
    pub bonjour: BonjourSettings,
    pub asr: AsrSettings,
    #[serde(default)]
    pub qwen3_asr: Qwen3AsrSettings,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BonjourSettings {
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Qwen3AsrSettings {
    #[serde(default = "default_qwen3_model_size")]
    pub model_size: String,
    #[serde(default = "default_qwen3_language")]
    pub language: String,
}

fn default_qwen3_model_size() -> String { "0.6b".to_string() }
fn default_qwen3_language() -> String { "auto".to_string() }

impl Default for Qwen3AsrSettings {
    fn default() -> Self {
        Self {
            model_size: default_qwen3_model_size(),
            language: default_qwen3_language(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AsrSettings {
    pub provider: String,
    pub app_id: String,
    #[serde(alias = "access_key_id")]
    pub access_key: String,
    #[serde(default)]
    pub access_key_secret: String, // kept for backward compat, not used by new API
    #[serde(alias = "cluster")]
    pub resource_id: String,
    pub asr_language: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            language: "zh-CN".to_string(),
            injection_method: "keyboard".to_string(),
            server_port: 8765,
            hotkey: "".to_string(),
            theme: "system".to_string(),
            history_retention_days: 30,
            asr_engine: "cloud".to_string(),
            bonjour: BonjourSettings { enabled: true },
            asr: AsrSettings {
                provider: "".to_string(),
                app_id: "".to_string(),
                access_key: "".to_string(),
                access_key_secret: "".to_string(),
                resource_id: "volc.bigasr.sauc.duration".to_string(),
                asr_language: "zh-CN".to_string(),
            },
            qwen3_asr: Qwen3AsrSettings::default(),
        }
    }
}

pub struct SettingsStore {
    settings: Settings,
    storage_path: std::path::PathBuf,
}

impl SettingsStore {
    pub fn new() -> Self {
        let storage_path = std::path::PathBuf::from(".").join("settings.json");

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
