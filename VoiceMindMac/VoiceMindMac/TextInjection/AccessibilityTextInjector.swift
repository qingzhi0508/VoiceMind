import Foundation
import Cocoa
import ApplicationServices

/// 基于 Accessibility API 的文本注入器
/// 直接在焦点元素的当前光标位置插入文本，不依赖剪贴板或键盘事件
class AccessibilityTextInjector: TextInjectionProtocol {
    var requiresAccessibilityPermission: Bool { true }

    private let chunkSize = 500
    private let chunkDelay: TimeInterval = 0.05 // 50ms

    func inject(_ text: String) throws {
        print("🔧 AccessibilityTextInjector.inject() 被调用")
        print("   文本: \(text)")

        guard checkAccessibilityPermission() else {
            print("❌ 缺少辅助功能权限")
            throw TextInjectionError.accessibilityPermissionDenied
        }

        print("✅ 辅助功能权限检查通过")

        // 获取焦点元素
        guard let focusedElement = getFocusedElement() else {
            print("❌ 未找到焦点元素")
            throw TextInjectionError.noFocusedInputTarget
        }

        print("🔍 焦点元素: \(getElementDescription(focusedElement))")

        // 检查元素是否可写
        guard isWritableElement(focusedElement) else {
            print("❌ 焦点元素不可写")
            throw TextInjectionError.noFocusedInputTarget
        }

        print("✅ 焦点元素可写")

        // 获取当前光标位置
        let cursorPosition = getCursorPosition(focusedElement)
        print("📍 当前光标位置: \(cursorPosition)")

        // 在光标位置插入文本
        try insertTextAtCursor(text, cursorPosition: cursorPosition, element: focusedElement)

        print("✅ 文本注入成功")
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func getFocusedElement() -> AXUIElement? {
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

        return unsafeBitCast(focusedElement, to: AXUIElement.self)
    }

    private func getElementDescription(_ element: AXUIElement) -> String {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)

        let roleStr = (role as? String) ?? "未知"
        let titleStr = (title as? String) ?? "无标题"

        return "\(roleStr) - \(titleStr)"
    }

    private func isWritableElement(_ element: AXUIElement) -> Bool {
        // 检查 AXEditable
        var editable: CFTypeRef?
        let editableResult = AXUIElementCopyAttributeValue(element, "AXEditable" as CFString, &editable)
        if editableResult == .success, let editableValue = editable as? Bool, editableValue {
            return true
        }

        // 检查角色类型
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let roleStr = role as? String {
            let writableRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                kAXComboBoxRole as String,
                "AXSearchField",
                "AXTextView",
                "AXWebArea",
                "AXText"
            ]
            if writableRoles.contains(roleStr) {
                return true
            }
        }

        // 检查 AXValue 是否可写
        var settable = DarwinBoolean(false)
        let settableResult = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        if settableResult == .success && settable.boolValue {
            return true
        }

        // 检查 AXSelectedTextRange 是否可写
        var selectedTextRangeSettable = DarwinBoolean(false)
        let rangeSettableResult = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedTextRangeSettable
        )
        if rangeSettableResult == .success && selectedTextRangeSettable.boolValue {
            return true
        }

        return false
    }

    private func getCursorPosition(_ element: AXUIElement) -> Int {
        var selectedRange: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )

        guard result == .success, let rangeValue = selectedRange else {
            // 如果无法获取选择范围，尝试获取值长度
            var value: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
            if valueResult == .success, let text = value as? String {
                return text.count
            }
            return 0
        }

        // 解析 AXValue 从 CFRange
        // AXSelectedTextRange 是一个包含 location 和 length 的值
        // 使用 AXValueCopyCFTypeDescription 或直接解析
        if let rangeDict = rangeValue as? [String: Any],
           let location = rangeDict["loc"] as? Int ?? rangeDict["location"] as? Int {
            return location
        }

        // 尝试另一种解析方式
        var range = CFRangeMake(0, 0)
        if AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) {
            return range.location
        }

        return 0
    }

    private func insertTextAtCursor(_ text: String, cursorPosition: Int, element: AXUIElement) throws {
        // 方法1: 直接使用 AXValue 设置新文本
        // 获取当前文本
        var currentValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

        if valueResult == .success, let currentText = currentValue as? String {
            // 在光标位置插入新文本
            let index = currentText.index(currentText.startIndex, offsetBy: min(cursorPosition, currentText.count))
            var newText = currentText
            newText.insert(contentsOf: text, at: index)

            // 设置新文本
            let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
            if setResult == .success {
                print("✅ 使用 AXValue 插入文本成功")

                // 将光标移动到插入文本之后
                let newCursorPosition = cursorPosition + text.count
                try setCursorPosition(newCursorPosition, element: element)
                return
            } else {
                print("⚠️ AXValue 设置失败，尝试其他方法")
            }
        }

        // 方法2: 使用 AXSelectedTextRange 和 AXValue
        // 首先设置选择范围到光标位置
        try setCursorPosition(cursorPosition, element: element)

        // 获取新的选择范围
        var selectedRange: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)

        // 设置值为：当前文本 + 新文本
        if valueResult == .success, let currentText = currentValue as? String {
            let index = currentText.index(currentText.startIndex, offsetBy: min(cursorPosition, currentText.count))
            var newText = currentText
            newText.insert(contentsOf: text, at: index)

            let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
            if setResult == .success {
                print("✅ 使用 AXValue 插入文本成功（方法2）")

                // 将光标移动到插入文本之后
                let newCursorPosition = cursorPosition + text.count
                try setCursorPosition(newCursorPosition, element: element)
                return
            }
        }

        // 方法3: 使用 CGEvent 键盘事件（备用）
        print("⚠️ Accessibility API 插入失败，使用 CGEvent 作为备用方案")
        try fallbackToCGEvent(text)
    }

    private func setCursorPosition(_ position: Int, element: AXUIElement) throws {
        // 创建新的选择范围（将光标设置到指定位置）
        // 使用 CFRange
        var range = CFRangeMake(position, 0)

        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            throw TextInjectionError.injectionFailed("Failed to create range value")
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )

        if result != .success {
            print("⚠️ 设置光标位置失败: \(result.rawValue)")
            // 不抛出错误，继续执行
        } else {
            print("✅ 光标位置已设置到: \(position)")
        }
    }

    private func fallbackToCGEvent(_ text: String) throws {
        // 将文本分割成小块进行注入
        let chunks = text.chunked(into: chunkSize)

        for (index, chunk) in chunks.enumerated() {
            try injectChunk(chunk)

            if index < chunks.count - 1 {
                Thread.sleep(forTimeInterval: chunkDelay)
            }
        }
    }

    private func injectChunk(_ text: String) throws {
        for char in text {
            let string = String(char)
            guard string.unicodeScalars.first != nil else { return }

            let keyCode = CGKeyCode(0)

            guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
                throw TextInjectionError.injectionFailed("Failed to create key down event")
            }

            keyDownEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

            guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
                throw TextInjectionError.injectionFailed("Failed to create key up event")
            }

            keyUpEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

            keyDownEvent.post(tap: .cghidEventTap)
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }
}
