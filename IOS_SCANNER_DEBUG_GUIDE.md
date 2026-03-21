# iOS 扫码功能调试指南

## 问题：编译后没有扫码功能

### 可能的原因

1. **文件未添加到 Xcode target**
2. **编译错误被忽略**
3. **运行的是旧版本**
4. **模拟器限制**

## 解决步骤

### 步骤 1：检查文件是否在 Xcode 项目中

1. 打开 Xcode
2. 在左侧项目导航器中查找：
   - `VoiceMindiOS/Scanner/QRCodeScannerController.swift`
   - `VoiceMindiOS/Scanner/CameraPreview.swift`
   - `VoiceMindiOS/Views/QRCodeScannerView.swift`

3. 如果看不到这些文件：
   - 右键点击 `VoiceMindiOS` 文件夹
   - 选择 "Add Files to VoiceMindiOS..."
   - 导航到文件位置并添加

### 步骤 2：检查 Target Membership

对于每个文件：

1. 在项目导航器中选择文件
2. 在右侧 File Inspector 中查看 "Target Membership"
3. 确保 **VoiceMindiOS** 被勾选

如果没有勾选：
- 勾选 VoiceMindiOS target
- 不要勾选 VoiceMindiOSTests 或 VoiceMindiOSUITests

### 步骤 3：清理并重新构建

1. Product → Clean Build Folder (Shift+Cmd+K)
2. 关闭 Xcode
3. 删除 DerivedData：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```
4. 重新打开 Xcode
5. Product → Build (Cmd+B)
6. 查看构建日志，确认没有错误

### 步骤 4：检查编译错误

在 Xcode 中：

1. 打开 Report Navigator (Cmd+9)
2. 选择最近的构建
3. 查看是否有错误或警告
4. 特别注意：
   - "Cannot find type 'QRCodeScannerController'"
   - "Cannot find type 'CameraPreview'"
   - AVFoundation 相关错误

### 步骤 5：验证按钮是否显示

运行应用后：

1. 在主界面应该看到两个按钮：
   - ✅ "扫码连接 Mac"（蓝色，主要按钮）
   - ✅ "手动输入连接"（灰色，次要按钮）

2. 如果只看到一个按钮或没有按钮：
   - 检查 `ContentView.swift` 是否正确更新
   - 检查 `viewModel.pairingState` 是否为 `.unpaired`

### 步骤 6：测试扫码功能

1. 点击 "扫码连接 Mac" 按钮
2. 应该弹出扫描界面
3. 首次使用会请求相机权限

**注意**：
- ⚠️ 模拟器不支持相机，必须使用真机测试
- ⚠️ 如果在模拟器上，会显示黑屏占位符

## 手动验证文件内容

### 检查 ContentView.swift

运行以下命令检查文件内容：

```bash
grep -n "扫码连接 Mac" /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/Views/ContentView.swift
```

应该输出：
```
24:                        Button("扫码连接 Mac") {
```

### 检查 QRCodeScannerView.swift

```bash
head -20 /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/QRCodeScannerView.swift
```

应该看到：
```swift
import SwiftUI
import AVFoundation
import SharedCore

struct QRCodeScannerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ContentViewModel

    @StateObject private var scanner = QRCodeScannerController()
    ...
```

## 常见问题

### Q1: 点击按钮没有反应

**检查**：
1. 查看 Xcode 控制台是否有错误
2. 确认 `viewModel.showPairingView` 能正确触发
3. 检查 sheet 是否正确绑定

**解决**：
在 ContentView.swift 中添加调试日志：
```swift
Button("扫码连接 Mac") {
    print("🔍 点击扫码按钮")
    viewModel.showPairingView = true
}
```

### Q2: 弹出空白界面

**原因**：QRCodeScannerView 加载失败

**检查**：
1. QRCodeScannerView.swift 是否在 target 中
2. QRCodeScannerController 是否能正确初始化
3. 查看控制台错误信息

### Q3: 显示 "Cannot find type 'QRCodeScannerController'"

**原因**：文件未添加到项目或 target

**解决**：
1. 在 Xcode 中找到 QRCodeScannerController.swift
2. 选中文件，查看右侧 Target Membership
3. 勾选 VoiceMindiOS

### Q4: 相机权限请求不显示

**检查 Info.plist**：
```bash
grep -A1 "NSCameraUsageDescription" /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist
```

应该输出：
```xml
<key>NSCameraUsageDescription</key>
<string>VoiceMind 需要使用相机扫描二维码以连接到您的 Mac</string>
```

如果没有，手动添加到 Info.plist。

## 快速测试脚本

创建一个测试脚本来验证所有文件：

```bash
#!/bin/bash

echo "🔍 检查 iOS 扫码功能文件..."

FILES=(
    "/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Scanner/QRCodeScannerController.swift"
    "/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Scanner/CameraPreview.swift"
    "/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/QRCodeScannerView.swift"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (不存在)"
    fi
done

echo ""
echo "🔍 检查 ContentView 是否包含扫码按钮..."
if grep -q "扫码连接 Mac" "/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/Views/ContentView.swift"; then
    echo "✅ ContentView 包含扫码按钮"
else
    echo "❌ ContentView 不包含扫码按钮"
fi

echo ""
echo "🔍 检查 Info.plist 相机权限..."
if grep -q "NSCameraUsageDescription" "/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist"; then
    echo "✅ Info.plist 包含相机权限描述"
else
    echo "❌ Info.plist 缺少相机权限描述"
fi
```

保存为 `check_scanner.sh` 并运行：
```bash
chmod +x check_scanner.sh
./check_scanner.sh
```

## 如果所有检查都通过但仍然没有扫码功能

### 最后的排查步骤

1. **完全重新构建**：
   ```bash
   # 删除所有构建产物
   rm -rf ~/Library/Developer/Xcode/DerivedData/*

   # 在 Xcode 中
   # Product → Clean Build Folder
   # Product → Build
   ```

2. **检查运行的应用版本**：
   - 删除设备/模拟器上的旧版本应用
   - 重新安装

3. **查看完整的构建日志**：
   - Xcode → View → Navigators → Show Report Navigator
   - 选择最近的构建
   - 展开所有步骤查看详细信息

4. **创建最小测试**：
   在 ContentView 中临时添加：
   ```swift
   Button("测试扫码视图") {
       print("显示扫码视图")
   }
   .sheet(isPresented: .constant(true)) {
       Text("扫码视图占位符")
   }
   ```

   如果这个能工作，说明 sheet 机制正常，问题在 QRCodeScannerView。

## 需要提供的调试信息

如果问题仍然存在，请提供：

1. Xcode 构建日志（特别是错误和警告）
2. 运行时控制台输出
3. 点击按钮后的控制台输出
4. 截图：
   - 主界面（显示按钮）
   - Xcode 项目导航器（显示文件结构）
   - File Inspector（显示 Target Membership）
