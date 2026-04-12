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
    func remoteConfirmSendsKeywordAndKeepsText() {
        let viewModel = ContentViewModel()
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "你好", language: "zh-CN")
        )
        #expect(viewModel.showsTranscriptActions)

        viewModel.confirmTranscriptAction()
        #expect(!viewModel.showsTranscriptActions)
        // 远端确认后文字保留（跟本地确认一样）
        #expect(viewModel.localTranscriptText.contains("你好"))
        #expect(viewModel._testLastSentKeywordAction == .confirm)
    }

    @Test
    func remoteUndoSendsKeywordAndRestoresPreviousText() {
        let viewModel = ContentViewModel()
        // 先有一段已有文字
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s1", text: "第一段", language: "zh-CN")
        )
        viewModel.confirmTranscriptAction()

        // 再来一段远端识别
        viewModel.simulateMacResult(
            ResultPayload(sessionId: "s2", text: "第二段", language: "zh-CN")
        )
        #expect(viewModel.showsTranscriptActions)

        // 撤销 - 应只撤销最后一步，恢复到 "第一段"
        viewModel.undoTranscriptAction()
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel._testLastSentKeywordAction == .undo)
        #expect(!viewModel.localTranscriptText.contains("第二段"))
        #expect(viewModel.localTranscriptText.contains("第一段"))
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

    // MARK: - 本地识别转发到 Mac 的确认/撤销

    @Test
    func localForwardedConfirmSendsKeywordActionToMac() {
        let viewModel = ContentViewModel()
        viewModel.simulateLocalResultWithForward("你好世界", sessionId: "local-s1")

        // 确认后应发送 .confirm keyword action 到 Mac
        viewModel.confirmTranscriptAction()
        #expect(viewModel._testLastSentKeywordAction == .confirm)
        // 本地确认行为：隐藏按钮，保留文字
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.contains("你好世界"))
    }

    @Test
    func localForwardedUndoSendsKeywordActionToMac() {
        let viewModel = ContentViewModel()
        viewModel.simulateLocalResultWithForward("你好世界", sessionId: "local-s2")

        // 撤销后应发送 .undo keyword action 到 Mac
        viewModel.undoTranscriptAction()
        #expect(viewModel._testLastSentKeywordAction == .undo)
        // 本地撤销行为：隐藏按钮，恢复之前的文字
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.isEmpty)
    }

    @Test
    func localNotForwardedConfirmDoesNotSendKeywordAction() {
        let viewModel = ContentViewModel()
        viewModel.simulateLocalResult("不转发")

        viewModel.confirmTranscriptAction()
        // 未转发时不应发送 keyword action
        #expect(viewModel._testLastSentKeywordAction == nil)
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.contains("不转发"))
    }

    @Test
    func localNotForwardedUndoDoesNotSendKeywordAction() {
        let viewModel = ContentViewModel()
        viewModel.simulateLocalResult("不转发")

        viewModel.undoTranscriptAction()
        // 未转发时不应发送 keyword action
        #expect(viewModel._testLastSentKeywordAction == nil)
        #expect(!viewModel.showsTranscriptActions)
    }

    // MARK: - Text Input Mode

    @Test
    func sendTextInputShowsTranscriptActions() {
        let viewModel = ContentViewModel()
        viewModel.simulateTextInputSent("手动输入", sessionId: "ti-1")

        #expect(viewModel.showsTranscriptActions)
        #expect(viewModel.isLastRecognitionLocal == false)
        #expect(viewModel.localTranscriptText.contains("手动输入"))
    }

    @Test
    func textInputConfirmSendsKeywordAction() {
        let viewModel = ContentViewModel()
        viewModel.simulateTextInputSent("确认测试", sessionId: "ti-2")

        viewModel.confirmTranscriptAction()

        #expect(viewModel._testLastSentKeywordAction == .confirm)
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText.contains("确认测试"))
    }

    @Test
    func textInputUndoSendsKeywordActionAndRestoresText() {
        let viewModel = ContentViewModel()
        let previousText = viewModel.localTranscriptText
        viewModel.simulateTextInputSent("撤销测试", sessionId: "ti-3")

        viewModel.undoTranscriptAction()

        #expect(viewModel._testLastSentKeywordAction == .undo)
        #expect(!viewModel.showsTranscriptActions)
        #expect(viewModel.localTranscriptText == previousText)
    }

    @Test
    func canSendTextInputIsFalseWhenDraftEmpty() {
        let viewModel = ContentViewModel()
        viewModel.sendResultsToMacEnabled = true
        viewModel.textInputDraft = "   "

        // Not connected so canSendTextInput will be false
        #expect(!viewModel.canSendTextInput)
    }

    @Test
    func toggleModeCyclesThroughTextInput() {
        let viewModel = ContentViewModel()
        viewModel.sendResultsToMacEnabled = true
        viewModel.preferredHomeTranscriptionMode = .microphone

        viewModel.toggleHomeTranscriptionMode()
        #expect(viewModel.preferredHomeTranscriptionMode == .textInput)

        viewModel.toggleHomeTranscriptionMode()
        #expect(viewModel.preferredHomeTranscriptionMode == .local)
    }
}
