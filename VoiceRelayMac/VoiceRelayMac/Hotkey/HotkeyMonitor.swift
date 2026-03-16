import Foundation
import Carbon
import Cocoa

protocol HotkeyMonitorDelegate: AnyObject {
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didPressHotkey sessionId: String)
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didReleaseHotkey sessionId: String)
}

class HotkeyMonitor {
    weak var delegate: HotkeyMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var configuration: HotkeyConfiguration
    private var isHotkeyPressed = false
    private var currentSessionId: String?
    private var pressTime: Date?

    private let debounceInterval: TimeInterval = 0.1 // 100ms

    init(configuration: HotkeyConfiguration = .defaultHotkey) {
        self.configuration = configuration
    }

    func start() -> Bool {
        guard checkAccessibilityPermission() else {
            print("Accessibility permission not granted")
            return false
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        print("Hotkey monitor started")
        return true
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        print("Hotkey monitor stopped")
    }

    func updateConfiguration(_ configuration: HotkeyConfiguration) {
        self.configuration = configuration
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown || type == .keyUp {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
            let currentModifiers = flags.intersection(modifierMask).rawValue

            // Check if this matches our hotkey
            if keyCode == configuration.keyCode && currentModifiers == UInt64(configuration.modifierFlags) {
                if type == .keyDown && !isHotkeyPressed {
                    handleHotkeyPress()
                    return nil // Consume event
                } else if type == .keyUp && isHotkeyPressed {
                    handleHotkeyRelease()
                    return nil // Consume event
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func handleHotkeyPress() {
        let now = Date()

        // Debounce: ignore if pressed too quickly after last release
        if let lastPress = pressTime, now.timeIntervalSince(lastPress) < debounceInterval {
            return
        }

        pressTime = now
        isHotkeyPressed = true

        let sessionId = UUID().uuidString
        currentSessionId = sessionId

        delegate?.hotkeyMonitor(self, didPressHotkey: sessionId)
    }

    private func handleHotkeyRelease() {
        guard let sessionId = currentSessionId else { return }

        let now = Date()

        // Debounce: ignore if released too quickly after press
        if let pressTime = pressTime, now.timeIntervalSince(pressTime) < debounceInterval {
            return
        }

        isHotkeyPressed = false
        delegate?.hotkeyMonitor(self, didReleaseHotkey: sessionId)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
