import Cocoa
import ApplicationServices

enum FocusedInputDetector {
    static func hasWritableFocusedElement() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedObject: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard result == .success, let focusedElement = focusedObject else {
            return false
        }

        let element = unsafeBitCast(focusedElement, to: AXUIElement.self)
        return isWritable(element: element, depth: 0)
    }

    private static func isWritable(element: AXUIElement, depth: Int) -> Bool {
        guard depth < 6 else { return false }

        if let editable = copyBoolAttribute("AXEditable" as CFString, from: element), editable {
            return true
        }

        if let role = copyStringAttribute(kAXRoleAttribute as CFString, from: element),
           writableRoles.contains(role) {
            return true
        }

        if isAttributeSettable(kAXValueAttribute as CFString, for: element)
            || isAttributeSettable(kAXSelectedTextRangeAttribute as CFString, for: element) {
            return true
        }

        if let parent = copyElementAttribute(kAXParentAttribute as CFString, from: element) {
            return isWritable(element: parent, depth: depth + 1)
        }

        return false
    }

    private static let writableRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField",
        "AXTextView",
        "AXWebArea",
        "AXText"
    ]

    private static func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return value as? String
    }

    private static func copyBoolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return value as? Bool
    }

    private static func copyElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func isAttributeSettable(_ attribute: CFString, for element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return result == .success && settable.boolValue
    }
}
