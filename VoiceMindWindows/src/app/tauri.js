export const invoke = (cmd, payload) => {
  const api = window.__TAURI__ && window.__TAURI__.core && window.__TAURI__.core.invoke;
  return api ? api(cmd, payload) : Promise.reject(new Error("Tauri invoke unavailable"));
};

export const listenApi = () =>
  window.__TAURI__ && window.__TAURI__.event && typeof window.__TAURI__.event.listen === "function"
    ? window.__TAURI__.event.listen
    : window.__TAURI__ && window.__TAURI__.core && typeof window.__TAURI__.core.listen === "function"
      ? window.__TAURI__.core.listen
      : null;
