import Foundation
import Carbon
import Cocoa

class CGEventTextInjector: TextInjectionProtocol {
    var requiresAccessibilityPermission: Bool { true }

    private let chunkSize = 500
    private let chunkDelay: TimeInterval = 0.01 // 10ms

    func inject(_ text: String) throws {
        guard checkAccessibilityPermission() else {
            throw TextInjectionError.accessibilityPermissionDenied
        }

        guard FocusedInputDetector.detectionStatus() != .nonWritable else {
            throw TextInjectionError.noFocusedInputTarget
        }

        // Split into chunks for long text
        let chunks = text.chunked(into: chunkSize)

        for (index, chunk) in chunks.enumerated() {
            try injectChunk(chunk)

            // Add delay between chunks (except for last chunk)
            if index < chunks.count - 1 {
                Thread.sleep(forTimeInterval: chunkDelay)
            }
        }
    }

    private func injectChunk(_ text: String) throws {
        for char in text {
            try injectCharacter(char)
        }
    }

    private func injectCharacter(_ char: Character) throws {
        let string = String(char)
        guard string.unicodeScalars.first != nil else { return }

        let keyCode = CGKeyCode(0) // Virtual key code for Unicode input

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw TextInjectionError.injectionFailed("Failed to create key down event")
        }

        // Set Unicode string
        keyDownEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw TextInjectionError.injectionFailed("Failed to create key up event")
        }

        keyUpEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var currentIndex = startIndex

        while currentIndex < endIndex {
            let nextIndex = index(currentIndex, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[currentIndex..<nextIndex]))
            currentIndex = nextIndex
        }

        return chunks
    }
}
