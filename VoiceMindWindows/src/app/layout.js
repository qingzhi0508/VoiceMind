import { state } from "./state.js";
import { pages, navItems } from "./dom.js";
import { applyTheme } from "./theme.js";

export function initSpeechAsrLayout() {
  const settingsPage = document.getElementById("settings");
  if (!settingsPage) return;

  if (!document.getElementById("settings-actions")) {
    const toolbar = document.createElement("div");
    toolbar.className = "toolbar";
    toolbar.id = "settings-actions";
    toolbar.innerHTML = [
      '<button id="save-settings-secondary" class="btn primary" type="button">&#x4fdd;&#x5b58;&#x8bbe;&#x7f6e;</button>',
      '<button id="reload-settings-secondary" class="btn secondary" type="button">&#x91cd;&#x65b0;&#x52a0;&#x8f7d;</button>',
    ].join("");
    settingsPage.appendChild(toolbar);
  }
}

export function showPage(id, { onRecordsPage } = {}) {
  state.page = id;
  pages.forEach(page => page.classList.toggle("active", page.id === id));
  navItems.forEach(item => item.classList.toggle("active", item.dataset.page === id));
  // Close any open modal when navigating away
  const modal = document.getElementById("speech-asr-modal");
  if (modal && !modal.hidden) {
    modal.hidden = true;
    document.body.classList.remove("modal-open");
    state.asrConfigExpanded = false;
  }
  if (id === "records" && onRecordsPage) onRecordsPage();
}

export function bindNavigation(options = {}) {
  navItems.forEach(item => item.addEventListener("click", () => showPage(item.dataset.page, options)));
}

export function bindSegmentedPickers({ onDataFilterChange } = {}) {
  document.querySelectorAll(".seg-picker").forEach(picker => {
    picker.querySelectorAll(".seg").forEach(seg => {
      seg.addEventListener("click", () => {
        picker.querySelectorAll(".seg").forEach(button => button.classList.remove("active"));
        seg.classList.add("active");
        if (picker.id === "theme-picker") applyTheme(seg.dataset.val);
        if (picker.id === "data-filter" && onDataFilterChange) onDataFilterChange(seg.dataset.filter);
      });
    });
  });
}
