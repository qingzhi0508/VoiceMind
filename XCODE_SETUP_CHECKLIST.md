# Xcode 文件添加和测试清单

## 第一步：添加 SharedCore 文件

1. 打开 Xcode workspace
2. 在左侧导航器中找到 **SharedCore** 项目
3. 展开 `Sources/SharedCore/Models/`
4. 右键点击 `Models` 文件夹 → "Add Files to SharedCore..."
5. 选择 `ConnectionInfo.swift`
6. 确保勾选 SharedCore target
7. 点击 "Add"

## 第二步：添加 macOS 文件

1. 在左侧导航器中找到 **VoiceMindMac** 项目
2. 展开 `VoiceMindMac/Views/`
3. 右键点击 `Views` 文件夹 → "Add Files to VoiceMindMac..."
4. 选择以下文件：
   - `QRCodePairingView.swift`
   - `PermissionsDebugView.swift`（如果还没添加）
5. 确保勾选 VoiceMindMac target
6. 点击 "Add"

## 第三步：添加 iOS 文件

1. 在左侧导航器中找到 **VoiceMindiOS** 项目
2. 展开 `VoiceMindiOS/Views/`
3. 右键点击 `Views` 文件夹 → "Add Files to VoiceMindiOS..."
4. 选择以下文件：
   - `ManualConnectionView.swift`
   - `QRCodeScannerView.swift`
5. 确保勾选 VoiceMindiOS target
6. 点击 "Add"

## 第四步：清理并构建

### SharedCore
1. 选择 SharedCore scheme
2. Product → Clean Build Folder (Shift+Cmd+K)
3. Product → Build (Cmd+B)
4. 确认构建成功

### VoiceMindMac
1. 选择 VoiceMindMac scheme
2. Product → Clean Build Folder (Shift+Cmd+K)
3. Product → Build (Cmd+B)
4. 查看是否有编译错误

### VoiceMindiOS
1. 选择 VoiceMindiOS scheme
2. Product → Clean Build Folder (Shift+Cmd+K)
3. Product → Build (Cmd+B)
4. 查看是否有编译错误

## 第五步：测试 macOS 端

1. 运行 VoiceMindMac
2. 在「状态」标签页点击「启动服务」
3. 点击「开始配对」
4. 应该看到：
   - ✅ 二维码显示
   - ✅ 6位配对码显示
   - ✅ IP 地址和端口显示
5. 记录显示的信息：
   - IP: `_______________`
   - 端口: `_______________`
   - 配对码: `_______________`

## 第六步：测试 iOS 端（手动连接）

1. 运行 VoiceMindiOS（模拟器或真机）
2. 点击「手动输入连接」
3. 输入 macOS 显示的 IP 和端口
4. 点击「连接」
5. 观察：
   - iOS 控制台：`📡 直接连接到: [IP]:[端口]`
   - macOS 控制台：应该显示连接信息

## 第七步：测试配对流程

### 方式 A：通过 iOS 手动连接视图

1. 连接成功后，iOS 应该自动显示配对码输入
2. 输入 macOS 显示的 6 位配对码
3. 观察控制台日志

### 方式 B：如果没有自动显示配对码输入

需要在 `ManualConnectionView.swift` 中添加配对码输入步骤。

## 预期的控制台日志

### macOS 端：
```
✅ WebSocket server started on port 8080
✅ Bonjour service: _voicerelay._tcp
✅ Connection manager started on port 8080
🔐 开始配对
   配对码: 123456
   有效期: 2分钟
📱 收到配对确认
   iOS 设备: iPhone
   配对码: 123456
✅ 配对码验证通过
🔑 生成共享密钥
💾 配对信息已保存到 Keychain
📤 发送配对成功消息
✅ 配对完成: iPhone
```

### iOS 端：
```
📡 直接连接到: 192.168.1.100:8080
🔐 使用配对码配对: 123456
✅ 配对成功
```

## 常见问题排查

### Q1: 找不到 ConnectionInfo 类型

**原因**：SharedCore 没有正确构建或导入

**解决**：
1. 确认 ConnectionInfo.swift 已添加到 SharedCore target
2. 重新构建 SharedCore
3. 在使用的文件中添加 `import SharedCore`

### Q2: macOS 端二维码不显示

**原因**：CoreImage 导入问题

**解决**：
1. 确认 `import CoreImage.CIFilterBuiltins` 存在
2. 查看控制台是否有错误信息

### Q3: iOS 连接失败

**可能原因**：
1. IP 地址输入错误
2. 端口号错误
3. 两个设备不在同一网络
4. macOS 防火墙阻止

**排查步骤**：
1. 确认 IP 地址正确（在 macOS 终端运行 `ifconfig en0 | grep inet`）
2. 确认端口号与 macOS 显示的一致
3. 确认两个设备连接到同一 WiFi
4. 在 macOS 系统设置中检查防火墙

### Q4: 配对码验证失败

**原因**：配对码输入错误或已过期

**解决**：
1. 仔细核对 6 位数字
2. 如果超过 2 分钟，重新开始配对
3. 查看控制台日志确认具体错误

## 下一步优化

如果手动连接测试成功：

1. **实现真正的二维码扫描**（iOS）
   - 使用 AVFoundation
   - 添加相机权限

2. **改进配对流程**
   - 连接后自动显示配对码输入
   - 添加配对进度提示

3. **添加错误处理**
   - 网络错误提示
   - 配对失败重试

4. **优化 UI**
   - 加载动画
   - 成功/失败反馈

## 测试记录

| 测试项 | 结果 | 备注 |
|--------|------|------|
| SharedCore 构建 | ⬜ 成功 / ⬜ 失败 | |
| macOS 构建 | ⬜ 成功 / ⬜ 失败 | |
| iOS 构建 | ⬜ 成功 / ⬜ 失败 | |
| macOS 启动服务 | ⬜ 成功 / ⬜ 失败 | |
| macOS 显示二维码 | ⬜ 成功 / ⬜ 失败 | |
| iOS 手动连接 | ⬜ 成功 / ⬜ 失败 | |
| 配对码验证 | ⬜ 成功 / ⬜ 失败 | |
| 配对完成 | ⬜ 成功 / ⬜ 失败 | |
