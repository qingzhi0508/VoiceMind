# macOS 自动更新功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 VoiceMindMac 增加 GitHub Releases 更新检查、About 页更新入口，以及启动时自动下载并打开新版本安装包的能力。

**Architecture:** 新增一个原生 Swift 更新管理器，统一处理版本比较、GitHub Releases 请求、安装包筛选、下载与打开。About 页只负责展示状态与触发动作；应用启动时按设置调用同一套管理逻辑。

**Tech Stack:** SwiftUI, Foundation, AppKit, URLSession, GitHub REST API

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `VoiceMindMac/VoiceMindMac/Updates/MacAppUpdateManager.swift` | 版本检查、远端 release 解析、安装包下载与打开 |
| Modify | `VoiceMindMac/VoiceMindMac/Settings/AppSettings.swift` | 自动更新开关与上次检查时间持久化 |
| Modify | `VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift` | 应用启动时触发自动更新检查 |
| Modify | `VoiceMindMac/VoiceMindMac/Views/MainWindow.swift` | About 页新增更新卡片和状态展示 |
| Modify | `VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings` | 新增中文文案 |
| Modify | `VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings` | 新增英文文案 |

---

### Task 1: 更新管理器

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Updates/MacAppUpdateManager.swift`

- [ ] **Step 1: 定义当前版本与 release 数据模型**
- [ ] **Step 2: 实现版本比较工具**
- [ ] **Step 3: 实现 GitHub Releases latest 请求与解码**
- [ ] **Step 4: 实现 macOS 资源选择策略**
- [ ] **Step 5: 实现下载目录创建、文件下载与安装包打开**
- [ ] **Step 6: 暴露 `checkForUpdates()` / `downloadAndInstallLatestRelease()` / `performAutomaticUpdateCheckIfNeeded()` 接口**

### Task 2: 设置持久化

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/Settings/AppSettings.swift`

- [ ] **Step 1: 新增自动更新开关键值**
- [ ] **Step 2: 新增上次检查时间键值**
- [ ] **Step 3: 在初始化和 `resetToDefaults()` 中接入默认值**

### Task 3: 应用启动自动更新

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift`

- [ ] **Step 1: 在启动流程末尾触发自动检查**
- [ ] **Step 2: 保持非阻塞，不影响现有语音服务初始化**

### Task 4: About 页更新卡片

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/Views/MainWindow.swift`

- [ ] **Step 1: 给 About 页接入更新管理器观察对象**
- [ ] **Step 2: 新增版本展示与自动更新开关**
- [ ] **Step 3: 新增检查更新按钮**
- [ ] **Step 4: 新增新版本摘要与下载并安装按钮**
- [ ] **Step 5: 保持现有视觉规范，不引入额外嵌套层级**

### Task 5: 本地化文案

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings`

- [ ] **Step 1: 增加更新区标题、状态、按钮、错误文案**
- [ ] **Step 2: 将 About 页版本文案改为纯标签，版本号由代码动态拼装**

### Task 6: 验证

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/...`

- [ ] **Step 1: 运行 macOS 构建验证**

Run:

```bash
xcodebuild -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Expected:

- 项目编译通过
- 无新增 Swift 语法错误

- [ ] **Step 2: 若 GitHub Releases 仓库当前不可访问，确认 UI 能展示失败状态，不崩溃**
