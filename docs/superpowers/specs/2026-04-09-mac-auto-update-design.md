# macOS 自动更新功能设计

## 概述

为 VoiceMindMac 添加一套可直接工作的更新能力：About 页支持手动检查更新，应用启动后可按用户开关自动检查并下载安装包。更新来源使用 GitHub Releases，更新方式为直接下载 macOS 安装包并由系统打开，不依赖额外更新框架或 appcast。

## 方案选择

**选定方案：GitHub Releases + 原生下载器（方案 B）**

当前仓库没有 Sparkle，也没有 appcast、EdDSA 签名和对应发布流程。若现在接入 Sparkle，代码可编译，但功能无法完整跑通。为了先交付可用能力，本次采用原生 Swift 实现：

- 用 GitHub Releases API 获取最新版本
- 比较本地版本与远端版本
- 选择适合 macOS 的 `.dmg` / `.zip` / `.pkg` 资源
- 下载到 `~/Downloads/VoiceMind Updates/`
- 下载完成后直接用 `NSWorkspace` 打开安装包

后续若发布链路补齐 appcast 与签名，可再切换到 Sparkle，不影响 About 页交互层。

## 设计细节

### 1. 更新源与版本判断

- 默认更新仓库：`qingzhi0508/VoiceMind`
- API 端点：`https://api.github.com/repos/qingzhi0508/VoiceMind/releases/latest`
- 当前版本来源：`Bundle.main.infoDictionary`
  - `CFBundleShortVersionString`
  - `CFBundleVersion`
- 版本比较规则：
  - 先去掉 `v` 前缀
  - 按 `major.minor.patch` 逐段数值比较
  - 若主版本相同但构建号更高，也视为可更新

### 2. 安装包选择策略

从 release `assets` 中筛选 macOS 安装包：

- 优先扩展名：`.dmg` > `.zip` > `.pkg`
- 优先匹配关键词：
  - Apple Silicon: `mac`, `macos`, `darwin`, `universal`, `arm64`, `apple-silicon`
  - Intel: `mac`, `macos`, `darwin`, `universal`, `x86_64`, `intel`
- 若没有架构专属资源，则回退到第一个 macOS 安装包

### 3. 触发时机

1. **About 页手动检查**
   - 点击“检查更新”后立即请求 API
   - 若发现新版本，页面内展示版本号、摘要与“下载并安装”

2. **启动自动更新**
   - 新增用户开关“自动检查并下载安装更新”
   - 开启后，应用启动时静默检查
   - 若发现新版本，直接开始下载并打开安装包
   - 同一天内只自动检查一次，避免频繁请求

### 4. 状态与错误处理

使用页面内状态展示，不使用多层弹窗：

- 空闲：显示当前版本
- 检查中：显示“正在检查更新”
- 已是最新：显示“当前已是最新版本”
- 发现新版本：显示版本号、发布时间、摘要、安装按钮
- 下载中：显示下载状态
- 成功：显示“安装包已打开”
- 失败：显示错误原因，并保留重试入口

若自动更新触发失败，仅更新状态，不打断用户当前工作流。

### 5. 设置持久化

`AppSettings` 新增：

- `automaticallyChecksForUpdates`
- `lastUpdateCheckDate`

默认行为：

- `automaticallyChecksForUpdates = false`
- 用户明确开启后才执行自动下载安装

### 6. About 页 UI

在现有 About Hero 下新增独立更新卡片，内容包括：

- 当前版本号
- 自动更新开关
- 检查更新按钮
- 更新状态文案
- 新版本摘要
- 下载并安装按钮

视觉延续当前 mac 界面规范，使用卡片式信息层级，不新增复杂面板。

## 涉及文件

| 文件 | 改动 |
|------|------|
| `VoiceMindMac/VoiceMindMac/Settings/AppSettings.swift` | 增加自动更新相关设置与持久化 |
| `VoiceMindMac/VoiceMindMac/VoiceMindMacApp.swift` | 启动时触发自动检查 |
| `VoiceMindMac/VoiceMindMac/Views/MainWindow.swift` | About 页新增更新区域 |
| `VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings` | 新增中文更新文案 |
| `VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings` | 新增英文更新文案 |
| `VoiceMindMac/VoiceMindMac/Updates/MacAppUpdateManager.swift` | 新建更新管理器，负责检查、下载、打开安装包 |

## 不做的事

- 不接入 Sparkle
- 不实现应用内无缝替换自身
- 不修改 GitHub Release 发布流程
- 不引入签名校验与 appcast
