# VoiceMind Project Settings

## 启动规则
- **打开本项目必须先完整加载 CLAUDE.md**，所有规则在每次会话开始时生效

## 默认设置
不需要每次都确认操作

## 权限
- 允许执行所有 Bash 命令（破坏性操作除外）
- 允许修改已存在的源文件
- 允许创建新的源文件
- 允许使用 Read/Edit/Write/Glob/Grep 等工具

## 开发约定
- 提交前确保代码可以编译
- Swift 项目使用 xcodebuild 或 swiftc 验证语法

## UI 设计规范
- 所有页面 UI 修改必须遵守 `docs/design/vendor/apple-design-md/DESIGN.md` 中的 Apple 设计规范
- 核心要点：
  - 系统字体（SF Pro），tight line-height，negative letter-spacing
  - 单一强调色 Apple Blue (`#0071e3`)，仅用于交互元素
  - 二元背景节奏：纯黑 (`#000000`) 交替浅灰 (`#f5f5f7`)
  - 极简阴影：仅用 `rgba(0,0,0,0.22) 3px 5px 30px` 或无阴影
  - Pill 形状 CTA（980px radius），圆角按钮 8px
  - 大量留白，内容居中，产品为视觉核心

## gstack
Use /browse from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.
Available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy, /canary, /benchmark, /browse, /connect-chrome, /qa, /qa-only, /design-review, /setup-browser-cookies, /setup-deploy, /retro, /investigate, /document-release, /codex, /cso, /autoplan, /plan-devex-review, /devex-review, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn.
