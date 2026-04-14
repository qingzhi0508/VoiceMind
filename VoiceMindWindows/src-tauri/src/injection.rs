#[cfg(windows)]
use windows::{
    Win32::UI::Input::KeyboardAndMouse::{
        SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT,
        KEYEVENTF_KEYUP, KEYEVENTF_UNICODE,
    },
    Win32::UI::WindowsAndMessaging::{
        GetForegroundWindow, SetForegroundWindow, GetWindowThreadProcessId,
        GetWindowTextW, GetWindowThreadProcessId as GetWindowThreadProcessIdWin,
    },
    Win32::System::Threading::{GetCurrentThreadId, AttachThreadInput},
    Win32::Foundation::{HWND, MAX_PATH},
};

use tracing::{info, warn, error};

const CHUNK_SIZE: usize = 500;
const CHUNK_DELAY_MS: u64 = 10;
const MAX_RETRIES: u32 = 3;
const RETRY_DELAY_MS: u64 = 100;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum InjectionMethod {
    Auto,
    Keyboard,
    Clipboard,
}

impl Default for InjectionMethod {
    fn default() -> Self {
        InjectionMethod::Auto
    }
}

pub struct TextInjector {
    method: InjectionMethod,
}

#[cfg(windows)]
#[derive(Clone)]
struct ForegroundWindowGuard {
    hwnd: HWND,
    pid: u32,
}

#[cfg(windows)]
impl ForegroundWindowGuard {
    fn capture() -> Option<Self> {
        unsafe {
            let hwnd = GetForegroundWindow();
            if hwnd.0.is_null() {
                return None;
            }
            
            let mut pid: u32 = 0;
            GetWindowThreadProcessIdWin(hwnd, Some(&mut pid));
            
            Some(Self { hwnd, pid })
        }
    }

    fn restore(&self) {
        unsafe {
            if !self.hwnd.0.is_null() {
                let target_tid = GetWindowThreadProcessId(self.hwnd, None);
                let current_tid = GetCurrentThreadId();

                if target_tid != current_tid {
                    let _ = AttachThreadInput(target_tid, current_tid, true);
                    let _ = SetForegroundWindow(self.hwnd);
                    let _ = AttachThreadInput(target_tid, current_tid, false);
                } else {
                    let _ = SetForegroundWindow(self.hwnd);
                }
            }
        }
    }
    
    fn get_window_title(&self) -> String {
        unsafe {
            let mut buffer: [u16; MAX_PATH as usize] = [0; MAX_PATH as usize];
            let len = GetWindowTextW(self.hwnd, &mut buffer);
            String::from_utf16_lossy(&buffer[..len as usize])
        }
    }
    
    fn get_process_name(&self) -> String {
        format!("Process {}", self.pid)
    }
}

impl TextInjector {
    pub fn new(method: InjectionMethod) -> Self {
        Self { method }
    }

    pub fn inject(&self, text: &str) -> Result<(), String> {
        info!("Starting text injection, method: {:?}, text length: {}", self.method, text.len());
        
        let start_time = std::time::Instant::now();
        let window_info = Self::get_current_window_info();
        
        info!("Target window: {} (PID: {})", 
              window_info.as_ref().map(|w| w.0.as_str()).unwrap_or("unknown"),
              window_info.as_ref().map(|w| w.1).unwrap_or(0));
        
        let _guard = ForegroundWindowGuard::capture();
        
        let final_method = match self.method {
            InjectionMethod::Auto => self.detect_best_method(&window_info),
            method => method,
        };
        
        info!("Selected injection method: {:?}", final_method);
        
        let result = match final_method {
            InjectionMethod::Keyboard => self.inject_keyboard_with_retry(text),
            InjectionMethod::Clipboard => self.inject_clipboard_with_retry(text),
            InjectionMethod::Auto => {
                match self.inject_keyboard_with_retry(text) {
                    Ok(_) => Ok(()),
                    Err(e) => {
                        warn!("Keyboard injection failed: {}, trying clipboard", e);
                        self.inject_clipboard_with_retry(text)
                    }
                }
            }
        };
        
        let elapsed = start_time.elapsed();
        match &result {
            Ok(_) => info!("Text injection completed successfully in {:?}, method: {:?}", elapsed, final_method),
            Err(e) => error!("Text injection failed after {:?}: {}", elapsed, e),
        }
        
        result
    }
    
    fn get_current_window_info() -> Option<(String, u32)> {
        ForegroundWindowGuard::capture().map(|guard| {
            (guard.get_window_title(), guard.pid)
        })
    }
    
    fn detect_best_method(&self, window_info: &Option<(String, u32)>) -> InjectionMethod {
        if let Some((ref title, _pid)) = window_info {
            let title_lower = title.to_lowercase();
            
            if title_lower.contains("chrome")
                || title_lower.contains("edge")
                || title_lower.contains("firefox")
                || title_lower.contains("browser")
                || title_lower.contains("notepad++")
                || title_lower.contains("vscode")
                || title_lower.contains("code")
                // Terminals: KEYEVENTF_UNICODE often garbles CJK text
                || title_lower.contains("terminal")
                || title_lower.contains("cmd")
                || title_lower.contains("powershell")
                || title_lower.contains("windowsterminal")
                || title_lower.contains("git bash")
                || title_lower.contains("mingw")
                || title_lower.contains("console")
            {
                info!("Detected browser, editor or terminal, using clipboard method");
                return InjectionMethod::Clipboard;
            }
        }
        
        info!("Using keyboard method as default");
        InjectionMethod::Keyboard
    }
    
    fn inject_keyboard_with_retry(&self, text: &str) -> Result<(), String> {
        let mut last_error = String::new();
        
        for attempt in 0..MAX_RETRIES {
            match self.inject_keyboard(text) {
                Ok(_) => return Ok(()),
                Err(e) => {
                    last_error = e;
                    if attempt < MAX_RETRIES - 1 {
                        warn!("Keyboard injection attempt {} failed: {}", attempt + 1, last_error);
                        std::thread::sleep(std::time::Duration::from_millis(RETRY_DELAY_MS * (attempt + 1) as u64));
                    }
                }
            }
        }
        
        Err(format!("Keyboard injection failed after {} attempts: {}", MAX_RETRIES, last_error))
    }
    
    fn inject_clipboard_with_retry(&self, text: &str) -> Result<(), String> {
        let mut last_error = String::new();
        
        for attempt in 0..MAX_RETRIES {
            match self.inject_clipboard_impl(text) {
                Ok(_) => return Ok(()),
                Err(e) => {
                    last_error = e;
                    if attempt < MAX_RETRIES - 1 {
                        warn!("Clipboard injection attempt {} failed: {}", attempt + 1, last_error);
                        std::thread::sleep(std::time::Duration::from_millis(RETRY_DELAY_MS * (attempt + 1) as u64));
                    }
                }
            }
        }
        
        Err(format!("Clipboard injection failed after {} attempts: {}", MAX_RETRIES, last_error))
    }
    
    fn inject_keyboard(&self, text: &str) -> Result<(), String> {
        let chars: Vec<char> = text.chars().collect();
        let total_chars = chars.len();
        let mut injected = 0;
        
        for chunk in chars.chunks(CHUNK_SIZE) {
            let mut inputs: Vec<INPUT> = Vec::with_capacity(chunk.len() * 2);
            
            for c in chunk {
                if let Err(e) = Self::send_unicode_char(*c, &mut inputs) {
                    warn!("Failed to create input for char '{}': {}", c, e);
                }
            }
            
            if !inputs.is_empty() {
                unsafe {
                    let result = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
                    if result as u32 != inputs.len() as u32 {
                        return Err(format!("SendInput failed: returned {}, expected {}", result, inputs.len()));
                    }
                }
            }
            
            injected += chunk.len();
            
            if injected < total_chars {
                std::thread::sleep(std::time::Duration::from_millis(CHUNK_DELAY_MS));
            }
        }
        
        Ok(())
    }
    
    #[cfg(windows)]
    fn send_unicode_char(c: char, inputs: &mut Vec<INPUT>) -> Result<(), String> {
        let scan_code = c as u16;
        
        inputs.push(INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: windows::Win32::UI::Input::KeyboardAndMouse::VIRTUAL_KEY(0),
                    wScan: scan_code,
                    dwFlags: KEYEVENTF_UNICODE,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        });
        
        inputs.push(INPUT {
            r#type: INPUT_KEYBOARD,
            Anonymous: INPUT_0 {
                ki: KEYBDINPUT {
                    wVk: windows::Win32::UI::Input::KeyboardAndMouse::VIRTUAL_KEY(0),
                    wScan: scan_code,
                    dwFlags: KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                    time: 0,
                    dwExtraInfo: 0,
                },
            },
        });
        
        Ok(())
    }
    
    #[cfg(not(windows))]
    fn send_unicode_char(_c: char, _inputs: &mut Vec<INPUT>) -> Result<(), String> {
        Err("Unicode input not supported on this platform".to_string())
    }
    
    fn inject_clipboard_impl(&self, text: &str) -> Result<(), String> {
        let previous = get_clipboard_text();
        
        set_clipboard_text(text)?;
        
        std::thread::sleep(std::time::Duration::from_millis(50));
        
        #[cfg(windows)]
        self.send_ctrl_v();
        
        let prev = previous;
        std::thread::spawn(move || {
            std::thread::sleep(std::time::Duration::from_secs(1));
            if let Some(text) = prev {
                if let Err(e) = set_clipboard_text(&text) {
                    warn!("Failed to restore clipboard: {}", e);
                }
            }
        });
        
        Ok(())
    }
    
    #[cfg(windows)]
    fn send_ctrl_v(&self) {
        use windows::Win32::UI::Input::KeyboardAndMouse::{
            SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, KEYBDINPUT,
            KEYEVENTF_KEYUP, VK_CONTROL, VIRTUAL_KEY, KEYBD_EVENT_FLAGS,
        };
        
        let inputs = [
            INPUT {
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
            },
            INPUT {
                r#type: INPUT_KEYBOARD,
                Anonymous: INPUT_0 {
                    ki: KEYBDINPUT {
                        wVk: VIRTUAL_KEY(0x56),
                        wScan: 0,
                        dwFlags: KEYBD_EVENT_FLAGS(0),
                        time: 0,
                        dwExtraInfo: 0,
                    },
                },
            },
            INPUT {
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
            },
            INPUT {
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
            },
        ];
        
        unsafe {
            let result = SendInput(&inputs, std::mem::size_of::<INPUT>() as i32);
            if result as u32 != inputs.len() as u32 {
                warn!("SendInput for Ctrl+V returned {}, expected {}", result, inputs.len());
            }
        }
    }
}

fn get_clipboard_text() -> Option<String> {
    #[cfg(windows)]
    {
        use windows::Win32::Foundation::HGLOBAL;
        use windows::Win32::System::DataExchange::{OpenClipboard, GetClipboardData, CloseClipboard};
        use windows::Win32::System::Memory::{GlobalLock, GlobalUnlock};

        unsafe {
            if OpenClipboard(None).is_ok() {
                // 13 = CF_UNICODETEXT
                if let Ok(handle) = GetClipboardData(13) {
                    if !handle.is_invalid() {
                        let hglobal = HGLOBAL(handle.0 as *mut _);
                        let ptr = GlobalLock(hglobal);
                        if !ptr.is_null() {
                            let u16_ptr = ptr as *const u16;
                            let len = (0..).take_while(|&i| *u16_ptr.add(i) != 0).count();
                            let text = String::from_utf16_lossy(std::slice::from_raw_parts(u16_ptr, len));
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

    #[cfg(not(windows))]
    {
        None
    }
}

fn set_clipboard_text(text: &str) -> Result<(), String> {
    #[cfg(windows)]
    {
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
            
            let handle_as_hwnd = HANDLE(handle.0);
            // 13 = CF_UNICODETEXT (UTF-16), matching the UTF-16 encoded data above
            let _ = SetClipboardData(13, Some(handle_as_hwnd));
            
            CloseClipboard().ok();
        }
        
        Ok(())
    }
    
    #[cfg(not(windows))]
    {
        Err("Clipboard not supported on this platform".to_string())
    }
}

pub fn inject_text_with_fallback(text: &str) -> Result<(), String> {
    let injector = TextInjector::new(InjectionMethod::Auto);
    
    match injector.inject(text) {
        Ok(_) => Ok(()),
        Err(e) => {
            error!("Primary injection failed: {}", e);
            
            let clipboard_injector = TextInjector::new(InjectionMethod::Clipboard);
            clipboard_injector.inject(text)
        }
    }
}
