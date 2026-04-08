# VoiceMind Windows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 VoiceMind Windows 版本，包括 Bonjour 发现、ASR 语音识别集成、设备配对、文本注入等核心功能

**Architecture:** 基于 Tauri 2.0 + Rust 后端，使用火山引擎 VEAnchor WebSocket 协议进行实时语音识别，Bonjour mDNS 实现设备发现

**Tech Stack:** Tauri 2.0, Rust, tokio-tungstenite, mdns, tracing

---

## File Structure

```
VoiceMindWindows/
├── src-tauri/
│   ├── src/
│   │   ├── main.rs           # 修改: 启动流程集成
│   │   ├── commands.rs       # 修改: 添加 ASR 相关命令
│   │   ├── network.rs        # 修改: 集成 ASR 会话管理
│   │   ├── pairing.rs        # 已有: 配对管理
│   │   ├── speech.rs         # 已有: 历史记录
│   │   ├── settings.rs       # 修改: 添加 ASR 配置结构
│   │   ├── injection.rs      # 已有: 文本注入
│   │   ├── asr.rs           # 新建: 火山引擎 ASR 客户端
│   │   └── bonjour.rs       # 新建: Bonjour mDNS 广播
│   ├── Cargo.toml            # 修改: 添加依赖
│   └── tauri.conf.json
└── src/
    └── index.html            # 修改: ASR 配置界面
```

---

## Dependencies (Cargo.toml additions)

```toml
# 新增依赖
tokio-tungstenite = "0.21"  # 已有
futures-util = "0.3"         # 已有
hmac = "0.12"                # 已有
sha2 = "0.10"                # 已有
base64 = "0.22"             # 已有

# Bonjour 支持
[[bin]]
name = "dns-sd"
path = "src/bonjour_dns_sd.rs"

# 或使用 mdns crate (待选型)
# mdns = "0.8"
```

---

## Task 1: 搭建项目结构

**Files:**
- Modify: `VoiceMindWindows/src-tauri/Cargo.toml`
- Create: `VoiceMindWindows/src-tauri/src/asr.rs`
- Create: `VoiceMindWindows/src-tauri/src/bonjour.rs`

- [ ] **Step 1: 创建 asr.rs 骨架**

```rust
// VoiceMindWindows/src-tauri/src/asr.rs
use std::sync::{Arc, Mutex};
use tokio::sync::mpsc;

pub struct VeAnchorConfig {
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,
    pub language: String,
}

#[derive(Debug, Clone)]
pub struct AsrResult {
    pub text: String,
    pub is_final: bool,
    pub timestamp: i64,
}

pub type AsrResultCallback = Box<dyn Fn(AsrResult) + Send + Sync>;

pub struct AsrSession {
    // 占位结构，后续实现
}

impl AsrSession {
    pub fn new(_callback: AsrResultCallback) -> Self {
        todo!()
    }
    pub fn send_audio(&self, _audio_data: &[u8]) -> Result<(), String> {
        todo!()
    }
    pub fn finish(&self) -> Result<(), String> {
        todo!()
    }
}

pub struct VeAnchorProvider {
    config: VeAnchorConfig,
}

impl VeAnchorProvider {
    pub fn new(config: VeAnchorConfig) -> Self {
        Self { config }
    }
    pub fn create_session(&self, callback: AsrResultCallback) -> Result<AsrSession, String> {
        Ok(AsrSession::new(callback))
    }
}
```

- [ ] **Step 2: 创建 bonjour.rs 骨架**

```rust
// VoiceMindWindows/src-tauri/src/bonjour.rs
pub struct BonjourService {
    service_name: String,
    port: u16,
    instance_name: String,
}

impl BonjourService {
    pub fn new(instance_name: &str, port: u16) -> Self {
        todo!()
    }
    pub async fn start(&self) -> Result<(), String> {
        todo!()
    }
    pub async fn stop(&self) {
        todo!()
    }
    pub async fn update(&self, port: u16) {
        todo!()
    }
}
```

- [ ] **Step 3: 在 main.rs 中引入新模块**

```rust
// VoiceMindWindows/src-tauri/src/main.rs
mod asr;
mod bonjour;
```

- [ ] **Step 4: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功（带 todo!() 的代码会警告但不会失败）

- [ ] **Step 5: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/asr.rs VoiceMindWindows/src-tauri/src/bonjour.rs VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat: create asr and bonjour module skeletons"
```

---

## Task 2: 实现 Bonjour 广播模块

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/bonjour.rs`

**Strategy:** 使用 `dns-sd.exe` (Windows Bonjour SDK) 或 `mdns` crate。推荐先用 `dns-sd.exe` 子进程方式实现，简单可靠。

- [ ] **Step 1: 实现 BonjourService 结构体**

```rust
// VoiceMindWindows/src-tauri/src/bonjour.rs
use std::process::Stdio;
use tokio::process::Command;
use tokio::sync::mpsc;
use tracing::{info, error};

pub struct BonjourService {
    service_name: String,
    port: u16,
    instance_name: String,
    child: Option<tokio::process::Child>,
}

impl BonjourService {
    pub fn new(instance_name: &str, port: u16) -> Self {
        Self {
            service_name: "VoiceMind".to_string(),
            port,
            instance_name: instance_name.to_string(),
            child: None,
        }
    }

    /// 启动 Bonjour 广播
    /// 使用 dns-sd.exe - 苹果提供的 Windows Bonjour 工具
    /// 命令: dns-sd -r "VoiceMind-{hostname}" _voicemind._tcp local. {port}
    pub async fn start(&mut self) -> Result<(), String> {
        let instance_name = format!("{}-{}", self.service_name, self.instance_name);

        info!("Starting Bonjour broadcast: {} on port {}", instance_name, self.port);

        // 检查 dns-sd.exe 是否存在
        let dns_sd_path = self.find_dns_sd().ok_or("dns-sd.exe not found")?;

        // 启动 dns-sd 进程
        let child = Command::new(&dns_sd_path)
            .args(&[
                "-r", &instance_name,
                "_voicemind._tcp", "local.",
                &self.port.to_string(),
            ])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("Failed to start dns-sd: {}", e))?;

        self.child = Some(child);
        info!("Bonjour broadcast started successfully");
        Ok(())
    }

    /// 停止 Bonjour 广播
    pub async fn stop(&mut self) {
        if let Some(mut child) = self.child.take() {
            info!("Stopping Bonjour broadcast");
            child.kill().await.ok();
        }
    }

    /// 更新端口
    pub async fn update(&mut self, port: u16) {
        // 停止旧服务
        self.stop().await;
        // 启动新端口
        self.port = port;
        self.start().await?;
    }

    /// 查找 dns-sd.exe 路径
    fn find_dns_sd(&self) -> Option<String> {
        // Windows 上通常在以下位置
        let paths = [
            "C:\\Program Files\\Bonjour\\dns-sd.exe",
            "C:\\Program Files (x86)\\Bonjour\\dns-sd.exe",
        ];
        for path in &paths {
            if std::path::Path::new(path).exists() {
                return Some(path.to_string());
            }
        }
        None
    }
}

impl Drop for BonjourService {
    fn drop(&mut self) {
        // 确保进程被清理
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
        }
    }
}
```

- [ ] **Step 2: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 3: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/bonjour.rs
git commit -m "feat(bonjour): implement Bonjour mDNS broadcast using dns-sd.exe"
```

---

## Task 3: 实现 ASR 客户端（火山引擎 VEAnchor）

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/asr.rs`

**火山引擎 VEAnchor WebSocket 协议要点:**
- 认证: 使用 HMAC-SHA256 签名请求
- 连接: wss://openspeech.bytedance.com
- 音频格式: PCM 16000Hz 16bit mono

- [ ] **Step 1: 实现 AsrSession 结构体**

```rust
// VoiceMindWindows/src-tauri/src/asr.rs
use std::sync::{Arc, Mutex};
use std::time::SystemTime;
use base64::{Engine, engine::general_purpose::STANDARD};
use futures_util::{SinkExt, StreamExt};
use hmac::{Hmac, Mac};
use sha2::Sha256;
use tokio::net::TcpStream;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use tracing::{info, error, warn};
use uuid::Uuid;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Clone)]
pub struct AsrResult {
    pub text: String,
    pub is_final: bool,
    pub timestamp: i64,
}

pub type AsrResultCallback = Box<dyn Fn(AsrResult) + Send + Sync>;

pub struct AsrSession {
    callback: AsrResultCallback,
    ws_writer: Option<futures_util::stream::SplitSink<tokio_tungstenite::WebSocketStream<TcpStream>, Message>>,
}

impl AsrSession {
    pub fn new(callback: AsrResultCallback) -> Self {
        Self {
            callback,
            ws_writer: None,
        }
    }

    /// 连接到火山引擎并开始识别会话
    pub async fn connect(&mut self, config: &VeAnchorConfig) -> Result<(), String> {
        let url = "wss://openspeech.bytedance.com";

        // 生成认证 token (简化版本，实际需要 HMAC 签名)
        let token = self.generate_token(config)?;

        let request = tokio_tungstenite::tungstenite::client::Request::builder()
            .uri(url)
            .header("Authorization", format!("Bearer {}", token))
            .header("X-Tt-Logid", Uuid::new_v4().to_string())
            .header("Content-Type", "application/json")
            .body("")
            .map_err(|e| format!("Failed to build request: {}", e))?;

        let (ws_stream, _) = connect_async(request)
            .await
            .map_err(|e| format!("Failed to connect to ASR server: {}", e))?;

        let (writer, mut reader) = ws_stream.split();
        self.ws_writer = Some(writer);

        // 发送开始请求
        self.send_start_request(config).await?;

        // 启动读取响应任务
        let callback = self.callback.clone();
        tokio::spawn(async move {
            while let Some(msg) = reader.next().await {
                if let Ok(Message::Text(text)) = msg {
                    if let Some(result) = Self::parse_response(&text) {
                        callback(result);
                    }
                }
            }
        });

        Ok(())
    }

    /// 发送音频数据
    pub async fn send_audio(&mut self, audio_data: &[u8]) -> Result<(), String> {
        let writer = self.ws_writer.as_mut()
            .ok_or("Not connected")?;

        let audio_base64 = STANDARD.encode(audio_data);
        let payload = serde_json::json!({
            "type": "audio",
            "payload": {
                "data": audio_base64,
                "format": "pcm",
                "rate": 16000,
                "channels": 1,
                "bits": 16
            }
        });

        writer.send(Message::Text(payload.to_string()))
            .await
            .map_err(|e| format!("Failed to send audio: {}", e))?;

        Ok(())
    }

    /// 结束识别会话
    pub async fn finish(&mut self) -> Result<(), String> {
        if let Some(writer) = self.ws_writer.as_mut() {
            let payload = serde_json::json!({
                "type": "finish"
            });
            writer.send(Message::Text(payload.to_string()))
                .await
                .map_err(|e| format!("Failed to send finish: {}", e))?;
        }
        Ok(())
    }

    fn generate_token(&self, config: &VeAnchorConfig) -> Result<String, String> {
        // 火山引擎认证需要生成 HMAC 签名
        // 简化版本 - 实际需要按照火山引擎文档实现
        let timestamp = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let auth_string = format!("{}:{}", config.app_id, timestamp);

        let mut mac = HmacSha256::new_from_slice(config.access_key_secret.as_bytes())
            .map_err(|e| format!("HMAC error: {}", e))?;
        mac.update(auth_string.as_bytes());

        let result = mac.finalize();
        let signature = STANDARD.encode(result.into_bytes());

        Ok(format!("{}.{}.{}", config.app_id, timestamp, signature))
    }

    fn send_start_request(&self, config: &VeAnchorConfig) -> impl std::future::Future<Output = Result<(), String>> {
        let payload = serde_json::json!({
            "type": "start",
            "payload": {
                "appid": config.app_id,
                "cluster": config.cluster,
                "language": config.language,
                "sample_rate": 16000,
                "format": "pcm"
            }
        });

        // 注意：这需要 writer 可用，实际应该在 connect 后调用
        async move {
            Ok(())
        }
    }

    fn parse_response(text: &str) -> Option<AsrResult> {
        let json: serde_json::Value = serde_json::from_str(text).ok()?;
        let resp_type = json.get("type")?.as_str()?;

        if resp_type == "result" {
            let payload = json.get("payload")?;
            let text = payload.get("text")?.as_str()?.to_string();
            let is_final = payload.get("is_final")?.as_bool().unwrap_or(true);

            Some(AsrResult {
                text,
                is_final,
                timestamp: SystemTime::now()
                    .duration_since(SystemTime::UNIX_EPOCH)
                    .unwrap()
                    .as_millis() as i64,
            })
        } else {
            None
        }
    }
}
```

- [ ] **Step 2: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 3: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/asr.rs
git commit -m "feat(asr): implement VeAnchor ASR client skeleton"
```

---

## Task 4: 集成 ASR 到 network.rs

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/network.rs`

**目标:** 在收到 audioStart 时创建 ASR 会话，audioData 时发送音频，audioEnd 时结束会话

- [ ] **Step 1: 添加 ASR 集成到 ConnectionManager**

```rust
// 在 network.rs 头部添加导入
use crate::asr::{VeAnchorProvider, VeAnchorConfig, AsrResult};

// 在 Connection 结构体添加 ASR 字段
pub struct Connection {
    // ... 现有字段
    pub asr_session: Option<AsrSession>,  // 新增
}

// 在 ConnectionManager 添加 ASR provider
pub struct ConnectionManager {
    // ... 现有字段
    pub asr_provider: Option<VeAnchorProvider>,  // 新增
}
```

- [ ] **Step 2: 修改 handle_audio_start 处理**

```rust
// 添加新的 handler
async fn handle_audio_start(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
    asr_provider: &Option<VeAnchorProvider>,
) -> Result<(), String> {
    let payload: AudioStartPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid audioStart payload: {}", e))?;

    info!("Audio stream started: session={}", payload.session_id);

    // 如果有 ASR provider，创建 ASR 会话
    if let Some(provider) = asr_provider {
        let mut conns = connections.write().await;
        if let Some(conn) = conns.get_mut(conn_id) {
            let callback = {
                let conn_id = conn_id.to_string();
                let connections = connections.clone();
                move |result: AsrResult| {
                    // 处理 ASR 结果
                    if result.is_final {
                        info!("ASR final result: {}", result.text);
                        // 注入文字
                        // TODO: 调用 injection
                    }
                }
            };

            let mut session = provider.create_session(Box::new(callback))
                .map_err(|e| format!("Failed to create ASR session: {}", e))?;

            // 连接并开始会话
            session.connect(&VeAnchorConfig {
                app_id: "your_app_id".to_string(),
                access_key_id: "your_key_id".to_string(),
                access_key_secret: "your_key_secret".to_string(),
                cluster: "volcengine_streaming_common".to_string(),
                language: payload.language.clone(),
            }).await?;

            conn.asr_session = Some(session);
        }
    }

    Ok(())
}
```

- [ ] **Step 3: 修改 handle_audio_data 处理**

```rust
async fn handle_audio_data(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: AudioDataPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid audioData payload: {}", e))?;

    // 转发到 ASR
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        if let Some(ref mut session) = conn.asr_session {
            session.send_audio(&payload.audio_data).await?;
        }
    }

    Ok(())
}
```

- [ ] **Step 4: 修改 handle_audio_end 处理**

```rust
async fn handle_audio_end(
    conn_id: &str,
    msg: &Envelope,
    connections: &Arc<RwLock<HashMap<String, Connection>>>,
) -> Result<(), String> {
    let payload: AudioEndPayload = serde_json::from_value(msg.payload.clone())
        .map_err(|e| format!("Invalid audioEnd payload: {}", e))?;

    info!("Audio stream ended: session={}", payload.session_id);

    // 结束 ASR 会话
    let mut conns = connections.write().await;
    if let Some(conn) = conns.get_mut(conn_id) {
        if let Some(ref mut session) = conn.asr_session {
            session.finish().await?;
        }
        conn.asr_session = None;
    }

    Ok(())
}
```

- [ ] **Step 5: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 6: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/network.rs
git commit -m "feat(network): integrate ASR session management into WebSocket handling"
```

---

## Task 5: 修改 main.rs 启动流程

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/main.rs`

**目标:** 在启动时初始化 Bonjour 广播、启动 WebSocket 服务器、初始化 ASR provider

- [ ] **Step 1: 添加 AppState 新字段**

```rust
pub struct AppState {
    pub pairing_manager: Arc<Mutex<pairing::PairingManager>>,
    pub connection_manager: Arc<Mutex<network::ConnectionManager>>,
    pub history_store: Arc<Mutex<speech::HistoryStore>>,
    pub settings_store: Arc<Mutex<settings::SettingsStore>>,
    pub bonjour_service: Arc<Mutex<Option<bonjour::BonjourService>>>,  // 新增
    pub asr_provider: Arc<Mutex<Option<asr::VeAnchorProvider>>>,        // 新增
}
```

- [ ] **Step 2: 修改 setup 逻辑**

```rust
.setup(|app| {
    info!("Setting up VoiceMind...");

    // 加载设置
    let settings_store = Arc::new(Mutex::new(settings::SettingsStore::new()));
    let settings = settings_store.lock().unwrap().get();

    // 创建配对管理器
    let pairing_manager = Arc::new(Mutex::new(pairing::PairingManager::new()));

    // 创建连接管理器
    let connection_manager = Arc::new(Mutex::new(network::ConnectionManager::new()));

    // 初始化 ASR provider (如果有配置)
    let asr_provider = if !settings.asr.access_key_id.is_empty() {
        Some(asr::VeAnchorProvider::new(asr::VeAnchorConfig {
            app_id: settings.asr.app_id.clone(),
            access_key_id: settings.asr.access_key_id.clone(),
            access_key_secret: settings.asr.access_key_secret.clone(),
            cluster: settings.asr.cluster.clone(),
            language: settings.asr.asr_language.clone(),
        }))
    } else {
        None
    };

    // 初始化 Bonjour 服务
    let bonjour_service = if settings.bonjour.enabled {
        let hostname = hostname::get()
            .map(|h| h.to_string_lossy().to_string())
            .unwrap_or_else(|_| "Unknown".to_string());

        let mut service = bonjour::BonjourService::new(&hostname, settings.server_port);
        // 启动 Bonjour 广播（异步）
        tokio::spawn(async move {
            if let Err(e) = service.start().await {
                error!("Failed to start Bonjour: {}", e);
            }
        });
        Some(service)
    } else {
        None
    };

    let state = AppState {
        pairing_manager,
        connection_manager,
        history_store: Arc::new(Mutex::new(speech::HistoryStore::new())),
        settings_store,
        bonjour_service: Arc::new(Mutex::new(bonjour_service)),
        asr_provider: Arc::new(Mutex::new(asr_provider)),
    };

    // ... 后续托盘设置保持不变
})
```

- [ ] **Step 3: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(main): integrate Bonjour and ASR initialization into app startup"
```

---

## Task 6: 添加 ASR 相关命令到 commands.rs

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/commands.rs`

**目标:** 添加获取/设置 ASR 配置的命令

- [ ] **Step 1: 添加 ASR 配置命令**

```rust
#[derive(Debug, Serialize, Deserialize)]
pub struct AsrConfig {
    pub provider: String,
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,
    pub asr_language: String,
}

#[tauri::command]
pub async fn get_asr_config(state: State<'_, AppState>) -> Result<Option<AsrConfig>, String> {
    let settings = state.settings_store.lock().await;
    let s = settings.get();

    if s.asr.access_key_id.is_empty() {
        return Ok(None);
    }

    Ok(Some(AsrConfig {
        provider: s.asr.provider.clone(),
        app_id: s.asr.app_id.clone(),
        access_key_id: s.asr.access_key_id.clone(),
        access_key_secret: s.asr.access_key_secret.clone(),
        cluster: s.asr.cluster.clone(),
        asr_language: s.asr.asr_language.clone(),
    }))
}

#[tauri::command]
pub async fn save_asr_config(state: State<'_, AppState>, config: AsrConfig) -> Result<(), String> {
    let mut settings = state.settings_store.lock().await;
    let mut s = settings.get();

    s.asr.provider = config.provider;
    s.asr.app_id = config.app_id;
    s.asr.access_key_id = config.access_key_id;
    s.asr.access_key_secret = config.access_key_secret;
    s.asr.cluster = config.cluster;
    s.asr.asr_language = config.asr_language;

    settings.update(s)?;
    tracing::info!("ASR config saved");

    // 更新运行时 ASR provider
    drop(settings);
    let mut asr_provider = state.asr_provider.lock().await;
    *asr_provider = Some(asr::VeAnchorProvider::new(asr::VeAnchorConfig {
        app_id: config.app_id,
        access_key_id: config.access_key_id,
        access_key_secret: config.access_key_secret,
        cluster: config.cluster,
        language: config.asr_language,
    }));

    Ok(())
}
```

- [ ] **Step 2: 在 main.rs 注册新命令**

```rust
.invoke_handler(tauri::generate_handler![
    // ... existing commands
    commands::get_asr_config,
    commands::save_asr_config,
])
```

- [ ] **Step 3: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/commands.rs VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(commands): add ASR config get/set commands"
```

---

## Task 7: 更新 settings.rs 添加 ASR 配置结构

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/settings.rs`

- [ ] **Step 1: 添加 ASR 配置结构**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AsrSettings {
    pub provider: String,
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,
    pub asr_language: String,
}

impl Default for AsrSettings {
    fn default() -> Self {
        Self {
            provider: "veanchor".to_string(),
            app_id: String::new(),
            access_key_id: String::new(),
            access_key_secret: String::new(),
            cluster: "volcengine_streaming_common".to_string(),
            asr_language: "zh-CN".to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BonjourSettings {
    pub enabled: bool,
    pub service_name: String,
}

impl Default for BonjourSettings {
    fn default() -> Self {
        Self {
            enabled: true,
            service_name: "VoiceMind".to_string(),
        }
    }
}
```

- [ ] **Step 2: 修改 Settings 结构体**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub language: String,
    pub injection_method: String,
    pub server_port: u16,
    pub hotkey: String,
    pub asr: AsrSettings,        // 新增
    pub bonjour: BonjourSettings, // 新增
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            language: "zh-CN".to_string(),
            injection_method: "keyboard".to_string(),
            server_port: 8765,
            hotkey: String::new(),
            asr: AsrSettings::default(),
            bonjour: BonjourSettings::default(),
        }
    }
}
```

- [ ] **Step 3: 运行 cargo check 验证编译**

Run: `cd VoiceMindWindows/src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/settings.rs
git commit -m "feat(settings): add ASR and Bonjour configuration structures"
```

---

## Task 8: 更新前端界面

**Files:**
- Modify: `VoiceMindWindows/src/index.html`

**目标:** 添加 ASR 配置界面

- [ ] **Step 1: 在设置页面添加 ASR 配置区域**

```html
<!-- 在 Settings Section 添加 -->
<div class="card" id="asr-config-card">
    <h3 data-i18n="asr_config_title">火山引擎 ASR 配置</h3>
    <div class="setting-row">
        <span class="setting-label" data-i18n="asr_app_id">App ID</span>
        <input type="text" id="asr-app-id" placeholder="" style="width: 150px;">
    </div>
    <div class="setting-row">
        <span class="setting-label" data-i18n="asr_access_key_id">Access Key ID</span>
        <input type="text" id="asr-access-key-id" placeholder="" style="width: 150px;">
    </div>
    <div class="setting-row">
        <span class="setting-label" data-i18n="asr_access_key_secret">Access Key Secret</span>
        <input type="password" id="asr-access-key-secret" placeholder="" style="width: 150px;">
    </div>
    <div class="setting-row">
        <span class="setting-label" data-i18n="asr_cluster">Cluster</span>
        <input type="text" id="asr-cluster" value="volcengine_streaming_common" style="width: 150px;">
    </div>
    <div class="setting-row">
        <span class="setting-label" data-i18n="asr_language">识别语言</span>
        <select id="asr-language">
            <option value="zh-CN">中文</option>
            <option value="en-US">English</option>
        </select>
    </div>
    <button class="btn" id="btn-save-asr" data-i18n="btn_save">保存配置</button>
</div>
```

- [ ] **Step 2: 添加 ASR 配置加载和保存逻辑**

```javascript
// ASR Config
async function loadAsrConfig() {
    try {
        const config = await invoke('get_asr_config');
        if (config) {
            document.getElementById('asr-app-id').value = config.app_id || '';
            document.getElementById('asr-access-key-id').value = config.access_key_id || '';
            document.getElementById('asr-access-key-secret').value = config.access_key_secret || '';
            document.getElementById('asr-cluster').value = config.cluster || 'volcengine_streaming_common';
            document.getElementById('asr-language').value = config.asr_language || 'zh-CN';
        }
    } catch (e) {
        console.error('Failed to load ASR config:', e);
    }
}

document.getElementById('btn-save-asr').addEventListener('click', async () => {
    const config = {
        provider: 'veanchor',
        app_id: document.getElementById('asr-app-id').value,
        access_key_id: document.getElementById('asr-access-key-id').value,
        access_key_secret: document.getElementById('asr-access-key-secret').value,
        cluster: document.getElementById('asr-cluster').value,
        asr_language: document.getElementById('asr-language').value,
    };

    try {
        await invoke('save_asr_config', { config });
        showToast(t('settings_saved'));
    } catch (e) {
        console.error('Failed to save ASR config:', e);
    }
});
```

- [ ] **Step 3: 在 init() 中加载 ASR 配置**

```javascript
function init() {
    // ...
    loadSettings();
    loadAsrConfig();  // 添加这行
    // ...
}
```

- [ ] **Step 4: 提交**

```bash
git add VoiceMindWindows/src/index.html
git commit -m "feat(frontend): add ASR configuration UI to settings page"
```

---

## Task 9: 完善 ASR 实现 - 连接和认证

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/asr.rs`

**目标:** 完善火山引擎认证和连接逻辑

- [ ] **Step 1: 完善 VeAnchorProvider 和 AsrSession**

```rust
// 完整的实现需要处理:
// 1. HMAC 签名生成
// 2. WebSocket 连接管理
// 3. 音频帧发送
// 4. 结果回调

pub struct VeAnchorProvider {
    config: VeAnchorConfig,
}

impl VeAnchorProvider {
    pub fn new(config: VeAnchorConfig) -> Self {
        Self { config }
    }

    pub fn create_session(&self, callback: AsrResultCallback) -> Result<AsrSession, String> {
        Ok(AsrSession::new(callback))
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/asr.rs
git commit -m "feat(asr): complete VeAnchor WebSocket connection implementation"
```

---

## Task 10: 集成文本注入到 ASR 结果处理

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/network.rs`

**目标:** 当收到 ASR 最终结果时调用 injection 注入文字

- [ ] **Step 1: 修改 ASR callback 实现注入**

```rust
// 在 handle_audio_start 中，修改 callback:

let callback = {
    let conn_id = conn_id.to_string();
    let connections = connections.clone();
    let injection_method = settings_store.lock().unwrap().get().injection_method;
    move |result: AsrResult| {
        if result.is_final && !result.text.is_empty() {
            info!("Injecting text: {}", result.text);

            // 获取注入器
            let method = if injection_method == "clipboard" {
                InjectionMethod::Clipboard
            } else {
                InjectionMethod::Keyboard
            };
            let injector = TextInjector::new(method);

            // 执行注入
            if let Err(e) = injector.inject(&result.text) {
                error!("Injection failed: {}", e);
            }
        }
    }
};
```

- [ ] **Step 2: 提交**

```bash
git add VoiceMindWindows/src-tauri/src/network.rs
git commit -m "feat(network): integrate text injection with ASR results"
```

---

## Task 11: 端到端测试和调试

**目标:** 验证整个流程是否正常工作

- [ ] **Step 1: 编译项目**

Run: `cd VoiceMindWindows/src-tauri && cargo build --release`
Expected: 编译成功

- [ ] **Step 2: 检查 dns-sd.exe 是否可用**

```powershell
# 检查 Bonjour SDK
Get-ChildItem "C:\Program Files\Bonjour" -ErrorAction SilentlyContinue
Get-ChildItem "C:\Program Files (x86)\Bonjour" -ErrorAction SilentlyContinue
```

- [ ] **Step 3: 运行并测试**

1. 启动 VoiceMind Windows
2. 检查托盘图标
3. 检查 Bonjour 是否广播
4. 配置 ASR 凭证
5. 测试配对流程
6. 测试语音识别和注入

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | 搭建项目结构 | asr.rs, bonjour.rs, main.rs |
| 2 | 实现 Bonjour 广播 | bonjour.rs |
| 3 | 实现 ASR 客户端骨架 | asr.rs |
| 4 | 集成 ASR 到 network | network.rs |
| 5 | 修改 main.rs 启动流程 | main.rs |
| 6 | 添加 ASR 命令 | commands.rs |
| 7 | 更新 settings | settings.rs |
| 8 | 更新前端 | index.html |
| 9 | 完善 ASR 实现 | asr.rs |
| 10 | 集成文本注入 | network.rs |
| 11 | 端到端测试 | - |

---

**Total estimated tasks: 11**

