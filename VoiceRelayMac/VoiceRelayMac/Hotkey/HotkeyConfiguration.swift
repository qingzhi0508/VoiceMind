import Foundation
import Carbon

struct HotkeyConfiguration: Codable {
    let keyCode: UInt16
    let modifierFlags: UInt32

    static let defaultHotkey = HotkeyConfiguration(
        keyCode: UInt16(kVK_Space),
        modifierFlags: UInt32(optionKey)
    )

    var displayString: String {
        var parts: [String] = []

        if modifierFlags & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifierFlags & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifierFlags & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifierFlags & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_ANSI_A...kVK_ANSI_Z:
            let char = Character(UnicodeScalar(Int(keyCode) - kVK_ANSI_A + 65)!)
            return String(char)
        default: return "Key\(keyCode)"
        }
    }
}
