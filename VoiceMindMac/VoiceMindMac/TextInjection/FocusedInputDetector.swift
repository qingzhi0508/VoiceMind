import AppKit
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

    static func currentWritableFocusedElement() -> AXUIElement? {
        guard let focusedElement = currentFocusedElement() else {
            return nil
        }

        return resolveWritableElement(startingAt: focusedElement, depth: 0)
    }

    static func currentFocusedElementSummary() -> String {
        guard let snapshot = currentSnapshot() else {
            let appSummary = frontmostApplicationSummary()
            return """
            Frontmost app: \(appSummary.name)
            Bundle ID: \(appSummary.bundleIdentifier)
            Focused element: unavailable
            """
        }

        return snapshot.summary
    }

    static func stringAttribute(_ attribute: String, for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private static func resolveWritableElement(startingAt element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 6 else {
            return nil
        }

        if isWritableElement(element) {
            return element
        }

        guard let parent = copyElementAttribute(kAXParentAttribute as CFString, from: element) else {
            return nil
        }

        return resolveWritableElement(startingAt: parent, depth: depth + 1)
    }

    private static func currentSnapshot() -> FocusedElementSnapshot? {
        guard let element = currentFocusedElement() else {
            return nil
        }

        let appSummary = frontmostApplicationSummary()
        return makeSnapshot(for: element, depth: 0, appSummary: appSummary)
    }

    private static func makeSnapshot(
        for element: AXUIElement,
        depth: Int,
        appSummary: (name: String, bundleIdentifier: String)
    ) -> FocusedElementSnapshot {
        guard depth < 6 else {
            return FocusedElementSnapshot(
                appName: appSummary.name,
                bundleIdentifier: appSummary.bundleIdentifier,
                rolePath: [],
                title: nil,
                editable: nil,
                valueSettable: false,
                selectedTextRangeSettable: false,
                isWritable: false
            )
        }

        let role = stringAttribute(kAXRoleAttribute as String, for: element)
        let title = stringAttribute(kAXTitleAttribute as String, for: element)
        let editable = boolAttribute("AXEditable", for: element)
        let valueSettable = isAttributeSettable(kAXValueAttribute as CFString, for: element)
        let selectedTextRangeSettable = isAttributeSettable(kAXSelectedTextRangeAttribute as CFString, for: element)
        let writable = isWritableElement(element)

        if writable {
            return FocusedElementSnapshot(
                appName: appSummary.name,
                bundleIdentifier: appSummary.bundleIdentifier,
                rolePath: [role ?? "unknown"],
                title: title,
                editable: editable,
                valueSettable: valueSettable,
                selectedTextRangeSettable: selectedTextRangeSettable,
                isWritable: true
            )
        }

        if let parent = copyElementAttribute(kAXParentAttribute as CFString, from: element) {
            var parentSnapshot = makeSnapshot(for: parent, depth: depth + 1, appSummary: appSummary)
            parentSnapshot.rolePath.insert(role ?? "unknown", at: 0)
            parentSnapshot.title = parentSnapshot.title ?? title
            parentSnapshot.editable = parentSnapshot.editable ?? editable
            return parentSnapshot
        }

        return FocusedElementSnapshot(
            appName: appSummary.name,
            bundleIdentifier: appSummary.bundleIdentifier,
            rolePath: [role ?? "unknown"],
            title: title,
            editable: editable,
            valueSettable: valueSettable,
            selectedTextRangeSettable: selectedTextRangeSettable,
            isWritable: false
        )
    }

    private static func isWritableElement(_ element: AXUIElement) -> Bool {
        if boolAttribute("AXEditable", for: element) == true {
            return true
        }

        if isAttributeSettable(kAXValueAttribute as CFString, for: element) {
            return true
        }

        if isAttributeSettable(kAXSelectedTextRangeAttribute as CFString, for: element) {
            return true
        }

        guard let role = stringAttribute(kAXRoleAttribute as String, for: element) else {
            return false
        }

        return writableRoles.contains(role)
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

    private static func boolAttribute(_ attribute: String, for element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else {
            return nil
        }

        return value as? Bool
    }

    private static func copyElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else {
            return nil
        }

        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func isAttributeSettable(_ attribute: CFString, for element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, attribute, &settable)
        return result == .success && settable.boolValue
    }

    private static func frontmostApplicationSummary() -> (name: String, bundleIdentifier: String) {
        let app = NSWorkspace.shared.frontmostApplication
        return (
            name: app?.localizedName ?? "unknown",
            bundleIdentifier: app?.bundleIdentifier ?? "unknown"
        )
    }
}

private struct FocusedElementSnapshot {
    let appName: String
    let bundleIdentifier: String
    var rolePath: [String]
    var title: String?
    var editable: Bool?
    var valueSettable: Bool
    var selectedTextRangeSettable: Bool
    let isWritable: Bool

    var summary: String {
        """
        Frontmost app: \(appName)
        Bundle ID: \(bundleIdentifier)
        Role path: \(rolePath.joined(separator: " -> "))
        Title: \(title ?? "untitled")
        AXEditable: \(editable.map(String.init(describing:)) ?? "unknown")
        AXValue settable: \(valueSettable ? "yes" : "no")
        AXSelectedTextRange settable: \(selectedTextRangeSettable ? "yes" : "no")
        Writable target resolved: \(isWritable ? "yes" : "no")
        """
    }
}
