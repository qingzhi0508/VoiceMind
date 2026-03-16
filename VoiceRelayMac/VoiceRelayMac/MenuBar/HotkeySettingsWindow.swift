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
            Text("热键设置")
                .font(.title)

            VStack(alignment: .leading, spacing: 10) {
                Text("修饰键：")
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

                Text("按键：")
                    .font(.headline)
                    .padding(.top)

                Picker("按键", selection: $selectedKey) {
                    ForEach(keyOptions, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()

            Text("当前热键: \(hotkeyDisplayString)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("取消") {
                    // Close window
                }

                Button("保存") {
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
