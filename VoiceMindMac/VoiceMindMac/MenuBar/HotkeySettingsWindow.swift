import SwiftUI
import Carbon

struct HotkeySettingsWindow: View {
    let onSave: (HotkeyConfiguration) -> Void

    @State private var selectedModifiers: Set<String> = ["Option"]
    @State private var selectedKey = "Space"

    let modifierOptions = ["Control", "Option", "Shift", "Command"]
    let keyOptions = ["Space", "Return", "Tab"]

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "hotkey_title"))
                .font(.title)

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "hotkey_modifier_label"))
                    .font(.headline)

                ForEach(modifierOptions, id: \.self) { modifier in
                    Toggle(modifier, isOn: Binding(
                        get: { selectedModifiers.contains(modifier) },
                        set: { isOn in
                            if isOn {
                                selectedModifiers.insert(modifier)
                            } else {
                                selectedModifiers.remove(modifier)
                            }
                        }
                    ))
                }

                Text(String(localized: "hotkey_key_label"))
                    .font(.headline)
                    .padding(.top)

                Picker(String(localized: "hotkey_key_picker"), selection: $selectedKey) {
                    ForEach(keyOptions, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()

            Text(String(format: String(localized: "hotkey_current_format"), hotkeyDisplayString))
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button(AppLocalization.localizedString("cancel_button")) {
                    // Close window
                }

                Button(AppLocalization.localizedString("save_button")) {
                    saveHotkey()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 400, height: 350)
        .padding()
    }

    private var hotkeyDisplayString: String {
        var parts: [String] = []

        if selectedModifiers.contains("Control") {
            parts.append("⌃")
        }
        if selectedModifiers.contains("Option") {
            parts.append("⌥")
        }
        if selectedModifiers.contains("Shift") {
            parts.append("⇧")
        }
        if selectedModifiers.contains("Command") {
            parts.append("⌘")
        }

        parts.append(selectedKey)
        return parts.joined()
    }

    private func saveHotkey() {
        var modifierFlags: UInt32 = 0

        if selectedModifiers.contains("Control") {
            modifierFlags |= UInt32(controlKey)
        }
        if selectedModifiers.contains("Option") {
            modifierFlags |= UInt32(optionKey)
        }
        if selectedModifiers.contains("Shift") {
            modifierFlags |= UInt32(shiftKey)
        }
        if selectedModifiers.contains("Command") {
            modifierFlags |= UInt32(cmdKey)
        }

        let keyCode = keyToKeyCode(selectedKey)
        let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifierFlags)

        onSave(config)
    }

    private func keyToKeyCode(_ key: String) -> UInt16 {
        switch key {
        case "Space": return UInt16(kVK_Space)
        case "Return": return UInt16(kVK_Return)
        case "Tab": return UInt16(kVK_Tab)
        default: return UInt16(kVK_Space)
        }
    }
}
