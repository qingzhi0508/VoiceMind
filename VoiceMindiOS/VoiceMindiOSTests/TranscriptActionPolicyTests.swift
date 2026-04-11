import Testing
@testable import VoiceMind
import SharedCore

struct TranscriptActionPolicyTests {
    // MARK: - showsTranscriptActions 时机

    @Test
    func showsActionsWhenMacRecognitionResultHasText() {
        let viewModel = ContentViewModel()
        #expect(!viewModel.showsTranscriptActions)

        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好世界", language: "zh-CN")
        )

        #expect(viewModel.showsTranscriptActions)
    }

    @Test
    func hidesActionsWhenResultIsEmpty() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "   ", language: "zh-CN")
        )
        #expect(!viewModel.showsTranscriptActions)
    }

    @Test
    func confirmActionHidesActionsAndClearsText() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )
        #expect(viewModel.showsTranscriptActions)

        viewModel.confirmTranscriptAction()
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.isEmpty)
    }

    @Test
    func undoActionHidesActionsAndClearsText() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )
        #expect(viewModel.showsTranscriptActions)

        viewModel.undoTranscriptAction()
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.isEmpty)
    }

    @Test
    func startPushToTalkResetsActions() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )
        #expect(viewModel.showsTranscriptActions)

        // 开始新录音时重置
        viewModel.resetTranscriptActionsForNewRecording()
        #expect(!viewModel.showsTranscriptActions)
    }
}
