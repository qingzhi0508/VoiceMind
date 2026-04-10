import XCTest

final class AccessibilityTextInjectorSourceTests: XCTestCase {
    func testWritableDetectionIncludesSelectedTextRangeSettableFallback() throws {
        let source = try accessibilityTextInjectorSource()

        XCTAssertTrue(
            source.contains("kAXSelectedTextRangeAttribute"),
            "AccessibilityTextInjector should treat a writable selected text range as a valid input target."
        )
    }

    func testInjectionIncludesKeyboardEventFallbackWhenDirectSetFails() throws {
        let source = try accessibilityTextInjectorSource()

        XCTAssertTrue(
            source.contains("fallbackToCGEvent"),
            "AccessibilityTextInjector should retain the keyboard event fallback used by the earlier implementation."
        )
    }

    func testInjectionFallsBackToKeyboardEventsWhenNoWritableTargetIsResolved() throws {
        let source = try accessibilityTextInjectorSource()
        let methodBody = try XCTUnwrap(methodBody(named: "func inject(_ text: String) throws", in: source))

        XCTAssertTrue(
            methodBody.contains("guard let focusedElement = FocusedInputDetector.currentWritableFocusedElement() else"),
            "AccessibilityTextInjector should still begin by resolving a writable focused element."
        )
        XCTAssertTrue(
            methodBody.contains("try fallbackToCGEvent(text)\n            return"),
            "AccessibilityTextInjector should fall back to keyboard events when AX focus lookup is unavailable but the target app has already been restored."
        )
    }

    func testInjectionFallsBackToKeyboardEventsWhenFocusedElementDoesNotExposeStringValue() throws {
        let source = try accessibilityTextInjectorSource()
        let methodBody = try XCTUnwrap(methodBody(named: "func inject(_ text: String) throws", in: source))

        XCTAssertTrue(
            methodBody.contains("guard let currentText = currentValue(for: focusedElement) else"),
            "AccessibilityTextInjector should treat missing AXValue text as a recoverable case."
        )
        XCTAssertTrue(
            methodBody.contains("try fallbackToCGEvent(text)\n            return"),
            "AccessibilityTextInjector should type through the active caret when AXValue is unreadable."
        )
    }

    private func accessibilityTextInjectorSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/TextInjection/AccessibilityTextInjector.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func methodBody(named signature: String, in source: String) -> String? {
        guard let signatureRange = source.range(of: signature) else {
            return nil
        }

        let bodyStart = signatureRange.upperBound
        guard let methodEnd = source[bodyStart...].range(of: "\n    }\n") else {
            return nil
        }

        return String(source[bodyStart..<methodEnd.lowerBound])
    }
}
