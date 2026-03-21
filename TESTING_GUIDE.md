# VoiceMind 测试指南

## 准备工作

### 1. 在 Xcode 中添加新文件到项目

由于我们创建了新文件，需要在 Xcode 中将它们添加到项目：

**iOS 项目需要添加的文件：**
1. 打开 `VoiceMind.xcworkspace`
2. 选择 VoiceMindiOS 项目
3. 右键点击 VoiceMindiOS 文件夹 → Add Files to "VoiceMindiOS"
4. 添加以下文件夹和文件：
   - `ViewModels/ContentViewModel.swift`
   - `Views/PairingView.swift`
   - `Views/SettingsView.swift`
   - `Info.plist`
5. 删除根目录下的旧 `ContentView.swift`（如果还存在）
6. 删除 `Persistence.swift`（不再需要）

**检查 SharedCore 依赖：**
1. 选择 VoiceMindiOS target
2. Build Phases → Link Binary With Libraries
3. 确保 SharedCore 已添加
4. 如果没有，点击 + 号添加 SharedCore.framework

### 2. 配置 Info.plist

1. 选择 VoiceMindiOS target
2. Info 标签页
3. 确认以下权限描述已添加：
   - Privacy - Microphone Usage Description
   - Privacy - Speech Recognition Usage Description
   - Privacy - Local Network Usage Description
4. 确认 Bonjour services 包含 `_voicerelay._tcp`

### 3. 配置签名

**macOS 应用：**
1. 选择 VoiceMindMac target
2. Signing & Capabilities
3. 选择你的开发团队
4. 确保 "Automatically manage signing" 已勾选

**iOS 应用：**
1. 选择 VoiceMindiOS target
2. Signing & Capabilities
3. 选择你的开发团队
4. 确保 "Automatically manage signing" 已勾选

## 测试步骤

### 阶段 1: 构建验证

#### 1.1 构建 SharedCore
```
1. 选择 SharedCore scheme
2. Product → Build (⌘B)
3. 确认构建成功，无错误
```

#### 1.2 构建 macOS 应用
```
1. 选择 VoiceMindMac scheme
2. 选择 "My Mac" 作为目标设备
3. Product → Build (⌘B)
4. 确认构建成功
```

#### 1.3 构建 iOS 应用
```
1. 选择 VoiceMindiOS scheme
2. 选择你的 iPhone 作为目标设备（或模拟器用于初步测试）
3. Product → Build (⌘B)
4. 确认构建成功
```

**常见构建错误及解决方法：**

- **"No such module 'SharedCore'"**
  - 解决：先构建 SharedCore，然后再构建应用

- **"Cannot find type 'XXX' in scope"**
  - 解决：确保所有新文件都已添加到 target

- **签名错误**
  - 解决：在 Signing & Capabilities 中选择正确的开发团队

### 阶段 2: macOS 应用测试

#### 2.1 启动 macOS 应用
```
1. 选择 VoiceMindMac scheme
2. Product → Run (⌘R)
3. 应用启动后，菜单栏应该出现麦克风图标（灰色）
```

#### 2.2 授予权限
```
1. 点击菜单栏图标 → "权限设置"
2. 点击"打开系统设置"
3. 在系统设置中：
   - 隐私与安全性 → 辅助功能
   - 勾选 VoiceMindMac
4. 返回应用，确认权限状态显示为"已授予"
```

#### 2.3 发起配对
```
1. 点击菜单栏图标 → "配对新设备"
2. 应该弹出配对窗口，显示 6 位数字配对码
3. 记下这个配对码（2 分钟内有效）
4. 观察 Xcode 控制台输出，应该看到：
   - "Bonjour service published"
   - "WebSocket server started on port XXXX"
```

### 阶段 3: iOS 应用测试

#### 3.1 启动 iOS 应用
```
1. 确保 iPhone 和 Mac 连接到同一个 Wi-Fi 网络
2. 选择 VoiceMindiOS scheme
3. 选择你的 iPhone 作为目标设备
4. Product → Run (⌘R)
5. 应用启动后应该显示主界面
```

#### 3.2 授予权限
```
1. 首次启动时，应该会弹出权限请求：
   - 麦克风权限 → 允许
   - 语音识别权限 → 允许
   - 本地网络权限 → 允许
2. 如果没有弹出，进入"设置"页面点击"请求权限"
```

#### 3.3 配对流程
```
1. 在 iOS 应用主界面，点击"与 Mac 配对"
2. 应该看到"发现的 Mac"列表
3. 如果列表为空，检查：
   - 两台设备是否在同一 Wi-Fi
   - Mac 应用是否已启动配对
   - 查看 Xcode 控制台是否有 Bonjour 相关错误
4. 点击你的 Mac 名称（应该显示为选中状态）
5. 输入 Mac 上显示的 6 位配对码
6. 点击"配对"按钮
7. 配对成功后：
   - iOS 应用应该自动关闭配对界面
   - 主界面显示"已连接"状态（绿色指示器）
   - Mac 菜单栏图标变为绿色
```

**配对失败排查：**
- 检查配对码是否正确
- 检查配对码是否已过期（2 分钟）
- 查看两边的 Xcode 控制台输出
- 尝试重启两个应用

### 阶段 4: 语音输入测试

#### 4.1 基本语音输入
```
1. 在 Mac 上打开任意文本编辑器（如 TextEdit、Notes）
2. 点击输入框，确保光标在输入位置
3. 按住 Option+Space（默认快捷键）
4. 观察 iPhone 屏幕：
   - 应该显示"正在聆听..."
   - 麦克风图标变为红色
   - 出现波形动画
5. 对着 iPhone 说话（例如："你好世界"）
6. 松开 Option+Space
7. 观察 iPhone 屏幕：
   - 显示"处理中..."
   - 然后显示"发送结果..."
   - 最后回到"准备就绪"
8. 观察 Mac 文本编辑器：
   - 识别的文字应该自动出现在光标位置
```

#### 4.2 测试场景

**场景 1: 中文输入**
```
1. 确保 iOS 应用设置中选择"中文（普通话）"
2. 测试短句："今天天气很好"
3. 测试长句："我想要测试一下这个语音输入系统的准确性"
4. 测试标点："你好，我是小明。很高兴认识你！"
```

**场景 2: 英文输入**
```
1. 在 iOS 应用设置中切换到"English (US)"
2. 测试短句："Hello world"
3. 测试长句："This is a test of the voice input system"
4. 测试拼写："My email is test at example dot com"
```

**场景 3: 不同应用测试**
```
在以下应用中测试语音输入：
- TextEdit
- Notes
- Safari 地址栏
- Chrome 搜索框
- Slack 消息输入
- VS Code 编辑器
```

**场景 4: 快速连续输入**
```
1. 按住 Option+Space，说"第一句话"，松开
2. 等待文字出现
3. 立即再次按住 Option+Space，说"第二句话"，松开
4. 确认两次输入都正确处理
```

**场景 5: 中断测试**
```
1. 按住 Option+Space 开始录音
2. 不说话，直接松开
3. 确认应用正常返回待机状态
```

### 阶段 5: 异常情况测试

#### 5.1 网络断开
```
1. 正常配对并连接
2. 关闭 iPhone 的 Wi-Fi
3. 观察：
   - iOS 应用显示"已断开"
   - Mac 菜单栏图标变为黄色或灰色
4. 重新打开 iPhone Wi-Fi
5. 观察：
   - 应该自动重连
   - 连接状态恢复为"已连接"
```

#### 5.2 应用重启
```
1. 正常配对并连接
2. 关闭 iOS 应用
3. 重新启动 iOS 应用
4. 观察：
   - 应该自动重连到已配对的 Mac
   - 无需重新配对
```

#### 5.3 取消配对
```
1. 在 iOS 应用中进入"设置"
2. 点击"取消配对"
3. 观察：
   - iOS 应用返回未配对状态
   - Mac 菜单栏图标变为灰色
4. 可以重新配对
```

### 阶段 6: 性能和稳定性测试

#### 6.1 长时间运行
```
1. 保持两个应用运行 30 分钟
2. 每隔 5 分钟进行一次语音输入
3. 观察是否有内存泄漏或崩溃
4. 检查 Xcode 控制台是否有异常日志
```

#### 6.2 心跳测试
```
1. 正常连接后，保持两个应用运行但不操作
2. 等待 2 分钟（心跳间隔为 30 秒）
3. 观察 Xcode 控制台，应该看到 ping/pong 消息
4. 进行一次语音输入，确认连接仍然正常
```

## 调试技巧

### 查看日志

**macOS 控制台：**
```
在 Xcode 中运行 VoiceMindMac，查看控制台输出：
- Bonjour 发布状态
- WebSocket 连接状态
- 接收到的消息
- HMAC 验证结果
```

**iOS 控制台：**
```
在 Xcode 中运行 VoiceMindiOS，查看控制台输出：
- Bonjour 发现的服务
- WebSocket 连接状态
- 语音识别状态
- 发送的消息
```

### 常见问题

**问题 1: 快捷键无响应**
- 检查辅助功能权限
- 尝试更换快捷键组合
- 查看 macOS 控制台是否有错误

**问题 2: 识别结果不准确**
- 检查选择的语言是否正确
- 确保在安静环境中测试
- 尝试靠近 iPhone 麦克风说话

**问题 3: 文字无法注入**
- 检查辅助功能权限
- 尝试在不同应用中测试
- 某些应用可能阻止程序化输入

**问题 4: 无法发现 Mac**
- 确认两台设备在同一 Wi-Fi
- 检查防火墙设置
- 重启两个应用

**问题 5: 配对失败**
- 检查配对码是否正确
- 确认配对码未过期
- 查看 HMAC 验证日志

## 测试检查清单

完成以下所有项目后，可以认为测试通过：

- [ ] macOS 应用成功构建并运行
- [ ] iOS 应用成功构建并运行
- [ ] 辅助功能权限已授予
- [ ] 麦克风和语音识别权限已授予
- [ ] Bonjour 服务发现正常工作
- [ ] 配对流程成功完成
- [ ] 配对信息持久化（重启后无需重新配对）
- [ ] 快捷键触发语音识别
- [ ] 中文语音识别准确
- [ ] 英文语音识别准确
- [ ] 识别结果正确注入到光标位置
- [ ] 在多个应用中测试成功
- [ ] 网络断开后自动重连
- [ ] 心跳保活机制正常工作
- [ ] 取消配对功能正常
- [ ] 长时间运行稳定，无崩溃
- [ ] 无明显内存泄漏

## 下一步

测试完成后，可以：
1. 打包发布版本
2. 添加更多语言支持
3. 优化识别准确度
4. 添加更多自定义选项
5. 改进 UI/UX
