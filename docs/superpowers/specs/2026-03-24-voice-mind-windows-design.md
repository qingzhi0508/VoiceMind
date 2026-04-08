# VoiceMind Windows 版本设计规格

**版本**: 1.0
**日期**: 2026-03-24
**状态**: 设计中

---

## 1. 项目概述

### 1.1 项目目标

开发 VoiceMind Windows 版本，实现将 iPhone 作为无线麦克风的功能。用户按住 iPhone 上的按钮说话，文字自动输入到 Windows 电脑的任意应用程序中。

### 1.2 参考实现

参考 Type4Me 项目（macOS 语音输入工具），使用火山引擎作为 ASR 提供商。

### 1.3 核心功能

| 功能 | 描述 |
|------|------|
| 设备配对 | 通过二维码/配对码连接 iPhone |
| Bonjour 发现 | 局域网内自动发现 Windows 电脑 |
| 语音识别 | 调用火山引擎 VEAnchor 实时识别 |
| 文本注入 | 自动输入文字到当前焦点窗口 |
| 历史记录 | 保存识别历史，支持搜索和删除 |
| 系统托盘 | 后台运行，托盘菜单快速访问 |

### 1.4 不包含的功能

- 本地录音（首页的本地录音功能）- Mac 版本特有，Windows 版本不需要

---

## 2. 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                     VoiceMind Windows                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Tray    │  │ Frontend │  │  Rust     │  │  HTTP    │   │
│  │ (托盘菜单) │  │(HTML/JS) │  │ Backend  │  │  Client  │   │
│  └──────────┘  └──────────┘  └────┬─────┘  └────┬────┘   │
│                                    │            │          │
│         ┌──────────────────────────┼────────────┘          │
│         │                          │                       │
│    ┌────▼─────┐  ┌──────────┐  ┌───▼────┐  ┌──────────┐   │
│    │  Bonjour │  │  WebSocket│  │  Text   │  │  火山引擎 │   │
│    │  (mDNS)  │  │  Server  │  │Injection│  │  (ASR)   │   │
│    └──────────┘  └────┬─────┘  └──────────┘  └─────────┘   │
│                       │                          │         │
└───────────────────────┼──────────────────────────┼─────────┘
                        │                          │
                   ┌────▼────┐                ┌────▼────┐
                   │  iPhone │                │  火山引擎 │
                   │ (发送音频) │               │  VEAnchor │
                   └─────────┘                └─────────┘
```

---

## 3. 模块设计

### 3.1 模块列表

| 模块 | 文件 | 职责 |
|------|------|------|
| Tray | main.rs | 系统托盘菜单、快速配对 |
| Frontend | src/index.html | HTML 界面、Tauri 事件监听 |
| Bonjour广播 | src/bonjour.rs (新建) | mDNS 广播，让 iPhone 发现 |
| WebSocket Server | src/network.rs | 接收 iPhone 连接和音频流 |
| ASR Client | src/asr.rs (新建) | 调用火山引擎 VEAnchor 识别 |
| Text Injection | src/injection.rs | 文字注入到当前窗口 |
| Settings | src/settings.rs | 配置管理 |
| History | src/speech.rs | 识别历史存储 |
| Commands | src/commands.rs | Tauri 命令接口 |

### 3.2 Bonjour 广播模块

**目标**：让 iPhone 在同一局域网内自动发现 Windows 电脑

**技术选型**：使用 Rust `mdns` crate 或调用 Windows 版 `dns-sd.exe`

**注册的服务记录**：
```
Name: "VoiceMind-{电脑名}"
Type: "_voicemind._tcp"
Port: {配置的端口}
TxtRecord: {
    "version": "1.0",
    "platform": "windows"
}
```

**接口**：
```rust
pub struct BonjourService {
    service_name: String,
    port: u16,
    instance_name: String,
}

impl BonjourService {
    pub fn new(instance_name: &str, port: u16) -> Self;
    pub async fn start(&self) -> Result<(), String>;
    pub async fn stop(&self);
    pub async fn update(&self, port: u16);
}
```

### 3.3 ASR 客户端（火山引擎 VEAnchor）

**目标**：接收 iPhone 音频流，调用火山引擎进行实时识别

**火山引擎 VEAnchor WebSocket 协议**：

| 阶段 | 客户端发送 | 服务端返回 |
|------|-----------|-----------|
| 连接 | WSS 连接 + Token | 鉴权结果 |
| 开始 | `{"type": "start", "payload": {...}}` | `{"type": "started"}` |
| 音频 | PCM 数据帧 (base64) | 识别结果/中间结果 |
| 结束 | `{"type": "finish"}` | `{"type": "finished"}` |

**接口**（使用 channel-based 结果传递）：
```rust
pub struct VeAnchorConfig {
    pub app_id: String,
    pub access_key_id: String,
    pub access_key_secret: String,
    pub cluster: String,       // 如 "volcengine_streaming_common"
    pub language: String,      // 如 "zh-CN"
}

pub struct AsrResult {
    pub text: String,
    pub is_final: bool,        // true=最终结果, false=中间结果
    pub timestamp: i64,
}

pub type AsrResultCallback = Box<dyn Fn(AsrResult) + Send + Sync>;

pub struct AsrSession {
    result_tx: Arc<Mutex<Option<AsrResultCallback>>>,
}

impl AsrSession {
    /// 创建新的 ASR 会话
    pub fn new(callback: AsrResultCallback) -> Self;

    /// 发送音频数据（来自 iPhone）
    pub fn send_audio(&self, audio_data: &[u8]) -> Result<(), String>;

    /// 结束当前识别会话
    pub fn finish(&self) -> Result<(), String>;
}

pub struct VeAnchorProvider {
    config: VeAnchorConfig,
}

impl VeAnchorProvider {
    /// 创建 ASR 会话（每次识别创建一个新会话）
    pub fn create_session(&self, callback: AsrResultCallback) -> Result<AsrSession, String>;
}
```

**会话生命周期**：
1. `create_session()` - 创建会话，传入结果回调
2. 多次 `send_audio()` - 发送音频帧
3. `finish()` - 结束会话

**音频格式要求**：
- 采样率：16000 Hz
- 声道：1 (单声道)
- 编码：PCM 16-bit
- 传输：分帧发送，每帧 100-500ms 音频

---

## 4. 会话状态机

```
                    ┌─────────────┐
                    │   IDLE      │
                    └──────┬──────┘
                           │ iPhone 连接
                           ▼
┌─────────────────────────────────────────┐
│            ┌─────────────┐              │
│            │  CONNECTED  │              │
│            └──────┬──────┘              │
│                   │ 配对成功             │
│                   ▼                      │
│            ┌─────────────┐              │
│            │   PAIRED    │              │
│            └──────┬──────┘              │
│                   │ iPhone 开始说话      │
│                   ▼                      │
│            ┌─────────────┐   ┌─────────┐ │
│            │  LISTENING  │──►│ SENDING │ │
│            └──────┬──────┘   │  TO ASR │ │
│                   │          └────┬────┘ │
│                   │               │      │
│                   │◄──────────────┘      │
│                   │ ASR 返回结果         │
│                   ▼                      │
│            ┌─────────────┐              │
│            │  INJECTING  │              │
│            └──────┬──────┘              │
│                   │ 注入完成            │
│                   ▼                      │
│            ┌─────────────┐              │
│            │   PAIRED    │              │
│            └─────────────┘              │
└─────────────────────────────────────────┘
```

---

## 5. 关键流程

### 5.1 启动流程

```
1. main() 启动
   ↓
2. 初始化日志系统
   ↓
3. 加载/创建设置
   ↓
4. 启动 WebSocket 服务器 (network.rs)
   ↓
5. 启动 Bonjour 广播 (bonjour.rs)
   ↓
6. 初始化 ASR 提供者 (asr.rs)
   ↓
7. 构建 Tauri 应用、设置托盘
   ↓
8. 进入事件循环
```

### 5.2 配对流程

**配对码格式**：6位数字（如 `123456`），有效期120秒

**详细流程**：
```
1. Windows 端：用户点击"刷新配对码"，生成随机6位数字，显示二维码
          ↓
   二维码内容：voicemind://pair?port={PORT}&code={CODE}
          ↓
2. iPhone 扫描二维码，解析出 port 和 code
          ↓
3. iPhone 连接 WebSocket (ws://{IP}:{port})
          ↓
4. iPhone 发送：
   {
     "id": "xxx",
     "type": "pairRequest",
     "payload": {
       "short_code": "123456",
       "mac_name": "DESKTOP-XXX",
       "mac_id": "{设备ID}"
     }
   }
          ↓
5. Windows 验证 short_code 是否匹配：
   - 匹配：生成共享密钥，返回 pairConfirm
   - 不匹配：返回 error，记录失败次数
          ↓
6. iPhone 收到确认后，发送 pairSuccess
          ↓
7. 配对成功，保存设备信息到 paired_devices.json
```

**速率限制**：
- 最多连续失败5次
- 失败5次后锁定5分钟
- 锁定期间无法发起新的配对请求

### 5.3 语音识别流程

**时序说明**：iPhone 发送音频 → Windows 接收 → 转发到火山引擎 → 返回结果 → 注入

```
1. iPhone 用户按住按钮开始说话
          ↓
2. iPhone 发送：
   {
     "id": "xxx",
     "type": "audioStart",
     "payload": { "session_id": "xxx", "language": "zh-CN", ... }
   }
          ↓
3. Windows 创建 ASR 会话，连接到火山引擎
          ↓
4. iPhone 持续发送音频帧：
   {
     "type": "audioData",
     "payload": { "session_id": "xxx", "audio_data": "<base64>", "sequence_number": 1 }
   }
          ↓
5. Windows 实时转发到火山引擎 (send_audio)
          ↓
6. 火山引擎返回识别结果（中间结果）→ 通过 callback 回调
          ↓
7. Windows 收到最终结果后：
   - 调用 injection.inject(text) 注入文字
   - 保存到历史记录
          ↓
8. iPhone 松开按钮，发送：
   {
     "type": "audioEnd",
     "payload": { "session_id": "xxx" }
   }
          ↓
9. Windows 调用 asr_session.finish() 结束会话
```

**INJECTING 状态进入条件**：收到火山引擎最终结果（is_final=true）

---

## 6. 错误处理

| 错误类型 | 处理方式 |
|----------|----------|
| iPhone 断开连接 | 切换到 PAIRED 状态，保留配对信息 |
| ASR 识别失败 | 重试 2 次，仍失败则返回错误给 iPhone |
| Bonjour 广播失败 | 降级：显示手动连接 IP:端口 |
| 火山引擎认证失败 | 提示用户检查 API Key 配置 |
| 键盘注入失败 | 自动回退到剪贴板方式注入 |

**文本注入 Fallback 逻辑**：
```
1. 优先使用键盘模拟（SendInput）注入文字
2. 如果键盘注入失败（返回错误）：
   - 保存当前剪贴板内容
   - 复制识别结果到剪贴板
   - 模拟 Ctrl+V 粘贴
   - 延迟1秒后恢复原剪贴板内容
3. 如果剪贴板方式也失败：
   - 记录错误日志
   - 通知前端显示错误提示
```

---

## 7. 配置文件结构

```json
// %LOCALAPPDATA%/VoiceMind/settings.json
{
    "language": "zh-CN",
    "injection_method": "keyboard",
    "server_port": 8765,
    "hotkey": "",
    "asr": {
        "provider": "veanchor",
        "app_id": "",
        "access_key_id": "",
        "access_key_secret": "",
        "cluster": "volcengine_streaming_common",
        "asr_language": "zh-CN"
    },
    "bonjour": {
        "enabled": true,
        "service_name": "VoiceMind"
    }
}
```

---

## 8. 技术选型总结

| 组件 | 技术选型 | 说明 |
|------|----------|------|
| 框架 | Tauri 2.0 | Rust 后端 + Web 前端 |
| 语言 | Rust | 后端实现 |
| WebSocket | tokio-tungstenite | 接收 iPhone 音频流 |
| Bonjour | mdns crate | Windows mDNS 广播 |
| ASR | 火山引擎 VEAnchor | 实时语音识别 WebSocket |
| 文本注入 | Windows API | SendInput + 剪贴板 |
| 日志 | tracing + tracing-appender | 文件日志 |

---

## 9. 文件结构

```
VoiceMindWindows/
├── src-tauri/
│   ├── src/
│   │   ├── main.rs           # 应用入口
│   │   ├── commands.rs       # Tauri 命令
│   │   ├── network.rs        # WebSocket 服务器
│   │   ├── pairing.rs        # 配对管理
│   │   ├── speech.rs         # 历史记录
│   │   ├── settings.rs       # 设置
│   │   ├── injection.rs      # 文本注入
│   │   ├── asr.rs           # ASR 客户端 (新建)
│   │   └── bonjour.rs       # Bonjour 广播 (新建)
│   ├── Cargo.toml
│   └── tauri.conf.json
└── src/
    └── index.html            # 前端界面
```
