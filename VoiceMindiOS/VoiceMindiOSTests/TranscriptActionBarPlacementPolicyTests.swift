import Testing
@testable import VoiceMind
import SharedCore

struct TranscriptActionBarPlacementPolicyTests {
    @Test
    func showsBarWhenActionsVisible() {
        #expect(
            TranscriptActionBarPlacementPolicy.shouldShowBar(
                showsTranscriptActions: true
            )
        )
    }

    @Test
    func hidesBarWhenActionsNotVisible() {
        #expect(
            !TranscriptActionBarPlacementPolicy.shouldShowBar(
                showsTranscriptActions: false
            )
        )
    }

    @Test
    func hidesBarWhenNewRecording() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )
        #expect(viewModel.showsTranscriptActions)

        viewModel.resetTranscriptActionsForNewRecording()
        #expect(
            !TranscriptActionBarPlacementPolicy.shouldShowBar(
                showsTranscriptActions: viewModel.showsTranscriptActions
            )
        )
    }

    @Test
    func hidesBarWhenConfirmAction() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )

        viewModel.confirmTranscriptAction()
        #expect(
            !TranscriptActionBarPlacementPolicy.shouldShowBar(
                showsTranscriptActions: viewModel.showsTranscriptActions
            )
        )
        // 确认后文字保留（不删除）
        #expect(viewModel.localTranscriptText.contains("你好"))
    }

    @Test
    func hidesBarWhenUndoAction() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )

        viewModel.undoTranscriptAction()
        #expect(
            !TranscriptActionBarPlacementPolicy.shouldShowBar(
                showsTranscriptActions: viewModel.showsTranscriptActions
            )
        )
        #expect(viewModel.localTranscriptText.isEmpty)
    }
}
