import Foundation

enum FeedbackSeverity: Equatable {
    case normal
    case warning
    case critical
    case muted
}

struct AcousticFeedbackDetector {
    private var rmsHistory: [Float] = []
    private var windowSize: Int = 20
    private var consecutiveCriticalCount: Int = 0
    private var consecutiveLowCount: Int = 0
    private var currentSeverity: FeedbackSeverity = .normal

    private let warningRiseCountThreshold: Int = 12
    private let warningLookback: Int = 15
    private let criticalRmsThreshold: Float = 0.5
    private let warningDurationForCritical: Int = 10
    private let criticalDurationForMuted: Int = 5
    private let recoveryRmsThreshold: Float = 0.1
    private let recoveryDuration: Int = 10

    mutating func process(rms: Float) -> FeedbackSeverity {
        rmsHistory.append(rms)
        if rmsHistory.count > windowSize {
            rmsHistory.removeFirst()
        }

        let detectedRising = detectRisingTrend()
        let highRms = rms > criticalRmsThreshold

        switch currentSeverity {
        case .normal:
            if detectedRising || highRms {
                currentSeverity = .warning
                consecutiveCriticalCount = 0
            }
        case .warning:
            if highRms {
                currentSeverity = .critical
                consecutiveCriticalCount = 1
            } else if detectedRising {
                consecutiveCriticalCount += 1
                if consecutiveCriticalCount >= warningDurationForCritical {
                    currentSeverity = .critical
                    consecutiveCriticalCount = 1
                }
            } else {
                consecutiveCriticalCount = 0
            }
        case .critical:
            consecutiveCriticalCount += 1
            if consecutiveCriticalCount >= criticalDurationForMuted {
                currentSeverity = .muted
            } else if rms < recoveryRmsThreshold {
                consecutiveLowCount += 1
                if consecutiveLowCount >= recoveryDuration {
                    currentSeverity = .normal
                    consecutiveCriticalCount = 0
                    consecutiveLowCount = 0
                }
            } else {
                consecutiveLowCount = 0
            }
        case .muted:
            if rms < recoveryRmsThreshold {
                consecutiveLowCount += 1
                if consecutiveLowCount >= recoveryDuration {
                    currentSeverity = .normal
                    consecutiveCriticalCount = 0
                    consecutiveLowCount = 0
                }
            } else {
                consecutiveLowCount = 0
            }
        }

        return currentSeverity
    }

    mutating func reset() {
        rmsHistory.removeAll()
        consecutiveCriticalCount = 0
        consecutiveLowCount = 0
        currentSeverity = .normal
    }

    private func detectRisingTrend() -> Bool {
        guard rmsHistory.count >= warningLookback else { return false }

        let recent = Array(rmsHistory.suffix(warningLookback))
        var consecutiveRises = 0
        var maxConsecutiveRises = 0

        for i in 1..<recent.count {
            if recent[i] > recent[i - 1] {
                consecutiveRises += 1
                maxConsecutiveRises = max(maxConsecutiveRises, consecutiveRises)
            } else {
                consecutiveRises = 0
            }
        }

        return maxConsecutiveRises >= warningRiseCountThreshold
    }
}
