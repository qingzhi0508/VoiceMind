# Windows 检查更新功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 VoiceMindWindows 添加 GitHub Releases 更新检查功能，支持启动自动检查和 About 页手动检查，发现新版本后在浏览器中下载 MSI。

**Architecture:** 纯前端方案。前端 JS 调用 GitHub Releases API 获取最新版本信息，通过 Tauri shell 插件在系统浏览器中打开下载链接。Rust 端仅新增一个 `get_version` 命令返回当前版本号。

**Tech Stack:** Tauri v2 (Rust), Vanilla JS, GitHub REST API

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `src-tauri/src/commands.rs` | 新增 `get_version` 命令 |
| Modify | `src-tauri/src/main.rs` | 注册 `get_version` 到 invoke_handler |
| Create | `src-tauri/capabilities/default.json` | 授予 shell:allow-open 权限 |
| Modify | `src/app/state.js` | 新增更新相关状态字段 |
| Modify | `src/app/app.js` | 更新检查逻辑、UI 渲染、事件绑定 |
| Modify | `src/index.html` | About 页改造、新增更新通知条 |
| Modify | `src/styles/app.css` | 更新通知条和 About 更新区域样式 |

---

### Task 1: Rust 后端 — get_version 命令

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/commands.rs` (末尾追加)
- Modify: `VoiceMindWindows/src-tauri/src/main.rs:239-269` (invoke_handler 注册)

- [ ] **Step 1: 在 commands.rs 末尾添加 get_version 命令**

```rust
#[tauri::command]
pub fn get_version(app: tauri::AppHandle) -> String {
    app.config().version.clone().unwrap_or_else(|| "0.0.0".to_string())
}
```

- [ ] **Step 2: 在 main.rs invoke_handler 中注册命令**

在 `commands::check_local_asr,` 之后追加一行：

```rust
commands::get_version,
```

- [ ] **Step 3: 验证编译通过**

Run: `cd D:/data/voice-mind/VoiceMindWindows/src-tauri && cargo check 2>&1 | tail -5`
Expected: `Finished` 或 `warning: ...` (无 error)

- [ ] **Step 4: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/commands.rs VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(windows): add get_version Tauri command"
```

---

### Task 2: Tauri v2 Capabilities 配置

**Files:**
- Create: `VoiceMindWindows/src-tauri/capabilities/default.json`

- [ ] **Step 1: 创建 capabilities 文件**

```json
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default capabilities for VoiceMind",
  "windows": ["main"],
  "permissions": [
    "core:default",
    "shell:allow-open"
  ]
}
```

- [ ] **Step 2: 验证编译通过**

Run: `cd D:/data/voice-mind/VoiceMindWindows/src-tauri && cargo check 2>&1 | tail -5`
Expected: `Finished` 或无 error

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/capabilities/default.json
git commit -m "feat(windows): add Tauri capabilities for shell:allow-open"
```

---

### Task 3: 前端状态扩展

**Files:**
- Modify: `VoiceMindWindows/src/app/state.js`

- [ ] **Step 1: 在 state 对象末尾添加更新相关字段**

在 `selectedHistoryIds: [],` 之后（第 24 行后）追加：

```js
  currentVersion: "",
  updateInfo: null,
  updateChecking: false,
  updateBannerDismissed: false,
```

- [ ] **Step 2: Commit**

```bash
git add VoiceMindWindows/src/app/state.js
git commit -m "feat(windows): add update check state fields"
```

---

### Task 4: index.html — About 页改造 + 更新通知条

**Files:**
- Modify: `VoiceMindWindows/src/index.html`

- [ ] **Step 1: 在 `#banner` 之后添加更新通知条**

在 `<div id="banner" class="banner">...</div>` 之后（第 39 行后）插入：

```html
<div id="update-banner" class="update-banner" hidden>
  <span id="update-banner-text"></span>
  <button id="update-banner-close" class="update-banner-close" type="button">&times;</button>
</div>
```

- [ ] **Step 2: 替换 About 页内容**

将 `<section id="about" class="page">...</section>`（第 204-213 行）整体替换为：

```html
<section id="about" class="page">
  <div class="about-hero">
    <img class="about-icon" src="./assets/app-icon.png" alt="VoiceMind icon">
    <h2>VoiceMind</h2>
    <p class="about-version" id="about-version">Version ...</p>
    <div class="about-divider"></div>
    <p class="about-desc">iPhone 无线麦克风 · Windows 端</p>
    <div class="about-actions">
      <button class="btn primary" type="button" id="btn-check-update">检查更新</button>
      <button class="btn secondary" type="button" id="btn-user-guide">使用指南</button>
    </div>
    <div id="update-result" class="update-result" hidden></div>
  </div>
</section>
```

注意：原 About 的 User Guide 按钮使用了内联 onclick，改为通过 id 在 JS 中绑定事件。

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src/index.html
git commit -m "feat(windows): add update check UI to About page"
```

---

### Task 5: CSS 样式

**Files:**
- Modify: `VoiceMindWindows/src/styles/app.css`

- [ ] **Step 1: 在文件末尾（responsive media query 之前）追加更新相关样式**

```css
/* Update banner */
.update-banner { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 16px; border-radius: 12px; border: 1px solid rgba(0,180,221,0.3); background: rgba(0,180,221,0.10); padding: 10px 14px; font-size: 13px; color: var(--accent); cursor: pointer; }
[data-theme="dark"] .update-banner { background: rgba(0,212,255,0.10); border-color: rgba(0,212,255,0.3); }
.update-banner-close { background: transparent; border: 0; font-size: 18px; color: var(--accent); cursor: pointer; padding: 0 4px; line-height: 1; }

/* About actions */
.about-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: center; }

/* Update result */
.update-result { margin-top: 20px; width: 100%; max-width: 400px; text-align: left; }
.update-result .update-card { padding: 16px; border-radius: 12px; border: 1px solid var(--cardBorder); background: var(--softSurface); }
.update-result .update-card h4 { margin: 0 0 8px; color: var(--title); font-size: 15px; }
.update-result .update-card p { margin: 0 0 12px; color: var(--secondaryText); font-size: 13px; line-height: 1.5; white-space: pre-line; }
.update-result .update-status { font-size: 13px; color: var(--secondaryText); }
.update-result .update-status.checking { color: var(--accent); }
.update-result .update-status.error { color: var(--accentRed); }
.update-result .update-status.up-to-date { color: var(--accentGreen); }
```

- [ ] **Step 2: Commit**

```bash
git add VoiceMindWindows/src/styles/app.css
git commit -m "feat(windows): add update check UI styles"
```

---

### Task 6: 前端更新检查逻辑 (app.js)

**Files:**
- Modify: `VoiceMindWindows/src/app/app.js`

这是最核心的 task。在 `app.js` 中添加：版本获取、更新检查 API 调用、UI 渲染、事件绑定。

- [ ] **Step 1: 在文件顶部 DOM 引用区域添加更新相关元素引用**

在 `const recordsBatchCount = ...` 之后（第 27 行后）追加：

```js
const updateResult = document.getElementById("update-result");
const btnCheckUpdate = document.getElementById("btn-check-update");
const btnUserGuide = document.getElementById("btn-user-guide");
const updateBanner = document.getElementById("update-banner");
const updateBannerText = document.getElementById("update-banner-text");
const updateBannerClose = document.getElementById("update-banner-close");
```

- [ ] **Step 2: 添加版本比较工具函数和更新检查核心逻辑**

在 `toast` 函数（第 570 行附近）之后追加：

```js
    /* ===== Version compare ===== */
    function parseVersion(v) {
      const parts = v.replace(/^v/, "").split(".").map(Number);
      return [parts[0] || 0, parts[1] || 0, parts[2] || 0];
    }

    function isNewer(remote, local) {
      const r = parseVersion(remote);
      const l = parseVersion(local);
      for (let i = 0; i < 3; i++) {
        if (r[i] > l[i]) return true;
        if (r[i] < l[i]) return false;
      }
      return false;
    }

    /* ===== Update check ===== */
    const CACHE_KEY = "voicemind_update_cache";
    const CACHE_INTERVAL = 4 * 60 * 60 * 1000; // 4 hours

    function getUpdateCache() {
      try {
        const raw = localStorage.getItem(CACHE_KEY);
        if (!raw) return null;
        return JSON.parse(raw);
      } catch { return null; }
    }

    function setUpdateCache(data) {
      try { localStorage.setItem(CACHE_KEY, JSON.stringify({ ...data, ts: Date.now() })); } catch {}
    }

    async function fetchLatestRelease() {
      const resp = await fetch("https://api.github.com/repos/qingzhi0508/VoiceMind/releases/latest");
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      return resp.json();
    }

    function extractUpdateInfo(release) {
      const version = (release.tag_name || "").replace(/^v/, "");
      const msiAsset = (release.assets || []).find(a => a.name && a.name.endsWith(".msi") && a.name.includes("x64"))
        || (release.assets || []).find(a => a.name && a.name.endsWith(".msi"));
      return {
        version,
        downloadUrl: msiAsset ? msiAsset.browser_download_url : null,
        body: (release.body || "").split("\n").slice(0, 5).join("\n"),
      };
    }

    async function checkUpdate({ force = false } = {}) {
      if (state.updateChecking) return;
      state.updateChecking = true;
      renderUpdateResult("checking");

      try {
        // Use cache for auto-check unless forced
        let release;
        if (!force) {
          const cache = getUpdateCache();
          if (cache && cache.ts && Date.now() - cache.ts < CACHE_INTERVAL) {
            release = cache;
          }
        }

        if (!release || !release.version) {
          release = await fetchLatestRelease();
          const info = extractUpdateInfo(release);
          setUpdateCache(info);
          release = info;
        } else {
          // release is already extracted info from cache
        }

        const remoteVersion = release.version || release.tag_name?.replace(/^v/, "");
        const info = release.downloadUrl ? release : extractUpdateInfo(release);

        if (remoteVersion && isNewer(remoteVersion, state.currentVersion)) {
          state.updateInfo = info;
          renderUpdateResult("available");
          showUpdateBanner(remoteVersion);
        } else {
          state.updateInfo = null;
          renderUpdateResult("up-to-date");
        }
      } catch (e) {
        console.error("checkUpdate error:", e);
        renderUpdateResult("error", e.message);
      } finally {
        state.updateChecking = false;
      }
    }

    function renderUpdateResult(status, detail) {
      if (!updateResult) return;
      updateResult.hidden = false;

      if (status === "checking") {
        updateResult.innerHTML = `<div class="update-status checking">正在检查更新...</div>`;
      } else if (status === "up-to-date") {
        updateResult.innerHTML = `<div class="update-status up-to-date">&#10003; 当前已是最新版本 (v${state.currentVersion})</div>`;
      } else if (status === "error") {
        updateResult.innerHTML = `<div class="update-status error">检查失败，请稍后重试${detail ? ` (${detail})` : ""}</div>`;
      } else if (status === "available") {
        const info = state.updateInfo;
        updateResult.innerHTML = `
          <div class="update-card">
            <h4>发现新版本 v${escHtml(info.version)}</h4>
            ${info.body ? `<p>${escHtml(info.body)}</p>` : ""}
            <div class="toolbar" style="margin-top:0">
              ${info.downloadUrl ? `<button class="btn primary" type="button" id="btn-download-update">下载更新</button>` : ""}
              <a href="https://github.com/qingzhi0508/VoiceMind/releases/latest" target="_blank" rel="noopener" style="font-size:13px;color:var(--accent)">查看 Release 页</a>
            </div>
          </div>`;
        const dlBtn = document.getElementById("btn-download-update");
        if (dlBtn && info.downloadUrl) {
          dlBtn.addEventListener("click", () => {
            if (window.__TAURI__ && window.__TAURI__.shell) {
              window.__TAURI__.shell.open(info.downloadUrl);
            } else {
              window.open(info.downloadUrl, "_blank");
            }
          });
        }
      }
    }

    function showUpdateBanner(version) {
      if (state.updateBannerDismissed) return;
      if (!updateBanner || !updateBannerText) return;
      updateBannerText.textContent = `发现新版本 v${version}，点击查看`;
      updateBanner.hidden = false;
    }

    // Update banner click → navigate to About page
    if (updateBanner) {
      updateBanner.addEventListener("click", e => {
        if (e.target === updateBannerClose) return;
        document.querySelector('[data-page="about"]').click();
        updateBanner.hidden = true;
      });
    }
    if (updateBannerClose) {
      updateBannerClose.addEventListener("click", e => {
        e.stopPropagation();
        updateBanner.hidden = true;
        state.updateBannerDismissed = true;
      });
    }

    // User guide button
    if (btnUserGuide) {
      btnUserGuide.addEventListener("click", () => toast("使用指南功能开发中"));
    }

    // Manual check button
    if (btnCheckUpdate) {
      btnCheckUpdate.addEventListener("click", () => checkUpdate({ force: true }));
    }
```

- [ ] **Step 3: 在 init() 函数中加载版本号并触发自动检查**

在 `init()` 函数内，`await Promise.all([refreshPairing(), refreshHistory(), loadSettings()]);` 这行之后（第 744 行后）追加：

```js
      // Load app version
      try {
        state.currentVersion = await invoke("get_version");
        const verEl = document.getElementById("about-version");
        if (verEl) verEl.textContent = `Version ${state.currentVersion}`;
      } catch (e) { console.warn("get_version failed:", e); }

      // Auto check update after 3s
      setTimeout(() => checkUpdate(), 3000);
```

- [ ] **Step 4: Commit**

```bash
git add VoiceMindWindows/src/app/app.js
git commit -m "feat(windows): implement update check logic and UI"
```

---

### Task 7: 集成验证

- [ ] **Step 1: 验证 Rust 编译**

Run: `cd D:/data/voice-mind/VoiceMindWindows/src-tauri && cargo check 2>&1 | tail -5`
Expected: `Finished` 无 error

- [ ] **Step 2: 验证前端无语法错误**

Run: `cd D:/data/voice-mind/VoiceMindWindows && npx vite build 2>&1 | tail -10`
Expected: 构建成功

- [ ] **Step 3: 确认所有改动文件一致**

Run: `cd D:/data/voice-mind && git diff --stat HEAD~7`
Expected: 列出 7 个文件（commands.rs, main.rs, capabilities/default.json, state.js, index.html, app.css, app.js）
