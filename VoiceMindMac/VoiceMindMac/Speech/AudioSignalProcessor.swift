import Foundation

struct AudioSignalProcessingResult {
    let effectiveGain: Float
    let gateLevel: Float
}

struct AudioSignalProcessor {
    // MARK: - AGC State
    private var agcGain: Float = 4.0
    private var agcRmsSmoothed: Float = 0

    // MARK: - Parameters
    private let targetRms: Float = 0.6
    private let rmsSmoothing: Float = 0.92
    private let agcSpeed: Float = 0.1
    private let maxGain: Float = 12.0
    private let minGain: Float = 0.5

    // MARK: - Noise Gate State
    private var gateLevel: Float = 1.0
    private let gateThreshold: Float = 0.03
    private let gateAttackRate: Float = 0.1
    private let gateReleaseRate: Float = 0.01

    mutating func process(rms: Float, feedbackSeverity: FeedbackSeverity) -> AudioSignalProcessingResult {
        // AGC: smooth RMS and adjust gain
        agcRmsSmoothed = rmsSmoothing * agcRmsSmoothed + (1 - rmsSmoothing) * rms
        let targetGain = targetRms / max(agcRmsSmoothed, 0.001)
        let clampedTarget = max(min(targetGain, maxGain), minGain)
        agcGain += agcSpeed * (clampedTarget - agcGain)

        // Noise gate
        let targetGate: Float = rms > gateThreshold ? 1.0 : 0.0
        let gateRate = targetGate > gateLevel ? gateAttackRate : gateReleaseRate
        gateLevel += gateRate * (targetGate - gateLevel)

        // Base effective gain
        var effectiveGain = agcGain * gateLevel

        // Feedback suppression
        switch feedbackSeverity {
        case .normal:
            break
        case .warning:
            effectiveGain *= 0.7
        case .critical:
            effectiveGain *= 0.4
        case .muted:
            effectiveGain = 0.0
        }

        return AudioSignalProcessingResult(effectiveGain: effectiveGain, gateLevel: gateLevel)
    }
}
