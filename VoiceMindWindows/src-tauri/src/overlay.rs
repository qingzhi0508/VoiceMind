#[cfg(windows)]
use windows::Win32::Foundation::COLORREF;
#[cfg(windows)]
use windows::Win32::UI::WindowsAndMessaging::{
    GetWindowLongPtrW, SetLayeredWindowAttributes, SetWindowLongPtrW, SetWindowPos,
    GWL_EXSTYLE, HWND_TOPMOST, LWA_ALPHA, SWP_FRAMECHANGED, SWP_NOMOVE, SWP_NOSIZE,
    SWP_NOOWNERZORDER, SWP_NOACTIVATE, WS_EX_APPWINDOW,
    WS_EX_LAYERED, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW, WS_EX_TRANSPARENT,
};

pub fn show_native_overlay<R: tauri::Runtime>(window: &tauri::WebviewWindow<R>) {
    let _ = window.set_focusable(false);
    let _ = window.set_ignore_cursor_events(true);
    apply_native_overlay_style(window);
    let _ = window.show();
}

pub fn hide_native_overlay<R: tauri::Runtime>(window: &tauri::WebviewWindow<R>) {
    let _ = window.eval("window.__overlayPrepareHide && window.__overlayPrepareHide();");
    let window = window.clone();
    std::thread::spawn(move || {
        std::thread::sleep(std::time::Duration::from_millis(95));
        let _ = window.hide();
    });
}

#[cfg(windows)]
pub fn apply_native_overlay_style<R: tauri::Runtime>(window: &tauri::WebviewWindow<R>) {
    let Ok(hwnd) = window.hwnd() else {
        return;
    };

    unsafe {
        let mut ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
        ex_style |= WS_EX_TOOLWINDOW.0 as isize;
        ex_style |= WS_EX_NOACTIVATE.0 as isize;
        ex_style |= WS_EX_LAYERED.0 as isize;
        ex_style |= WS_EX_TRANSPARENT.0 as isize;
        ex_style &= !(WS_EX_APPWINDOW.0 as isize);
        let _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE, ex_style);
        let _ = SetLayeredWindowAttributes(hwnd, COLORREF(0), 255, LWA_ALPHA);
        let _ = SetWindowPos(
            hwnd,
            Some(HWND_TOPMOST),
            0,
            0,
            0,
            0,
            SWP_NOMOVE
                | SWP_NOSIZE
                | SWP_NOACTIVATE
                | SWP_FRAMECHANGED
                | SWP_NOOWNERZORDER,
        );
    }
}

#[cfg(not(windows))]
pub fn apply_native_overlay_style<R: tauri::Runtime>(_window: &tauri::WebviewWindow<R>) {}
