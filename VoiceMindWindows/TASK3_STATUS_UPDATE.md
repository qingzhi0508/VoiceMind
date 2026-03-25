# 任务3：添加状态更新 - 实现实时状态显示

## 📋 任务描述

在VoiceMind Windows端实现完整的实时状态更新机制，让用户能够实时了解应用和设备的连接状态。

## 🎯 核心目标

1. **多维度状态追踪** - 连接状态、聆听状态、设备信息
2. **实时UI更新** - 状态变化立即反映到界面
3. **事件驱动架构** - 基于Tauri事件系统的状态同步
4. **可靠性保证** - 状态一致性和错误恢复

## 📁 关键文件位置

```
VoiceMindWindows/src-tauri/src/
├── network.rs           # 网络通信层
├── commands.rs         # Tauri命令层
└── main.rs             # 入口和事件注册

VoiceMindWindows/src/
├── index.html          # 前端UI
└── script.js           # 前端逻辑
```

## 📊 状态类型定义

### 后端状态

```rust
// 状态枚举
#[derive(Debug, Clone, PartialEq)]
pub enum ConnectionState {
    Disconnected,    // 未连接
    Connecting,      // 连接中
    Paired,          // 已配对
    Connected,        // 已连接
    Listening,        // 聆听中
}

#[derive(Debug, Clone)]
pub struct DeviceStatus {
    pub device_id: String,
    pub device_name: String,
    pub connection_state: ConnectionState,
    pub is_listening: bool,
    pub last_seen: Option<chrono::DateTime<chrono::Utc>>,
    pub battery_level: Option<u8>,  // 如果能获取
    pub signal_strength: Option<u8>, // 信号强度
}

#[derive(Debug, Clone)]
pub struct AppStatus {
    pub running: bool,
    pub server_port: u16,
    pub bonjour_enabled: bool,
    pub current_device: Option<DeviceStatus>,
}
```

### 前端状态

```javascript
const AppState = {
    connection: {
        status: 'disconnected', // disconnected | connecting | paired | connected | listening
        device: null,
        lastUpdated: null
    },
    listening: {
        active: false,
        sessionId: null,
        startTime: null
    },
    device: {
        name: null,
        battery: null,
        signal: null,
        lastSeen: null
    },
    errors: []
};
```

## 🔄 事件系统架构

### Tauri事件定义

```rust
// src-tauri/src/events.rs

#[derive(Clone, serde::Serialize)]
pub struct ConnectionChangedEvent {
    pub connected: bool,
    pub device_name: Option<String>,
    pub device_id: Option<String>,
}

#[derive(Clone, serde::Serialize)]
pub struct ListeningEvent {
    pub started: bool,
    pub session_id: Option<String>,
}

#[derive(Clone, serde::Serialize)]
pub struct DeviceInfoEvent {
    pub device_name: String,
    pub battery: Option<u8>,
    pub signal: Option<u8>,
}

#[derive(Clone, serde::Serialize)]
pub struct ErrorEvent {
    pub code: String,
    pub message: String,
    pub recoverable: bool,
}
```

### 事件列表

| 事件名称 | 触发时机 | 数据内容 |
|---------|---------|---------|
| `connection-changed` | 连接状态变化 | connected, device_name, device_id |
| `listening-started` | 开始聆听 | session_id, device_name |
| `listening-stopped` | 停止聆听 | session_id |
| `recognition-result` | 收到识别结果 | text, language, session_id |
| `partial-result` | 部分识别结果 | text, language, session_id |
| `device-info` | 设备信息更新 | device_name, battery, signal |
| `error` | 发生错误 | code, message, recoverable |

## 🎯 后端实现

### 1. 状态管理模块

```rust
// src-tauri/src/status_manager.rs

use std::sync::Arc;
use tokio::sync::{Mutex, RwLock};
use tauri::{AppHandle, Emitter};

pub struct StatusManager {
    app_handle: AppHandle,
    current_state: RwLock<AppStatus>,
    connection_states: RwLock<HashMap<String, DeviceStatus>>,
}

impl StatusManager {
    pub fn new(app_handle: AppHandle) -> Self {
        Self {
            app_handle,
            current_state: RwLock::new(AppStatus::default()),
            connection_states: RwLock::new(HashMap::new()),
        }
    }
    
    pub async fn update_connection_state(&self, device_id: &str, state: ConnectionState) {
        let mut states = self.connection_states.write().await;
        
        if let Some(device) = states.get_mut(device_id) {
            let old_state = device.connection_state.clone();
            device.connection_state = state.clone();
            
            // 发送事件
            if old_state != state {
                self.emit_connection_changed(device).await;
            }
        }
    }
    
    pub async fn update_listening_state(&self, device_id: &str, listening: bool, session_id: Option<String>) {
        let mut states = self.connection_states.write().await;
        
        if let Some(device) = states.get_mut(device_id) {
            device.is_listening = listening;
            
            self.emit_listening_event(listening, session_id).await;
        }
    }
    
    async fn emit_connection_changed(&self, device: &DeviceStatus) {
        let event = ConnectionChangedEvent {
            connected: matches!(device.connection_state, ConnectionState::Connected | ConnectionState::Listening),
            device_name: Some(device.device_name.clone()),
            device_id: Some(device.device_id.clone()),
        };
        
        self.app_handle.emit("connection-changed", event).ok();
    }
    
    async fn emit_listening_event(&self, started: bool, session_id: Option<String>) {
        let event = ListeningEvent {
            started,
            session_id,
        };
        
        if started {
            self.app_handle.emit("listening-started", event).ok();
        } else {
            self.app_handle.emit("listening-stopped", event).ok();
        }
    }
}
```

### 2. 在network.rs中集成状态管理

```rust
// 在handle_connection函数中添加状态更新

async fn handle_connection(/* ... */) -> Result<(), String> {
    // 连接建立
    {
        let mut conns = connections.write().await;
        let mut status_manager = status_manager.write().await;
        
        conns.insert(conn_id.clone(), Connection {
            // ...
        });
        
        // 更新状态
        status_manager.update_connection_state(&conn_id, ConnectionState::Connected).await;
    }
    
    // 配对成功
    if let MessageType::PairSuccess = msg_type {
        let mut status_manager = status_manager.write().await;
        status_manager.update_connection_state(&conn_id, ConnectionState::Paired).await;
    }
    
    // 开始聆听
    if let MessageType::StartListen = msg_type {
        let mut status_manager = status_manager.write().await;
        status_manager.update_listening_state(&conn_id, true, Some(session_id)).await;
    }
}
```

### 3. Tauri命令接口

```rust
// src-tauri/src/commands.rs

#[tauri::command]
pub async fn get_current_status(state: State<'_, AppState>) -> Result<AppStatus, String> {
    let status_manager = state.status_manager.lock().await;
    Ok(status_manager.get_current_state().await)
}

#[tauri::command]
pub async fn get_device_status(state: State<'_, AppState>, device_id: String) -> Result<Option<DeviceStatus>, String> {
    let status_manager = state.status_manager.lock().await;
    Ok(status_manager.get_device_status(&device_id).await)
}

#[tauri::command]
pub async fn force_refresh_status(state: State<'_, AppState>) -> Result<(), String> {
    let status_manager = state.status_manager.lock().await;
    status_manager.force_refresh().await;
    Ok(())
}
```

## 🎨 前端实现

### 1. 状态管理类

```javascript
// src/status.js

class StatusManager {
    constructor() {
        this.state = {
            connection: {
                status: 'disconnected',
                device: null,
                lastUpdated: null
            },
            listening: {
                active: false,
                sessionId: null,
                duration: 0
            },
            errors: []
        };
        
        this.timers = {
            duration: null
        };
        
        this.init();
    }
    
    init() {
        this.setupEventListeners();
        this.startPolling();
    }
    
    setupEventListeners() {
        const { listen } = window.__TAURI__.core;
        
        // 连接状态变化
        listen('connection-changed', (event) => {
            this.updateConnectionState(event.payload);
        });
        
        // 开始聆听
        listen('listening-started', (event) => {
            this.startListening(event.payload);
        });
        
        // 停止聆听
        listen('listening-stopped', (event) => {
            this.stopListening();
        });
        
        // 识别结果
        listen('recognition-result', (event) => {
            this.handleRecognitionResult(event.payload);
        });
        
        // 错误事件
        listen('error', (event) => {
            this.handleError(event.payload);
        });
    }
    
    updateConnectionState(payload) {
        const { connected, device_name, device_id } = payload;
        
        this.state.connection = {
            status: connected ? 'connected' : 'disconnected',
            device: connected ? { name: device_name, id: device_id } : null,
            lastUpdated: new Date()
        };
        
        this.render();
        this.showNotification(connected ? '已连接' : '已断开');
    }
    
    startListening(payload) {
        const { session_id, device_name } = payload;
        
        this.state.listening = {
            active: true,
            sessionId: session_id,
            startTime: new Date(),
            duration: 0
        };
        
        // 开始计时器
        this.timers.duration = setInterval(() => {
            this.state.listening.duration = Math.floor(
                (new Date() - this.state.listening.startTime) / 1000
            );
            this.renderDuration();
        }, 1000);
        
        this.render();
        this.showNotification('开始聆听', `Session: ${session_id}`);
    }
    
    stopListening() {
        if (this.timers.duration) {
            clearInterval(this.timers.duration);
        }
        
        const duration = this.state.listening.duration;
        
        this.state.listening = {
            active: false,
            sessionId: null,
            startTime: null,
            duration: 0
        };
        
        this.render();
        this.showNotification('停止聆听', `持续时间: ${duration}秒`);
    }
    
    handleRecognitionResult(payload) {
        const { text, language, session_id } = payload;
        
        // 更新字幕
        this.updateSubtitle(text);
        
        // 添加到历史
        this.addToHistory({
            text,
            language,
            session_id,
            timestamp: new Date()
        });
    }
    
    handleError(payload) {
        const { code, message, recoverable } = payload;
        
        this.state.errors.push({
            code,
            message,
            recoverable,
            timestamp: new Date()
        });
        
        if (!recoverable) {
            this.showErrorDialog(message);
        }
        
        this.renderErrors();
    }
    
    render() {
        // 更新状态指示器
        this.updateStatusIndicator();
        
        // 更新设备信息
        this.updateDeviceInfo();
        
        // 更新聆听按钮
        this.updateListeningButton();
    }
    
    updateStatusIndicator() {
        const indicator = document.querySelector('.status-indicator');
        const statusText = document.querySelector('.status-text');
        const dot = document.querySelector('.status-dot');
        
        if (!indicator) return;
        
        // 移除所有状态类
        indicator.classList.remove('connected', 'disconnected', 'listening', 'connecting');
        
        // 添加当前状态类
        indicator.classList.add(this.state.connection.status);
        
        // 更新文本
        if (this.state.connection.status === 'connected') {
            statusText.textContent = `已连接 ${this.state.connection.device?.name || '设备'}`;
        } else if (this.state.listening.active) {
            statusText.textContent = '聆听中...';
        } else {
            statusText.textContent = '未连接';
        }
    }
    
    startPolling() {
        // 每30秒刷新一次状态
        setInterval(async () => {
            try {
                const status = await invoke('get_current_status');
                this.syncWithBackend(status);
            } catch (error) {
                console.error('Failed to refresh status:', error);
            }
        }, 30000);
    }
}
```

### 2. UI更新函数

```javascript
// src/ui-updater.js

class UIUpdater {
    constructor() {
        this.elements = {
            statusDot: document.querySelector('.status-dot'),
            statusText: document.querySelector('.status-text'),
            micButton: document.querySelector('.mic-button'),
            subtitleText: document.querySelector('.subtitle-text'),
            deviceInfo: document.querySelector('.device-info'),
            historyList: document.querySelector('.history-list')
        };
    }
    
    updateStatusDot(status) {
        if (!this.elements.statusDot) return;
        
        // 移除所有状态
        this.elements.statusDot.classList.remove(
            'connected', 'disconnected', 'listening', 'connecting'
        );
        
        // 添加当前状态
        this.elements.statusDot.classList.add(status);
        
        // 添加脉冲动画
        if (status === 'listening') {
            this.elements.statusDot.classList.add('pulse');
        } else {
            this.elements.statusDot.classList.remove('pulse');
        }
    }
    
    updateMicButton(listening) {
        if (!this.elements.micButton) return;
        
        if (listening) {
            this.elements.micButton.classList.add('listening');
            this.elements.micButton.innerHTML = '<span class="mic-icon">🔴</span>';
        } else {
            this.elements.micButton.classList.remove('listening');
            this.elements.micButton.innerHTML = '<span class="mic-icon">🎤</span>';
        }
    }
    
    updateSubtitle(text) {
        if (!this.elements.subtitleText) return;
        
        this.elements.subtitleText.textContent = text || '等待开始说话...';
        
        // 添加高亮动画
        this.elements.subtitleText.classList.add('highlight');
        setTimeout(() => {
            this.elements.subtitleText.classList.remove('highlight');
        }, 500);
    }
    
    updateDeviceInfo(device) {
        if (!this.elements.deviceInfo) return;
        
        if (device) {
            this.elements.deviceInfo.innerHTML = `
                <span class="device-icon">📱</span>
                <span class="device-name">${device.name}</span>
                ${device.battery ? `<span class="battery">🔋${device.battery}%</span>` : ''}
            `;
        } else {
            this.elements.deviceInfo.innerHTML = `
                <span class="device-icon">📱</span>
                <span class="device-name">未连接</span>
            `;
        }
    }
    
    showNotification(title, message) {
        // 创建通知
        const notification = document.createElement('div');
        notification.className = 'toast-notification';
        notification.innerHTML = `
            <strong>${title}</strong>
            <p>${message}</p>
        `;
        
        document.body.appendChild(notification);
        
        // 自动移除
        setTimeout(() => {
            notification.classList.add('fade-out');
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
    
    showErrorDialog(message) {
        const dialog = document.createElement('div');
        dialog.className = 'error-dialog';
        dialog.innerHTML = `
            <div class="error-content">
                <h3>⚠️ 发生错误</h3>
                <p>${message}</p>
                <button class="btn-primary">确定</button>
            </div>
        `;
        
        dialog.querySelector('button').addEventListener('click', () => {
            dialog.remove();
        });
        
        document.body.appendChild(dialog);
    }
}
```

## 🔄 状态同步机制

### 心跳检测

```rust
// src-tauri/src/heartbeat.rs

pub struct HeartbeatMonitor {
    interval: Duration,
    on_timeout: Arc<dyn Fn() + Send + Sync>,
}

impl HeartbeatMonitor {
    pub fn new(interval: Duration, callback: impl Fn() + Send + Sync + 'static) -> Self {
        Self {
            interval,
            on_timeout: Arc::new(callback),
        }
    }
    
    pub async fn start(&self) {
        let callback = self.on_timeout.clone();
        
        tokio::spawn(async move {
            let mut interval_timer = tokio::time::interval(self.interval);
            
            loop {
                interval_timer.tick().await;
                callback();
            }
        });
    }
}
```

### 状态重连

```javascript
// 前端重连逻辑

class ReconnectionManager {
    constructor(maxRetries = 5, baseDelay = 1000) {
        this.maxRetries = maxRetries;
        this.baseDelay = baseDelay;
        this.currentRetry = 0;
    }
    
    async attemptReconnection() {
        if (this.currentRetry >= this.maxRetries) {
            this.showError('无法重新连接，请检查网络');
            return;
        }
        
        const delay = this.baseDelay * Math.pow(2, this.currentRetry);
        
        await this.sleep(delay);
        
        try {
            await invoke('get_connection_status');
            this.currentRetry = 0;
            this.showNotification('重新连接成功');
        } catch (error) {
            this.currentRetry++;
            await this.attemptReconnection();
        }
    }
    
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    
    reset() {
        this.currentRetry = 0;
    }
}
```

## 🧪 测试用例

### 状态更新测试

1. **连接状态变化**
   - [ ] 从断开到连接
   - [ ] 从连接断开
   - [ ] 快速切换

2. **聆听状态变化**
   - [ ] 开始聆听
   - [ ] 停止聆听
   - [ ] 聆听超时

3. **设备信息更新**
   - [ ] 电池电量变化
   - [ ] 信号强度变化

4. **错误处理**
   - [ ] 网络断开
   - [ ] 服务器无响应
   - [ ] 设备超出范围

## 📊 监控指标

### 关键指标

1. **状态更新延迟** - 状态变化到UI更新的时间
2. **心跳成功率** - ping/pong成功率
3. **重连成功率** - 自动重连成功的比例
4. **错误率** - 各类错误的频率

### 日志记录

```rust
tracing::info!("Status updated: {:?}", status);
tracing::warn!("Heartbeat timeout for device {}", device_id);
tracing::error!("Failed to emit event: {}", error);
```

## 📦 交付成果

1. **后端状态管理系统**
   - 状态枚举和结构体
   - 事件发射机制
   - 心跳监控

2. **前端状态管理器**
   - 状态类
   - UI更新逻辑
   - 重连机制

3. **测试脚本**
   - 状态转换测试
   - 性能测试
   - 错误场景测试

## ⏱️ 预估工时

- 状态定义和枚举：1小时
- 后端状态管理器：3小时
- 事件系统集成：2小时
- 前端状态管理：3小时
- UI更新逻辑：2小时
- 重连机制：2小时
- 测试和调试：2小时
- **总计：约15小时**

## 🎯 成功标准

- [ ] 状态更新延迟 < 100ms
- [ ] 心跳成功率 > 99%
- [ ] 自动重连成功率 > 95%
- [ ] UI状态与实际状态一致
- [ ] 错误恢复机制正常
- [ ] 日志完整可追溯
