import SwiftUI
import Testing
@testable import VoiceMind

struct PrimaryRecognitionLayoutPolicyTests {
    @Test
    func recognitionControlStaysCenteredWhetherTranscriptIsVisibleOrNot() {
        #expect(
            PrimaryRecognitionLayoutPolicy.recognitionControlAlignment(
                showingTranscriptPreview: false
            ) == .center
        )
        #expect(
            PrimaryRecognitionLayoutPolicy.recognitionControlAlignment(
                showingTranscriptPreview: true
            ) == .center
        )
    }
}
