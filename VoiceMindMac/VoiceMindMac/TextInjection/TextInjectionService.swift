import Foundation

// MARK: - Outcome & Delegate

enum TextInjectionServiceOutcome: Equatable {
    case injected
    case permissionRequired(text: String)
    case fallbackToCopy(text: String, reason: String)
}

protocol TextInjectionServiceDelegate: AnyObject {
    func textInjectionService(
        _ service: TextInjectionService,
        didFinishWithOutcome outcome: TextInjectionServiceOutcome
    )
}

// MARK: - App Activation (closure-based)

struct AppActivationContext {
    let captureFrontmost: () -> pid_t?
    let activateApp: (pid_t) -> Void
    let isFrontmost: (pid_t) -> Bool
    let isOwnBundle: (pid_t) -> Bool
}

// MARK: - Service

final class TextInjectionService {
    weak var delegate: TextInjectionServiceDelegate?

    private let coordinator: TextInjectionCoordinator
    private let appCtx: AppActivationContext

    /// 测试用：覆盖重试延迟
    var overrideRetryDelay: TimeInterval?

    private(set) var pendingTargetPID: pid_t?
    private var isInjecting = false

    private let appRestoreDelay: TimeInterval = 0.12
    private let defaultRetryDelay: TimeInterval = 0.08
    private let maxRetryCount = 4

    init(
        injector: TextInjecting,
        appCtx: AppActivationContext
    ) {
        self.coordinator = TextInjectionCoordinator(injector: injector)
        self.appCtx = appCtx
    }

    // MARK: - Target Capture

    func captureTargetApplication() {
        guard let pid = appCtx.captureFrontmost() else {
            pendingTargetPID = nil
            return
        }

        if appCtx.isOwnBundle(pid) {
            pendingTargetPID = nil
            return
        }

        pendingTargetPID = pid
    }

    // MARK: - Main Entry Point

    func injectRecognizedText(_ text: String) {
        print("💉 TextInjectionService.injectRecognizedText: \"\(text.prefix(50))\" isInjecting=\(isInjecting)")
        guard !isInjecting else { return }
        isInjecting = true

        restoreTargetApplicationIfNeeded { [weak self] in
            self?.performInjection(text, remainingRetries: self?.maxRetryCount ?? 0)
        }
    }

    // MARK: - Internal

    private var retryDelay: TimeInterval {
        overrideRetryDelay ?? defaultRetryDelay
    }

    private func restoreTargetApplicationIfNeeded(completion: @escaping () -> Void) {
        guard let pid = pendingTargetPID else {
            completion()
            return
        }

        let alreadyFrontmost = appCtx.isFrontmost(pid)
        pendingTargetPID = nil

        guard !alreadyFrontmost else {
            completion()
            return
        }

        appCtx.activateApp(pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + appRestoreDelay) {
            completion()
        }
    }

    private func performInjection(_ text: String, remainingRetries: Int) {
        print("💉 performInjection: remainingRetries=\(remainingRetries)")
        switch coordinator.deliver(text: text) {
        case .injected:
            isInjecting = false
            print("💉 → injected")
            delegate?.textInjectionService(self, didFinishWithOutcome: .injected)

        case .permissionRequired:
            isInjecting = false
            print("💉 → permissionRequired")
            delegate?.textInjectionService(self, didFinishWithOutcome: .permissionRequired(text: text))

        case .fallbackToCopy(let reason):
            if reason == "No focused input target", remainingRetries > 0 {
                print("💉 → retry in \(retryDelay)s (remainingRetries=\(remainingRetries))")
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.performInjection(text, remainingRetries: remainingRetries - 1)
                }
            } else {
                isInjecting = false
                print("💉 → fallbackToCopy: \(reason)")
                delegate?.textInjectionService(self, didFinishWithOutcome: .fallbackToCopy(text: text, reason: reason))
            }
        }
    }
}
