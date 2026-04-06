import ApplicationServices
import Foundation

final class AccessibilityTextInjector: TextInjecting {
    func inject(_ text: String) throws {
        guard PermissionsManager.checkAccessibility() == .granted else {
            throw TextInjectionError.accessibilityPermissionDenied
        }

        guard let focusedElement = FocusedInputDetector.currentFocusedElement() else {
            throw TextInjectionError.noFocusedInputTarget
        }

        guard isWritableElement(focusedElement) else {
            throw TextInjectionError.noFocusedInputTarget
        }

        let currentText = try currentValue(for: focusedElement)
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
            throw TextInjectionError.injectionFailed("Unable to set text for focused element")
        }

        let insertedLength = (text as NSString).length
        try setCursorPosition(
            location: safeRange.location + insertedLength,
            element: focusedElement
        )
    }

    private func currentValue(for element: AXUIElement) throws -> NSString {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)

        guard result == .success else {
            throw TextInjectionError.injectionFailed("Unable to read current text value")
        }

        guard let stringValue = value as? String else {
            throw TextInjectionError.injectionFailed("Focused element does not expose string value")
        }

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
}
