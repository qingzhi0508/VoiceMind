import ApplicationServices
import Foundation

enum FocusedInputDetector {
    static func currentFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedObject: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard result == .success, let focusedObject else {
            return nil
        }

        return unsafeBitCast(focusedObject, to: AXUIElement.self)
    }

    static func currentFocusedElementSummary() -> String {
        guard let element = currentFocusedElement() else {
            return "Focused element: unavailable"
        }

        let role = stringAttribute(kAXRoleAttribute, for: element) ?? "unknown"
        let title = stringAttribute(kAXTitleAttribute, for: element) ?? "untitled"
        return "Focused element: \(role) - \(title)"
    }

    static func stringAttribute(_ attribute: String, for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value as? String
    }
}
