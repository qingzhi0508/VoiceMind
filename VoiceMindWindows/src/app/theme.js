export function applyTheme(theme) {
  if (theme === "system") {
    const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
  } else {
    document.documentElement.setAttribute("data-theme", theme);
  }
  localStorage.setItem("voicemind_theme", theme);
  document.querySelectorAll("#theme-picker .seg").forEach(seg => seg.classList.toggle("active", seg.dataset.val === theme));
}
