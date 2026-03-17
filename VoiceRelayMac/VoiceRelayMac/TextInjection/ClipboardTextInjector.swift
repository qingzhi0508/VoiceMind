import Foundation
import Cocoa
import Carbon

class ClipboardTextInjector: TextInjectionProtocol {
    var requiresAccessibilityPermission: Bool { true }

    private let restoreDelay: TimeInterval = 0.5 // 500ms

    func inject(_ text: String) throws {
        guard checkAccessibilityPermission() else {
            throw TextInjectionError.accessibilityPermissionDenied
        }

        guard FocusedInputDetector.hasWritableFocusedElement() else {
            throw TextInjectionError.noFocusedInputTarget
        }

        // 1. Backup current clipboard content
        let pasteboard = NSPasteboard.general
        let backup = pasteboard.string(forType: .string)

        // 2. Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Simulate Cmd+V to paste
        try simulatePaste()

        // 4. Restore clipboard after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
            if let backup = backup {
                pasteboard.clearContents()
                pasteboard.setString(backup, forType: .string)
            }
        }
    }

    private func simulatePaste() throws {
        // Create Cmd key down event
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true) else {
            throw TextInjectionError.injectionFailed("Failed to create Cmd down event")
        }
        cmdDown.flags = .maskCommand

        // Create V key down event
        guard let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) else {
            throw TextInjectionError.injectionFailed("Failed to create V down event")
        }
        vDown.flags = .maskCommand

        // Create V key up event
        guard let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
            throw TextInjectionError.injectionFailed("Failed to create V up event")
        }

        // Create Cmd key up event
        guard let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false) else {
            throw TextInjectionError.injectionFailed("Failed to create Cmd up event")
        }

        // Post events in sequence
        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
}
