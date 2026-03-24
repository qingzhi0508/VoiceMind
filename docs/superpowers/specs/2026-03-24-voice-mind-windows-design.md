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

**接口**：
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
    pub is_final: bool,
    pub timestamp: i64,
}

pub trait AsrProvider: Send + Sync {
    fn start(&self, config: &VeAnchorConfig) -> Result<Box<dyn AudioStream>, String>;
    fn send_audio(&self, audio_data: &[u8]) -> Result<(), String>;
    fn finish(&self) -> Result<(), String>;
}
```

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

```
1. iPhone 扫描 Bonjour 服务发现 Windows
          ↓
2. iPhone 连接 WebSocket
          ↓
3. Windows 发送配对码验证
          ↓
4. 配对成功，保存设备信息
```

### 5.3 语音识别流程

```
1. iPhone 开始录音，发送 audioStart
          ↓
2. Windows 收到后调用 asr.start()
          ↓
3. iPhone 发送音频数据 (audioData)
          ↓
4. Windows 转发到火山引擎 WebSocket
          ↓
5. 火山引擎返回识别结果
          ↓
6. Windows 调用 injection.inject() 注入文字
          ↓
7. iPhone 发送 audioEnd
          ↓
8. Windows 调用 asr.finish()
```

---

## 6. 错误处理

| 错误类型 | 处理方式 |
|----------|----------|
| iPhone 断开连接 | 切换到 PAIRED 状态，保留配对信息 |
| ASR 识别失败 | 重试 2 次，仍失败则返回错误给 iPhone |
| Bonjour 广播失败 | 降级：显示手动连接 IP:端口 |
| 火山引擎认证失败 | 提示用户检查 API Key 配置 |
| 文本注入失败 | 回退到剪贴板方式注入 |

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
