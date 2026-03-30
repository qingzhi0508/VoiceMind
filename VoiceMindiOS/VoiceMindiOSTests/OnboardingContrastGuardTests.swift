import Foundation
import Testing

struct OnboardingContrastGuardTests {
    @Test
    func onboardingCopyDoesNotUseWhiteForegroundText() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let onboardingViewURL = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("VoiceMindiOS/Views/OnboardingView.swift")

        let source = try String(contentsOf: onboardingViewURL, encoding: .utf8)

        #expect(!source.contains(".foregroundStyle(.white"))
    }
}
