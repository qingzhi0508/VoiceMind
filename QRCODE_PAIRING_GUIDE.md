# 二维码配对方案实施指南

## 方案概述

用二维码替换 Bonjour 服务发现，解决发现慢的问题。

## 配对流程

### macOS 端

1. 用户点击「开始配对」
2. 生成二维码，包含：
   - IP 地址
   - 端口号
   - 设备 ID
   - 设备名称
3. 同时显示 6 位配对码（备用）

### iOS 端

**方式 1：扫码连接（推荐）**
1. 点击「扫码连接 Mac」
2. 扫描 Mac 上的二维码
3. 自动连接到 Mac
4. 输入配对码完成配对

**方式 2：手动连接（备用）**
1. 点击「手动输入连接」
2. 输入 IP 地址和端口
3. 连接后输入配对码

## 已实现的文件

### SharedCore
- `ConnectionInfo.swift` - 连接信息模型（IP、端口、设备信息）

### macOS
- `QRCodePairingView.swift` - 二维码配对视图
  - 显示二维码
  - 显示配对码
  - 显示连接信息
- 更新 `MenuBarController.swift` - 使用新的配对视图

### iOS
- `ManualConnectionView.swift` - 手动输入连接信息
- `QRCodeScannerView.swift` - 二维码扫描视图（占位符）
- 更新 `ContentView.swift` - 添加两种连接方式
- 更新 `ContentViewModel.swift` - 添加直接连接方法
- 更新 `ConnectionManager.swift` - 添加直接连接和配对方法

## 下一步工作

### 1. 在 Xcode 中添加文件

**SharedCore:**
- `Sources/SharedCore/Models/ConnectionInfo.swift`

**macOS:**
- `Views/QRCodePairingView.swift`

**iOS:**
- `Views/ManualConnectionView.swift`
- `Views/QRCodeScannerView.swift`

### 2. 实现真正的二维码扫描（iOS）

需要使用 AVFoundation 实现相机扫描：

```swift
import AVFoundation

class QRCodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String?

    private var captureSession: AVCaptureSession?

    func startScanning() {
        // 实现相机扫描
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        // 处理扫描结果
    }
}
```

### 3. 添加相机权限（iOS）

在 `Info.plist` 中添加：
```xml
<key>NSCameraUsageDescription</key>
<string>VoiceMind 需要使用相机扫描二维码以连接到 Mac</string>
```

### 4. 测试流程

1. **macOS 端**：
   - 启动服务
   - 点击「开始配对」
   - 查看二维码和配对码

2. **iOS 端**：
   - 方式 1：扫描二维码（需要实现相机扫描）
   - 方式 2：手动输入 IP 和端口
   - 输入配对码
   - 验证配对成功

## 优势

1. **快速连接**：无需等待 Bonjour 发现，扫码即连
2. **可靠性高**：直接 IP 连接，不依赖 mDNS
3. **用户友好**：二维码扫描比手动输入更方便
4. **有备用方案**：手动输入作为后备

## 技术细节

### 二维码内容格式

```json
{
  "ip": "192.168.1.100",
  "port": 8080,
  "deviceId": "uuid",
  "deviceName": "Mac"
}
```

### 连接流程

```
iOS                           macOS
 |                              |
 | 1. 扫描二维码                 |
 |    - 获取 IP 和端口           |
 |                              |
 | 2. 直接连接                   |
 |    connectDirectly(ip, port) |
 |                              |
 |    ---- TCP 连接 -------->   |
 |                              |
 | 3. 输入配对码                 |
 |                              |
 |    <--- pairConfirm ------   |
 |    (shortCode)               |
 |                              |
 |                              | 4. 验证配对码
 |                              |
 |    ---- pairSuccess ----->   |
 |    (sharedSecret)            |
 |                              |
 | 5. 配对完成                   | 6. 配对完成
```

## 注意事项

1. **网络要求**：两个设备仍需在同一局域网
2. **防火墙**：确保 macOS 防火墙允许入站连接
3. **相机权限**：iOS 需要相机权限才能扫描二维码
4. **二维码大小**：确保二维码足够大，易于扫描

## 移除的功能

- Bonjour 服务发现（iOS 端的 BonjourBrowser）
- 服务列表显示（iOS 端的 PairingView）

保留 Bonjour 广播（macOS 端），以便未来支持其他发现方式。
