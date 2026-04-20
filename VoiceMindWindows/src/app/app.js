import { state } from "./state.js";
import { banner, historyList, devicesList, activityList } from "./dom.js";
import { invoke, listenApi } from "./tauri.js";
import { pairedName, connLabel, summary, escHtml } from "./helpers.js";
import { applyTheme } from "./theme.js";
import { initSpeechAsrLayout, bindNavigation, bindSegmentedPickers } from "./layout.js";
import { check as checkForAppUpdate } from "@tauri-apps/plugin-updater";
import { relaunch } from "@tauri-apps/plugin-process";

if (!state.isTauri) banner.style.display = "block";

applyTheme(localStorage.getItem("voicemind_theme") || "light");
initSpeechAsrLayout();
bindNavigation({ onRecordsPage: () => refreshHistory() });
bindSegmentedPickers({
  onDataFilterChange: filter => {
    state.dataFilter = filter;
    renderActivity();
  },
});

const engineRows = [...document.querySelectorAll(".engine-row")];
const speechEngineHint = document.getElementById("speech-engine-hint");
const cloudEngineStatus = document.getElementById("engine-status-cloud");
const qwen3EngineStatus = document.getElementById("engine-status-qwen3");
const btnDownloadQwen3Binary = document.getElementById("btn-download-qwen3-binary");
const speechAsrModal = document.getElementById("speech-asr-modal");
const qwen3ConfigModal = document.getElementById("qwen3-config-modal");
const speechConfigCancel = document.getElementById("speech-config-cancel");
const qwen3ConfigCancel = document.getElementById("qwen3-config-cancel");
const speechConfigClose = null;
const recordsBatchToolbar = document.getElementById("records-batch-toolbar");
const recordsBatchCount = document.getElementById("records-batch-count");
const updateResult = document.getElementById("update-result");
const btnCheckUpdate = document.getElementById("btn-check-update");
const btnOpenReleases = document.getElementById("btn-open-releases");
const btnUserGuide = document.getElementById("btn-user-guide");
const RELEASES_URL = "https://github.com/qingzhi0508/VoiceMind/releases";

function getFilteredHistoryItems() {
  let items = state.history;
  const q = state.recordsSearch.toLowerCase();
  if (q) items = items.filter(h => (h.text || "").toLowerCase().includes(q));
  return items;
}

function setRecordsBatchMode(enabled) {
  state.recordsBatchMode = enabled;
  if (!enabled) state.selectedHistoryIds = [];
  renderHistory();
}

function toggleHistorySelection(id) {
  const selected = new Set(state.selectedHistoryIds);
  if (selected.has(id)) selected.delete(id);
  else selected.add(id);
  state.selectedHistoryIds = [...selected];
  renderHistory();
}

function selectAllVisibleHistory() {
  state.selectedHistoryIds = getFilteredHistoryItems().map(item => item.id);
  renderHistory();
}

function updateRecordsBatchToolbar() {
  if (!recordsBatchToolbar || !recordsBatchCount) return;
  recordsBatchToolbar.hidden = !state.recordsBatchMode;
  recordsBatchCount.textContent = `\u5df2\u9009\u4e2d: ${state.selectedHistoryIds.length}`;
}

async function copySelectedHistory() {
  const selectedItems = getFilteredHistoryItems().filter(item => state.selectedHistoryIds.includes(item.id));
  if (!selectedItems.length) {
    toast("\u8bf7\u5148\u9009\u62e9\u8981\u590d\u5236\u7684\u8bb0\u5f55");
    return;
  }

  const content = selectedItems.map(item => {
    const time = item.timestamp || "";
    return `${time}\n${item.text || ""}`;
  }).join("\n\n");

  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(content);
    } else {
      const textarea = document.createElement("textarea");
      textarea.value = content;
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand("copy");
      textarea.remove();
    }
    toast(`\u5df2\u590d\u5236 ${selectedItems.length} \u6761\u8bb0\u5f55`);
  } catch (e) {
    toast(`\u590d\u5236\u5931\u8d25: ${e}`);
  }
}

async function deleteSelectedHistory() {
  const ids = [...state.selectedHistoryIds];
  if (!ids.length) {
    toast("\u8bf7\u5148\u9009\u62e9\u8981\u5220\u9664\u7684\u8bb0\u5f55");
    return;
  }

  if (!state.isTauri) {
    state.history = state.history.filter(item => !ids.includes(item.id));
    addActivity("\u6279\u91cf\u5220\u9664\u8bb0\u5f55", `\u5df2\u5220\u9664 ${ids.length} \u6761`, "records");
    setRecordsBatchMode(false);
    return;
  }

  try {
    await Promise.all(ids.map(id => invoke("delete_history_item", { id })));
    addActivity("\u6279\u91cf\u5220\u9664\u8bb0\u5f55", `\u5df2\u5220\u9664 ${ids.length} \u6761`, "records");
    await refreshHistory();
    setRecordsBatchMode(false);
    toast(`\u5df2\u5220\u9664 ${ids.length} \u6761\u8bb0\u5f55`);
  } catch (e) {
    toast(`\u6279\u91cf\u5220\u9664\u5931\u8d25: ${e}`);
  }
}

function isCloudConfigured(settings = state.settings) {
  const asr = settings && settings.asr;
  return Boolean(asr && asr.app_id && asr.access_key && asr.resource_id);
}

function isEngineSelectable(engine) {
  if (engine === "cloud") return state.asrConfigured;
  if (engine === "local") return state.localAsrAvailable !== false;
  if (engine === "qwen3_local") return state.qwen3BinaryAvailable &&
    (state.qwen3Models["0.6b"].downloaded || state.qwen3Models["1.7b"].downloaded);
  return false;
}

function getPreferredEngine() {
  const saved = state.settings && state.settings.asr_engine;
  if (saved === "cloud" && state.asrConfigured) return "cloud";
  if (saved === "qwen3_local" && isEngineSelectable("qwen3_local")) return "qwen3_local";
  if (saved === "local" && state.localAsrAvailable !== false) return "local";
  if (state.localAsrAvailable !== false) return "local";
  if (isEngineSelectable("qwen3_local")) return "qwen3_local";
  if (state.asrConfigured) return "cloud";
  return "local";
}

function setAsrConfigExpanded(expanded) {
  state.asrConfigExpanded = expanded;
  if (speechAsrModal) speechAsrModal.hidden = !expanded;
  if (expanded && qwen3ConfigModal) qwen3ConfigModal.hidden = true;
}

function setQwen3ConfigExpanded(expanded) {
  state.qwen3ConfigExpanded = expanded;
  if (qwen3ConfigModal) qwen3ConfigModal.hidden = !expanded;
  if (expanded && speechAsrModal) speechAsrModal.hidden = true;
}

function updateEngineHint(message) {
  if (!speechEngineHint) return;
  speechEngineHint.textContent = message || "";
  speechEngineHint.hidden = !message;
}

function updateSpeechEngineActions() {
  const focusEngine = state.pendingEngine || (state.settings && state.settings.asr_engine) || "local";
  let hintText = "\u70b9\u51fb\u5f15\u64ce\u67e5\u770b\u53ef\u7528\u72b6\u6001\u548c\u914d\u7f6e\u5165\u53e3\u3002";

  if (focusEngine === "cloud") {
    if (state.asrConfigured) {
      hintText = "\u5f53\u524d\u4e91\u7aef ASR \u5df2\u914d\u7f6e\uff0c\u53ef\u4ee5\u76f4\u63a5\u9009\u4e2d\uff0c\u4e5f\u53ef\u4ee5\u7ee7\u7eed\u7ef4\u62a4\u51ed\u636e\u3002";
    } else {
      hintText = "\u5f53\u524d\u4e91\u7aef ASR \u5c1a\u672a\u914d\u7f6e\uff0c\u5b8c\u6210\u51ed\u636e\u914d\u7f6e\u540e\u624d\u80fd\u9009\u4e2d\u3002";
    }
  } else if (focusEngine === "local") {
    if (state.localAsrAvailable === false) {
      hintText = "Windows \u672c\u5730\u8bed\u97f3\u8bc6\u522b\u5f53\u524d\u4e0d\u53ef\u7528\uff0c\u8bf7\u5148\u68c0\u67e5\u7cfb\u7edf\u8bed\u97f3\u7ec4\u4ef6\u3002";
    } else {
      hintText = "";
    }
  } else if (focusEngine === "qwen3_local") {
    if (!state.qwen3BinaryAvailable) {
      hintText = "Qwen3-ASR 引擎未安装，请点击「下载引擎」按钮下载。";
    } else if (!state.qwen3Models["0.6b"].downloaded && !state.qwen3Models["1.7b"].downloaded) {
      hintText = "\u5c1a\u672a\u4e0b\u8f7d\u4efb\u4f55\u6a21\u578b\uff0c\u8bf7\u5148\u4e0b\u8f7d\u81f3\u5c11\u4e00\u4e2a\u6a21\u578b\u3002";
    } else {
      hintText = "";
    }
  }

  if (cloudEngineStatus) {
    cloudEngineStatus.textContent = state.asrConfigured ? "\u5df2\u914d\u7f6e" : "\u672a\u914d\u7f6e";
    cloudEngineStatus.className = state.asrConfigured ? "engine-status available" : "engine-status warning";
    cloudEngineStatus.disabled = false;
    cloudEngineStatus.title = state.asrConfigured ? "\u70b9\u51fb\u7f16\u8f91 ASR \u914d\u7f6e" : "\u70b9\u51fb\u53bb\u914d\u7f6e ASR";
  }

  if (qwen3EngineStatus) {
    const hasModel = state.qwen3Models["0.6b"].downloaded || state.qwen3Models["1.7b"].downloaded;
    if (!state.qwen3BinaryAvailable) {
      qwen3EngineStatus.textContent = state.qwen3BinaryDownloading ? "下载中..." : "\u672a\u5b89\u88c5";
      qwen3EngineStatus.className = "engine-status error";
    } else if (hasModel) {
      qwen3EngineStatus.textContent = "\u53ef\u7528";
      qwen3EngineStatus.className = "engine-status available";
    } else {
      qwen3EngineStatus.textContent = "\u672a\u4e0b\u8f7d";
      qwen3EngineStatus.className = "engine-status warning";
    }
    qwen3EngineStatus.disabled = false;
    qwen3EngineStatus.title = "\u70b9\u51fb\u7ba1\u7406 Qwen3 \u6a21\u578b";
  }
  // Show/hide download binary button
  if (btnDownloadQwen3Binary) {
    if (!state.qwen3BinaryAvailable && !state.qwen3BinaryDownloading) {
      btnDownloadQwen3Binary.hidden = false;
      btnDownloadQwen3Binary.textContent = "下载引擎";
      btnDownloadQwen3Binary.disabled = false;
    } else if (state.qwen3BinaryDownloading) {
      btnDownloadQwen3Binary.hidden = false;
      btnDownloadQwen3Binary.textContent = "下载中...";
      btnDownloadQwen3Binary.disabled = true;
    } else {
      btnDownloadQwen3Binary.hidden = true;
    }
  }
  updateEngineHint(hintText);
}

function renderEngineSelection() {
  const currentEngine = getPreferredEngine();
  if (state.settings) state.settings.asr_engine = currentEngine;

  engineRows.forEach(row => {
    const engine = row.dataset.engine;
    const isSelected = engine === currentEngine;
    row.classList.toggle("selected", isSelected);
    row.classList.toggle("locked",
      (engine === "cloud" && !state.asrConfigured) ||
      (engine === "qwen3_local" && !isEngineSelectable("qwen3_local"))
    );
    row.classList.toggle("unavailable",
      (engine === "local" && state.localAsrAvailable === false) ||
      (engine === "qwen3_local" && !state.qwen3BinaryAvailable)
    );
  });

  updateSpeechEngineActions();
}

async function selectAsrEngine(engine, { silent = false } = {}) {
  if (!isEngineSelectable(engine)) return false;

  if (state.settings) state.settings.asr_engine = engine;
  state.pendingEngine = engine;
  renderEngineSelection();

  if (state.isTauri && state.settings) {
    try {
      await invoke("save_settings", { settings: { ...state.settings, asr_engine: engine } });
      if (!silent) {
        const labels = {
          local: "\u5df2\u5207\u6362\u5230 Windows \u672c\u5730\u8bc6\u522b",
          cloud: "\u5df2\u5207\u6362\u5230 Volcengine ASR",
          qwen3_local: "\u5df2\u5207\u6362\u5230 Qwen3-ASR \u672c\u5730\u8bc6\u522b",
        };
        toast(labels[engine] || "\u5df2\u5207\u6362\u5f15\u64ce");
      }
    } catch (e) {
      toast(`\u5207\u6362\u5931\u8d25: ${e}`);
      return false;
    }
  }

  return true;
}

    /* ===== Render ===== */
    function renderStatus() {
      const dot = document.getElementById("side-dot");
      dot.className = "dot";
      if (state.listening) dot.classList.add("listening");
      else if (state.connected) dot.classList.add("connected");
      document.getElementById("side-title").textContent = connLabel();
      document.getElementById("side-detail").textContent = state.deviceName
        ? `${state.deviceName}${state.listening ? " \u6b63\u5728\u53d1\u9001\u8bed\u97f3" : " \u5df2\u8fde\u63a5"}`
        : "\u7b49\u5f85 iPhone \u63a5\u5165";

      const connBadge = document.getElementById("home-badge-conn");
      connBadge.className = "stat-badge";
      if (state.listening) connBadge.classList.add("listening");
      else if (state.connected) connBadge.classList.add("connected");
      else connBadge.classList.add("disconnected");
      document.getElementById("home-conn-label").textContent = connLabel();

      document.getElementById("home-summary").textContent = summary();
      document.getElementById("home-status").textContent = connLabel();
      document.getElementById("home-device").textContent = pairedName() || "\u6682\u65e0";
      document.getElementById("home-network").textContent = state.pairingIp ? `${state.pairingIp}:${state.pairingPort || "-"}` : "\u5f85\u52a0\u8f7d";

      const btn = document.getElementById("btn-toggle-service");
      btn.textContent = state.serviceRunning ? "\u505c\u6b62\u670d\u52a1" : "\u542f\u52a8\u670d\u52a1";
      btn.classList.toggle("danger", state.serviceRunning);
      btn.classList.toggle("primary", !state.serviceRunning);
    }

    function renderRecordsCount() {
      document.getElementById("home-records-count").textContent = `记录: ${state.history.length}`;
      const recordsTotal = document.getElementById("records-total-count");
      if (recordsTotal) recordsTotal.textContent = `共 ${state.history.length} 条`;
    }

    function createItem(title, detail, meta, action) {
      const el = document.createElement("div");
      el.className = "item";
      const main = document.createElement("div");
      main.className = "item-main";
      main.innerHTML = `<div class="item-title">${escHtml(title)}</div><div class="item-detail">${escHtml(detail)}</div>`;
      const side = document.createElement("div");
      side.className = "item-meta";
      side.textContent = meta || "";
      if (action) { side.appendChild(document.createElement("br")); side.appendChild(action); }
      el.append(main, side);
      return el;
    }

    function renderList(container, items, emptyText, builder) {
      container.innerHTML = "";
      if (!items.length) { container.innerHTML = `<div class="empty">${escHtml(emptyText)}</div>`; return; }
      items.forEach(x => container.appendChild(builder(x)));
    }

    /* ===== Activity with category/severity ===== */
    function addActivity(title, detail, category, severity) {
      category = category || "info";
      severity = severity || "info";
      const sig = `${category}::${title}::${detail}`;
      if (state.activity[0] && state.activity[0].sig === sig) return;
      state.activity.unshift({
        sig, title, detail, category, severity,
        time: new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", second: "2-digit" })
      });
      state.activity = state.activity.slice(0, 50);
      renderActivity();
    }

    function renderActivity() {
      let items = state.activity;
      if (state.dataFilter !== "all") {
        items = items.filter(a => a.category === state.dataFilter);
      }
      const q = document.getElementById("data-search").value.toLowerCase();
      if (q) items = items.filter(a => a.title.toLowerCase().includes(q) || a.detail.toLowerCase().includes(q));

      renderList(activityList, items, "\u6682\u65e0\u6d3b\u52a8\u8bb0\u5f55", x => {
        const el = createItem(x.title, x.detail, x.time);
        const sev = document.createElement("span");
        sev.className = `sev ${x.severity}`;
        sev.textContent = x.severity === "warning" ? "\u8b66\u544a" : x.severity === "error" ? "\u9519\u8bef" : "\u4fe1\u606f";
        el.querySelector(".item-meta").prepend(sev);
        return el;
      });
      renderDataSummary();
    }

    function renderDataSummary() {
      const all = state.activity;
      document.getElementById("data-total").textContent = `\u603b\u8ba1: ${all.length}`;
      document.getElementById("data-voice").textContent = `\u8bed\u97f3: ${all.filter(a => a.category === "voice").length}`;
      document.getElementById("data-pairing").textContent = `\u914d\u5bf9: ${all.filter(a => a.category === "pairing" || a.category === "connection").length}`;
      document.getElementById("data-errors").textContent = `\u9519\u8bef: ${all.filter(a => a.severity === "error").length}`;
    }

    /* ===== Records with date grouping + search ===== */
    function renderHistory() {
      let items = getFilteredHistoryItems();
      historyList.innerHTML = "";
      updateRecordsBatchToolbar();
      if (!items.length) {
        historyList.innerHTML = `<div class="empty">&#x6682;&#x65e0;&#x8bc6;&#x522b;&#x5386;&#x53f2;</div>`;
        return;
      }
      const today = new Date().toDateString();
      const yesterday = new Date(Date.now() - 86400000).toDateString();
      const groups = {};
      items.forEach(r => {
        const d = r.timestamp ? new Date(r.timestamp.replace(/-/g, "/")).toDateString() : today;
        const label = d === today ? "\u4eca\u5929" : d === yesterday ? "\u6628\u5929" : d;
        if (!groups[label]) groups[label] = [];
        groups[label].push(r);
      });
      Object.entries(groups).forEach(([label, records]) => {
        const group = document.createElement("div");
        group.className = "date-group";
        group.innerHTML = `<div class="date-label">${escHtml(label)}</div>`;
        const list = document.createElement("div");
        list.className = "list";
        records.forEach(r => {
          const src = r.source || "";
          const badge = src && src !== "asr" ? `<span class="source-badge ios">${escHtml(src)}</span>` : `<span class="source-badge local">Local</span>`;
          const el = document.createElement("div");
          const selected = state.selectedHistoryIds.includes(r.id);
          el.className = `item${state.recordsBatchMode ? " selectable" : ""}${selected ? " selected" : ""}`;
          const time = r.timestamp ? (r.timestamp.split(" ")[1] || r.timestamp) : "";
          if (state.recordsBatchMode) {
            const check = document.createElement("label");
            check.className = "item-check";
            const input = document.createElement("input");
            input.type = "checkbox";
            input.checked = selected;
            input.addEventListener("click", event => event.stopPropagation());
            input.addEventListener("change", () => toggleHistorySelection(r.id));
            check.appendChild(input);
            el.appendChild(check);
            el.addEventListener("click", () => toggleHistorySelection(r.id));
          }
          const main = document.createElement("div");
          main.className = "item-main";
          main.innerHTML = `<div class="item-title">${badge} ${escHtml(r.text || "(\u7a7a\u5185\u5bb9)")}</div>`;
          const meta = document.createElement("div");
          meta.className = "item-meta";
          meta.textContent = time;
          el.append(main, meta);
          list.appendChild(el);
        });
        group.appendChild(list);
        historyList.appendChild(group);
      });
      renderRecordsCount();
    }

    /* ===== Devices ===== */
    function renderDevices() {
      renderList(devicesList, state.devices, "\u6682\u65e0\u5df2\u914d\u5bf9\u8bbe\u5907", d => {
        const btn = document.createElement("button");
        btn.className = "btn secondary";
        btn.type = "button";
        btn.textContent = "\u79fb\u9664";
        btn.addEventListener("click", async () => {
          try {
            await invoke("remove_paired_device", { id: d.id });
            addActivity("\u8bbe\u5907\u5df2\u79fb\u9664", d.name, "pairing");
            await refreshDevices();
          } catch (e) { toast(`\u79fb\u9664\u8bbe\u5907\u5931\u8d25: ${e}`); }
        });
        return createItem(d.name || "\u672a\u547d\u540d\u8bbe\u5907", d.last_seen ? `\u6700\u540e\u5728\u7ebf: ${d.last_seen}` : `\u8bbe\u5907 ID: ${d.id}`, "", btn);
      });
    }

    /* ===== Tauri async ===== */
    async function refreshConnection() {
      if (!state.isTauri) return;
      try {
        const s = await invoke("get_connection_status");
        const next = Boolean(s && s.connected);
        const nextName = s && s.name ? s.name : null;
        const changed = state.connected !== next || state.deviceName !== nextName;
        state.connected = next;
        state.deviceName = nextName;
        state.deviceId = s && s.device_id ? s.device_id : null;
        if (changed) {
          addActivity(next ? "\u8fde\u63a5\u5df2\u5efa\u7acb" : "\u8bbe\u5907\u5df2\u65ad\u5f00", next ? `${nextName || "iPhone"} \u5df2\u8fde\u63a5` : "\u8bbe\u5907\u65ad\u5f00", "connection");
          if (next) refreshPairing();
        }
        renderStatus();
      } catch (e) { console.error("refreshConnection error:", e); }
    }

    async function refreshPairing() {
      if (!state.isTauri) return;
      try {
        const r = await invoke("start_pairing");
        if (!r || !r.success) { toast(r && r.message ? r.message : "\u751f\u6210\u914d\u5bf9\u7801\u5931\u8d25"); return; }
        state.pairingCode = r.pairing_code || "";
        state.pairingIp = r.ip || null;
        state.pairingPort = r.port || null;
        document.getElementById("pairing-code").textContent = state.pairingCode || "------";
        document.getElementById("pairing-meta").textContent = `IP: ${state.pairingIp || "\u672a\u77e5"}  \u7aef\u53e3: ${state.pairingPort || "-"}`;
        const qr = document.getElementById("qr-box");
        qr.innerHTML = "";
        if (r.qr_content) {
          const img = document.createElement("img");
          img.src = r.qr_content;
          img.alt = "Pairing QR";
          qr.appendChild(img);
        } else {
          qr.innerHTML = `<div class="empty">&#x4e8c;&#x7ef4;&#x7801;&#x5c1a;&#x672a;&#x751f;&#x6210;</div>`;
        }
        addActivity("\u914d\u5bf9\u7801\u5df2\u5237\u65b0", `\u9a8c\u8bc1\u7801: ${state.pairingCode}`, "pairing");
        renderStatus();
      } catch (e) { console.error("refreshPairing", e); toast(`\u751f\u6210\u914d\u5bf9\u7801\u5931\u8d25: ${e}`); }
    }

    async function refreshDevices() {
      if (!state.isTauri) return;
      try {
        const ds = await invoke("get_paired_devices");
        state.devices = Array.isArray(ds) ? ds : [];
        renderDevices();
        renderStatus();
      } catch (e) { console.error("refreshDevices", e); }
    }

    async function refreshHistory() {
      if (!state.isTauri) return;
      try {
        const h = await invoke("get_history");
        state.history = Array.isArray(h) ? h : [];
        renderHistory();
      } catch (e) { console.error("refreshHistory error:", e); }
    }

    async function loadSettings() {
      if (!state.isTauri) return;
      try {
        const s = await invoke("get_settings");
        state.settings = s || null;
        if (!s) return;
        const inj = (s.injection_method || "keyboard");
        document.querySelectorAll(`input[name="injection"]`).forEach(r => r.checked = r.value === inj);
        document.querySelectorAll("#lang-picker .seg").forEach(seg => seg.classList.toggle("active", seg.dataset.val === (s.language || "zh-CN")));
        document.getElementById("setting-port").value = s.server_port || 8765;
        if (s.asr) {
          document.getElementById("setting-asr-appid").value = s.asr.app_id || "";
          document.getElementById("setting-asr-accesskey").value = s.asr.access_key || "";
          const resourceIdEl = document.getElementById("setting-asr-resourceid");
          // Set value; if not in options, add a custom option
          const rid = s.asr.resource_id || "";
          if (rid && !resourceIdEl.querySelector(`option[value="${rid}"]`)) {
            const opt = document.createElement("option");
            opt.value = rid;
            opt.textContent = rid;
            resourceIdEl.prepend(opt);
          }
          resourceIdEl.value = rid;
          document.getElementById("setting-asr-language").value = s.asr.asr_language || "zh-CN";
        }
        const rd = s.history_retention_days || 30;
        document.querySelectorAll("#retention-picker .seg").forEach(seg => seg.classList.toggle("active", parseInt(seg.dataset.days) === rd));
        state.asrConfigured = isCloudConfigured(s);
        const cloudEl = document.getElementById("engine-status-cloud");
        if (state.asrConfigured) { cloudEl.textContent = "\u5df2\u914d\u7f6e"; cloudEl.className = "engine-status available"; }
        else { cloudEl.textContent = "\u672a\u914d\u7f6e"; cloudEl.className = "engine-status warning"; }
        try {
          const localOk = await invoke("check_local_asr");
          state.localAsrAvailable = Boolean(localOk);
          const localEl = document.getElementById("engine-status-local");
          if (localOk) { localEl.textContent = "\u53ef\u7528"; localEl.className = "engine-status available"; }
          else { localEl.textContent = "\u4e0d\u53ef\u7528"; localEl.className = "engine-status error"; }
        } catch(e) {}
        state.pendingEngine = s.asr_engine || "local";
        renderEngineSelection();
        if (!s.asr_engine || !isEngineSelectable(s.asr_engine)) {
          await selectAsrEngine(getPreferredEngine(), { silent: true });
        }
        if (s.theme) applyTheme(s.theme);
        // Load Qwen3 status
        await loadQwen3Status();
        await loadQwen3OnnxStatus();
      } catch (e) { console.error("loadSettings", e); }
    }

    async function saveSettings() {
      if (!state.isTauri) return;
      const inj = document.querySelector('input[name="injection"]:checked').value;
      const lang = document.querySelector("#lang-picker .seg.active").dataset.val;
      const next = {
        ...(state.settings || {}),
        language: lang,
        injection_method: inj,
        server_port: Number(document.getElementById("setting-port").value || 8765),
        hotkey: state.settings && state.settings.hotkey || "",
        bonjour: state.settings && state.settings.bonjour || { enabled: true },
        theme: localStorage.getItem("voicemind_theme") || "light",
        asr: {
          provider: state.settings && state.settings.asr ? state.settings.asr.provider || "" : "",
          app_id: state.settings && state.settings.asr ? state.settings.asr.app_id || "" : "",
          access_key: state.settings && state.settings.asr ? state.settings.asr.access_key || "" : "",
          access_key_secret: state.settings && state.settings.asr ? state.settings.asr.access_key_secret || "" : "",
          resource_id: state.settings && state.settings.asr ? state.settings.asr.resource_id || "" : "",
          asr_language: document.getElementById("setting-asr-language").value
        }
      };
      try {
        await invoke("save_settings", { settings: next });
        state.settings = next;
        addActivity("\u8bbe\u7f6e\u5df2\u4fdd\u5b58", "\u914d\u7f6e\u5df2\u5199\u5165", "settings");
        toast("\u8bbe\u7f6e\u5df2\u4fdd\u5b58");
      } catch (e) { toast(`\u4fdd\u5b58\u5931\u8d25: ${e}`); }
    }

    async function saveASR() {
      if (!state.isTauri) return;
      const config = {
        provider: "volcengine",
        app_id: document.getElementById("setting-asr-appid").value,
        access_key: document.getElementById("setting-asr-accesskey").value,
        access_key_secret: "",
        resource_id: document.getElementById("setting-asr-resourceid").value,
        asr_language: document.getElementById("setting-asr-language").value
      };
      try {
        await invoke("save_asr_config", { config });
        addActivity("ASR \u914d\u7f6e\u5df2\u4fdd\u5b58", `\u8bed\u8a00: ${config.asr_language}`, "settings");
        state.pendingEngine = "cloud";
        toast("ASR \u914d\u7f6e\u5df2\u4fdd\u5b58");
        await loadSettings();
        await selectAsrEngine("cloud", { silent: true });
        toast("ASR \u914d\u7f6e\u5df2\u4fdd\u5b58\uff0c\u5df2\u5207\u6362\u5230 Volcengine ASR");
        setAsrConfigExpanded(false);
      } catch (e) { toast(`ASR \u4fdd\u5b58\u5931\u8d25: ${e}`); }
    }

    /* ===== Qwen3 ASR ===== */
    async function loadQwen3Status() {
      if (!state.isTauri) return;
      try {
        const result = await invoke("check_qwen3_asr");
        state.qwen3BinaryAvailable = result.binary_available;
        if (result.models) {
          result.models.forEach(m => {
            state.qwen3Models[m.size] = { downloaded: m.downloaded };
          });
        }
        renderQwen3ModelCards();
        renderEngineSelection();
      } catch (e) {
        console.error("loadQwen3Status error:", e);
      }
    }

    function renderQwen3ModelCards() {
      const activeModel = state.settings && state.settings.qwen3_asr ? state.settings.qwen3_asr.model_size : "0.6b";
      ["0.6b", "1.7b"].forEach(size => {
        const model = state.qwen3Models[size];
        const statusEl = document.getElementById(`qwen3-status-${size}`);
        const btn = document.getElementById(`qwen3-btn-${size}`);
        const radio = document.getElementById(`qwen3-radio-${size}`);
        const card = document.querySelector(`.qwen3-model-card[data-model="${size}"]`);
        if (!statusEl || !btn) return;

        if (state.qwen3Downloading === size) {
          statusEl.textContent = "\u4e0b\u8f7d\u4e2d...";
          statusEl.className = "qwen3-model-status downloading";
          btn.textContent = "\u4e0b\u8f7d\u4e2d...";
          btn.disabled = true;
        } else if (model && model.downloaded) {
          statusEl.textContent = "\u5df2\u4e0b\u8f7d";
          statusEl.className = "qwen3-model-status downloaded";
          btn.textContent = "\u5220\u9664";
          btn.className = "btn danger qwen3-action-btn";
          btn.disabled = false;
        } else {
          statusEl.textContent = "\u672a\u4e0b\u8f7d";
          statusEl.className = "qwen3-model-status";
          btn.textContent = "\u4e0b\u8f7d";
          btn.className = "btn primary qwen3-action-btn";
          btn.disabled = false;
        }

        // Update radio button state
        if (radio) {
          radio.checked = (activeModel === size);
          radio.disabled = !(model && model.downloaded);
        }
        if (card) {
          card.classList.toggle("active", activeModel === size && model && model.downloaded);
        }
      });

      // Load language from settings
      if (state.settings && state.settings.qwen3_asr) {
        const langEl = document.getElementById("qwen3-language");
        if (langEl) langEl.value = state.settings.qwen3_asr.language || "auto";
      }
    }

    async function downloadQwen3Model(size) {
      if (!state.isTauri || state.qwen3Downloading) return;
      state.qwen3Downloading = size;
      renderQwen3ModelCards();

      try {
        await invoke("download_qwen3_model", { modelSize: size });
      } catch (e) {
        toast(`\u4e0b\u8f7d\u5931\u8d25: ${e}`);
        state.qwen3Downloading = null;
        renderQwen3ModelCards();
      }
    }

    async function deleteQwen3Model(size) {
      if (!state.isTauri) return;
      if (!confirm(`\u786e\u5b9a\u5220\u9664 Qwen3-ASR ${size} \u6a21\u578b\uff1f`)) return;

      try {
        await invoke("delete_qwen3_model", { modelSize: size });
        state.qwen3Models[size] = { downloaded: false };
        toast(`\u5df2\u5220\u9664 Qwen3-ASR ${size} \u6a21\u578b`);
        renderQwen3ModelCards();
        renderEngineSelection();
      } catch (e) {
        toast(`\u5220\u9664\u5931\u8d25: ${e}`);
      }
    }

    async function saveQwen3Config() {
      if (!state.isTauri) return;
      // Read active model from radio buttons
      const activeRadio = document.querySelector('input[name="qwen3-active-model"]:checked');
      const modelSize = activeRadio ? activeRadio.value : (state.settings && state.settings.qwen3_asr ? state.settings.qwen3_asr.model_size : "0.6b");
      const config = {
        model_size: modelSize,
        language: document.getElementById("qwen3-language").value,
      };
      try {
        await invoke("save_qwen3_asr_config", { config });
        toast("Qwen3 \u914d\u7f6e\u5df2\u4fdd\u5b58");
        await loadSettings();
        await selectAsrEngine("qwen3_local");
        setQwen3ConfigExpanded(false);
      } catch (e) {
        toast(`\u4fdd\u5b58\u5931\u8d25: ${e}`);
      }
    }

    // Qwen3 model action buttons
    ["0.6b", "1.7b"].forEach(size => {
      const btn = document.getElementById(`qwen3-btn-${size}`);
      if (btn) {
        btn.addEventListener("click", event => {
          event.stopPropagation();
          const model = state.qwen3Models[size];
          if (model && model.downloaded) {
            deleteQwen3Model(size);
          } else {
            downloadQwen3Model(size);
          }
        });
      }
    });

    // Download Qwen3 binary button
    if (btnDownloadQwen3Binary) {
      btnDownloadQwen3Binary.addEventListener("click", async event => {
        event.stopPropagation();
        if (state.qwen3BinaryDownloading) return;
        state.qwen3BinaryDownloading = true;
        updateSpeechEngineActions();
        try {
          await invoke("download_qwen3_binary");
        } catch (e) {
          toast(`下载引擎失败: ${e}`);
          state.qwen3BinaryDownloading = false;
          updateSpeechEngineActions();
        }
      });
    }

    const saveQwen3ConfigBtn = document.getElementById("save-qwen3-config");
    if (saveQwen3ConfigBtn) {
      saveQwen3ConfigBtn.addEventListener("click", saveQwen3Config);
    }


    async function toggleService() {
      if (!state.isTauri) return;
      try {
        if (state.serviceRunning) {
          await invoke("stop_service");
          state.serviceRunning = false;
          state.connected = false;
          state.listening = false;
          addActivity("\u670d\u52a1\u5df2\u505c\u6b62", "\u672c\u5730\u670d\u52a1\u5df2\u5173\u95ed", "connection");
          toast("\u670d\u52a1\u5df2\u505c\u6b62");
        } else {
          const r = await invoke("start_service");
          state.serviceRunning = true;
          addActivity("\u670d\u52a1\u5df2\u542f\u52a8", `\u7aef\u53e3: ${r && r.port || "-"}`, "connection");
          toast("\u670d\u52a1\u5df2\u542f\u52a8");
        }
        renderStatus();
      } catch (e) { toast(`\u670d\u52a1\u64cd\u4f5c\u5931\u8d25: ${e}`); }
    }

    // Engine row click handler
    engineRows.forEach(row => {
      row.addEventListener("click", async () => {
        const engine = row.dataset.engine;
        state.pendingEngine = engine;
        if (engine === "cloud" && !state.asrConfigured) {
          setAsrConfigExpanded(true);
          renderEngineSelection();
          return;
        }
        if (engine === "local" && state.localAsrAvailable === false) {
          renderEngineSelection();
          toast("Windows \u672c\u5730\u8bed\u97f3\u8bc6\u522b\u5f53\u524d\u4e0d\u53ef\u7528");
          return;
        }
        if (engine === "qwen3_local") {
          if (!state.qwen3BinaryAvailable) {
            renderEngineSelection();
            // Show hint about downloading binary
            updateEngineHint("Qwen3-ASR 引擎未安装，请点击「下载引擎」按钮下载。");
            return;
          }
          if (!isEngineSelectable("qwen3_local")) {
            setQwen3ConfigExpanded(true);
            renderEngineSelection();
            return;
          }
          setAsrConfigExpanded(false);
          setQwen3ConfigExpanded(false);
          await selectAsrEngine(engine);
          return;
        }
        setAsrConfigExpanded(false);
        setQwen3ConfigExpanded(false);
        await selectAsrEngine(engine);
      });
    });
    function toast(message) {

      const old = document.querySelector(".toast");
      if (old) old.remove();
      const el = document.createElement("div");
      el.className = "toast";
      el.textContent = message;
      document.body.appendChild(el);
      setTimeout(() => el.remove(), 2800);
    }

    /* ===== App update ===== */
    async function installUpdate() {
      if (!state.updateInfo || state.updateInstalling) return;
      state.updateInstalling = true;
      state.updateProgress = null;
      renderUpdateResult("installing");

      try {
        await state.updateInfo.downloadAndInstall(event => {
          if (event.event === "Started") {
            state.updateProgress = { downloaded: 0, total: event.data.contentLength || 0 };
          } else if (event.event === "Progress") {
            const current = state.updateProgress || { downloaded: 0, total: 0 };
            current.downloaded += event.data.chunkLength;
            state.updateProgress = current;
            renderUpdateResult("installing");
          } else if (event.event === "Finished") {
            state.updateProgress = { ...(state.updateProgress || { downloaded: 0, total: 0 }), finished: true };
            renderUpdateResult("installing");
          }
        });

        renderUpdateResult("installed");
        toast("\u66f4\u65b0\u5df2\u4e0b\u8f7d\u5b89\u88c5\uff0c\u6b63\u5728\u91cd\u542f\u5e94\u7528");
        setTimeout(() => {
          relaunch().catch(error => {
            console.error("relaunch failed:", error);
            toast("\u66f4\u65b0\u5df2\u5b89\u88c5\uff0c\u8bf7\u624b\u52a8\u91cd\u542f\u5e94\u7528");
          });
        }, 1200);
      } catch (e) {
        console.error("installUpdate error:", e);
        renderUpdateResult("error", e.message || String(e));
      } finally {
        state.updateInstalling = false;
      }
    }

    async function checkUpdate({ silent = false } = {}) {
      if (state.updateChecking || state.updateInstalling) return;
      state.updateChecking = true;
      renderUpdateResult("checking");

      try {
        const update = await checkForAppUpdate({ timeout: 15000 });
        state.updateInfo = update;
        state.updateProgress = null;

        if (update) {
          renderUpdateResult("available");
        } else {
          renderUpdateResult("up-to-date");
        }
      } catch (e) {
        console.error("checkUpdate error:", e);
        if (silent) {
          renderUpdateResult("idle");
        } else {
          renderUpdateResult("error", e.message || String(e));
        }
      } finally {
        state.updateChecking = false;
      }
    }

    function formatDownloadProgress() {
      if (!state.updateProgress) return "";
      const downloaded = state.updateProgress.downloaded || 0;
      const total = state.updateProgress.total || 0;
      if (!total) return "\u6b63\u5728\u4e0b\u8f7d\u66f4\u65b0\u5305...";
      const percent = Math.max(0, Math.min(100, Math.round(downloaded / total * 100)));
      return `\u4e0b\u8f7d\u8fdb\u5ea6 ${percent}% (${Math.round(downloaded / 1024)} KB / ${Math.round(total / 1024)} KB)`;
    }

    function renderUpdateResult(status, detail = "") {
      if (!updateResult) return;

      if (status === "idle") {
        updateResult.hidden = true;
        updateResult.innerHTML = "";
        return;
      }

      updateResult.hidden = false;

      if (status === "checking") {
        updateResult.innerHTML = `<div class="update-status checking">\u6b63\u5728\u68c0\u67e5\u66f4\u65b0...</div>`;
        return;
      }

      if (status === "up-to-date") {
        updateResult.innerHTML = `<div class="update-status up-to-date">&#10003; \u5f53\u524d\u5df2\u662f\u6700\u65b0\u7248\u672c (v${escHtml(state.currentVersion || "-")})</div>`;
        return;
      }

      if (status === "error") {
        updateResult.innerHTML = `<div class="update-status error">\u66f4\u65b0\u68c0\u67e5\u5931\u8d25${detail ? `: ${escHtml(detail)}` : ""}</div>`;
        return;
      }

      if (status === "available") {
        const info = state.updateInfo;
        updateResult.innerHTML = `
          <div class="update-card">
            <h4>\u53d1\u73b0\u65b0\u7248\u672c v${escHtml(info.version)}</h4>
            <p>\u5f53\u524d\u7248\u672c v${escHtml(info.currentVersion)} \u53ef\u5347\u7ea7\u81f3 v${escHtml(info.version)}${info.date ? `\n\u53d1\u5e03\u65f6\u95f4: ${escHtml(info.date)}` : ""}</p>
            ${info.body ? `<p>${escHtml(info.body)}</p>` : ""}
            <div class="toolbar" style="margin-top:0">
              <button class="btn primary" type="button" id="btn-install-update">\u4e0b\u8f7d\u5e76\u5b89\u88c5</button>
              <a href="${RELEASES_URL}" target="_blank" rel="noopener" style="font-size:13px;color:var(--accent)">\u67e5\u770b Releases</a>
            </div>
          </div>`;
        const installButton = document.getElementById("btn-install-update");
        if (installButton) installButton.addEventListener("click", installUpdate);
        return;
      }

      if (status === "installing") {
        updateResult.innerHTML = `
          <div class="update-card">
            <h4>\u6b63\u5728\u5b89\u88c5\u66f4\u65b0</h4>
            <p>${escHtml(formatDownloadProgress())}</p>
            <div class="update-status checking">\u8bf7\u4fdd\u6301\u5e94\u7528\u8fd0\u884c\uff0c\u5b89\u88c5\u5b8c\u6210\u540e\u5c06\u81ea\u52a8\u91cd\u542f\u3002</div>
          </div>`;
        return;
      }

      if (status === "installed") {
        updateResult.innerHTML = `<div class="update-status up-to-date">\u66f4\u65b0\u5df2\u5b89\u88c5\uff0c\u6b63\u5728\u91cd\u542f...</div>`;
      }
    }

    if (btnOpenReleases) {
      btnOpenReleases.addEventListener("click", () => window.open(RELEASES_URL, "_blank", "noopener"));
    }

    if (btnUserGuide) {
      btnUserGuide.addEventListener("click", () => toast("\u4f7f\u7528\u6307\u5357\u529f\u80fd\u5f00\u53d1\u4e2d"));
    }

    if (btnCheckUpdate) {
      btnCheckUpdate.addEventListener("click", () => checkUpdate());
    }
/* ===== Event bindings ===== */
    document.getElementById("btn-toggle-service").addEventListener("click", toggleService);
    document.getElementById("btn-pairing").addEventListener("click", refreshPairing);
    document.getElementById("btn-refresh-devices").addEventListener("click", refreshDevices);
    document.getElementById("refresh-history").addEventListener("click", refreshHistory);
    document.getElementById("toggle-records-batch").addEventListener("click", () => {
      setRecordsBatchMode(!state.recordsBatchMode);
    });
    document.getElementById("cancel-records-batch").addEventListener("click", () => setRecordsBatchMode(false));
    document.getElementById("select-all-records").addEventListener("click", selectAllVisibleHistory);
    document.getElementById("copy-selected-records").addEventListener("click", copySelectedHistory);
    document.getElementById("delete-selected-records").addEventListener("click", deleteSelectedHistory);
    document.getElementById("clear-history").addEventListener("click", async () => {
      if (!state.isTauri) return;
      try {
        await invoke("clear_history");
        state.history = [];
        state.selectedHistoryIds = [];
        state.recordsBatchMode = false;
        renderHistory();
        addActivity("\u5386\u53f2\u5df2\u6e05\u7a7a", "\u8bc6\u522b\u8bb0\u5f55\u5df2\u5220\u9664", "records");
      } catch (e) {
        toast(`\u6e05\u7a7a\u5931\u8d25: ${e}`);
      }
    });
    const saveSettingsPrimaryButton = document.getElementById("save-settings");
    if (saveSettingsPrimaryButton) saveSettingsPrimaryButton.addEventListener("click", saveSettings);
    document.getElementById("save-asr").addEventListener("click", saveASR);
    document.getElementById("test-asr-connection").addEventListener("click", async () => {
      if (!state.isTauri) { toast("仅桌面端可用"); return; }
      toast("正在测试 ASR 连接...");
      try {
        const result = await invoke("test_asr_connection");
        toast(`ASR 连接测试: ${result}`);
      } catch (e) {
        toast(`ASR 连接失败: ${e}`);
      }
    });
    document.getElementById("reload-settings").addEventListener("click", loadSettings);
    if (cloudEngineStatus) {
      cloudEngineStatus.addEventListener("click", event => {
        event.stopPropagation();
        state.pendingEngine = "cloud";
        setAsrConfigExpanded(true);
        updateSpeechEngineActions();
      });
    }
    if (qwen3EngineStatus) {
      qwen3EngineStatus.addEventListener("click", event => {
        event.stopPropagation();
        state.pendingEngine = "qwen3_local";
        setQwen3ConfigExpanded(true);
        updateSpeechEngineActions();
        loadQwen3Status();
      });
    }
    if (speechConfigCancel) {
      speechConfigCancel.addEventListener("click", () => {
        setAsrConfigExpanded(false);
        updateSpeechEngineActions();
      });
    }
    if (qwen3ConfigCancel) {
      qwen3ConfigCancel.addEventListener("click", () => {
        setQwen3ConfigExpanded(false);
        updateSpeechEngineActions();
      });
    }
    document.addEventListener("keydown", event => {
      if (event.key === "Escape" && (state.asrConfigExpanded || state.qwen3ConfigExpanded)) {
        setAsrConfigExpanded(false);
        setQwen3ConfigExpanded(false);
        updateSpeechEngineActions();
      }
    });
    document.getElementById("save-settings-secondary").addEventListener("click", saveSettings);
    document.getElementById("reload-settings-secondary").addEventListener("click", loadSettings);
    document.getElementById("clear-activity").addEventListener("click", () => { state.activity = []; renderActivity(); });

    document.getElementById("records-search").addEventListener("input", e => { state.recordsSearch = e.target.value; renderHistory(); });
    document.querySelectorAll("#retention-picker .seg").forEach(seg => {
      seg.addEventListener("click", async () => {
        const days = parseInt(seg.dataset.days);
        document.querySelectorAll("#retention-picker .seg").forEach(s => s.classList.remove("active"));
        seg.classList.add("active");
        if (state.isTauri) {
          try {
            await invoke("set_history_retention", { days });
            toast(`\u4fdd\u5b58\u65f6\u95f4\u5df2\u8bbe\u4e3a ${days} \u5929`);
            await refreshHistory();
          } catch (e) {
            toast(`\u8bbe\u7f6e\u5931\u8d25: ${e}`);
          }
        }
      });
    });
    document.getElementById("data-search").addEventListener("input", () => renderActivity());

    document.getElementById("btn-check-perm").addEventListener("click", async () => {
      if (!state.isTauri) { toast("\u5df2\u6388\u6743\uff08\u9884\u89c8\u6a21\u5f0f\uff09"); return; }
      try {
        const s = await invoke("get_accessibility_status");
        toast(`\u6743\u9650\u72b6\u6001: ${s}`);
      } catch (e) {
        toast(`\u68c0\u67e5\u5931\u8d25: ${e}`);
      }
    });
    document.getElementById("btn-open-settings").addEventListener("click", async () => {
      if (!state.isTauri) { toast("\u4ec5\u684c\u9762\u7aef\u53ef\u7528"); return; }
      try {
        await invoke("open_accessibility_settings");
      } catch (e) {
        toast(`\u6253\u5f00\u5931\u8d25: ${e}`);
      }
    });

    /* ===== Tauri events ===== */
    const unlisteners = [];
    async function bindEvents() {
      const listen = listenApi();
      if (!listen) return;
      unlisteners.push(await listen("connection-changed", async event => {
        const p = event.payload || {};
        console.log("connection-changed event received:", p);
        const next = Boolean(p.connected);
        const nextName = p.device_name || p.name || null;
        const changed = state.connected !== next || state.deviceName !== nextName;
        state.connected = next;
        state.deviceName = nextName;
        state.deviceId = p.device_id || p.deviceId || null;
        if (!next) state.listening = false;
        if (changed) addActivity(next ? "\u8fde\u63a5\u5df2\u5efa\u7acb" : "\u8bbe\u5907\u5df2\u65ad\u5f00", next ? `${nextName || "iPhone"} \u5df2\u8fde\u63a5` : "\u8bbe\u5907\u65ad\u5f00", "connection");
        renderStatus();
        await Promise.all([refreshConnection(), refreshDevices()]);
      }));
      unlisteners.push(await listen("listening-started", event => {
        state.listening = true;
        renderStatus();
        addActivity("监听已开始", `${(event.payload || {}).device_name || state.deviceName || "iPhone"}`, "voice");
        // Show recognition bar
        const bar = document.getElementById("recognition-bar");
        const text = document.getElementById("recognition-text");
        if (bar && text) { text.textContent = "正在识别..."; bar.hidden = false; }
      }));
      unlisteners.push(await listen("listening-stopped", event => {
        state.listening = false;
        renderStatus();
        addActivity("监听已停止", `会话 ${(event.payload || {}).session_id || "-"}`, "voice");
        // Hide recognition bar if no result arrives within 3s (ASR may fail)
        const bar = document.getElementById("recognition-bar");
        if (bar && !bar.hidden) {
          setTimeout(() => { if (bar) bar.hidden = true; }, 3000);
        }
      }));
      unlisteners.push(await listen("recognition-result", async event => {
        const p = event.payload || {};
        state.noteText = p.text || "";
        renderStatus();
        addActivity("识别结果", p.text || "(空)", "voice");
        // Show final text on bar, then hide after injection
        const bar = document.getElementById("recognition-bar");
        const text = document.getElementById("recognition-text");
        if (bar && text && p.text) { text.textContent = p.text; }
        setTimeout(() => { if (bar) bar.hidden = true; }, 1500);
        await refreshHistory();
      }));
      unlisteners.push(await listen("partial-result", event => {
        const p = event.payload || {};
        if (p.text) {
          state.noteText = p.text;
          renderStatus();
          const text = document.getElementById("recognition-text");
          if (text) text.textContent = p.text;
        }
      }));
      unlisteners.push(await listen("error", event => {
        const p = event.payload || {};
        console.error("Backend error:", p);
        addActivity("\u274c \u9519\u8bef", p.message || "\u672a\u77e5\u9519\u8bef", "connection");
        toast(p.message || "\u53d1\u751f\u9519\u8bef");
        // Hide recognition bar on error
        state.listening = false;
        renderStatus();
        const bar = document.getElementById("recognition-bar");
        if (bar) bar.hidden = true;
      }));
      unlisteners.push(await listen("qwen3-download-progress", event => {
        const p = event.payload || {};
        if (!p.model_size) return;

        const progressBar = document.getElementById(`qwen3-progress-${p.model_size}`);
        const progressText = document.getElementById(`qwen3-progress-text-${p.model_size}`);
        const progressFill = progressBar ? progressBar.querySelector(".qwen3-progress-fill") : null;

        if (p.status === "downloading") {
          if (progressBar) progressBar.hidden = false;
          if (progressText) progressText.hidden = false;
          if (progressFill) progressFill.style.width = `${Math.round(p.progress * 100)}%`;
          if (progressText) {
            const percent = Math.round(p.progress * 100);
            const currentFile = p.current_file || "";
            const shortFile = currentFile.length > 30 ? "..." + currentFile.slice(-27) : currentFile;
            progressText.textContent = `${percent}% - ${shortFile}`;
          }
        } else if (p.status === "completed") {
          if (progressBar) progressBar.hidden = true;
          if (progressText) progressText.hidden = true;
          if (progressFill) progressFill.style.width = "100%";
          state.qwen3Models[p.model_size] = { downloaded: true };
          state.qwen3Downloading = null;
          toast(`Qwen3-ASR ${p.model_size} \u6a21\u578b\u4e0b\u8f7d\u5b8c\u6210`);
          renderQwen3ModelCards();
          renderEngineSelection();
        } else if (p.status === "failed") {
          state.qwen3Downloading = null;
          renderQwen3ModelCards();
        }
      }));
      unlisteners.push(await listen("qwen3-binary-download-progress", async event => {
        const p = event.payload || {};
        if (p.status === "completed") {
          state.qwen3BinaryAvailable = true;
          state.qwen3BinaryDownloading = false;
          toast("Qwen3-ASR 引擎下载完成");
          updateSpeechEngineActions();
          renderEngineSelection();
        } else if (p.status === "extracting") {
          if (btnDownloadQwen3Binary) {
            btnDownloadQwen3Binary.textContent = "正在解压...";
          }
        } else if (p.status === "downloading") {
          state.qwen3BinaryDownloading = true;
          if (btnDownloadQwen3Binary) {
            const pct = Math.round((p.progress || 0) * 100);
            btnDownloadQwen3Binary.textContent = `下载中 ${pct}%`;
          }
        }
      }));
    }

    /* ===== Init ===== */
    async function init() {
      renderStatus(); renderHistory(); renderDevices(); renderActivity();
      // Check Tauri via invoke availability
      const hasInvoke = window.__TAURI__ && window.__TAURI__.core && typeof window.__TAURI__.core.invoke === "function";
      console.log("init: Tauri available:", !!window.__TAURI__, "hasInvoke:", hasInvoke);
      if (!hasInvoke) { console.warn("Tauri not available, running in preview mode"); return; }
      state.isTauri = true;

      // Primary: polling sync every 2 seconds (always works, no event dependency)
      async function syncStatus() {
        try { state.serviceRunning = await invoke("get_service_status"); } catch(e) {}
        await Promise.all([refreshConnection(), refreshDevices()]).catch(e => console.error("syncStatus", e));
        renderStatus();
      }
      // Initial load
      await syncStatus();
      await Promise.all([refreshPairing(), refreshHistory(), loadSettings()]);

      // Load app version
      try {
        state.currentVersion = await invoke("get_version");
        const verEl = document.getElementById("about-version");
        if (verEl) verEl.textContent = `Version ${state.currentVersion}`;
      } catch (e) { console.warn("get_version failed:", e); }

      // Auto check update after startup; keep failures silent until user checks manually.
      setTimeout(() => checkUpdate({ silent: true }), 3000);

      console.log("init: initial load done, connected:", state.connected);
      // Start polling
      setInterval(syncStatus, 2000);

      // Secondary: try event listeners for real-time updates (optional)
      try { await bindEvents(); console.log("init: event listeners registered"); }
      catch (e) { console.warn("init: event listeners failed, polling only:", e); }
    }
    init();

