import { invoke, listenApi } from "./tauri.js";

const shell = document.getElementById("overlay-shell");
const overlayText = document.getElementById("overlay-text");

let pollTimer = null;

function setState(mode) {
  shell.className = `overlay-shell ${mode}`;
}

function setText(text) {
  if (!overlayText) return;
  overlayText.textContent = text || "正在识别...";
}

function applyOverlayPayload(payload = {}) {
  setState(payload.mode || "state-listening");
  setText(payload.text || payload.title || "");
}

function prepareOverlayHide() {
  setState("state-closing");
}

async function syncOverlayWindow() {
  try {
    await invoke("sync_overlay_window");
  } catch (error) {
    console.error("Failed to sync overlay window:", error);
  }
}

function startPolling() {
  if (pollTimer) return;
  void syncOverlayWindow();
  pollTimer = window.setInterval(() => {
    void syncOverlayWindow();
  }, 80);
}

async function bindEvents() {
  const listen = listenApi();
  if (!listen) {
    startPolling();
    return;
  }

  await listen("overlay-state", event => {
    applyOverlayPayload(event.payload || {});
    void syncOverlayWindow();
  });

  startPolling();
}

window.__overlayUpdate = applyOverlayPayload;
window.__overlayPrepareHide = prepareOverlayHide;
setText("");
void bindEvents();
