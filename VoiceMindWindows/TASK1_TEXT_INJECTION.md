# 任务1：优化文本注入 - 确保文本能正确注入到目标应用

## 📋 任务描述

优化Windows端的文本注入功能，确保语音识别结果能够正确注入到用户当前使用的目标应用程序中。

## 🎯 核心目标

1. **稳定可靠的文本注入** - 在各种Windows应用中都能正确工作
2. **多种注入方式** - 支持键盘模拟、剪贴板等多种方式
3. **优雅的错误处理** - 注入失败时能自动切换到备用方案
4. **用户体验优化** - 最小化对用户工作流的干扰

## 📁 关键文件位置

```
VoiceMindWindows/src-tauri/src/
├── injection.rs           # 主要的文本注入实现 ⚠️ 需要优化
├── network.rs            # 网络通信，会调用注入功能
└── main.rs              # 入口文件
```

## 📊 当前实现状态

### injection.rs 当前功能

```rust
pub enum InjectionMethod {
    Keyboard,    // 键盘Unicode模拟
    Clipboard,  // 剪贴板+Ctrl+V
}
```

**已实现：**
- ✅ 键盘Unicode输入（SendInput）
- ✅ 剪贴板方式（保存→粘贴→恢复）
- ✅ 前台窗口捕获和恢复
- ✅ 分块注入避免缓冲区溢出

**需要优化：**
- ❌ 中文输入支持（Unicode可能有问题）
- ❌ 焦点窗口切换处理
- ❌ 各种应用的兼容性
- ❌ 注入失败时的重试机制
- ❌ 管理员权限处理
- ❌ 日志和错误报告

## 🔧 具体优化需求

### 1. 中文输入优化（高优先级）

**问题：** 当前Unicode方式可能无法在某些应用中正确输入中文

**解决方案：**
```rust
// 方案1：优先使用剪贴板
// 方案2：Win32 API直接发送Unicode字符
// 方案3：检测应用类型选择注入方式
```

**实现要点：**
- 智能检测当前应用是否支持Unicode输入
- 回退机制：Unicode失败自动切换剪贴板
- 中文标点符号处理

### 2. 焦点窗口管理（高优先级）

**问题：** 注入时可能丢失焦点或注入到错误窗口

**解决方案：**
```rust
struct WindowManager {
    // 保存当前焦点窗口
    original_hwnd: HWND,
    
    // 确保目标窗口是焦点
    fn ensure_focus(&self, target_hwnd: HWND) -> Result<()>;
    
    // 恢复原始焦点
    fn restore(&self);
}
```

**实现要点：**
- 使用AttachThreadInput确保可靠焦点切换
- 最小化焦点窗口停留时间
- 异常时确保恢复到原始状态

### 3. 智能注入策略（中优先级）

**问题：** 不同应用可能需要不同的注入方式

**解决方案：**
```rust
enum InjectionStrategy {
    Auto,           // 自动选择最佳方式
    Keyboard,       // 强制使用键盘
    Clipboard,      // 强制使用剪贴板
    Accessibility,  // 使用Windows Accessibility API
}

impl TextInjector {
    fn select_strategy(&self, target_app: &str) -> InjectionStrategy {
        match target_app {
            "notepad" | "notepad++" | "code" => InjectionStrategy::Keyboard,
            "chrome" | "firefox" => InjectionStrategy::Clipboard,
            _ => InjectionStrategy::Auto,
        }
    }
}
```

### 4. 错误处理和重试（高优先级）

**需求：**
```rust
impl TextInjector {
    fn inject_with_retry(&self, text: &str, max_retries: u32) -> Result<()> {
        for attempt in 0..max_retries {
            match self.inject(text) {
                Ok(_) => return Ok(()),
                Err(e) => {
                    if attempt == max_retries - 1 {
                        return Err(e);
                    }
                    // 等待后重试
                    std::thread::sleep(Duration::from_millis(100));
                }
            }
        }
        unreachable!()
    }
}
```

### 5. 管理员权限处理（中优先级）

**问题：** 某些应用需要管理员权限才能注入

**解决方案：**
- 检测是否需要提权
- 提供清晰的权限引导
- UAC提示处理

### 6. 日志和监控（中优先级）

**需求：**
```rust
tracing::info!("Injecting text: {} chars", text.len());
tracing::info!("Injection method: {:?}", method);
tracing::info!("Target window: {}", window_title);
tracing::info!("Injection completed in {}ms", elapsed_ms);
```

## 🧪 测试用例

### 必须测试的应用

1. **记事本** - 最基础的文本编辑器
2. **浏览器** - Chrome、Edge、Firefox
3. **IDE** - VS Code、Notepad++
4. **Office** - Word、Excel（如果可用）
5. **终端** - CMD、PowerShell

### 测试场景

1. ✅ 英文文本注入
2. ✅ 中文文本注入
3. ✅ 混合文本（英文+中文+标点）
4. ✅ 长文本注入（>1000字符）
5. ✅ 特殊字符注入（@#$%^&*）
6. ✅ 连续注入（多次快速注入）

## 📦 交付成果

1. **优化后的injection.rs**
   - 完整的中文支持
   - 智能注入策略
   - 完善的错误处理
   - 详细的日志

2. **测试脚本**
   - 自动化测试用例
   - 性能基准测试

3. **文档**
   - API使用说明
   - 故障排查指南

## ⏱️ 预估工时

- 中文输入优化：2小时
- 焦点窗口管理：1小时
- 智能注入策略：2小时
- 错误处理和重试：1小时
- 测试和调试：2小时
- **总计：约8小时**

## 🎯 成功标准

- [ ] 在至少5个常用应用中测试通过
- [ ] 中文文本注入成功率 > 95%
- [ ] 平均注入延迟 < 500ms
- [ ] 错误自动恢复成功率 > 90%
- [ ] 日志完整可追溯
