import { state } from "./state.js";

export const pairedName = () => state.deviceName || (state.devices[0] && state.devices[0].name) || null;

export const connLabel = () =>
  !state.serviceRunning
    ? "\u670d\u52a1\u5df2\u505c\u6b62"
    : state.listening
      ? "\u76d1\u542c\u4e2d"
      : state.connected
        ? "\u5df2\u8fde\u63a5"
        : "\u672a\u8fde\u63a5";

export function summary() {
  if (state.deviceName) {
    return `${state.deviceName} \u5df2\u5b8c\u6210\u914d\u5bf9\uff0c\u5f53\u524d${state.listening ? "\u6b63\u5728\u4f20\u8f93\u8bed\u97f3" : "\u5904\u4e8e\u53ef\u7528\u8fde\u63a5\u72b6\u6001"}\u3002`;
  }
  if (pairedName()) {
    return `${pairedName()} \u5df2\u5b8c\u6210\u914d\u5bf9\uff0c\u5f53\u524d\u672a\u8fde\u63a5\u3002`;
  }
  return "\u5c1a\u672a\u914d\u5bf9\u8bbe\u5907\u3002\u8bf7\u5237\u65b0\u4e8c\u7ef4\u7801\uff0c\u7528 iPhone \u626b\u7801\u5efa\u7acb\u8fde\u63a5\u3002";
}

export function escHtml(value) {
  const div = document.createElement("div");
  div.textContent = value;
  return div.innerHTML;
}
