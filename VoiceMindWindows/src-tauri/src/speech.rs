use chrono::NaiveDateTime;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

const MAX_RECORDS: usize = 1000;
const EXPIRY_DAYS: i64 = 30;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryRecord {
    pub id: String,
    pub text: String,
    pub source: String,
    pub timestamp: String,
    pub session_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryItem {
    pub id: String,
    pub text: String,
    pub source: String,
    pub timestamp: String,
    pub session_id: Option<String>,
}

impl From<HistoryRecord> for HistoryItem {
    fn from(record: HistoryRecord) -> Self {
        HistoryItem {
            id: record.id,
            text: record.text,
            source: record.source,
            timestamp: record.timestamp,
            session_id: record.session_id,
        }
    }
}

pub struct HistoryStore {
    records: Vec<HistoryRecord>,
    storage_path: std::path::PathBuf,
}

impl HistoryStore {
    pub fn new() -> Self {
        let storage_path = std::path::PathBuf::from(".").join("history.json");

        let mut store = Self {
            records: Vec::new(),
            storage_path,
        };
        store.load();
        store.cleanup_expired();
        store
    }

    pub fn add(&mut self, text: String, source: String, session_id: Option<String>) {
        let now = chrono::Local::now();
        let record = HistoryRecord {
            id: Uuid::new_v4().to_string(),
            text,
            source,
            timestamp: now.format("%Y-%m-%d %H:%M:%S").to_string(),
            session_id,
        };

        // Keep only last 1000 records
        if self.records.len() >= MAX_RECORDS {
            self.records.remove(0);
        }

        self.records.push(record);
        self.save();
    }

    pub fn get_all(&self) -> Vec<HistoryItem> {
        // Return in reverse order (newest first)
        self.records.iter().rev().map(|r| r.clone().into()).collect()
    }

    pub fn cleanup_expired(&mut self) {
        self.cleanup_expired_with_days(EXPIRY_DAYS as u32);
    }

    pub fn cleanup_expired_with_days(&mut self, days: u32) {
        let expiry = chrono::Local::now() - chrono::Duration::days(days as i64);
        let expiry_naive = expiry.naive_local();
        self.records.retain(|r| {
            if let Ok(dt) = NaiveDateTime::parse_from_str(&r.timestamp, "%Y-%m-%d %H:%M:%S") {
                dt > expiry_naive
            } else {
                true
            }
        });
    }

    pub fn delete(&mut self, id: &str) {
        self.records.retain(|r| r.id != id);
        self.save();
    }

    pub fn clear(&mut self) {
        self.records.clear();
        self.save();
    }

    pub fn search(&self, query: &str) -> Vec<HistoryItem> {
        let query_lower = query.to_lowercase();
        self.records.iter()
            .filter(|r| r.text.to_lowercase().contains(&query_lower))
            .map(|r| r.clone().into())
            .collect()
    }

    pub fn cleanup_expired_and_save(&mut self) {
        self.cleanup_expired();
        self.save();
    }

    pub fn save(&self) {
        if let Some(parent) = self.storage_path.parent() {
            std::fs::create_dir_all(parent).ok();
        }
        if let Ok(data) = serde_json::to_string_pretty(&self.records) {
            std::fs::write(&self.storage_path, data).ok();
        }
    }

    fn load(&mut self) {
        if let Ok(data) = std::fs::read_to_string(&self.storage_path) {
            if let Ok(records) = serde_json::from_str::<Vec<HistoryRecord>>(&data) {
                self.records = records;
            }
        }
    }
}
