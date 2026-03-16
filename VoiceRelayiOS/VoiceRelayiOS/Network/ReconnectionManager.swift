import Foundation

class ReconnectionManager {
    private var currentDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 10.0
    private let backoffMultiplier: TimeInterval = 2.0

    private var reconnectTimer: Timer?
    private var onReconnect: (() -> Void)?

    func scheduleReconnect(onReconnect: @escaping () -> Void) {
        self.onReconnect = onReconnect

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: currentDelay, repeats: false) { [weak self] _ in
            self?.onReconnect?()
            self?.increaseDelay()
        }

        print("Reconnecting in \(currentDelay)s")
    }

    func reset() {
        currentDelay = 1.0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func increaseDelay() {
        currentDelay = min(currentDelay * backoffMultiplier, maxDelay)
    }
}
