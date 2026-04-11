import Foundation
import XCTest
@testable import VoiceMind

final class RemoteMicrophoneMonitorPlayerTests: XCTestCase {

    // MARK: - AGC Behavior

    func testLowRmsIncreasesGain() {
        var processor = AudioSignalProcessor()

        // Feed very quiet input — AGC should increase gain
        let quietRms: Float = 0.001
        let result = processor.process(rms: quietRms, feedbackSeverity: .normal)

        // Initial gain is 4.0; with RMS well below gate threshold the gate starts closing
        // but even with gate attenuating, effective gain should still be > 1.0
        XCTAssertGreaterThan(result.effectiveGain, 1.0, "AGC should increase gain for quiet input")
    }

    func testHighRmsDecreasesGain() {
        var processor = AudioSignalProcessor()

        // Feed very loud input repeatedly — AGC should decrease gain below initial value
        let loudRms: Float = 0.8
        var lastGain: Float = 0
        for _ in 0..<80 {
            let result = processor.process(rms: loudRms, feedbackSeverity: .normal)
            lastGain = result.effectiveGain
        }

        // After sustained very loud input (RMS > targetRms), gain should drop below 1.0
        XCTAssertLessThan(lastGain, 1.0, "AGC should decrease gain after sustained loud input")
    }

    // MARK: - Noise Gate

    func testNoiseGateClosesBelowThreshold() {
        var processor = AudioSignalProcessor()

        // Feed very quiet signal (below threshold)
        let quietRms: Float = 0.001
        let result = processor.process(rms: quietRms, feedbackSeverity: .normal)

        // Gate should be closing (gateLevel < 1.0)
        // Note: gateLevel may not be 0 yet due to smooth transition
        XCTAssertLessThan(result.gateLevel, 1.0, "Noise gate should start closing for quiet input")
    }

    func testNoiseGateOpensAboveThreshold() {
        var processor = AudioSignalProcessor()

        // Feed signal above threshold
        let loudRms: Float = 0.1
        let result = processor.process(rms: loudRms, feedbackSeverity: .normal)

        // Gate should be open (gateLevel close to 1.0)
        XCTAssertGreaterThan(result.gateLevel, 0.5, "Noise gate should be open for signal above threshold")
    }

    // MARK: - Feedback Suppression

    func testFeedbackWarningReducesGain() {
        var processor = AudioSignalProcessor()

        let normalResult = processor.process(rms: 0.05, feedbackSeverity: .normal)
        var processor2 = AudioSignalProcessor()
        let warningResult = processor2.process(rms: 0.05, feedbackSeverity: .warning)

        // Warning should apply 0.7 multiplier (reduced suppression for louder monitoring)
        let expectedRatio = warningResult.effectiveGain / normalResult.effectiveGain
        XCTAssertEqual(expectedRatio, 0.7, accuracy: 0.01, "Warning should reduce effective gain to 70%")
    }

    func testFeedbackMutedZeroesOutput() {
        var processor = AudioSignalProcessor()

        let result = processor.process(rms: 0.05, feedbackSeverity: .muted)

        XCTAssertEqual(result.effectiveGain, 0.0, "Muted should produce zero effective gain")
    }
}
