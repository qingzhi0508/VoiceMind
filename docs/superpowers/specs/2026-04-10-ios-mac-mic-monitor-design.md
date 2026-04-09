# iOS 双端协同话筒直通 Mac 喇叭设计

## 概述

为 iOS 端“设置 > 双端协同”增加一个新的“话筒”开关。该开关只在 iPhone 首页选择 `Mac` 模式并按住说话时生效：开启后，手机麦克风采集到的 PCM 音频除了继续发送给 Mac 做语音识别外，还需要在 Mac 端以尽可能低的时延直接从电脑喇叭播放出来。

这个功能的目标不是替代识别，而是在保留当前“双端协同识别”体验的基础上，增加一条实时监听链路。识别和外放必须共享同一份网络音频，避免重复采集、重复编码或引入额外协议分支。

## 方案选择

**选定方案：复用现有 `audioStart/audioData/audioEnd` 音频流协议，并在会话开始阶段声明是否需要 Mac 外放。**

当前项目已经具备完整的 iPhone -> Mac 音频流通道：

- iOS 端使用 `AudioStreamController` 采集麦克风 PCM16 数据
- 通过 `AudioStartPayload` / `AudioDataPayload` / `AudioEndPayload` 向 Mac 发送音频流
- Mac 端在 `ConnectionManager` 中接收音频并交给 `SpeechRecognitionManager` 识别

在此基础上，新增一个布尔型会话参数即可表达本次会话是否需要“边识别边外放”。这样可以保持：

- 协议改动小，兼容现有链路
- iOS 不需要新增第二套采集或发送逻辑
- Mac 可以对同一份 PCM 数据同时执行识别与扬声器播放，路径最短，时延最低

## 用户行为定义

### 1. 设置开关

- 新开关位于 iOS 设置页“双端协同”区域
- 建议文案为“话筒”
- 开关值持久化到本地 `UserDefaults`
- 仅当“发送到 Mac”已开启时展示该选项

### 2. 生效范围

开关只对以下场景生效：

- iPhone 首页当前处于 `Mac` 模式
- 用户按住首页主录音按钮发起双端协同录音

以下场景不受该开关影响：

- iPhone 本地识别模式
- 仅发送识别文本结果到 Mac 的本地识别流程
- Mac 主动下发 `startListen` 的会话

### 3. 生效结果

当开关打开且用户在首页 `Mac` 模式下按住说话时：

- iPhone 继续使用当前音频流模式把麦克风音频发给 Mac
- Mac 继续使用当前识别引擎做识别
- Mac 同时把收到的 PCM 数据以低时延方式播放到系统输出设备

当开关关闭时：

- 当前 `Mac` 模式行为保持不变，只做识别，不做扬声器外放

## 协议设计

### AudioStartPayload 扩展

在 `SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift` 中为 `AudioStartPayload` 增加新字段：

- `playThroughMacSpeaker: Bool`

设计要求：

- 默认值为 `false`
- 保持 `Codable` 向后兼容
- `audioData` / `audioEnd` 不新增对应字段

### 协议语义

- `audioStart.playThroughMacSpeaker == true`：本次音频流除了识别，还需要在 Mac 扬声器播放
- `audioStart.playThroughMacSpeaker == false`：沿用当前行为，只做识别

## iOS 端设计

### 1. 设置状态

在 `ContentViewModel` 中新增“话筒外放”偏好值：

- 本地持久化
- 暴露给 `SettingsView`
- 与现有 `sendResultsToMacEnabled` 一起决定设置区域显示和会话行为

建议的派生规则：

- `sendResultsToMacEnabled == false` 时，不展示“话筒”开关
- 即使用户曾开启该开关，只要当前不是首页 `Mac` 模式，也不触发外放行为

### 2. 会话发起

在 `ContentViewModel.startPushToTalk()` 中，当满足以下条件时，构造 `AudioStartPayload(playThroughMacSpeaker: true)`：

- `effectiveHomeTranscriptionMode == .mac`
- 用户开启了新的“话筒”设置

否则发送 `playThroughMacSpeaker: false`。

### 3. 不影响现有行为

以下流程保持原样：

- `AudioStreamController` 的采集格式仍为 16kHz / 单声道 / PCM16
- `audioData` 持续发送逻辑不变
- 现有识别会话统计、双端协同计数和状态提示保持原有语义

## Mac 端设计

### 1. 新增低时延播放器

新增一个专门消费远端 PCM 数据的播放器组件，职责如下：

- 根据 `audioStart` 提供的采样率、通道数和格式建立播放格式
- 接收 `audioData.audioData`
- 以尽可能小的缓冲将 PCM 数据送入本机扬声器
- 支持 `start / append / stop / reset`

推荐技术路径：

- 使用 `AVAudioEngine + AVAudioPlayerNode`
- 输入数据为 `pcm16 / 16kHz / mono`
- 使用小缓冲调度，优先保证低时延而不是强抗抖动

该播放器只负责外放，不负责识别，不与现有 `SpeechRecognitionManager` 混杂职责。

### 2. ConnectionManager 状态

Mac 端在 `ConnectionManager` 中新增当前音频流是否需要扬声器外放的会话状态。

在收到 `audioStart` 时：

- 正常启动识别
- 读取 `playThroughMacSpeaker`
- 若为 `true`，启动/预热扬声器播放器
- 若为 `false`，确保本次会话不启动外放

在收到 `audioData` 时：

- 保持现有 `speechManager.processAudioData(...)`
- 若当前会话启用了扬声器外放，则把同一份 PCM 数据追加到播放器

在收到 `audioEnd` 时：

- 正常停止识别
- 若当前会话启用了扬声器外放，则同步停止播放器并清空缓冲

### 3. 只影响 iPhone 首页 Mac 模式

Mac 不主动根据其它线索决定是否外放。是否外放完全由 iOS 在 `audioStart` 中声明。

这意味着：

- Mac 主动发送 `startListen` 并触发的会话不会自动外放
- 没有 `playThroughMacSpeaker` 标记的旧会话保持原行为

## 状态与容错

### 1. 失败隔离

识别与外放共用输入音频，但运行时必须尽量隔离：

- 扬声器播放器启动失败：记录 warning，识别继续
- 扬声器中途写入失败：停止外放，识别继续
- 识别失败：沿用当前错误处理逻辑，不要求强制停止外放，但会话结束时统一清理

### 2. 会话结束清理

以下情况都必须立即停止外放并重置播放器状态：

- 收到 `audioEnd`
- 连接断开
- 当前会话切换或 session 不匹配
- Mac 端处理链路抛出不可恢复错误

### 3. 日志与可观测性

保留当前语音流日志结构，同时增加适度的新日志：

- 本次 `audioStart` 是否启用 Mac 扬声器外放
- 扬声器播放器启动/停止
- 扬声器外放失败但识别继续的降级事件

不需要为每个 `audioData` 包单独增加额外的“播放成功”日志，避免噪音。

## UI 设计

### iOS 设置页

在现有“双端协同”区域中新增一个附属开关：

- 标题：`话筒`
- 辅助说明：强调“在 Mac 模式按住说话时，同时从电脑喇叭播放手机麦克风声音”

交互层级：

- `发送到 Mac`
- `话筒`
- 配对与连接状态

不新增单独页面，不新增多级导航。

### Mac 端

本次不要求新增可视化控制项。默认只按 iOS 会话声明执行实时外放。

如需未来扩展本机静音、音量、电平监视，可在后续迭代追加。

## 涉及文件

| 文件 | 改动 |
|------|------|
| `SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift` | 为 `AudioStartPayload` 增加外放标记 |
| `SharedCore/Tests/SharedCoreTests/MessageEnvelopeTests.swift` 或新增协议测试文件 | 增加 payload 编解码测试 |
| `VoiceMindiOS/VoiceMindiOS/ViewModels/ContentViewModel.swift` | 持久化设置、决定何时为音频流开启外放 |
| `VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift` | 在“双端协同”区域新增“话筒”开关 |
| `VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings` | 增加中文设置文案 |
| `VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings` | 增加英文设置文案 |
| `VoiceMindMac/VoiceMindMac/Network/ConnectionManager.swift` | 接收会话级外放标记，并将音频同时送识别与播放 |
| `VoiceMindMac/VoiceMindMac/...` 新增播放器文件 | 实现低时延 PCM 扬声器播放 |
| `VoiceMindMac/VoiceMindMacTests/...` | 增加播放启动条件与容错测试 |

## 测试策略

### SharedCore

- 验证新增字段的 `AudioStartPayload` 编解码
- 验证缺省情况下 `playThroughMacSpeaker` 为 `false` 或能被安全解码

### iOS

- 验证“话筒”开关的持久化
- 验证只有在首页 `Mac` 模式按住说话时才会发送 `playThroughMacSpeaker: true`
- 验证关闭“发送到 Mac”后不会触发该行为

### Mac

- 验证启用标记时会启动播放器
- 验证未启用标记时不会启动播放器
- 验证 `audioEnd` 与连接断开会停止播放器
- 验证播放器失败不会阻断识别处理

### 构建验证

- iOS 目标至少执行一轮 `xcodebuild build`
- macOS 目标至少执行一轮 `xcodebuild build`
- 涉及的单元测试目标执行对应 `xcodebuild test`

## 不做的事

- 不新增第二套音频传输协议
- 不改变 Mac 主动发起 `startListen` 会话的行为
- 不在本次实现中加入 Mac 端音量调节 UI
- 不做回声消除、自动降噪或复杂网络抖动补偿
