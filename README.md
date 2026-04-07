# VoiceMind (语灵)

VoiceMind 是一个 macOS + iOS 语音输入系统，通过局域网连接 iPhone 与 Mac，在 Mac 应用内接收和查看识别结果。

## 功能特点

- 🔒 **安全配对**：使用 6 位数字配对码和 HMAC-SHA256 加密通信
- 🌐 **本地网络**：通过 Bonjour 自动发现，无需手动配置 IP
- 🗣️ **多语言支持**：支持中文（普通话）和英文
- 📝 **集中查看**：识别结果会显示并保存在 Mac 应用内
- 🎙️ **本地识别**：Mac 端可使用 Apple Speech 进行本地语音识别

## 系统要求

- **macOS**: macOS 14.0 (Sonoma) 或更高版本
- **iOS**: iOS 18.0 或更高版本
- **网络**: Mac 和 iPhone 需要连接到同一个 Wi-Fi 网络

## 安装步骤

### 1. 构建项目

使用 Xcode 打开 `VoiceMind.xcworkspace`：

```bash
open VoiceMind.xcworkspace
```

### 2. 配置签名

在 Xcode 中为两个 target 配置开发者账号：
- VoiceMindMac
- VoiceMindiOS

### 3. 构建和运行

1. 选择 VoiceMindMac scheme，运行到 Mac
2. 选择 VoiceMindiOS scheme，运行到 iPhone

## 使用说明

### 首次配对

1. **在 Mac 上**：
   - 启动 VoiceMindMac，菜单栏会出现麦克风图标
   - 点击菜单栏图标，选择"配对新设备"
   - 会显示一个 6 位数字的配对码（2 分钟有效）

2. **在 iPhone 上**：
   - 启动 VoiceMindiOS
   - 点击"与 Mac 配对"
   - 从列表中选择你的 Mac
   - 输入 Mac 上显示的 6 位配对码
   - 点击"配对"

3. **授予权限**：
   - **Mac**: 如使用本地识别，需要麦克风和语音识别权限
   - **iPhone**: 需要授予麦克风和语音识别权限

### 日常使用

1. 确保 Mac 和 iPhone 都在同一个 Wi-Fi 网络
2. 在 Mac 上启动 VoiceMindMac（菜单栏图标显示为绿色表示已连接）
3. 在 iPhone 上启动 VoiceMindiOS（显示"已连接"状态）
4. 在 iPhone 上开始语音输入
5. 识别结果会显示在 Mac 应用内

### 切换语言

在 iPhone 上：
1. 打开 VoiceMindiOS
2. 点击"设置"
3. 在"识别语言"中选择中文或英文

## 技术架构

### 网络通信

- **发现**: Bonjour (mDNS) 服务发现 `_voicerelay._tcp`
- **传输**: TCP + WebSocket 协议
- **安全**: HMAC-SHA256 消息认证
- **心跳**: 30 秒 ping/pong 保活
- **重连**: 指数退避重连（1s → 2s → 4s → 8s → 10s）

### 消息协议

```
[4 字节长度] + [JSON 消息体]
```

消息类型：
- `pairRequest`: Mac 发起配对请求
- `pairConfirm`: iPhone 确认配对
- `pairSuccess`: Mac 返回配对成功和共享密钥
- `startListen`: Mac 通知 iPhone 开始录音
- `stopListen`: Mac 通知 iPhone 停止录音
- `result`: iPhone 返回识别结果
- `ping/pong`: 心跳保活
- `error`: 错误消息

### 安全机制

1. **配对阶段**: 6 位数字配对码（2 分钟有效）
2. **通信阶段**: 所有消息使用 HMAC-SHA256 签名
3. **存储**: 配对信息存储在系统 Keychain
4. **会话**: 每次录音使用唯一 Session ID 防止重放

## 故障排除

### Mac 菜单栏图标显示为灰色

- 检查 iPhone 是否已启动 VoiceMindiOS
- 检查两台设备是否在同一个 Wi-Fi 网络
- 尝试在 iPhone 上重启应用

### Mac 端没有显示识别结果

- 检查 Mac 与 iPhone 是否已完成配对
- 检查两台设备是否在同一个 Wi-Fi 网络

### iPhone 无法发现 Mac

- 确保两台设备在同一个 Wi-Fi 网络
- 检查防火墙设置，确保允许本地网络连接
- 尝试重启两台设备的 Wi-Fi

### 语音识别不准确

- 在 iPhone 设置中切换语言
- 确保在安静的环境中说话
- 尝试靠近 iPhone 麦克风

## 项目结构

```
VoiceMind/
├── SharedCore/                 # 共享代码包
│   └── Sources/SharedCore/
│       ├── Protocol/          # 消息协议定义
│       ├── Security/          # HMAC 和 Keychain
│       └── Models/            # 数据模型
├── VoiceMindMac/             # macOS 应用
│   ├── Network/               # 网络层（服务器、Bonjour）
│   ├── Speech/                # 本地语音识别
│   └── MenuBar/               # 菜单栏 UI
└── VoiceMindiOS/             # iOS 应用
    ├── Network/               # 网络层（客户端、Bonjour）
    ├── Speech/                # 语音识别
    ├── Views/                 # SwiftUI 视图
    └── ViewModels/            # 视图模型
```

## 开发说明

### 设计规范

- 项目默认设计规范入口：`docs/design/README.md`
- Apple 风格基线文档：`docs/design/vendor/apple-design-md/DESIGN.md`

### 依赖

- **Swift**: 5.9+
- **Frameworks**:
  - Network.framework (TCP/WebSocket)
  - Speech.framework (语音识别)
  - CryptoKit (HMAC)
  - AppKit (macOS UI)
  - SwiftUI (iOS UI)

### 构建配置

- **macOS Deployment Target**: 13.0
- **iOS Deployment Target**: 18.0
- **Swift Language Version**: 5.9

## 许可证

MIT License

## 作者

VoiceMind Team
