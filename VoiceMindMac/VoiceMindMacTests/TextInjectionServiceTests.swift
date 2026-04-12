import XCTest
@testable import VoiceMind

final class TIServiceTests: XCTestCase {
    private var heldService: TextInjectionService?

    override func tearDown() {
        heldService = nil
        super.tearDown()
    }

    func testSuccessfulInjection() {
        let injector = TIStubInjector()
        let service = makeService(injector: injector)
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("你好世界")

        XCTAssertEqual(delegate.lastOutcome, .injected)
        XCTAssertEqual(injector.injectedTexts, ["你好世界"])
    }

    func testPermissionDenied() {
        let injector = TIStubInjector()
        injector.error = .accessibilityPermissionDenied
        let service = makeService(injector: injector)
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("需要授权")

        if case .permissionRequired("需要授权") = delegate.lastOutcome {} else {
            XCTFail("Expected permissionRequired")
        }
    }

    func testRetryExhausted() {
        let injector = TIStubInjector()
        injector.error = .noFocusedInputTarget
        let service = makeService(injector: injector)
        service.overrideRetryDelay = 0.01
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("重试测试")

        let exp = expectation(description: "done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(injector.injectCallCount, 5)
            if case .fallbackToCopy(_, "No focused input target") = delegate.lastOutcome {} else {
                XCTFail("Expected fallbackToCopy")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testRetrySucceeds() {
        let injector = TIStubInjector()
        injector.error = .noFocusedInputTarget
        injector.succeedAfterAttempts = 3
        let service = makeService(injector: injector)
        service.overrideRetryDelay = 0.01
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("重试成功")

        let exp = expectation(description: "done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(delegate.lastOutcome, .injected)
            XCTAssertGreaterThanOrEqual(injector.injectCallCount, 3)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testGenericFailureNoRetry() {
        let injector = TIStubInjector()
        injector.error = .injectionFailed("some error")
        let service = makeService(injector: injector)
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("通用失败")

        if case .fallbackToCopy(_, "some error") = delegate.lastOutcome {} else {
            XCTFail("Expected fallbackToCopy")
        }
        XCTAssertEqual(injector.injectCallCount, 1)
    }

    func testCaptureStoresPID() {
        let ctx = TIContext(capturedPID: 1234, ownBundle: false)
        let service = makeService(ctx: ctx)
        heldService = service
        service.captureTargetApplication()
        XCTAssertEqual(service.pendingTargetPID, 1234)
    }

    func testCaptureIgnoresOwnBundle() {
        let ctx = TIContext(capturedPID: 5678, ownBundle: true)
        let service = makeService(ctx: ctx)
        heldService = service
        service.captureTargetApplication()
        XCTAssertNil(service.pendingTargetPID)
    }

    func testCaptureNil() {
        let ctx = TIContext(capturedPID: nil)
        let service = makeService(ctx: ctx)
        heldService = service
        service.captureTargetApplication()
        XCTAssertNil(service.pendingTargetPID)
    }

    func testConcurrentRejected() {
        let injector = TIStubInjector()
        injector.error = .noFocusedInputTarget
        let service = makeService(injector: injector)
        service.overrideRetryDelay = 0.5
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("第一次")
        service.injectRecognizedText("第二次")

        XCTAssertEqual(injector.injectCallCount, 1)
    }

    func testRestoreActivates() {
        let ctx = TIContext(capturedPID: 1234, ownBundle: false, frontmost: false)
        let service = makeService(ctx: ctx)
        service.captureTargetApplication()
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("恢复测试")

        let exp = expectation(description: "done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertTrue(ctx.activateCalled)
            XCTAssertEqual(delegate.lastOutcome, .injected)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testRestoreSkipsWhenFrontmost() {
        let ctx = TIContext(capturedPID: 1234, ownBundle: false, frontmost: true)
        let service = makeService(ctx: ctx)
        service.captureTargetApplication()
        heldService = service
        let delegate = TIDelegate()
        service.delegate = delegate

        service.injectRecognizedText("已是前台")

        XCTAssertEqual(delegate.lastOutcome, .injected)
        XCTAssertFalse(ctx.activateCalled)
    }

    // MARK: - Helpers

    private func makeService(
        injector: TIStubInjector = TIStubInjector(),
        ctx: TIContext = TIContext()
    ) -> TextInjectionService {
        let appCtx = AppActivationContext(
            captureFrontmost: { [ctx] in ctx.capturedPID },
            activateApp: { [ctx] _ in ctx.activateCalled = true },
            isFrontmost: { [ctx] _ in ctx.frontmost },
            isOwnBundle: { [ctx] _ in ctx.ownBundle }
        )
        return TextInjectionService(injector: injector, appCtx: appCtx)
    }
}

// MARK: - Test Doubles

final class TIContext {
    var capturedPID: pid_t?
    var ownBundle: Bool
    var frontmost: Bool
    var activateCalled = false

    init(capturedPID: pid_t? = nil, ownBundle: Bool = false, frontmost: Bool = false) {
        self.capturedPID = capturedPID
        self.ownBundle = ownBundle
        self.frontmost = frontmost
    }
}

final class TIStubInjector: TextInjecting {
    var injectedTexts: [String] = []
    var injectCallCount = 0
    var error: TextInjectionError?
    var succeedAfterAttempts: Int = 0

    func inject(_ text: String) throws {
        injectedTexts.append(text)
        injectCallCount += 1
        if succeedAfterAttempts > 0 && injectCallCount >= succeedAfterAttempts { return }
        if let error { throw error }
    }
}

final class TIDelegate: TextInjectionServiceDelegate {
    var lastOutcome: TextInjectionServiceOutcome?
    func textInjectionService(_ service: TextInjectionService, didFinishWithOutcome outcome: TextInjectionServiceOutcome) {
        lastOutcome = outcome
    }
}
