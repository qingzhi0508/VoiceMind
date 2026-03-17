import Foundation

class ReconnectionManager {
    private var currentDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 10.0
    private let backoffMultiplier: TimeInterval = 2.0
    private let maxAttempts = 3

    private var reconnectTimer: Timer?
    private var onReconnect: (() -> Void)?
    private var onExhausted: (() -> Void)?
    private var attemptCount = 0

    func scheduleReconnect(onReconnect: @escaping () -> Void, onExhausted: @escaping () -> Void) {
        guard attemptCount < maxAttempts else {
            onExhausted()
            return
        }

        self.onReconnect = onReconnect
        self.onExhausted = onExhausted

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: currentDelay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.attemptCount += 1
            self.onReconnect?()
            self.increaseDelay()
        }

        print("Reconnecting in \(currentDelay)s (attempt \(attemptCount + 1)/\(maxAttempts))")
    }

    func reset() {
        currentDelay = 1.0
        attemptCount = 0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        onReconnect = nil
        onExhausted = nil
    }

    private func increaseDelay() {
        currentDelay = min(currentDelay * backoffMultiplier, maxDelay)
    }
}
