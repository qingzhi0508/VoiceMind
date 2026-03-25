# 任务2：重构前端UI - 实现完整的Mac风格界面

## 📋 任务描述

重构VoiceMind Windows端的前端界面，使其具有与Mac端一致的现代化用户体验。

## 🎯 核心目标

1. **Mac风格设计语言** - 侧边栏导航、卡片式布局
2. **响应式交互** - 实时状态反馈、平滑动画
3. **完整功能页面** - 主页、设备、历史、设置等
4. **现代化视觉效果** - 玻璃拟态、渐变、阴影

## 📁 关键文件位置

```
VoiceMindWindows/src/
├── index.html           # 主HTML文件 ⚠️ 需要重构
├── styles.css           # 样式文件 ⚠️ 需要重构
└── script.js            # JavaScript逻辑（可能需要）
```

**参考Mac端实现：**
```
VoiceMindMac/VoiceMindMac/Views/
├── MainWindow.swift     # 主窗口结构
├── HomeDashboard.swift  # 主页Dashboard
├── SpeechRecognitionTab.swift  # 语音识别页面
└── SettingsView.swift  # 设置页面
```

## 📊 当前UI vs 目标UI

### 当前UI（基础）
```
┌─────────────────┐
│  VoiceMind      │  ← 简单标题
├─────────────────┤
│ ● Disconnected  │  ← 状态栏
├─────────────────┤
│ [配对][设备][历史][设置] │ ← 简单Tab
├─────────────────┤
│ 配对区域        │  ← 基础卡片
│ 二维码 + 配对码 │
└─────────────────┘
```

### 目标UI（Mac风格）
```
┌──────────────────────────────────────────┐
│ ← 侧边栏 (240px)  │  主内容区              │
│                   │                        │
│ 🎙️ VoiceMind     │  ┌──────────────────┐ │
│ ─────────────── │  │  主页Dashboard    │ │
│                   │  │                  │ │
│ 📱 首页          │  │  连接状态卡片     │ │
│ 📡 设备          │  │  聆听控制卡片     │ │
│ 📝 历史          │  │  最近的识别       │ │
│ ⚙️ 设置          │  │                  │ │
│ ℹ️ 关于          │  └──────────────────┘ │
│                   │                        │
│ ─────────────── │  ┌──────────────────┐ │
│ 连接状态        │  │  实时字幕显示     │ │
│ ● 已连接 iPhone │  │  (部分识别结果)   │ │
└─────────────────┴──┴──────────────────┘─┘
```

## 🎨 设计规范

### 颜色系统

```css
:root {
    /* 主色调 */
    --primary: #667eea;           /* 品牌蓝 */
    --primary-dark: #5568d3;
    --secondary: #764ba2;         /* 紫色 */
    --accent: #f093fb;            /* 粉色强调 */
    
    /* 文本颜色 */
    --text-primary: #1a202c;      /* 主文本 */
    --text-secondary: #4a5568;    /* 次要文本 */
    --text-light: #718096;        /* 浅色文本 */
    
    /* 背景颜色 */
    --bg-primary: #ffffff;
    --bg-secondary: #f7fafc;
    --bg-dark: #1a1a2e;           /* 深色模式背景 */
    
    /* 状态颜色 */
    --status-connected: #00ff88;  /* 绿色 - 已连接 */
    --status-listening: #ff6b6b; /* 红色 - 聆听中 */
    --status-connecting: #ffaa00;/* 黄色 - 连接中 */
    
    /* 阴影 */
    --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.1);
    --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1);
    --shadow-lg: 0 10px 40px rgba(0, 0, 0, 0.15);
    
    /* 圆角 */
    --radius-sm: 8px;
    --radius-md: 12px;
    --radius-lg: 20px;
    --radius-xl: 30px;
}
```

### 字体系统

```css
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 
                 'Noto Sans SC', sans-serif;
    font-size: 14px;
    line-height: 1.6;
}

h1 { font-size: 32px; font-weight: 700; }
h2 { font-size: 24px; font-weight: 600; }
h3 { font-size: 18px; font-weight: 600; }
```

### 间距系统

```css
:root {
    --spacing-xs: 4px;
    --spacing-sm: 8px;
    --spacing-md: 16px;
    --spacing-lg: 24px;
    --spacing-xl: 32px;
    --spacing-2xl: 48px;
}
```

## 🏗️ 页面结构

### 1. 侧边栏（Sidebar）

```html
<aside class="sidebar">
    <!-- Logo区域 -->
    <div class="sidebar-header">
        <span class="logo-icon">🎙️</span>
        <span class="logo-text">VoiceMind</span>
    </div>
    
    <!-- 导航菜单 -->
    <nav class="sidebar-nav">
        <a href="#home" class="nav-item active">
            <span class="nav-icon">📱</span>
            <span class="nav-text">首页</span>
        </a>
        <a href="#devices" class="nav-item">
            <span class="nav-icon">📡</span>
            <span class="nav-text">设备</span>
        </a>
        <a href="#history" class="nav-item">
            <span class="nav-icon">📝</span>
            <span class="nav-text">历史</span>
        </a>
        <a href="#settings" class="nav-item">
            <span class="nav-icon">⚙️</span>
            <span class="nav-text">设置</span>
        </a>
    </nav>
    
    <!-- 连接状态 -->
    <div class="sidebar-footer">
        <div class="connection-status">
            <span class="status-dot connected"></span>
            <span class="status-text">已连接 iPhone</span>
        </div>
    </div>
</aside>
```

### 2. 主页Dashboard

```html
<section id="home" class="page active">
    <!-- 状态卡片 -->
    <div class="status-card">
        <div class="status-indicator connected">
            <span class="pulse"></span>
            <span>已连接</span>
        </div>
        <div class="device-info">
            <span class="device-icon">📱</span>
            <span class="device-name">iPhone 13 Pro</span>
        </div>
    </div>
    
    <!-- 聆听控制卡片 -->
    <div class="control-card">
        <button class="mic-button" id="mic-toggle">
            <span class="mic-icon">🎤</span>
        </button>
        <p class="control-hint">点击开始聆听</p>
    </div>
    
    <!-- 实时字幕 -->
    <div class="subtitle-card">
        <div class="subtitle-content">
            <p class="subtitle-text" id="subtitle-text">等待开始说话...</p>
        </div>
    </div>
    
    <!-- 最近识别 -->
    <div class="recent-card">
        <h3>最近的识别</h3>
        <div class="recent-list">
            <!-- 动态生成 -->
        </div>
    </div>
</section>
```

### 3. 设备页面

```html
<section id="devices" class="page">
    <div class="section-header">
        <h2>已连接设备</h2>
    </div>
    
    <div class="device-card connected">
        <div class="device-icon">📱</div>
        <div class="device-info">
            <h3>iPhone 13 Pro</h3>
            <p>最后活动: 刚刚</p>
        </div>
        <span class="status-badge connected">已连接</span>
    </div>
    
    <div class="section-header">
        <h2>已配对设备</h2>
        <button class="btn-secondary">添加设备</button>
    </div>
    
    <div class="device-card">
        <div class="device-icon">📱</div>
        <div class="device-info">
            <h3>iPad Pro</h3>
            <p>最后在线: 2小时前</p>
        </div>
        <button class="btn-text">忘记</button>
    </div>
</section>
```

### 4. 历史页面

```html
<section id="history" class="page">
    <div class="section-header">
        <h2>识别历史</h2>
        <div class="search-box">
            <input type="text" placeholder="搜索...">
        </div>
    </div>
    
    <div class="filter-tabs">
        <button class="filter-tab active">全部</button>
        <button class="filter-tab">今天</button>
        <button class="filter-tab">本周</button>
    </div>
    
    <div class="history-list">
        <!-- 历史项 -->
    </div>
</section>
```

### 5. 设置页面

```html
<section id="settings" class="page">
    <!-- 语言设置 -->
    <div class="settings-group">
        <h3>语言</h3>
        <div class="setting-row">
            <span>界面语言</span>
            <select>
                <option value="zh-CN">简体中文</option>
                <option value="en-US">English</option>
            </select>
        </div>
    </div>
    
    <!-- 注入设置 -->
    <div class="settings-group">
        <h3>文本注入</h3>
        <div class="setting-row">
            <span>注入方式</span>
            <select>
                <option value="auto">自动</option>
                <option value="keyboard">键盘模拟</option>
                <option value="clipboard">剪贴板</option>
            </select>
        </div>
    </div>
    
    <!-- 服务器设置 -->
    <div class="settings-group">
        <h3>服务器</h3>
        <div class="setting-row">
            <span>端口</span>
            <input type="number" value="8765">
        </div>
    </div>
    
    <!-- 关于 -->
    <div class="settings-group">
        <h3>关于</h3>
        <div class="about-info">
            <p>VoiceMind Windows v1.0.0</p>
            <p>iPhone作为无线麦克风</p>
        </div>
    </div>
</section>
```

## 🎭 交互效果

### 侧边栏切换

```css
.sidebar-nav .nav-item {
    transition: all 0.2s ease;
    border-radius: var(--radius-md);
    padding: var(--spacing-sm) var(--spacing-md);
}

.sidebar-nav .nav-item:hover {
    background: rgba(102, 126, 234, 0.1);
}

.sidebar-nav .nav-item.active {
    background: var(--primary);
    color: white;
}
```

### 聆听按钮动画

```css
.mic-button {
    width: 120px;
    height: 120px;
    border-radius: 50%;
    background: var(--bg-gradient);
    border: none;
    cursor: pointer;
    transition: all 0.3s ease;
}

.mic-button:hover {
    transform: scale(1.05);
    box-shadow: var(--shadow-lg);
}

.mic-button.listening {
    animation: pulse-ring 1.5s infinite;
}

@keyframes pulse-ring {
    0% {
        box-shadow: 0 0 0 0 rgba(255, 107, 107, 0.7);
    }
    70% {
        box-shadow: 0 0 0 20px rgba(255, 107, 107, 0);
    }
    100% {
        box-shadow: 0 0 0 0 rgba(255, 107, 107, 0);
    }
}
```

### 状态卡片动画

```css
.status-card {
    background: white;
    border-radius: var(--radius-lg);
    padding: var(--spacing-lg);
    box-shadow: var(--shadow-md);
    transition: all 0.3s ease;
}

.status-card:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-lg);
}

.status-dot {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    animation: pulse 2s infinite;
}

.status-dot.connected {
    background: var(--status-connected);
}

.status-dot.listening {
    background: var(--status-listening);
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}
```

## 📱 响应式设计

### 平板适配（768px - 1024px）

```css
@media (max-width: 1024px) {
    .sidebar {
        width: 200px;
    }
    
    .main-content {
        margin-left: 200px;
    }
}
```

### 移动适配（< 768px）

```css
@media (max-width: 768px) {
    .sidebar {
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        width: 100%;
        height: auto;
        flex-direction: row;
        z-index: 100;
    }
    
    .sidebar-nav {
        display: flex;
        justify-content: space-around;
        width: 100%;
    }
    
    .main-content {
        margin-left: 0;
        margin-bottom: 60px;
    }
}
```

## 🔄 JavaScript功能

### 页面路由

```javascript
class Router {
    constructor() {
        this.routes = {
            '#home': HomePage,
            '#devices': DevicesPage,
            '#history': HistoryPage,
            '#settings': SettingsPage
        };
        this.init();
    }
    
    init() {
        window.addEventListener('hashchange', () => this.navigate());
        this.navigate();
    }
    
    navigate() {
        const hash = window.location.hash || '#home';
        const Page = this.routes[hash];
        if (Page) {
            new Page().render();
        }
    }
}
```

### 状态管理

```javascript
class AppState {
    constructor() {
        this.state = {
            connectionStatus: 'disconnected',
            listening: false,
            currentDevice: null,
            recentTranscripts: []
        };
        this.listeners = [];
    }
    
    setState(newState) {
        this.state = { ...this.state, ...newState };
        this.notify();
    }
    
    subscribe(listener) {
        this.listeners.push(listener);
    }
    
    notify() {
        this.listeners.forEach(fn => fn(this.state));
    }
}
```

### Tauri事件监听

```javascript
// 监听后端事件
const { listen } = window.__TAURI__.core;

listen('connection-changed', (event) => {
    appState.setState({ connectionStatus: event.payload.connected ? 'connected' : 'disconnected' });
});

listen('listening-started', (event) => {
    appState.setState({ listening: true });
});

listen('listening-stopped', (event) => {
    appState.setState({ listening: false });
});

listen('recognition-result', (event) => {
    const { text, language } = event.payload;
    appState.setState({
        currentTranscript: text,
        recentTranscripts: [text, ...appState.state.recentTranscripts].slice(0, 10)
    });
});
```

## 🧪 测试清单

### 界面测试
- [ ] 侧边栏导航正常切换
- [ ] 所有页面都能正确渲染
- [ ] 响应式布局正常工作
- [ ] 动画效果流畅

### 功能测试
- [ ] 连接状态实时更新
- [ ] 聆听按钮正常工作
- [ ] 历史记录正常显示
- [ ] 设置保存和加载

### 兼容性测试
- [ ] Chrome/Edge浏览器
- [ ] 不同屏幕尺寸
- [ ] 深色/浅色模式

## 📦 交付成果

1. **完整的HTML结构**
   - 语义化的标签
   - 可访问性支持
   - SEO优化

2. **现代化的CSS样式**
   - CSS变量系统
   - 响应式设计
   - 动画效果

3. **交互逻辑JavaScript**
   - 路由系统
   - 状态管理
   - Tauri集成

4. **完整的文档**
   - API说明
   - 组件说明
   - 故障排查

## ⏱️ 预估工时

- 侧边栏设计：2小时
- 主页Dashboard：3小时
- 设备页面：2小时
- 历史页面：2小时
- 设置页面：2小时
- 动画和交互：2小时
- 测试和调试：2小时
- **总计：约15小时**

## 🎯 成功标准

- [ ] 界面与Mac端风格一致
- [ ] 所有页面完整可用
- [ ] 响应式布局正常
- [ ] 动画效果流畅
- [ ] 与后端事件正常通信
