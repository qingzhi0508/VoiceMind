# VoiceMind macOS 应用配置完整指南

## 当前状态

✅ **已完成**：
- 应用入口点（VoiceMindMacApp.swift）
- 主窗口界面（状态、设置、权限、关于、调试）
- 设置管理系统（AppSettings）
- 两种文本注入方式（剪贴板 + CGEvent）
- 网络层（WebSocketServer 集成 Bonjour）
- 权限调试工具

⚠️ **需要解决**：
- SDK 版本不匹配（SourceKit 错误）
- 辅助功能权限配置

## 步骤 1：解决 SDK 版本问题

### 方法 A：在 Xcode 中切换 SDK（推荐）

1. 打开 Xcode
2. 关闭当前项目
3. 在终端运行：
   ```bash
   # 清理 Xcode 缓存
   rm -rf ~/Library/Developer/Xcode/DerivedData/*

   # 重启 Xcode
   killall Xcode
   ```
4. 重新打开项目
5. 在 Xcode 中：
   - Product → Clean Build Folder (Shift+Cmd+K)
   - 等待索引完成
   - Product → Build (Cmd+B)

### 方法 B：更新 Xcode

如果方法 A 不行，可能需要更新 Xcode：
```bash
# 检查 Xcode 版本
xcodebuild -version

# 如果版本过旧，从 App Store 更新 Xcode
```

## 步骤 2：在 Xcode 中配置项目

### 2.1 添加新文件

在 Xcode 项目导航器中，确保以下文件已添加到 VoiceMindMac target：

**必需文件**：
- ✅ `VoiceMindMacApp.swift`
- ✅ `Settings/AppSettings.swift`
- ✅ `Views/MainWindow.swift`
- ✅ `Views/PermissionsDebugView.swift`
- ✅ `TextInjection/TextInjectionProtocol.swift`
- ✅ `TextInjection/TextInjectionMethod.swift`
- ✅ `TextInjection/CGEventTextInjector.swift`
- ✅ `TextInjection/ClipboardTextInjector.swift`

**需要移除的文件**：
- ❌ `TextInjection/TextInjector.swift`（已删除）
- ❌ `Network/BonjourPublisher.swift`（已删除，功能集成到 WebSocketServer）
- ❌ `VoiceMindMacApp_Minimal.swift`（已删除）
- ❌ `ContentView.swift`（已删除）
- ❌ `Persistence.swift`（已删除）

### 2.2 验证 Info.plist

确认 `Info.plist` 配置正确：
- `LSUIElement` = `false`（或删除该键）
- 所有权限描述字符串存在

### 2.3 配置签名

1. 选择 VoiceMindMac target
2. 点击 "Signing & Capabilities"
3. 勾选 "Automatically manage signing"
4. 选择你的 Team

## 步骤 3：构建并运行

1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)
3. 如果构建成功，Product → Run (Cmd+R)

## 步骤 4：配置辅助功能权限

### 使用调试标签页（最简单）

1. 运行应用后，切换到「调试」标签页
2. 查看「应用信息」部分，记录：
   - Bundle ID
   - 应用路径
3. 点击「2️⃣ 请求辅助功能权限」
4. 系统设置应该会自动打开
5. 在「隐私与安全性」→「辅助功能」中：
   - 如果看到 VoiceMindMac，勾选启用
   - 如果看不到，点击「+」手动添加应用路径

### 手动配置

如果自动请求不行：

1. 打开「系统设置」→「隐私与安全性」→「辅助功能」
2. 点击左下角「🔒」解锁（需要密码）
3. 点击「+」按钮
4. 导航到应用路径（在调试标签页可以看到完整路径）
5. 选择 VoiceMindMac.app 并添加
6. 勾选启用

## 步骤 5：测试功能

### 基本功能测试

- [ ] 应用在 Dock 中显示
- [ ] 菜单栏显示图标
- [ ] 主窗口可以打开/关闭
- [ ] 四个标签页都能正常显示

### 权限测试

- [ ] 在调试标签页点击「检查权限」
- [ ] 辅助功能显示「✅ 已授予」
- [ ] 输入监控显示「✅ 已授予」

### 网络测试

- [ ] 在状态标签页点击「启动服务」
- [ ] 控制台显示：
  ```
  ✅ WebSocket server started on port XXXX
  ✅ Bonjour service: _voicerelay._tcp
  ✅ Connection manager started on port XXXX
  ```
- [ ] 没有错误信息（特别是 Bonjour 错误）

### 设置测试

- [ ] 在设置标签页切换文本注入方式
- [ ] 重启应用，设置保持

## 常见问题

### Q1: SourceKit 报错 "SDK is not supported by the compiler"

**解决方案**：
1. 关闭 Xcode
2. 清理缓存：`rm -rf ~/Library/Developer/Xcode/DerivedData/*`
3. 重新打开项目
4. Clean Build Folder
5. 重新构建

### Q2: Bonjour service failed: POSIXErrorCode 22

**已修复**：WebSocketServer 现在直接集成 Bonjour 服务，不再使用单独的 BonjourPublisher。

### Q3: 辅助功能列表中找不到应用

**解决方案**：
1. 使用调试标签页的「请求辅助功能权限」按钮
2. 或手动添加应用（路径在调试标签页显示）
3. 这是开发环境的正常现象

### Q4: 每次构建都需要重新授权

**原因**：Xcode 每次构建会生成新的应用路径，macOS 认为是不同的应用。

**解决方案**：
- 开发阶段：每次重新授权
- 发布版本：使用 Developer ID 签名和公证

## 网络架构说明

### 修改内容

**之前**：
- WebSocketServer 创建 TCP listener
- BonjourPublisher 创建另一个 listener 用于广播
- 两个 listener 在同一端口冲突 → POSIXErrorCode 22

**现在**：
- WebSocketServer 创建一个 listener
- 在同一个 listener 上配置 Bonjour 服务
- 一个 listener 同时处理 TCP 连接和 Bonjour 广播

### 代码变化

```swift
// WebSocketServer.swift
let parameters = NWParameters.tcp
parameters.includePeerToPeer = true // 启用 Bonjour

listener.service = NWListener.Service(
    name: Host.current().localizedName ?? "VoiceMind Mac",
    type: "_voicerelay._tcp"
)
```

```swift
// ConnectionManager.swift
func start() throws {
    // 只需要启动 WebSocketServer
    try server.start()
    // 不再需要单独的 BonjourPublisher
}
```

## 下一步

如果所有测试通过：

1. **测试与 iOS 设备配对**
2. **测试文本注入（两种方式）**
3. **完成 Phase 3 & 4**：
   - 网络层心跳和重连
   - HotkeyConfiguration 持久化

## 需要帮助？

如果遇到问题：
1. 查看 Xcode 控制台日志
2. 使用调试标签页查看应用信息
3. 检查构建错误的具体信息
