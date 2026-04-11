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

    // MARK: - 本地识别 showsTranscriptActions

    @Test
    func showsActionsWhenLocalRecognitionResultHasText() {
        let viewModel = ContentViewModel()
        #expect(!viewModel.showsTranscriptActions)

        viewModel.simulateLocalResult("你好世界")

        #expect(viewModel.showsTranscriptActions)
        #expect(viewModel.isLastRecognitionLocal)
    }

    @Test
    func hidesActionsWhenLocalResultIsEmpty() {
        let viewModel = ContentViewModel()
        viewModel.simulateLocalResult("   ")
        #expect(!viewModel.showsTranscriptActions)
    }

    // MARK: - 本地识别 确认/撤销

    @Test
    func localConfirmKeepsTextAndHidesBar() {
        let viewModel = ContentViewModel()
        viewModel.simulateLocalResult("你好")

        #expect(viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.contains("你好"))

        viewModel.confirmTranscriptAction()
        #expect(!viewModel.showsTranscriptActions)
        // 确认后文字保留
        #expect(viewModel.localTranscriptText.contains("你好"))
    }

    @Test
    func localUndoRestoresPreviousTextAndHidesBar() {
        let viewModel = ContentViewModel()
        // 先有一些已有文字
        viewModel.simulateLocalResult("第一段")
        viewModel.confirmTranscriptAction()
        #expect(viewModel.localTranscriptText.contains("第一段"))

        // 再识别一段
        viewModel.simulateLocalResult("第二段")
        #expect(viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.contains("第二段"))

        // 撤销 - 应该恢复到 "第一段"
        viewModel.undoTranscriptAction()
        #expect(!viewModel.showsTranscriptActions)
        #expect(!viewModel.localTranscriptText.contains("第二段"))
        #expect(viewModel.localTranscriptText.contains("第一段"))
    }
}
