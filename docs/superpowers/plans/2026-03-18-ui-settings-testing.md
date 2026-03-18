# UI, Settings Persistence, and Testing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add engine selection UI, persist settings, and implement comprehensive testing for the speech recognition system.

**Architecture:** Extend existing MainWindow with a new Speech Recognition tab, integrate settings persistence on app launch, and add unit/integration tests for core components.

**Tech Stack:** SwiftUI, XCTest, UserDefaults, Combine

---

## File Structure

### New Files
- `VoiceRelayMac/VoiceRelayMac/Views/SpeechRecognitionTab.swift` - UI for engine selection and model management
- `VoiceRelayMac/VoiceRelayMacTests/SpeechRecognitionManagerTests.swift` - Unit tests for manager
- `VoiceRelayMac/VoiceRelayMacTests/AppleSpeechEngineTests.swift` - Unit tests for Apple Speech engine
- `VoiceRelayMac/VoiceRelayMacTests/ModelManagerTests.swift` - Unit tests for model manager
- `VoiceRelayMac/VoiceRelayMacTests/AudioFormatTests.swift` - Audio format conversion tests

### Modified Files
- `VoiceRelayMac/VoiceRelayMac/Views/MainWindow.swift` - Add Speech Recognition tab
- `VoiceRelayMac/VoiceRelayMac/VoiceRelayMacApp.swift` - Load persisted engine selection on launch
- `VoiceRelayMac/VoiceRelayMac/Speech/SpeechRecognitionManager.swift` - Add notification for engine changes

---

## Chunk 1: Speech Recognition UI Tab

### Task 1: Create SpeechRecognitionTab View

**Files:**
- Create: `VoiceRelayMac/VoiceRelayMac/Views/SpeechRecognitionTab.swift`

- [ ] **Step 1: Create basic tab structure**

```swift
import SwiftUI

struct SpeechRecognitionTab: View {
    @ObservedObject var controller: MenuBarController
    @State private var availableEngines: [SpeechRecognitionEngine] = []
    @State private var selectedEngineId: String = ""
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("语音识别引擎")
                .font(.title2)
                .fontWeight(.semibold)

            // Engine selection section
            engineSelectionSection

            Spacer()
        }
        .padding()
        .onAppear {
            refreshEngines()
        }
    }

    @ViewBuilder
    private var engineSelectionSection: some View {
        GroupBox(label: Label("选择识别引擎", systemImage: "waveform.circle")) {
            VStack(alignment: .leading, spacing: 12) {
                if availableEngines.isEmpty {
                    Text("正在加载引擎...")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableEngines, id: \.identifier) { engine in
                        engineRow(engine)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func engineRow(_ engine: SpeechRecognitionEngine) -> some View {
        HStack {
            RadioButton(
                isSelected: selectedEngineId == engine.identifier,
                action: {
                    selectEngine(engine.identifier)
                }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(engine.displayName)
                    .font(.headline)

                HStack {
                    if engine.isAvailable {
                        Label("可用", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Label("不可用", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Text("支持语言: \(engine.supportedLanguages.prefix(3).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func refreshEngines() {
        isRefreshing = true
        availableEngines = SpeechRecognitionManager.shared.availableEngines()
        selectedEngineId = SpeechRecognitionManager.shared.currentEngine?.identifier ?? ""
        isRefreshing = false
    }

    private func selectEngine(_ identifier: String) {
        do {
            try SpeechRecognitionManager.shared.selectEngine(identifier: identifier)
            selectedEngineId = identifier
            UserDefaults.standard.selectedSpeechEngine = identifier

            // Post notification for engine change
            NotificationCenter.default.post(
                name: .speechEngineDidChange,
                object: nil
            )
        } catch {
            print("❌ 选择引擎失败: \(error)")
        }
    }
}

// Radio button component
struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// Notification name extension
extension Notification.Name {
    static let speechEngineDidChange = Notification.Name("speechEngineDidChange")
}
```

- [ ] **Step 2: Build the project to verify syntax**

Run: `xcodebuild -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -configuration Debug build | grep -E "(error|warning)" | head -20`
Expected: No errors related to SpeechRecognitionTab.swift

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMac/Views/SpeechRecognitionTab.swift
git commit -m "feat: add speech recognition engine selection UI

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 2: Integrate Tab into MainWindow

**Files:**
- Modify: `VoiceRelayMac/VoiceRelayMac/Views/MainWindow.swift:12-51`

- [ ] **Step 1: Add Speech Recognition tab**

```swift
TabView(selection: $selectedTab) {
    StatusTab(controller: controller)
        .tabItem {
            Label("状态", systemImage: "antenna.radiowaves.left.and.right")
        }
        .tag(0)

    SettingsTab(settings: settings, controller: controller)
        .tabItem {
            Label("设置", systemImage: "gearshape")
        }
        .tag(1)

    SpeechRecognitionTab(controller: controller)
        .tabItem {
            Label("语音识别", systemImage: "waveform.circle")
        }
        .tag(2)

    DataRecordsTab(controller: controller)
        .tabItem {
            Label("数据", systemImage: "tray.full")
        }
        .tag(3)

    PermissionsTab()
        .tabItem {
            Label("权限", systemImage: "lock.shield")
        }
        .tag(4)

    AboutTab()
        .tabItem {
            Label("关于", systemImage: "info.circle")
        }
        .tag(5)

    PermissionsDebugView()
        .tabItem {
            Label("调试", systemImage: "ladybug")
        }
        .tag(6)
}
.frame(width: 600, height: 600)
```

- [ ] **Step 2: Build to verify integration**

Run: `xcodebuild -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -configuration Debug build | grep -E "(error|warning)" | head -20`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMac/Views/MainWindow.swift
git commit -m "feat: integrate speech recognition tab into main window

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 2: Settings Persistence on Launch

### Task 3: Load Persisted Engine Selection

**Files:**
- Modify: `VoiceRelayMac/VoiceRelayMac/VoiceRelayMacApp.swift`

- [ ] **Step 1: Add engine selection restoration in app launch**

Find the `applicationDidFinishLaunching` method and add after engine registration:

```swift
// Restore previously selected engine
let savedEngineId = UserDefaults.standard.selectedSpeechEngine
if !savedEngineId.isEmpty {
    do {
        try SpeechRecognitionManager.shared.selectEngine(identifier: savedEngineId)
        print("✅ 恢复上次选择的引擎: \(savedEngineId)")
    } catch {
        print("⚠️ 无法恢复引擎 \(savedEngineId)，使用默认引擎")
        // Fallback to apple-speech
        try? SpeechRecognitionManager.shared.selectEngine(identifier: "apple-speech")
    }
} else {
    // First launch, select apple-speech as default
    try? SpeechRecognitionManager.shared.selectEngine(identifier: "apple-speech")
    UserDefaults.standard.selectedSpeechEngine = "apple-speech"
}

// Setup speech recognition delegate
connectionManager.setupSpeechRecognition()
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -configuration Debug build | grep -E "(error|warning)" | head -20`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMac/VoiceRelayMacApp.swift
git commit -m "feat: persist and restore engine selection on app launch

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 3: Unit Tests for SpeechRecognitionManager

### Task 4: Create SpeechRecognitionManager Tests

**Files:**
- Create: `VoiceRelayMac/VoiceRelayMacTests/SpeechRecognitionManagerTests.swift`

- [ ] **Step 1: Write test file structure**

```swift
import XCTest
@testable import VoiceRelayMac

final class SpeechRecognitionManagerTests: XCTestCase {
    var manager: SpeechRecognitionManager!
    var mockEngine: MockSpeechEngine!

    override func setUp() {
        super.setUp()
        manager = SpeechRecognitionManager.shared
        mockEngine = MockSpeechEngine()
    }

    override func tearDown() {
        mockEngine = nil
        super.tearDown()
    }

    func testEngineRegistration() {
        // Given
        let initialCount = manager.availableEngines().count

        // When
        manager.registerEngine(mockEngine)

        // Then
        let newCount = manager.availableEngines().count
        XCTAssertEqual(newCount, initialCount + 1, "Engine should be registered")

        let registered = manager.getEngine(identifier: mockEngine.identifier)
        XCTAssertNotNil(registered, "Registered engine should be retrievable")
        XCTAssertEqual(registered?.identifier, mockEngine.identifier)
    }

    func testEngineSelection() throws {
        // Given
        manager.registerEngine(mockEngine)

        // When
        try manager.selectEngine(identifier: mockEngine.identifier)

        // Then
        XCTAssertEqual(manager.currentEngine?.identifier, mockEngine.identifier)
    }

    func testEngineSelectionWithInvalidId() {
        // Given
        let invalidId = "non-existent-engine"

        // When/Then
        XCTAssertThrowsError(try manager.selectEngine(identifier: invalidId)) { error in
            XCTAssertTrue(error is SpeechError)
        }
    }

    func testFallbackToAppleSpeech() throws {
        // Given
        mockEngine.mockIsAvailable = false
        manager.registerEngine(mockEngine)
        try manager.selectEngine(identifier: mockEngine.identifier)

        // When
        XCTAssertThrowsError(try manager.startRecognition(sessionId: "test", language: "zh-CN"))

        // Then - should fallback to apple-speech
        XCTAssertEqual(manager.currentEngine?.identifier, "apple-speech")
    }
}

// Mock engine for testing
class MockSpeechEngine: NSObject, SpeechRecognitionEngine {
    let identifier = "mock-engine"
    let displayName = "Mock Engine"
    let supportsStreaming = true
    var supportedLanguages: [String] = ["zh-CN", "en-US"]
    var mockIsAvailable = true
    var isAvailable: Bool { mockIsAvailable }
    weak var delegate: SpeechRecognitionEngineDelegate?

    var initializeCalled = false
    var startRecognitionCalled = false
    var processAudioDataCalled = false
    var stopRecognitionCalled = false

    func initialize() async throws {
        initializeCalled = true
    }

    func startRecognition(sessionId: String, language: String) throws {
        startRecognitionCalled = true
    }

    func processAudioData(_ data: Data) throws {
        processAudioDataCalled = true
    }

    func stopRecognition() throws {
        stopRecognitionCalled = true
    }
}
```

- [ ] **Step 2: Run tests**

Run: `xcodebuild test -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -destination 'platform=macOS' | grep -E "(Test|PASS|FAIL)"`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMacTests/SpeechRecognitionManagerTests.swift
git commit -m "test: add unit tests for SpeechRecognitionManager

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 4: Audio Format Conversion Tests

### Task 5: Create Audio Format Tests

**Files:**
- Create: `VoiceRelayMac/VoiceRelayMacTests/AudioFormatTests.swift`

- [ ] **Step 1: Write audio format conversion tests**

```swift
import XCTest
import AVFoundation
@testable import VoiceRelayMac

final class AudioFormatTests: XCTestCase {

    func testInt16ToFloat32Conversion() {
        // Given - Create sample Int16 PCM data
        let samples: [Int16] = [0, Int16.max, Int16.min, Int16.max / 2]
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size)

        // When - Convert to Float32
        let floatSamples = convertInt16ToFloat32(data)

        // Then - Verify conversion
        XCTAssertEqual(floatSamples.count, samples.count)
        XCTAssertEqual(floatSamples[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(floatSamples[1], 1.0, accuracy: 0.001)
        XCTAssertEqual(floatSamples[2], -1.0, accuracy: 0.001)
        XCTAssertEqual(floatSamples[3], 0.5, accuracy: 0.001)
    }

    func testAudioBufferCreation() {
        // Given
        let sampleRate: Double = 16000
        let channels: AVAudioChannelCount = 1
        let frameCount: AVAudioFrameCount = 1024

        // When
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            XCTFail("Failed to create audio format")
            return
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            XCTFail("Failed to create audio buffer")
            return
        }

        // Then
        XCTAssertEqual(buffer.format.sampleRate, sampleRate)
        XCTAssertEqual(buffer.format.channelCount, channels)
        XCTAssertEqual(buffer.frameCapacity, frameCount)
    }

    func testEmptyDataConversion() {
        // Given
        let emptyData = Data()

        // When
        let floatSamples = convertInt16ToFloat32(emptyData)

        // Then
        XCTAssertTrue(floatSamples.isEmpty)
    }

    // Helper function
    private func convertInt16ToFloat32(_ data: Data) -> [Float] {
        let int16Array = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int16>(
                start: $0.baseAddress?.assumingMemoryBound(to: Int16.self),
                count: data.count / 2
            ))
        }

        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}
```

- [ ] **Step 2: Run tests**

Run: `xcodebuild test -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -destination 'platform=macOS' -only-testing:VoiceRelayMacTests/AudioFormatTests | grep -E "(Test|PASS|FAIL)"`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMacTests/AudioFormatTests.swift
git commit -m "test: add audio format conversion tests

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 5: Integration Tests

### Task 6: Create Integration Tests

**Files:**
- Create: `VoiceRelayMac/VoiceRelayMacTests/SpeechRecognitionIntegrationTests.swift`

- [ ] **Step 1: Write integration tests**

```swift
import XCTest
@testable import VoiceRelayMac

final class SpeechRecognitionIntegrationTests: XCTestCase {
    var manager: SpeechRecognitionManager!
    var mockDelegate: MockEngineDelegate!

    override func setUp() {
        super.setUp()
        manager = SpeechRecognitionManager.shared
        mockDelegate = MockEngineDelegate()
    }

    override func tearDown() {
        mockDelegate = nil
        super.tearDown()
    }

    func testEndToEndRecognitionFlow() throws {
        // Given - Register and select mock engine
        let mockEngine = MockSpeechEngine()
        mockEngine.delegate = mockDelegate
        manager.registerEngine(mockEngine)
        try manager.selectEngine(identifier: mockEngine.identifier)

        let sessionId = "test-session-123"
        let language = "zh-CN"

        // When - Start recognition
        try manager.startRecognition(sessionId: sessionId, language: language)
        XCTAssertTrue(mockEngine.startRecognitionCalled)

        // Process audio data
        let audioData = Data(repeating: 0, count: 1024)
        try manager.processAudioData(audioData)
        XCTAssertTrue(mockEngine.processAudioDataCalled)

        // Stop recognition
        try manager.stopRecognition()
        XCTAssertTrue(mockEngine.stopRecognitionCalled)

        // Then - Verify delegate was called
        XCTAssertTrue(mockDelegate.didRecognizeTextCalled)
    }

    func testEngineNotAvailableFallback() throws {
        // Given - Unavailable engine
        let unavailableEngine = MockSpeechEngine()
        unavailableEngine.mockIsAvailable = false
        manager.registerEngine(unavailableEngine)
        try manager.selectEngine(identifier: unavailableEngine.identifier)

        // When - Try to start recognition
        XCTAssertThrowsError(try manager.startRecognition(sessionId: "test", language: "zh-CN"))

        // Then - Should fallback to apple-speech
        XCTAssertEqual(manager.currentEngine?.identifier, "apple-speech")
    }

    func testMultipleEnginesSwitching() throws {
        // Given - Two engines
        let engine1 = MockSpeechEngine()
        let engine2 = MockSpeechEngine()
        engine2.identifier = "mock-engine-2"

        manager.registerEngine(engine1)
        manager.registerEngine(engine2)

        // When - Switch between engines
        try manager.selectEngine(identifier: engine1.identifier)
        XCTAssertEqual(manager.currentEngine?.identifier, engine1.identifier)

        try manager.selectEngine(identifier: engine2.identifier)
        XCTAssertEqual(manager.currentEngine?.identifier, engine2.identifier)

        // Then - Both engines should be available
        let engines = manager.availableEngines()
        XCTAssertTrue(engines.contains { $0.identifier == engine1.identifier })
        XCTAssertTrue(engines.contains { $0.identifier == engine2.identifier })
    }
}

// Mock delegate for testing
class MockEngineDelegate: SpeechRecognitionEngineDelegate {
    var didRecognizeTextCalled = false
    var didFailWithErrorCalled = false
    var didReceivePartialResultCalled = false

    var recognizedText: String?
    var error: Error?
    var partialResult: String?

    func engine(_ engine: SpeechRecognitionEngine, didRecognizeText text: String, sessionId: String, language: String) {
        didRecognizeTextCalled = true
        recognizedText = text
    }

    func engine(_ engine: SpeechRecognitionEngine, didFailWithError error: Error, sessionId: String) {
        didFailWithErrorCalled = true
        self.error = error
    }

    func engine(_ engine: SpeechRecognitionEngine, didReceivePartialResult text: String, sessionId: String) {
        didReceivePartialResultCalled = true
        partialResult = text
    }
}
```

- [ ] **Step 2: Run integration tests**

Run: `xcodebuild test -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -destination 'platform=macOS' -only-testing:VoiceRelayMacTests/SpeechRecognitionIntegrationTests | grep -E "(Test|PASS|FAIL)"`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMacTests/SpeechRecognitionIntegrationTests.swift
git commit -m "test: add integration tests for speech recognition flow

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 6: Model Management UI (Optional Enhancement)

### Task 7: Add Model Management Section

**Files:**
- Modify: `VoiceRelayMac/VoiceRelayMac/Views/SpeechRecognitionTab.swift`

- [ ] **Step 1: Add model management section**

Add after `engineSelectionSection`:

```swift
Divider()
    .padding(.vertical)

// Model management section
modelManagementSection

@ViewBuilder
private var modelManagementSection: some View {
    GroupBox(label: Label("模型管理", systemImage: "square.and.arrow.down")) {
        VStack(alignment: .leading, spacing: 12) {
            Text("管理本地语音识别模型")
                .font(.caption)
                .foregroundColor(.secondary)

            if let senseVoiceEngine = availableEngines.first(where: { $0.identifier == "sensevoice" }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SenseVoice Small")
                            .font(.headline)

                        Text("多语言语音识别模型，约 85MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if senseVoiceEngine.isAvailable {
                        Label("已下载", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Button("下载模型") {
                            // TODO: Implement model download
                            print("下载 SenseVoice 模型")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("SenseVoice 引擎未注册")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -configuration Debug build | grep -E "(error|warning)" | head -20`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add VoiceRelayMac/VoiceRelayMac/Views/SpeechRecognitionTab.swift
git commit -m "feat: add model management section to speech recognition tab

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Verification Steps

After completing all tasks:

1. **Build the project**
   ```bash
   xcodebuild -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -configuration Debug build
   ```

2. **Run all tests**
   ```bash
   xcodebuild test -workspace VoiceRelay.xcworkspace -scheme VoiceRelayMac -destination 'platform=macOS'
   ```

3. **Manual testing**
   - Launch the app
   - Open the main window (显示状态)
   - Navigate to "语音识别" tab
   - Verify engine selection UI is visible
   - Select different engines and verify selection persists
   - Restart the app and verify the selected engine is restored

4. **Test engine switching**
   - Select Apple Speech engine
   - Start a voice recognition session from iOS
   - Verify recognition works
   - Stop the session
   - Switch to SenseVoice (if available)
   - Start another session
   - Verify the new engine is used

---

## Notes

- The UI follows existing patterns in MainWindow.swift
- Settings persistence uses the existing UserDefaults+Speech.swift extension
- Tests use XCTest framework, following Apple's testing guidelines
- Mock objects are used to isolate unit tests from actual speech recognition
- Integration tests verify the complete flow from manager to engine

## Future Enhancements

- Add model download progress UI
- Add model deletion functionality
- Add engine performance metrics
- Add A/B testing for engine comparison
- Add custom model support
