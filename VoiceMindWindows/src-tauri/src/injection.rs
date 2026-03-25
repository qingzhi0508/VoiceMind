#[cfg(windows)]
use windows::{
    Win32::UI::Input::KeyboardAndMouse::{
        SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT,
        KEYEVENTF_KEYUP, KEYEVENTF_UNICODE,
    },
    Win32::UI::WindowsAndMessaging::{
        GetForegroundWindow, SetForegroundWindow, GetWindowThreadProcessId,
    },
    Win32::System::Threading::{GetCurrentThreadId, AttachThreadInput},
    Win32::Foundation::HWND,
};

use tracing::info;

const CHUNK_SIZE: usize = 500;
const CHUNK_DELAY_MS: u64 = 10;

pub enum InjectionMethod {
    Keyboard,
    Clipboard,
}

pub struct TextInjector {
    method: InjectionMethod,
}

#[cfg(windows)]
#[derive(Clone, Copy)]
struct ForegroundWindowGuard {
    #[allow(dead_code)]
    hwnd: HWND,
}

#[cfg(windows)]
impl ForegroundWindowGuard {
    fn capture() -> Option<Self> {
        unsafe {
            let hwnd = GetForegroundWindow();
            if hwnd.0.is_null() {
                return None;
            }
            Some(Self { hwnd })
        }
    }

    fn restore(&self) {
        unsafe {
            let hwnd = self.hwnd;
            if !hwnd.0.is_null() {
                // Use AttachThreadInput to ensure we can set foreground window
                let target_tid = GetWindowThreadProcessId(hwnd, None);
                let current_tid = GetCurrentThreadId();

                if target_tid != current_tid {
                    let _ = AttachThreadInput(target_tid, current_tid, true);
                    let _ = SetForegroundWindow(hwnd);
                    let _ = AttachThreadInput(target_tid, current_tid, false);
                } else {
                    let _ = SetForegroundWindow(hwnd);
                }
            }
        }
    }
}

impl TextInjector {
    pub fn new(method: InjectionMethod) -> Self {
        Self { method }
    }

    pub fn inject(&self, text: &str) -> Result<(), String> {
        // Capture foreground window before injection
        let _guard = ForegroundWindowGuard::capture();

        match self.method {
            InjectionMethod::Keyboard => self.inject_keyboard(text),
            InjectionMethod::Clipboard => self.inject_clipboard(text),
        }
    }

    #[cfg(windows)]
    fn inject_keyboard(&self, text: &str) -> Result<(), String> {
        // Inject in chunks to avoid buffer overflow and allow processing
        let chars: Vec<char> = text.chars().collect();
        let total_chars = chars.len();
        let mut injected = 0;

        for chunk in chars.chunks(CHUNK_SIZE) {
            let mut inputs: Vec<INPUT> = Vec::with_capacity(chunk.len() * 2);

            for c in chunk {
                // Key down
                inputs.push(INPUT {
                    r#type: INPUT_KEYBOARD,
                    Anonymous: INPUT_0 {
                        ki: KEYBDINPUT {
                            wVk: windows::Win32::UI::Input::KeyboardAndMouse::VIRTUAL_KEY(0),
                            wScan: *c as u16,
                            dwFlags: KEYEVENTF_UNICODE,
                            time: 0,
                            dwExtraInfo: 0,
                        },
                    },
                });

                // Key up
                inputs.push(INPUT {
                    r#type: INPUT_KEYBOARD,
                    Anonymous: INPUT_0 {
                        ki: KEYBDINPUT {
                            wVk: windows::Win32::UI::Input::KeyboardAndMouse::VIRTUAL_KEY(0),
                            wScan: *c as u16,
                            dwFlags: KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                            time: 0,
                            dwExtraInfo: 0,
                        },
                    },
                });
            }

            unsafe {
                let result = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
                if result as u32 != inputs.len() as u32 {
                    return Err(format!("SendInput failed: {}", result));
                }
            }

            injected += chunk.len();

            // Small delay between chunks
            if injected < total_chars {
                std::thread::sleep(std::time::Duration::from_millis(CHUNK_DELAY_MS));
            }
        }

        info!("Injected {} characters via keyboard", total_chars);
        Ok(())
    }

    #[cfg(not(windows))]
    fn inject_keyboard(&self, text: &str) -> Result<(), String> {
        Err("Keyboard injection not supported on this platform".to_string())
    }

    fn inject_clipboard(&self, text: &str) -> Result<(), String> {
        // Save current clipboard content
        let previous = get_clipboard_text();

        // Set new clipboard content
        set_clipboard_text(text)?;

        // Small delay
        std::thread::sleep(std::time::Duration::from_millis(50));

        // Simulate Ctrl+V
        #[cfg(windows)]
        self.send_ctrl_v();

        // Restore previous clipboard after a delay
        let prev = previous;
        std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_secs(1));
            if let Some(text) = prev {
                set_clipboard_text(&text).ok();
            }
        });

        info!("Injected text via clipboard");
        Ok(())
    }

    #[cfg(windows)]
    fn send_ctrl_v(&self) {
        use windows::Win32::UI::Input::KeyboardAndMouse::{
            SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT,
            KEYEVENTF_KEYUP, VK_CONTROL, VIRTUAL_KEY, KEYBD_EVENT_FLAGS,
        };

        let ctrl_down = INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: VK_CONTROL,
                    wScan: 0,
                    dwFlags: KEYBD_EVENT_FLAGS(0),
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        let ctrl_up = INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: VK_CONTROL,
                    wScan: 0,
                    dwFlags: KEYEVENTF_KEYUP,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        let v_down = INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: VIRTUAL_KEY(0x56), // 'V' key
                    wScan: 0,
                    dwFlags: KEYBD_EVENT_FLAGS(0),
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        let v_up = INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: VIRTUAL_KEY(0x56),
                    wScan: 0,
                    dwFlags: KEYEVENTF_KEYUP,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        };

        let inputs = [ctrl_down, v_down, v_up, ctrl_up];

        unsafe {
            SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
        }
    }
}

#[cfg(windows)]
fn get_clipboard_text() -> Option<String> {
    use windows::Win32::Foundation::HGLOBAL;
    use windows::Win32::System::DataExchange::{OpenClipboard, GetClipboardData, CloseClipboard};
    use windows::Win32::System::Memory::{GlobalLock, GlobalUnlock};

    unsafe {
        if OpenClipboard(None).is_ok() {
            if let Ok(handle) = GetClipboardData(1) { // CF_TEXT
                if !handle.is_invalid() {
                    let hglobal = HGLOBAL(handle.0 as *mut _);
                    let ptr = GlobalLock(hglobal);
                    if !ptr.is_null() {
                        let text = std::ffi::CStr::from_ptr(ptr as *const i8)
                            .to_string_lossy()
                            .into_owned();
                        let _ = GlobalUnlock(hglobal);
                        CloseClipboard().ok();
                        return Some(text);
                    }
                }
            }
            CloseClipboard().ok();
        }
    }
    None
}

#[cfg(windows)]
fn set_clipboard_text(text: &str) -> Result<(), String> {
    use windows::Win32::Foundation::{HGLOBAL, HANDLE};
    use windows::Win32::System::DataExchange::{
        OpenClipboard, EmptyClipboard, SetClipboardData, CloseClipboard,
    };
    use windows::Win32::System::Memory::{GlobalAlloc, GMEM_MOVEABLE, GlobalLock, GlobalUnlock};

    unsafe {
        if OpenClipboard(None).is_err() {
            return Err("Failed to open clipboard".to_string());
        }

        EmptyClipboard().map_err(|e| format!("Failed to empty clipboard: {}", e))?;

        let wide: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
        let size = wide.len() * 2;

        let handle = GlobalAlloc(GMEM_MOVEABLE, size)
            .map_err(|e| format!("Failed to allocate global memory: {}", e))?;

        let hglobal = HGLOBAL(handle.0 as *mut _);
        let ptr = GlobalLock(hglobal);
        if ptr.is_null() {
            CloseClipboard().ok();
            return Err("Failed to lock memory".to_string());
        }

        std::ptr::copy_nonoverlapping(wide.as_ptr(), ptr as *mut u16, wide.len());
        let _ = GlobalUnlock(hglobal);

        // Convert HGLOBAL to HANDLE for SetClipboardData
        let handle_as_hwnd = HANDLE(handle.0);
        let _ = SetClipboardData(1, Some(handle_as_hwnd)); // CF_TEXT

        CloseClipboard().ok();
    }

    Ok(())
}
