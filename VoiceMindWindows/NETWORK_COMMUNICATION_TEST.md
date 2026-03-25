# VoiceMind Windows 端网络通信完善指南

## 📋 功能更新总结

### 已完成的功能

1. **增强的网络通信模块** (`network_enhanced.rs`)
   - 完整的iOS设备通信协议
   - 实时状态事件通知
   - 文本注入和历史记录

2. **新增的Tauri命令** (`commands_updated.rs`)
   - `start_listening` - 开始聆听
   - `stop_listening` - 停止聆听
   - `get_listening_status` - 获取聆听状态

3. **前端事件监听**
   - `connection-changed` - 连接状态变化
   - `listening-started` - 开始聆听
   - `listening-stopped` - 停止聆听
   - `recognition-result` - 识别结果
   - `partial-result` - 部分识别结果

---

## 🔧 如何集成到现有项目

### 步骤 1：替换现有的network.rs和commands.rs

由于我们创建了新文件，需要将它们集成到项目中：

**方案A：直接替换现有文件（推荐）**

1. 备份现有的文件：
```bash
cp src-tauri/src/network.rs src-tauri/src/network.rs.backup
cp src-tauri/src/commands.rs src-tauri/src/commands.rs.backup
```

2. 重命名新文件：
```bash
mv src-tauri/src/network_enhanced.rs src-tauri/src/network.rs
mv src-tauri/src/commands_updated.rs src-tauri/src/commands.rs
```

3. 更新main.rs中的模块引用：
```rust
mod network;  // 已经是network了
mod commands; // 已经是commands了
```

**方案B：保持两个版本（开发中）**

如果想保留原有的network.rs，可以：

1. 在main.rs中同时注册两个版本
2. 逐步迁移功能
3. 测试兼容性

### 步骤 2：更新Cargo.toml

确保添加了必要的依赖：

```toml
[dependencies]
uuid = "0.8"
tauri = { version = "2", features = ["protocol-asset"] }
tokio = { version = "1", features = ["full"] }
tokio-tungstenite = "0.21"
futures-util = "0.3"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
hmac = "0.12"
sha2 = "0.10"
base64 = "0.21"
tracing = "0.1"
tracing-subscriber = "0.3"
tracing-appender = "0.2"
windows = { version = "0.52", features = [
    "Win32_UI_Input_KeyboardAndMouse",
    "Win32_UI_WindowsAndMessaging",
    "Win32_System_Threading",
    "Win32_Foundation",
    "Win32_System_DataExchange",
    "Win32_System_Memory"
]}
```

### 步骤 3：更新main.rs

确保注册了新的命令：

```rust
use tauri::Manager;

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            // ... 现有的设置代码 ...
            
            // 如果需要使用增强版管理器，可以在这里初始化
            // let enhanced_manager = EnhancedConnectionManager::new();
            // enhanced_manager.set_app_handle(app.handle().clone());
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::get_pairing_qr_code,
            commands::start_pairing,
            commands::stop_pairing,
            commands::get_pairing_status,
            commands::confirm_pairing,
            commands::get_paired_devices,
            commands::remove_paired_device,
            commands::get_connection_status,
            commands::get_history,
            commands::clear_history,
            commands::delete_history_item,
            commands::get_settings,
            commands::save_settings,
            commands::get_server_port,
            commands::set_server_port,
            commands::get_asr_config,
            commands::save_asr_config,
            // 新增的命令
            commands::start_listening,
            commands::stop_listening,
            commands::get_listening_status,
        ])
        .run(tauri::generate_context!());
}
```

---

## 🧪 测试指南

### 前提条件

1. ✅ Windows端应用已编译运行
2. ✅ iOS设备上安装了VoiceMind iOS应用
3. ✅ Windows和iOS在同一Wi-Fi网络

### 测试步骤

#### 1. 基本连接测试

```bash
# 启动应用
npm run tauri dev
```

**检查项：**
- [ ] 托盘图标显示
- [ ] 配对二维码生成
- [ ] 状态栏显示"未连接"

#### 2. 配对测试

1. 在Windows端点击"刷新配对码"
2. 在iOS端打开VoiceMind应用
3. iOS端应该能发现Windows设备
4. 输入6位配对码完成配对

**检查项：**
- [ ] iOS端能发现Windows设备
- [ ] 配对码验证成功
- [ ] 连接状态变为"已连接"
- [ ] 托盘状态图标变绿

#### 3. 语音识别测试

1. 确保iOS和Windows已配对连接
2. 在Windows端点击"开始聆听"按钮（需要添加）
3. 在iOS端开始说话
4. 观察识别结果

**检查项：**
- [ ] Windows端发送startListen消息
- [ ] iOS端开始录音（应该有视觉反馈）
- [ ] iOS端发送识别结果
- [ ] Windows端接收并注入文本
- [ ] 文本出现在目标应用中

#### 4. 状态事件测试

在浏览器开发者工具中测试事件：

```javascript
// 监听连接状态变化
window.__TAURI__.core.listen('connection-changed', (event) => {
    console.log('Connection changed:', event.payload);
});

// 监听聆听开始
window.__TAURI__.core.listen('listening-started', (event) => {
    console.log('Listening started:', event.payload);
});

// 监听聆听结束
window.__TAURI__.core.listen('listening-stopped', (event) => {
    console.log('Listening stopped:', event.payload);
});

// 监听识别结果
window.__TAURI__.core.listen('recognition-result', (event) => {
    console.log('Recognition result:', event.payload);
});
```

---

## 🎯 前端集成示例

### 添加聆听控制按钮

在`index.html`中添加：

```html
<!-- 在配对区域添加 -->
<div class="listening-controls" id="listening-controls" style="display: none;">
    <button class="btn btn-primary" id="btn-start-listening">
        开始聆听
    </button>
    <button class="btn btn-secondary" id="btn-stop-listening" style="display: none;">
        停止聆听
    </button>
</div>
```

### 添加JavaScript控制逻辑

```javascript
// 监听连接状态
window.__TAURI__.core.listen('connection-changed', (event) => {
    const { connected } = event.payload;
    document.getElementById('listening-controls').style.display = 
        connected ? 'block' : 'none';
});

// 开始聆听
document.getElementById('btn-start-listening').addEventListener('click', async () => {
    try {
        const result = await invoke('start_listening');
        if (result.success) {
            document.getElementById('btn-start-listening').style.display = 'none';
            document.getElementById('btn-stop-listening').style.display = 'block';
            updateStatus('listening', '聆听中...');
        }
    } catch (e) {
        console.error('Failed to start listening:', e);
    }
});

// 停止聆听
document.getElementById('btn-stop-listening').addEventListener('click', async () => {
    try {
        const result = await invoke('stop_listening');
        if (result.success) {
            document.getElementById('btn-start-listening').style.display = 'block';
            document.getElementById('btn-stop-listening').style.display = 'none';
            updateStatus('connected', '已连接');
        }
    } catch (e) {
        console.error('Failed to stop listening:', e);
    }
});

// 监听识别结果
window.__TAURI__.core.listen('recognition-result', (event) => {
    const { text, language, session_id } = event.payload;
    console.log('识别结果:', text);
    // 可以在这里显示实时字幕或更新历史记录
});
```

---

## 🔍 调试技巧

### 查看WebSocket连接日志

在Rust代码中添加详细日志：

```rust
tracing::info!("Processing message: {:?}", msg);
tracing::debug!("Connection state: {:?}", conn.state);
```

### 查看网络流量

使用Wireshark监控WebSocket流量：

```bash
# 监控8765端口
wireshark -i <network_interface> -f "tcp port 8765"
```

### 检查iOS端日志

在iOS端Xcode中添加日志：

```swift
print("🔍 Connection state: \(connectionManager.connectionState)")
print("📨 Received message: \(message)")
```

---

## ⚠️ 常见问题

### 问题1：iOS设备无法发现Windows

**可能原因：**
- Bonjour服务未启动
- 防火墙阻止了端口
- 不在同一网络

**解决方案：**
```bash
# 检查防火墙规则
netsh advfirewall firewall show rule name="VoiceMind"

# 添加规则（如果不存在）
netsh advfirewall firewall add rule name="VoiceMind" dir=in action=allow protocol=tcp localport=8765
```

### 问题2：配对成功但无法通信

**可能原因：**
- WebSocket消息格式不匹配
- HMAC验证失败

**解决方案：**
1. 检查iOS端和Windows端的协议版本
2. 禁用HMAC验证进行测试
3. 查看日志中的错误信息

### 问题3：文本注入不工作

**可能原因：**
- 目标应用不支持文本输入
- Windows API调用失败
- 权限问题

**解决方案：**
1. 尝试在记事本中测试
2. 检查是否需要管理员权限
3. 使用剪贴板方式作为备选

---

## 📊 性能监控

### 监控指标

1. **连接稳定性**
   - 连接建立时间
   - 断开频率
   - 重连成功率

2. **识别延迟**
   - 从说话到文本出现的时间
   - 网络传输延迟

3. **资源占用**
   - CPU使用率
   - 内存占用
   - 网络带宽

### 日志分析

```bash
# 查看最近的日志
tail -f ~/.local/share/VoiceMind/logs/voicemind.log

# 过滤关键日志
grep -E "(ERROR|WARN|connection|recognition)" logs/voicemind.log
```

---

## 🚀 下一步优化

### 短期优化（1-2天）

1. ✅ 完成网络通信测试
2. ✅ 添加前端聆听控制UI
3. ✅ 实现历史记录自动更新

### 中期优化（1周）

1. 实现多设备支持
2. 添加离线缓存
3. 优化识别延迟
4. 添加错误重试机制

### 长期优化（1个月）

1. 添加自定义快捷键
2. 支持多语言识别
3. 添加云端同步
4. 开发统计面板

---

## 📞 技术支持

如果遇到问题：

1. 查看日志文件
2. 检查网络连接
3. 确认设备兼容性
4. 提交Issue到GitHub

---

**祝测试顺利！** 🎉
