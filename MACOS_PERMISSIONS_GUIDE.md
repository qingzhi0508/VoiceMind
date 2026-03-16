# macOS 权限配置指南

## 问题说明

macOS 的辅助功能（Accessibility）和输入监控（Input Monitoring）权限需要特殊配置。

## 解决方案

### 1. 在 Xcode 中配置 Info.plist

1. 选择 **VoiceRelayMac** target
2. 点击 **Info** 标签页
3. 添加 Info.plist 文件：
   - 在 **Build Settings** 中搜索 "Info.plist File"
   - 设置为：`VoiceRelayMac/Info.plist`

### 2. 配置 Signing & Capabilities

1. 选择 **VoiceRelayMac** target
2. 点击 **Signing & Capabilities** 标签页
3. 确保勾选 **Automatically manage signing**
4. 选择你的 **Team**

### 3. 配置 Hardened Runtime

1. 在 **Signing & Capabilities** 标签页
2. 点击 **+ Capability**
3. 添加 **Hardened Runtime**
4. 在 **Runtime Exceptions** 中勾选：
   - ✅ **Disable Library Validation**
   - ✅ **Allow Dyld Environment Variables** (可选)

### 4. 首次运行流程

当应用首次请求权限时：

#### 辅助功能权限
1. 应用会弹出系统对话框
2. 点击"打开系统设置"
3. 在 **隐私与安全性 → 辅助功能** 中
4. 找到 **VoiceRelayMac**
5. 勾选启用

#### 输入监控权限
1. 应用会自动打开系统设置
2. 在 **隐私与安全性 → 输入监控** 中
3. 找到 **VoiceRelayMac**
4. 勾选启用

### 5. 如果应用不在权限列表中

这通常是因为：

**原因 1: 应用未签名**
- 解决：在 Xcode 中配置签名（见步骤 2）

**原因 2: 应用未请求权限**
- 解决：运行应用并点击"授予权限"按钮

**原因 3: 应用路径变化**
- 解决：删除旧的权限条目，重新运行应用

### 6. 手动添加应用到权限列表

如果应用仍然不出现：

1. 打开 **系统设置 → 隐私与安全性**
2. 选择 **辅助功能** 或 **输入监控**
3. 点击左下角的 **锁图标** 解锁
4. 点击 **+** 按钮
5. 导航到应用位置：
   ```
   ~/Library/Developer/Xcode/DerivedData/VoiceRelay-xxx/Build/Products/Debug/VoiceRelayMac.app
   ```
6. 选择应用并添加
7. 勾选启用

### 7. 开发环境特殊说明

在开发环境中，每次重新构建应用，macOS 可能会认为这是一个"新"应用，需要重新授权。

**解决方法：**
- 使用固定的 Bundle Identifier
- 使用相同的签名证书
- 或者每次重新授权（开发阶段）

### 8. 验证权限状态

在应用中，权限状态会实时显示：
- ✅ **已授予** - 绿色
- ❌ **已拒绝** - 红色
- ⚠️ **未授予** - 橙色

## 调试技巧

### 查看应用签名
```bash
codesign -dv --verbose=4 /path/to/VoiceRelayMac.app
```

### 查看权限数据库
```bash
# 辅助功能
tccutil reset Accessibility com.yourcompany.VoiceRelayMac

# 输入监控
tccutil reset ListenEvent com.yourcompany.VoiceRelayMac
```

### 重置所有权限（慎用）
```bash
tccutil reset All
```

## 常见问题

### Q: 为什么打开系统设置后看不到应用？
A: 应用需要先请求权限，才会出现在列表中。确保：
1. 应用已签名
2. 已运行并点击"授予权限"按钮
3. 等待几秒钟刷新列表

### Q: 授予权限后应用仍然显示"未授予"？
A: 点击应用中的"刷新"按钮，或重启应用。

### Q: 每次构建都需要重新授权？
A: 这是开发环境的正常现象。发布版本不会有这个问题。

## 发布版本配置

发布应用时，需要：
1. 使用 Developer ID 签名
2. 公证（Notarization）
3. 在首次运行时引导用户授权
4. 提供清晰的权限说明

## 参考资料

- [Apple: Requesting Permission to Control Your Mac](https://developer.apple.com/documentation/security/requesting_permission_to_control_your_mac)
- [Apple: Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime)
- [TCC Database](https://www.rainforestqa.com/blog/macos-tcc-db-deep-dive)
