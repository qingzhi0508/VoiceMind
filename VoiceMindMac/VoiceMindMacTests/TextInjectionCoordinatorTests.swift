import XCTest
@testable import VoiceMind

final class TextInjectionCoordinatorTests: XCTestCase {
    func testDeliverReturnsInjectedWhenInjectorSucceeds() {
        let injector = StubTextInjector()
        let coordinator = TextInjectionCoordinator(injector: injector)

        let outcome = coordinator.deliver(text: "你好，世界")

        XCTAssertEqual(outcome, .injected)
        XCTAssertEqual(injector.injectedTexts, ["你好，世界"])
    }

    func testDeliverReturnsPermissionRequiredWhenInjectorThrowsAccessibilityDenied() {
        let injector = StubTextInjector()
        injector.error = .accessibilityPermissionDenied
        let coordinator = TextInjectionCoordinator(injector: injector)

        let outcome = coordinator.deliver(text: "需要授权")

        XCTAssertEqual(outcome, .permissionRequired)
        XCTAssertEqual(injector.injectedTexts, ["需要授权"])
    }

    func testDeliverReturnsCopyFallbackWhenInjectorThrowsGenericFailure() {
        let injector = StubTextInjector()
        injector.error = .injectionFailed("boom")
        let coordinator = TextInjectionCoordinator(injector: injector)

        let outcome = coordinator.deliver(text: "复制兜底")

        XCTAssertEqual(outcome, .fallbackToCopy(reason: "boom"))
        XCTAssertEqual(injector.injectedTexts, ["复制兜底"])
    }
}

private final class StubTextInjector: TextInjecting {
    var injectedTexts: [String] = []
    var error: TextInjectionError?

    func inject(_ text: String) throws {
        injectedTexts.append(text)

        if let error {
            throw error
        }
    }
}
