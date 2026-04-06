import XCTest

final class StartupViewSizingTests: XCTestCase {
    func testOnboardingFlowRootUsesScaledCanvasSize() throws {
        let source = try onboardingFlowSource()

        XCTAssertTrue(
            source.contains(".frame(width: 400, height: 480)"),
            "Onboarding flow should use the scaled 400 by 480 canvas."
        )
    }

    func testUsageGuideRootUsesScaledCanvasSize() throws {
        let source = try usageGuideSource()

        XCTAssertTrue(
            source.contains(".frame(width: 416, height: 448)"),
            "Usage guide should use the scaled 416 by 448 canvas."
        )
    }

    private func onboardingFlowSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/MenuBar/OnboardingFlow.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func usageGuideSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let projectRoot = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("VoiceMindMac/VoiceMindMac/Views/UsageGuideView.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
