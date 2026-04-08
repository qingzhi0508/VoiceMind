import ApplicationServices
import Foundation

final class AccessibilityTextInjector: TextInjecting {
    private let chunkSize = 500
    private let chunkDelay: TimeInterval = 0.05

    func inject(_ text: String) throws {
        guard PermissionsManager.checkAccessibility() == .granted else {
            throw TextInjectionError.accessibilityPermissionDenied
        }

        guard let focusedElement = FocusedInputDetector.currentWritableFocusedElement() else {
            try fallbackToCGEvent(text)
            return
        }

        guard let currentText = currentValue(for: focusedElement) else {
            try fallbackToCGEvent(text)
            return
        }
        let selectedRange = selectedTextRange(for: focusedElement, fallbackLength: currentText.length)
        let safeLocation = min(selectedRange.location, currentText.length)
        let safeRange = NSRange(
            location: safeLocation,
            length: min(selectedRange.length, max(0, currentText.length - safeLocation))
        )

        let updatedText = currentText.replacingCharacters(in: safeRange, with: text)
        let setValueResult = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            updatedText as CFTypeRef
        )

        guard setValueResult == .success else {
            try fallbackToCGEvent(text)
            return
        }

        let insertedLength = (text as NSString).length
        try setCursorPosition(
            location: safeRange.location + insertedLength,
            element: focusedElement
        )
    }

    private func currentValue(for element: AXUIElement) -> NSString? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)

        guard result == .success else { return nil }

        guard let stringValue = value as? String else { return nil }

        return stringValue as NSString
    }

    private func selectedTextRange(for element: AXUIElement, fallbackLength: Int) -> NSRange {
        var selectedRange: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )

        guard result == .success,
              let selectedRange else {
            return NSRange(location: fallbackLength, length: 0)
        }

        let axValue = unsafeBitCast(selectedRange, to: AXValue.self)

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return NSRange(location: fallbackLength, length: 0)
        }

        return NSRange(location: max(range.location, 0), length: max(range.length, 0))
    }

    private func setCursorPosition(location: Int, element: AXUIElement) throws {
        var range = CFRange(location: location, length: 0)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            throw TextInjectionError.injectionFailed("Unable to create cursor range")
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )

        guard result == .success else {
            throw TextInjectionError.injectionFailed("Unable to update cursor position")
        }
    }

    private func isWritableElement(_ element: AXUIElement) -> Bool {
        var editable: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editable)
        if editableResult == .success, let editableValue = editable as? Bool, editableValue {
            return true
        }

        var settable = DarwinBoolean(false)
        let settableResult = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &settable
        )
        if settableResult == .success, settable.boolValue {
            return true
        }

        var selectedTextRangeSettable = DarwinBoolean(false)
        let rangeSettableResult = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedTextRangeSettable
        )
        if rangeSettableResult == .success, selectedTextRangeSettable.boolValue {
            return true
        }

        guard let role = FocusedInputDetector.stringAttribute(kAXRoleAttribute as String, for: element) else {
            return false
        }

        return [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField",
            "AXTextView",
            "AXWebArea",
            "AXText"
        ].contains(role)
    }

    private func fallbackToCGEvent(_ text: String) throws {
        let chunks = text.chunked(into: chunkSize)

        for (index, chunk) in chunks.enumerated() {
            try injectChunk(chunk)

            if index < chunks.count - 1 {
                Thread.sleep(forTimeInterval: chunkDelay)
            }
        }
    }

    private func injectChunk(_ text: String) throws {
        for character in text {
            let string = String(character)
            let utf16Characters = Array(string.utf16)
            guard !utf16Characters.isEmpty else { continue }

            let keyCode = CGKeyCode(0)

            guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
                throw TextInjectionError.injectionFailed("Failed to create keyboard events")
            }

            keyDownEvent.keyboardSetUnicodeString(stringLength: utf16Characters.count, unicodeString: utf16Characters)
            keyUpEvent.keyboardSetUnicodeString(stringLength: utf16Characters.count, unicodeString: utf16Characters)

            keyDownEvent.post(tap: .cghidEventTap)
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }
}

private extension String {
    func chunked(into size: Int) -> [String] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }

        var chunks: [String] = []
        var currentChunkStart = startIndex

        while currentChunkStart < endIndex {
            let currentChunkEnd = index(currentChunkStart, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[currentChunkStart..<currentChunkEnd]))
            currentChunkStart = currentChunkEnd
        }

        return chunks
    }
}
