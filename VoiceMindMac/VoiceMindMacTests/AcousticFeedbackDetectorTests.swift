import Foundation
import XCTest
@testable import VoiceMind

final class AcousticFeedbackDetectorTests: XCTestCase {

    // MARK: - Initial State

    func testInitialSeverityIsNormal() {
        var detector = AcousticFeedbackDetector()
        let result = detector.process(rms: 0.05)
        XCTAssertEqual(result, .normal)
    }

    // MARK: - Steady Low RMS

    func testSteadyLowRmsStaysNormal() {
        var detector = AcousticFeedbackDetector()
        for _ in 0..<30 {
            let result = detector.process(rms: 0.05)
            XCTAssertEqual(result, .normal)
        }
    }

    // MARK: - Rising RMS → Warning

    func testRisingRmsTriggersWarning() {
        var detector = AcousticFeedbackDetector()

        // Feed a steadily rising sequence to trigger warning
        var sawWarning = false
        for i in 0..<30 {
            let rms: Float = 0.01 + Float(i) * 0.02
            let result = detector.process(rms: rms)
            if result == .warning {
                sawWarning = true
            }
        }

        XCTAssertTrue(sawWarning, "Should detect warning after sustained rising RMS")
    }

    // MARK: - High RMS → Critical

    func testHighRmsTriggersCritical() {
        var detector = AcousticFeedbackDetector()

        // Feed very high RMS values to trigger critical directly
        var sawCritical = false
        for _ in 0..<25 {
            let result = detector.process(rms: 0.8)
            if result == .critical {
                sawCritical = true
                break
            }
        }

        XCTAssertTrue(sawCritical, "Should detect critical when RMS is dangerously high")
    }

    // MARK: - Prolonged Critical → Muted

    func testProlongedCriticalTriggersMuted() {
        var detector = AcousticFeedbackDetector()

        // Drive into critical first
        for _ in 0..<25 {
            _ = detector.process(rms: 0.8)
        }

        // Continue feeding high RMS to trigger muted
        var sawMuted = false
        for _ in 0..<20 {
            let result = detector.process(rms: 0.8)
            if result == .muted {
                sawMuted = true
                break
            }
        }

        XCTAssertTrue(sawMuted, "Should mute after prolonged critical state")
    }

    // MARK: - Recovery from Muted

    func testRecoveryFromMutedAfterSilence() {
        var detector = AcousticFeedbackDetector()

        // Drive into muted state
        for _ in 0..<50 {
            _ = detector.process(rms: 0.8)
        }
        XCTAssertEqual(detector.process(rms: 0.8), .muted)

        // Feed silence to allow recovery
        var recovered = false
        for _ in 0..<20 {
            let result = detector.process(rms: 0.05)
            if result == .normal {
                recovered = true
                break
            }
        }

        XCTAssertTrue(recovered, "Should recover to normal after sustained silence")
    }

    // MARK: - Reset

    func testResetReturnsToNormal() {
        var detector = AcousticFeedbackDetector()

        // Drive into a bad state
        for _ in 0..<50 {
            _ = detector.process(rms: 0.8)
        }

        detector.reset()

        // After reset, feeding a normal value should return normal
        let result = detector.process(rms: 0.05)
        XCTAssertEqual(result, .normal)
    }
}
