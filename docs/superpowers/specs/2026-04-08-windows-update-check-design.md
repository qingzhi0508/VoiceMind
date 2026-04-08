# Windows 检查更新功能设计

## 概述

为 VoiceMindWindows (Tauri v2) 添加应用更新检查功能。采用纯前端方案，通过 GitHub Releases API 获取最新版本信息，支持启动时自动检查和 About 页手动检查。发现新版本后提供下载链接，由系统浏览器完成下载。

## 方案选择

**选定方案：纯前端方案（方案 A）**

前端 JS 直接调用 GitHub Releases API，通过 Tauri shell 插件打开下载链接。不引入额外 Rust 依赖，改动最小。

## 设计细节

### 1. 版本管理

- Rust 端新增 `get_version` 命令，通过 `app.config().version` 返回 `tauri.conf.json` 中定义的版本号
- 前端 About 页的版本号改为动态获取并显示
- 启动时将版本号存入 `state.js`
- 版本比较：解析 `major.minor.patch`，逐段数值比较

### 2. 更新检查流程

**API 调用：**
- 端点：`https://api.github.com/repos/qingzhi0508/VoiceMind/releases/latest`
- 提取 `tag_name`（去掉 `v` 前缀）作为远程版本号
- 从 `assets` 数组中找到 `.msi` 文件的 `browser_download_url` 作为下载链接

**触发时机：**
1. **启动时自动检查** — 应用加载完成后延迟 3 秒静默检查，有新版本时在页面顶部显示通知条
2. **手动检查** — About 页的"检查更新"按钮，结果在 About 页内展示

**错误处理：**
- 网络失败 / API 限流：显示"检查失败，请稍后重试"
- 无新版本：显示"当前已是最新版本"
- 全部使用页面内 UI 元素，不使用 alert

### 3. UI 改动

**About 页改造：**
- 版本号动态显示：`Version {x.y.z}`
- 新增"检查更新"按钮，在 User Guide 按钮下方
- 按钮状态流转：空闲 → 检查中 → 结果（有更新/已是最新/失败）
- 有更新时显示：新版本号、更新说明摘要（`body` 字段前几行）、下载按钮
- 下载按钮通过 Tauri shell 插件在系统浏览器中打开 MSI 下载链接

**启动通知条：**
- 固定在页面顶部的通知条元素，可关闭
- 有新版本时显示："发现新版本 v{x.y.z}，点击查看"
- 点击通知条导航到 About 页并展开更新详情
- 关闭后本次启动不再显示

**不改动：** 侧边栏、导航逻辑、其他页面均不变。

## 涉及文件

| 文件 | 改动 |
|------|------|
| `src-tauri/src/commands.rs` | 新增 `get_version` 命令 |
| `src/app/state.js` | 新增 `currentVersion`、`updateInfo`、`updateChecking`、`updateBannerDismissed` 字段 |
| `src/app/app.js` | 新增更新检查逻辑、UI 渲染、事件绑定 |
| `src/index.html` | About 页版本号动态化、新增检查更新按钮、新增顶部通知条 |
| `src/styles/app.css` | 更新相关 UI 样式 |

## 不做的事

- 不实现自动安装替换
- 不使用 tauri-plugin-updater
- 不添加 Rust 端网络请求依赖
- 不修改侧边栏或导航结构
