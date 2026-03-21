# Xcode 快速开始指南

## 第一步：打开工作区

```bash
cd /Users/cayden/Data/my-data/voiceMind
open VoiceMind.xcworkspace
```

## 第二步：在 Xcode 中添加新文件

### iOS 项目需要添加的文件

1. 在 Xcode 左侧项目导航器中，找到 **VoiceMindiOS** 项目
2. 展开 **VoiceMindiOS** 文件夹

#### 添加 ViewModels 文件夹
1. 右键点击 **VoiceMindiOS** 文件夹
2. 选择 **Add Files to "VoiceMindiOS"...**
3. 导航到 `VoiceMindiOS/VoiceMindiOS/ViewModels`
4. 选择整个 **ViewModels** 文件夹
5. 确保勾选：
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ VoiceMindiOS (target)
6. 点击 **Add**

#### 添加 Views 文件夹中的新文件
1. 右键点击 **VoiceMindiOS** 文件夹下的 **Views** 文件夹（如果没有，先创建）
2. 选择 **Add Files to "VoiceMindiOS"...**
3. 导航到 `VoiceMindiOS/VoiceMindiOS/Views`
4. 选择以下文件：
   - PairingView.swift
   - SettingsView.swift
   - ContentView.swift（新版本）
5. 确保勾选：
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ VoiceMindiOS (target)
6. 点击 **Add**

#### 添加 Info.plist
1. 右键点击 **VoiceMindiOS** 文件夹
2. 选择 **Add Files to "VoiceMindiOS"...**
3. 选择 `VoiceMindiOS/VoiceMindiOS/Info.plist`
4. 确保勾选：
   - ✅ Copy items if needed
   - ✅ VoiceMindiOS (target)
5. 点击 **Add**

#### 删除旧文件
1. 在项目导航器中找到并删除（如果存在）：
   - 根目录下的旧 `ContentView.swift`
   - `Persistence.swift`
   - `VoiceMindiOS.xcdatamodeld`
2. 右键点击 → **Delete** → 选择 **Move to Trash**

### 配置 Info.plist

1. 选择 **VoiceMindiOS** target
2. 点击 **Info** 标签页
3. 确认以下权限已添加（如果没有，手动添加）：
   - **Privacy - Microphone Usage Description**: "VoiceMind 需要使用麦克风进行语音识别"
   - **Privacy - Speech Recognition Usage Description**: "VoiceMind 需要使用语音识别功能将您的语音转换为文字"
   - **Privacy - Local Network Usage Description**: "VoiceMind 需要访问本地网络以连接到您的 Mac"
4. 在 **Custom iOS Target Properties** 中添加：
   - Key: `NSBonjourServices`
   - Type: Array
   - Item 0: `_voicerelay._tcp`

## 第三步：配置 SharedCore 依赖

### iOS 项目
1. 选择 **VoiceMindiOS** target
2. 点击 **General** 标签页
3. 滚动到 **Frameworks, Libraries, and Embedded Content**
4. 如果 **SharedCore** 不在列表中：
   - 点击 **+** 按钮
   - 选择 **SharedCore** (在 Workspace 下)
   - 点击 **Add**
5. 确保 **Embed** 设置为 **Do Not Embed**

### macOS 项目
1. 选择 **VoiceMindMac** target
2. 重复上述步骤，确保 SharedCore 已链接

## 第四步：配置签名

### macOS 应用
1. 选择 **VoiceMindMac** target
2. 点击 **Signing & Capabilities** 标签页
3. 勾选 **Automatically manage signing**
4. 选择你的 **Team**（开发者账号）

### iOS 应用
1. 选择 **VoiceMindiOS** target
2. 点击 **Signing & Capabilities** 标签页
3. 勾选 **Automatically manage signing**
4. 选择你的 **Team**（开发者账号）

## 第五步：构建测试

### 1. 构建 SharedCore
```
1. 在 Xcode 顶部选择 scheme: SharedCore
2. 按 ⌘B 构建
3. 确认构建成功（无错误）
```

### 2. 构建 macOS 应用
```
1. 选择 scheme: VoiceMindMac
2. 选择目标: My Mac
3. 按 ⌘B 构建
4. 确认构建成功
```

### 3. 构建 iOS 应用
```
1. 选择 scheme: VoiceMindiOS
2. 选择目标: 你的 iPhone（或模拟器）
3. 按 ⌘B 构建
4. 确认构建成功
```

## 第六步：运行测试

### 运行 macOS 应用
```
1. 选择 VoiceMindMac scheme
2. 按 ⌘R 运行
3. 菜单栏应该出现麦克风图标
```

### 运行 iOS 应用
```
1. 确保 iPhone 和 Mac 在同一 Wi-Fi
2. 选择 VoiceMindiOS scheme
3. 选择你的 iPhone
4. 按 ⌘R 运行
5. 应用应该在 iPhone 上启动
```

## 常见问题

### 问题 1: "No such module 'SharedCore'"
**解决方法：**
1. 先构建 SharedCore (⌘B)
2. 然后再构建应用

### 问题 2: 文件找不到
**解决方法：**
1. 确保文件已添加到正确的 target
2. 在文件检查器中（右侧面板）确认 Target Membership

### 问题 3: 签名错误
**解决方法：**
1. 确保选择了正确的开发团队
2. 如果是免费账号，可能需要修改 Bundle Identifier

### 问题 4: Info.plist 权限未生效
**解决方法：**
1. 确保 Info.plist 已添加到 target
2. 在 Build Settings 中搜索 "Info.plist File"
3. 确认路径正确：`VoiceMindiOS/Info.plist`

## 下一步

构建成功后，按照 **TESTING_GUIDE.md** 进行完整的功能测试。

## 快速命令

```bash
# 检查所有文件是否就绪
./check_files.sh

# 打开工作区
open VoiceMind.xcworkspace

# 查看项目结构
tree -L 3 -I 'build|DerivedData'
```
