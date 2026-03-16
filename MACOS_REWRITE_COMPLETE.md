# VoiceRelayMac 重写完成指南

## 已完成的工作

### Phase 1: 基础设施 ✅
- ✅ 创建 `AppSettings.swift` - 设置管理系统
- ✅ 创建 `TextInjectionProtocol.swift` - 文本注入协议
- ✅ 创建 `TextInjectionMethod.swift` - 注入方式枚举
- ✅ 创建 `CGEventTextInjector.swift` - CGEvent 字符注入实现
- ✅ 创建 `ClipboardTextInjector.swift` - 剪贴板粘贴实现
- ✅ 删除旧的 `TextInjector.swift`

### Phase 2: 应用入口点 ✅
- ✅ 创建 `VoiceRelayMacApp.swift` - SwiftUI 应用入口
- ✅ 创建 `MainWindow.swift` - 主窗口（状态、设置、权限、关于）
- ✅ 更新 `MenuBarController.swift` - 集成设置和文本注入器
- ✅ 删除旧文件（VoiceRelayMacApp_Minimal.swift, ContentView.swift, Persistence.swift）

### Phase 3 & 4: 待完成
- ⏳ 网络层增强（WebSocketServer 重连和心跳）
- ⏳ HotkeyConfiguration 持久化

## 在 Xcode 中完成配置

### 1. 切换 Xcode 工具链

首先需要解决 SDK 版本不匹配问题：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 2. 在 Xcode 中更新项目

1. 打开 `/Users/cayden/Data/my-data/voiceMind/VoiceRelay.xcworkspace`

2. 选择 **VoiceRelayMac** target

3. **添加新文件到项目**：
   - 在左侧导航器中，右键点击 `VoiceRelayMac` 文件夹
   - 选择 "Add Files to VoiceRelayMac..."
   - 添加以下新文件：
     - `Settings/AppSettings.swift`
     - `TextInjection/TextInjectionProtocol.swift`
     - `TextInjection/TextInjectionMethod.swift`
     - `TextInjection/CGEventTextInjector.swift`
     - `TextInjection/ClipboardTextInjector.swift`
     - `Views/MainWindow.swift`
     - `VoiceRelayMacApp.swift`

4. **移除旧文件引用**（如果还存在）：
   - 在项目导航器中找到以下文件并删除引用：
     - `TextInjection/TextInjector.swift`（已删除）
     - `VoiceRelayMacApp_Minimal.swift`（已删除）
     - `ContentView.swift`（已删除）
     - `Persistence.swift`（已删除）

5. **验证 Info.plist**：
   - 确认 `LSUIElement` 为 `false`（已配置）
   - 确认所有权限描述字符串存在（已配置）

6. **清理并构建**：
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)

### 3. 运行应用

1. 选择 VoiceRelayMac scheme
2. 点击 Run (Cmd+R)
3. 应用应该：
   - 在 Dock 中显示
   - 显示主窗口
   - 菜单栏显示图标
   - 首次启动显示引导流程

### 4. 测试功能

- [ ] 主窗口显示正常
- [ ] 应用出现在 Dock 中
- [ ] 菜单栏图标显示
- [ ] 引导流程正常
- [ ] 权限请求正常
- [ ] 设置页面可以切换文本注入方式
- [ ] 从菜单栏可以显示/隐藏窗口

## 已知问题

### SDK 版本不匹配
**症状**：SourceKit 报错 "SDK is not supported by the compiler"

**解决方案**：
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

然后在 Xcode 中：
1. 关闭 Xcode
2. 重新打开项目
3. 等待索引完成
4. Clean Build Folder
5. 重新构建

### 如果窗口仍然不显示

检查以下几点：
1. 确认 Info.plist 中 `LSUIElement` 为 `false`
2. 确认 `VoiceRelayMacApp.swift` 中设置了 `.regular` 激活策略
3. 查看控制台日志是否有错误
4. 尝试从 Dock 点击应用图标

## 下一步工作

如果基本功能正常，可以继续完成：

### Phase 3: 网络层增强
- 修改 `WebSocketServer.swift` 添加重连和心跳
- 修改 `ConnectionManager.swift` 添加连接健康监控

### Phase 4: 设置持久化
- 修改 `HotkeyConfiguration.swift` 添加 UserDefaults 持久化
- 在 `OnboardingFlow.swift` 中添加设置选项

### Phase 5: 最终测试
- 完整的端到端测试
- 与 iOS 设备配对测试
- 文本注入测试（两种方式）
- 重启后设置保持测试

## 文件结构

```
VoiceRelayMac/VoiceRelayMac/
├── VoiceRelayMacApp.swift ✨ 新建
├── Settings/
│   └── AppSettings.swift ✨ 新建
├── Views/
│   └── MainWindow.swift ✨ 新建
├── TextInjection/
│   ├── TextInjectionProtocol.swift ✨ 新建
│   ├── TextInjectionMethod.swift ✨ 新建
│   ├── CGEventTextInjector.swift ✨ 新建
│   └── ClipboardTextInjector.swift ✨ 新建
├── MenuBar/
│   ├── MenuBarController.swift ✏️ 已更新
│   ├── OnboardingFlow.swift
│   ├── PairingWindow.swift
│   ├── StatusWindow.swift
│   └── ...
├── Hotkey/
│   ├── HotkeyMonitor.swift
│   └── HotkeyConfiguration.swift
├── Permissions/
│   └── PermissionsManager.swift
└── Network/
    ├── ConnectionManager.swift
    ├── WebSocketServer.swift
    └── BonjourPublisher.swift
```

## 联系支持

如果遇到问题，请检查：
1. Xcode 版本是否正确
2. 工具链是否指向 Xcode.app
3. 所有新文件是否已添加到 target
4. 构建日志中的具体错误信息
