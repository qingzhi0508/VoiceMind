import AppKit
import ApplicationServices

class CursorPositionTracker {
    private var timer: Timer?
    private var tracking = false

    var onPositionUpdate: ((NSPoint) -> Void)?

    func currentPosition() -> NSPoint {
        return Self.currentCursorPosition()
    }

    func startTracking() {
        guard !tracking else { return }
        tracking = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            let position = Self.currentCursorPosition()
            DispatchQueue.main.async {
                self.onPositionUpdate?(position)
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopTracking() {
        tracking = false
        timer?.invalidate()
        timer = nil
    }

    private static func currentCursorPosition() -> NSPoint {
        if let textCursor = axTextCursorPosition() {
            return textCursor
        }
        return NSEvent.mouseLocation
    }

    private static func axTextCursorPosition() -> NSPoint? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard result == .success else { return nil }
        let element = unsafeBitCast(focusedElement, to: AXUIElement.self)

        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )
        guard rangeResult == .success, let selectedRange else { return nil }

        let axValue = unsafeBitCast(selectedRange, to: AXValue.self)
        var cfRange = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &cfRange) else { return nil }

        let rangeAXValue = AXValueCreate(.cfRange, &cfRange)
        guard let rangeAXValue else { return nil }

        var bounds: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeAXValue,
            &bounds
        )
        guard boundsResult == .success, let bounds else { return nil }

        let boundsAXValue = unsafeBitCast(bounds, to: AXValue.self)
        var rect = CGRect.zero
        guard AXValueGetValue(boundsAXValue, .cgRect, &rect) else { return nil }

        // Convert CG coords (origin top-left) to AppKit coords (origin bottom-left)
        // rect.origin.y = top of text cursor in CG coords
        // AppKit Y = screenHeight - cgY (top of cursor)
        guard let mainScreen = NSScreen.main else { return nil }
        let screenFrame = mainScreen.frame
        let appKitY = screenFrame.height - rect.origin.y
        return NSPoint(x: rect.origin.x, y: appKitY)
    }
}
