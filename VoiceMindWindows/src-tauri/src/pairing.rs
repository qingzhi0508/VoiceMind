use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use uuid::Uuid;

const MAX_FAILED_ATTEMPTS: u32 = 5;
const LOCKOUT_DURATION_SECS: u64 = 300; // 5 minutes
const PAIRING_CODE_VALIDITY_SECS: u64 = 120; // 2 minutes

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairedDeviceData {
    pub id: String,
    pub name: String,
    pub secret_key: String,
    pub paired_at: u64,
    pub last_seen: Option<u64>,
    pub auto_reconnect: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PairingState {
    current_code: Option<String>,
    pairing_code_expires: Option<u64>,
    pairing_mode: bool,
    failed_attempts: u32,
    lockout_until: Option<u64>,
    pending_device_id: Option<String>,
    pending_device_name: Option<String>,
}

pub struct PairingManager {
    port: u16,
    paired_devices: HashMap<String, PairedDeviceData>,
    state: PairingState,
    secret_key: Option<String>,
}

impl PairingManager {
    pub fn new() -> Self {
        let mut manager = Self {
            port: 8765,
            paired_devices: HashMap::new(),
            state: PairingState {
                current_code: None,
                pairing_code_expires: None,
                pairing_mode: false,
                failed_attempts: 0,
                lockout_until: None,
                pending_device_id: None,
                pending_device_name: None,
            },
            secret_key: None,
        };
        manager.load_paired_devices();
        manager
    }

    /// Generate a new 6-digit pairing code with 120-second validity
    pub fn generate_pairing_code(&mut self) {
        let code = format!("{:06}", rand_u32() % 1_000_000);
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let expires = now + PAIRING_CODE_VALIDITY_SECS;

        self.state.current_code = Some(code.clone());
        self.state.pairing_code_expires = Some(expires);
        tracing::info!("Generated pairing code: {}, expires at {}", code, expires);
    }

    pub fn get_current_code(&self) -> String {
        self.state
            .current_code
            .clone()
            .unwrap_or_else(|| "------".to_string())
    }

    pub fn get_port(&self) -> u16 {
        self.port
    }

    pub fn set_port(&mut self, port: u16) {
        self.port = port;
    }

    /// Start pairing mode
    pub fn start_pairing_mode(&mut self) {
        // Reset lockout when starting new pairing
        self.state.lockout_until = None;
        self.state.failed_attempts = 0;
        self.state.pairing_mode = true;
        self.generate_pairing_code();
        tracing::info!("Pairing mode started");
    }

    /// Stop pairing mode
    pub fn stop_pairing_mode(&mut self) {
        self.state.pairing_mode = false;
        self.state.current_code = None;
        self.state.pairing_code_expires = None;
        self.state.pending_device_id = None;
        self.state.pending_device_name = None;
        tracing::info!("Pairing mode stopped");
    }

    /// Check if currently in pairing mode
    pub fn is_pairing_mode(&self) -> bool {
        self.state.pairing_mode
    }

    /// Check if pairing is currently locked due to failed attempts
    pub fn is_locked(&mut self) -> bool {
        if let Some(lockout_until) = self.state.lockout_until {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            if now < lockout_until {
                return true;
            }
            // Lockout expired, reset
            self.state.lockout_until = None;
            self.state.failed_attempts = 0;
        }
        false
    }

    /// Get remaining lockout time in seconds
    pub fn get_lockout_remaining_secs(&self) -> Option<u64> {
        if let Some(lockout_until) = self.state.lockout_until {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            if now < lockout_until {
                return Some(lockout_until - now);
            }
        }
        None
    }

    /// Check if a pairing code is valid
    pub fn is_valid_code(&mut self, code: &str) -> bool {
        if self.is_locked() {
            return false;
        }
        if let (Some(current), Some(expires)) =
            (&self.state.current_code, self.state.pairing_code_expires)
        {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            current == code && now < expires
        } else {
            false
        }
    }

    /// Record a failed pairing attempt
    pub fn record_failed_attempt(&mut self) {
        self.state.failed_attempts += 1;
        tracing::warn!(
            "Failed pairing attempt: {}/{}",
            self.state.failed_attempts,
            MAX_FAILED_ATTEMPTS
        );

        if self.state.failed_attempts >= MAX_FAILED_ATTEMPTS {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            self.state.lockout_until = Some(now + LOCKOUT_DURATION_SECS);
            tracing::warn!(
                "Too many failed attempts. Locked for {} seconds",
                LOCKOUT_DURATION_SECS
            );
        }
    }

    /// Get remaining attempts before lockout
    pub fn get_remaining_attempts(&self) -> u32 {
        MAX_FAILED_ATTEMPTS.saturating_sub(self.state.failed_attempts)
    }

    /// Set pending device for confirmation
    pub fn set_pending_device(&mut self, device_id: String, device_name: String) {
        self.state.pending_device_id = Some(device_id);
        self.state.pending_device_name = Some(device_name);
    }

    /// Confirm pairing and generate secret key
    /// Returns the generated secret key
    pub fn confirm_pairing(&mut self, device_id: &str, device_name: &str) -> String {
        let secret_key = generate_secret_key();
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let device = PairedDeviceData {
            id: device_id.to_string(),
            name: device_name.to_string(),
            secret_key: secret_key.clone(),
            paired_at: now,
            last_seen: Some(now),
            auto_reconnect: true,
        };

        self.paired_devices.insert(device_id.to_string(), device);
        self.save_paired_devices();
        self.stop_pairing_mode();
        self.secret_key = Some(secret_key.clone());

        tracing::info!(
            "Device paired successfully: {} ({}) -> {}",
            device_name,
            device_id,
            Self::get_storage_path().display()
        );
        secret_key
    }

    /// Get paired device secret key
    pub fn get_device_secret(&self, device_id: &str) -> Option<String> {
        self.paired_devices
            .get(device_id)
            .map(|d| d.secret_key.clone())
    }

    pub fn get_device_name(&self, device_id: &str) -> Option<String> {
        self.paired_devices.get(device_id).map(|d| d.name.clone())
    }

    pub fn get_paired_device_records(&self) -> Vec<PairedDeviceData> {
        self.paired_devices.values().cloned().collect()
    }

    /// Check if a device is paired
    pub fn is_device_paired(&self, device_id: &str) -> bool {
        self.paired_devices.contains_key(device_id)
    }

    /// Update last seen timestamp for a device
    pub fn update_last_seen(&mut self, device_id: &str) {
        if let Some(device) = self.paired_devices.get_mut(device_id) {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs();
            device.last_seen = Some(now);
            self.save_paired_devices();
        }
    }

    pub fn migrate_device_id(
        &mut self,
        previous_device_id: &str,
        current_device_id: &str,
    ) -> Option<PairedDeviceData> {
        if previous_device_id == current_device_id {
            self.update_last_seen(current_device_id);
            return self.paired_devices.get(current_device_id).cloned();
        }

        let mut device = self.paired_devices.remove(previous_device_id)?;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        device.id = current_device_id.to_string();
        device.last_seen = Some(now);

        self.paired_devices
            .insert(current_device_id.to_string(), device.clone());
        self.save_paired_devices();

        tracing::warn!(
            "Migrated paired device id from {} to {} for {}",
            previous_device_id,
            current_device_id,
            device.name
        );

        Some(device)
    }

    /// Get list of paired devices
    pub fn get_paired_devices(&self) -> Vec<crate::commands::PairedDevice> {
        let mut devices: Vec<_> = self.paired_devices.values().collect();
        devices.sort_by(|a, b| b.paired_at.cmp(&a.paired_at));

        devices
            .into_iter()
            .map(|d| {
                let last_seen = d.last_seen.map(|ts| {
                    let duration = UNIX_EPOCH + Duration::from_secs(ts);
                    chrono::DateTime::<chrono::Utc>::from(duration)
                        .format("%Y-%m-%d %H:%M")
                        .to_string()
                });

                crate::commands::PairedDevice {
                    id: d.id.clone(),
                    name: d.name.clone(),
                    last_seen,
                }
            })
            .collect()
    }

    pub fn reload_paired_devices(&mut self) {
        self.load_paired_devices();
    }

    pub fn paired_device_count(&self) -> usize {
        self.paired_devices.len()
    }

    /// Remove a paired device
    pub fn remove_device(&mut self, id: &str) {
        self.paired_devices.remove(id);
        self.save_paired_devices();
        tracing::info!("Device removed: {}", id);
    }

    /// Enable/disable auto-reconnect for a device
    pub fn set_auto_reconnect(&mut self, device_id: &str, enabled: bool) {
        if let Some(device) = self.paired_devices.get_mut(device_id) {
            device.auto_reconnect = enabled;
            self.save_paired_devices();
        }
    }

    /// Check if a device has auto-reconnect enabled
    pub fn get_auto_reconnect(&self, device_id: &str) -> bool {
        self.paired_devices
            .get(device_id)
            .map(|d| d.auto_reconnect)
            .unwrap_or(false)
    }

    /// Get the current secret key (for newly paired device)
    pub fn get_current_secret(&self) -> Option<String> {
        self.secret_key.clone()
    }

    fn get_storage_path() -> std::path::PathBuf {
        dirs::data_local_dir()
            .unwrap_or_else(|| std::path::PathBuf::from("."))
            .join("VoiceMind")
            .join("paired_devices.json")
    }

    fn load_paired_devices(&mut self) {
        let path = Self::get_storage_path();
        tracing::info!("Loading paired devices from {}", path.display());
        if let Ok(data) = std::fs::read_to_string(&path) {
            if let Ok(devices) = serde_json::from_str::<HashMap<String, PairedDeviceData>>(&data) {
                self.paired_devices = devices;
                tracing::info!("Loaded {} paired devices", self.paired_devices.len());
            }
        }
    }

    fn save_paired_devices(&self) {
        let path = Self::get_storage_path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).ok();
        }
        if let Ok(data) = serde_json::to_string_pretty(&self.paired_devices) {
            std::fs::write(path, data).ok();
        }
    }
}

impl Default for PairingManager {
    fn default() -> Self {
        Self::new()
    }
}

fn rand_u32() -> u32 {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    (now % u32::MAX as u128) as u32
}

fn generate_secret_key() -> String {
    use hmac::{Hmac, Mac};
    use sha2::Sha256;

    type HmacSha256 = Hmac<Sha256>;

    let mut mac = HmacSha256::new_from_slice(b"voicemind-secret").unwrap();
    mac.update(Uuid::new_v4().as_bytes());
    let result = mac.finalize();
    base64::Engine::encode(
        &base64::engine::general_purpose::STANDARD,
        result.into_bytes(),
    )
}
