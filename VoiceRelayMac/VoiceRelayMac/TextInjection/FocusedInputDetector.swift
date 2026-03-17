import Cocoa
import ApplicationServices

enum FocusedInputDetector {
    enum DetectionStatus {
        case writable
        case nonWritable
        case unavailable
    }

    static func hasWritableFocusedElement() -> Bool {
        detectionStatus() == .writable
    }

    static func detectionStatus() -> DetectionStatus {
        guard let snapshot = currentSnapshot() else {
            return .unavailable
        }

        return snapshot.isWritable ? .writable : .nonWritable
    }

    static func currentFocusedElementSummary() -> String {
        guard let snapshot = currentSnapshot() else {
            let appSummary = frontmostApplicationSummary()
            return """
            前台应用: \(appSummary.name)
            Bundle ID: \(appSummary.bundleIdentifier)
            焦点元素: 未获取到
            """
        }

        return snapshot.summary
    }

    private static func currentSnapshot() -> FocusedElementSnapshot? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedObject: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard result == .success, let focusedElement = focusedObject else {
            return nil
        }

        let element = unsafeBitCast(focusedElement, to: AXUIElement.self)
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
                subrole: nil,
                title: nil,
                editable: nil,
                valueSettable: false,
                selectedTextRangeSettable: false,
                isWritable: false
            )
        }

        let role = copyStringAttribute(kAXRoleAttribute as CFString, from: element)
        let subrole = copyStringAttribute(kAXSubroleAttribute as CFString, from: element)
        let title = copyStringAttribute(kAXTitleAttribute as CFString, from: element)
        let editable = copyBoolAttribute("AXEditable" as CFString, from: element)
        let valueSettable = isAttributeSettable(kAXValueAttribute as CFString, for: element)
        let selectedTextRangeSettable = isAttributeSettable(kAXSelectedTextRangeAttribute as CFString, for: element)

        let selfWritable = (editable == true)
            || (role.map { writableRoles.contains($0) } ?? false)
            || valueSettable
            || selectedTextRangeSettable

        if selfWritable {
            return FocusedElementSnapshot(
                appName: appSummary.name,
                bundleIdentifier: appSummary.bundleIdentifier,
                rolePath: [role ?? "未知角色"],
                subrole: subrole,
                title: title,
                editable: editable,
                valueSettable: valueSettable,
                selectedTextRangeSettable: selectedTextRangeSettable,
                isWritable: true
            )
        }

        if let parent = copyElementAttribute(kAXParentAttribute as CFString, from: element) {
            var parentSnapshot = makeSnapshot(for: parent, depth: depth + 1, appSummary: appSummary)
            parentSnapshot.rolePath.insert(role ?? "未知角色", at: 0)
            parentSnapshot.subrole = parentSnapshot.subrole ?? subrole
            parentSnapshot.title = parentSnapshot.title ?? title
            parentSnapshot.editable = parentSnapshot.editable ?? editable
            return parentSnapshot
        }

        return FocusedElementSnapshot(
            appName: appSummary.name,
            bundleIdentifier: appSummary.bundleIdentifier,
            rolePath: [role ?? "未知角色"],
            subrole: subrole,
            title: title,
            editable: editable,
            valueSettable: valueSettable,
            selectedTextRangeSettable: selectedTextRangeSettable,
            isWritable: false
        )
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

    private static func frontmostApplicationSummary() -> (name: String, bundleIdentifier: String) {
        let app = NSWorkspace.shared.frontmostApplication
        return (
            name: app?.localizedName ?? "未知应用",
            bundleIdentifier: app?.bundleIdentifier ?? "未知 Bundle ID"
        )
    }
}

private struct FocusedElementSnapshot {
    let appName: String
    let bundleIdentifier: String
    var rolePath: [String]
    var subrole: String?
    var title: String?
    var editable: Bool?
    var valueSettable: Bool
    var selectedTextRangeSettable: Bool
    let isWritable: Bool

    var summary: String {
        """
        前台应用: \(appName)
        Bundle ID: \(bundleIdentifier)
        角色链: \(rolePath.joined(separator: " -> "))
        Subrole: \(subrole ?? "无")
        标题: \(title ?? "无")
        AXEditable: \(editable.map(String.init(describing:)) ?? "未知")
        AXValue 可写: \(valueSettable ? "是" : "否")
        AXSelectedTextRange 可写: \(selectedTextRangeSettable ? "是" : "否")
        判定为可写输入控件: \(isWritable ? "是" : "否")
        """
    }
}
