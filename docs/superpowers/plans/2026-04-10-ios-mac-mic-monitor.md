# iOS Mac Mic Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an iOS-side microphone relay toggle that, during iPhone home-screen `Mac` mode push-to-talk sessions, streams microphone audio to the Mac for both speech recognition and low-latency speaker playback.

**Architecture:** Reuse the existing `audioStart/audioData/audioEnd` PCM stream between iPhone and Mac, extend `AudioStartPayload` with a session-scoped `playThroughMacSpeaker` flag, and keep the iOS decision logic in small policy/settings helpers. On macOS, introduce a dedicated remote microphone monitor controller/player so speaker playback can fail independently without breaking speech recognition.

**Tech Stack:** Swift, Swift Testing, XCTest, SwiftUI, AVFoundation, SharedCore protocol models, `xcodebuild`, `swift test`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift` | Add `playThroughMacSpeaker` to `AudioStartPayload` with backward-compatible decoding |
| Modify | `SharedCore/Tests/SharedCoreTests/MessagePayloadsTests.swift` | Cover `AudioStartPayload` encode/decode and missing-field fallback |
| Create | `VoiceMindiOS/VoiceMindiOS/ViewModels/MacMicrophoneMonitorSettings.swift` | Persist the new iOS setting through `UserDefaults` |
| Create | `VoiceMindiOS/VoiceMindiOS/ViewModels/MacMicrophoneMonitorPolicy.swift` | Decide when the setting is visible and when a session should request Mac speaker playback |
| Create | `VoiceMindiOS/VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests.swift` | Verify preference persistence in an isolated test suite |
| Create | `VoiceMindiOS/VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests.swift` | Verify settings visibility and `Mac`-mode-only session routing rules |
| Modify | `VoiceMindiOS/VoiceMindiOS/Speech/AudioStreamController.swift` | Accept a per-session speaker-playback flag and include it in `AudioStartPayload` |
| Modify | `VoiceMindiOS/VoiceMindiOS/ViewModels/ContentViewModel.swift` | Load/store the setting, decide when to pass the flag, keep `startListen` sessions at `false` |
| Modify | `VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift` | Add the new toggle under the existing “send to Mac” control |
| Modify | `VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings` | Add Chinese strings for the new toggle and helper text |
| Modify | `VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings` | Add English strings for the new toggle and helper text |
| Create | `VoiceMindMac/VoiceMindMac/Speech/RemoteMicrophoneMonitorPlayer.swift` | Concrete low-latency PCM player built on `AVAudioEngine + AVAudioPlayerNode` |
| Create | `VoiceMindMac/VoiceMindMac/Speech/RemoteMicrophoneMonitorController.swift` | Session-aware coordinator that starts, appends, and stops speaker playback independently from recognition |
| Create | `VoiceMindMac/VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests.swift` | Verify start/append/stop behavior and graceful degradation when playback fails |
| Modify | `VoiceMindMac/VoiceMindMac/Network/ConnectionManager.swift` | Read the new audio-start flag and route PCM to both recognition and playback |

---

### Task 1: Extend SharedCore AudioStartPayload

**Files:**
- Modify: `SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift`
- Modify: `SharedCore/Tests/SharedCoreTests/MessagePayloadsTests.swift`

- [ ] **Step 1: Write the failing payload tests**

```swift
func testAudioStartPayloadRoundTripsSpeakerPlaybackFlag() throws {
    let payload = AudioStartPayload(
        sessionId: "session-1",
        language: "zh-CN",
        sampleRate: 16_000,
        channels: 1,
        format: "pcm16",
        playThroughMacSpeaker: true
    )

    let encoded = try JSONEncoder().encode(payload)
    let decoded = try JSONDecoder().decode(AudioStartPayload.self, from: encoded)

    XCTAssertTrue(decoded.playThroughMacSpeaker)
}

func testAudioStartPayloadDefaultsSpeakerPlaybackFlagToFalseWhenMissing() throws {
    let json = """
    {"sessionId":"session-1","language":"zh-CN","sampleRate":16000,"channels":1,"format":"pcm16"}
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(AudioStartPayload.self, from: json)

    XCTAssertFalse(decoded.playThroughMacSpeaker)
}
```

- [ ] **Step 2: Run the SharedCore payload tests to confirm RED**

Run: `swift test --package-path /Users/cayden/Data/my-data/voiceMind/SharedCore --filter MessagePayloadsTests`

Expected: FAIL because `AudioStartPayload` does not yet expose or decode `playThroughMacSpeaker`.

- [ ] **Step 3: Add the new field with backward-compatible decoding**

```swift
public struct AudioStartPayload: Codable {
    public let sessionId: String
    public let language: String
    public let sampleRate: Int
    public let channels: Int
    public let format: String
    public let playThroughMacSpeaker: Bool

    public init(
        sessionId: String,
        language: String,
        sampleRate: Int,
        channels: Int,
        format: String = "pcm16",
        playThroughMacSpeaker: Bool = false
    ) {
        self.sessionId = sessionId
        self.language = language
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.playThroughMacSpeaker = playThroughMacSpeaker
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        language = try container.decode(String.self, forKey: .language)
        sampleRate = try container.decode(Int.self, forKey: .sampleRate)
        channels = try container.decode(Int.self, forKey: .channels)
        format = try container.decode(String.self, forKey: .format)
        playThroughMacSpeaker = try container.decodeIfPresent(Bool.self, forKey: .playThroughMacSpeaker) ?? false
    }
}
```

- [ ] **Step 4: Re-run the SharedCore payload tests to confirm GREEN**

Run: `swift test --package-path /Users/cayden/Data/my-data/voiceMind/SharedCore --filter MessagePayloadsTests`

Expected: PASS with the new round-trip and missing-field tests green.

- [ ] **Step 5: Commit the protocol change**

```bash
git add SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift SharedCore/Tests/SharedCoreTests/MessagePayloadsTests.swift
git commit -m "feat(shared): add speaker playback flag to audio start payload"
```

---

### Task 2: Add iOS Monitor Settings and Decision Policy

**Files:**
- Create: `VoiceMindiOS/VoiceMindiOS/ViewModels/MacMicrophoneMonitorSettings.swift`
- Create: `VoiceMindiOS/VoiceMindiOS/ViewModels/MacMicrophoneMonitorPolicy.swift`
- Create: `VoiceMindiOS/VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests.swift`
- Create: `VoiceMindiOS/VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests.swift`

- [ ] **Step 1: Write the failing iOS settings and policy tests**

```swift
@Test
func settingsStoreDefaultsToDisabled() {
    let suiteName = "MacMicrophoneMonitorSettingsTests-default"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    #expect(!MacMicrophoneMonitorSettings.load(from: defaults))
}

@Test
func settingsStoreRoundTripsEnabledValue() {
    let suiteName = "MacMicrophoneMonitorSettingsTests-roundtrip"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    MacMicrophoneMonitorSettings.store(true, in: defaults)

    #expect(MacMicrophoneMonitorSettings.load(from: defaults))
}

@Test
func speakerPlaybackRequiresMacModeSyncToggleAndMicMonitorToggle() {
    #expect(
        MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
            sendToMacEnabled: true,
            preferredMode: .mac,
            microphoneMonitorEnabled: true
        )
    )

    #expect(
        !MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
            sendToMacEnabled: true,
            preferredMode: .local,
            microphoneMonitorEnabled: true
        )
    )
}

@Test
func settingsToggleIsHiddenWhenMacSyncIsDisabled() {
    #expect(!MacMicrophoneMonitorPolicy.shouldShowToggle(sendToMacEnabled: false))
    #expect(MacMicrophoneMonitorPolicy.shouldShowToggle(sendToMacEnabled: true))
}
```

- [ ] **Step 2: Run the focused iOS tests to confirm RED**

Run: `xcodebuild test -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests`

Expected: FAIL because the new settings and policy types do not exist yet.

- [ ] **Step 3: Add the preference store and policy helpers**

```swift
enum MacMicrophoneMonitorSettings {
    static let storageKey = "voicemind.playMicrophoneThroughMacSpeaker"

    static func load(from defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    static func store(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: storageKey)
    }
}

enum MacMicrophoneMonitorPolicy {
    static func shouldShowToggle(sendToMacEnabled: Bool) -> Bool {
        sendToMacEnabled
    }

    static func shouldPlayThroughMacSpeaker(
        sendToMacEnabled: Bool,
        preferredMode: HomeTranscriptionMode,
        microphoneMonitorEnabled: Bool
    ) -> Bool {
        sendToMacEnabled && preferredMode == .mac && microphoneMonitorEnabled
    }
}
```

- [ ] **Step 4: Re-run the focused iOS tests to confirm GREEN**

Run: `xcodebuild test -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests`

Expected: PASS with both new test files green.

- [ ] **Step 5: Commit the iOS helper layer**

```bash
git add VoiceMindiOS/VoiceMindiOS/ViewModels/MacMicrophoneMonitorSettings.swift VoiceMindiOS/VoiceMindiOS/ViewModels/MacMicrophoneMonitorPolicy.swift VoiceMindiOS/VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests.swift VoiceMindiOS/VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests.swift
git commit -m "feat(ios): add microphone monitor settings helpers"
```

---

### Task 3: Wire the iOS Setting Into Sessions and Settings UI

**Files:**
- Modify: `VoiceMindiOS/VoiceMindiOS/Speech/AudioStreamController.swift`
- Modify: `VoiceMindiOS/VoiceMindiOS/ViewModels/ContentViewModel.swift`
- Modify: `VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- Modify: `VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings`

- [ ] **Step 1: Update the streaming API to accept a session-scoped speaker flag**

```swift
func startStreaming(sessionId: String, playThroughMacSpeaker: Bool = false) throws {
    ...
    delegate?.audioStreamController(
        self,
        didStartStream: AudioStartPayload(
            sessionId: sessionId,
            language: selectedLanguage,
            sampleRate: Int(sampleRate),
            channels: Int(channels),
            format: "pcm16",
            playThroughMacSpeaker: playThroughMacSpeaker
        )
    )
}
```

- [ ] **Step 2: Persist the new setting and decide when to request playback**

```swift
@Published var playMicrophoneThroughMacSpeakerEnabled: Bool {
    didSet { MacMicrophoneMonitorSettings.store(playMicrophoneThroughMacSpeakerEnabled) }
}

private var shouldPlayThroughMacSpeakerOnMac: Bool {
    MacMicrophoneMonitorPolicy.shouldPlayThroughMacSpeaker(
        sendToMacEnabled: sendResultsToMacEnabled,
        preferredMode: effectiveHomeTranscriptionMode,
        microphoneMonitorEnabled: playMicrophoneThroughMacSpeakerEnabled
    )
}
```

Use that computed value in `startPushToTalk()`:

```swift
try audioStreamController.startStreaming(
    sessionId: sessionId,
    playThroughMacSpeaker: shouldPlayThroughMacSpeakerOnMac
)
```

Keep `handleStartListen(_:)` explicitly off:

```swift
try audioStreamController.startStreaming(
    sessionId: payload.sessionId,
    playThroughMacSpeaker: false
)
```

- [ ] **Step 3: Add the settings toggle under “send to Mac”**

```swift
if MacMicrophoneMonitorPolicy.shouldShowToggle(sendToMacEnabled: viewModel.sendResultsToMacEnabled) {
    Toggle(
        String(localized: "settings_send_to_mac_microphone_title"),
        isOn: Binding(
            get: { viewModel.playMicrophoneThroughMacSpeakerEnabled },
            set: { viewModel.playMicrophoneThroughMacSpeakerEnabled = $0 }
        )
    )

    Text(String(localized: "settings_send_to_mac_microphone_footer"))
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

- [ ] **Step 4: Add localized copy for the new control**

```text
"settings_send_to_mac_microphone_title" = "话筒";
"settings_send_to_mac_microphone_footer" = "在 Mac 模式按住说话时，同时从电脑喇叭播放手机麦克风声音。";
```

```text
"settings_send_to_mac_microphone_title" = "Microphone";
"settings_send_to_mac_microphone_footer" = "In Mac mode, hold to talk and also play the iPhone microphone through your Mac speakers.";
```

- [ ] **Step 5: Run the focused iOS test suite and a build**

Run: `xcodebuild test -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests -only-testing:VoiceMindiOSTests/LocalTranscriptionPolicyTests`

Expected: PASS.

Run: `xcodebuild build -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'generic/platform=iOS Simulator'`

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit the iOS wiring**

```bash
git add VoiceMindiOS/VoiceMindiOS/Speech/AudioStreamController.swift VoiceMindiOS/VoiceMindiOS/ViewModels/ContentViewModel.swift VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat(ios): add microphone relay toggle for Mac mode"
```

---

### Task 4: Build a macOS Remote Microphone Monitor Controller

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Speech/RemoteMicrophoneMonitorPlayer.swift`
- Create: `VoiceMindMac/VoiceMindMac/Speech/RemoteMicrophoneMonitorController.swift`
- Create: `VoiceMindMac/VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests.swift`

- [ ] **Step 1: Write failing controller tests with a mock player**

```swift
func testStartRelayBootsPlayerOnlyWhenFlagIsEnabled() throws {
    let player = MockRemoteMicrophoneMonitorPlayer()
    let controller = RemoteMicrophoneMonitorController(player: player)

    try controller.startSession(
        sessionId: "session-1",
        sampleRate: 16_000,
        channels: 1,
        format: "pcm16",
        playThroughMacSpeaker: true
    )

    XCTAssertEqual(player.startCalls.count, 1)
}

func testAppendAudioIsIgnoredWhenPlaybackIsDisabled() throws {
    let player = MockRemoteMicrophoneMonitorPlayer()
    let controller = RemoteMicrophoneMonitorController(player: player)

    try controller.startSession(
        sessionId: "session-1",
        sampleRate: 16_000,
        channels: 1,
        format: "pcm16",
        playThroughMacSpeaker: false
    )

    try controller.appendAudio(Data([0x00, 0x01]), sessionId: "session-1")

    XCTAssertTrue(player.appendedData.isEmpty)
}

func testPlaybackFailureDisablesRelayButDoesNotThrowPastController() throws {
    let player = MockRemoteMicrophoneMonitorPlayer()
    player.errorOnAppend = MonitorPlaybackError.deviceUnavailable
    let controller = RemoteMicrophoneMonitorController(player: player)

    try controller.startSession(
        sessionId: "session-1",
        sampleRate: 16_000,
        channels: 1,
        format: "pcm16",
        playThroughMacSpeaker: true
    )

    XCTAssertNoThrow(try controller.appendAudio(Data([0x00, 0x01]), sessionId: "session-1"))
    XCTAssertFalse(controller.isRelayActive)
}
```

- [ ] **Step 2: Run the macOS controller tests to confirm RED**

Run: `xcodebuild test -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests`

Expected: FAIL because the controller and player do not exist yet.

- [ ] **Step 3: Implement the player protocol, concrete player, and controller**

```swift
protocol RemoteMicrophoneMonitorPlaying {
    func start(sampleRate: Double, channels: AVAudioChannelCount, format: String) throws
    func appendPCM16(_ data: Data) throws
    func stop()
}

final class RemoteMicrophoneMonitorController {
    private let player: RemoteMicrophoneMonitorPlaying
    private(set) var currentSessionId: String?
    private(set) var isRelayActive = false

    func startSession(...) throws {
        currentSessionId = sessionId
        guard playThroughMacSpeaker else {
            isRelayActive = false
            return
        }
        try player.start(sampleRate: Double(sampleRate), channels: AVAudioChannelCount(channels), format: format)
        isRelayActive = true
    }

    func appendAudio(_ data: Data, sessionId: String) throws {
        guard isRelayActive, sessionId == currentSessionId else { return }
        do {
            try player.appendPCM16(data)
        } catch {
            player.stop()
            isRelayActive = false
        }
    }

    func stopSession(sessionId: String?) {
        guard sessionId == nil || sessionId == currentSessionId else { return }
        player.stop()
        currentSessionId = nil
        isRelayActive = false
    }
}
```

- [ ] **Step 4: Re-run the macOS controller tests to confirm GREEN**

Run: `xcodebuild test -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests`

Expected: PASS with the new controller tests green.

- [ ] **Step 5: Commit the macOS playback controller**

```bash
git add VoiceMindMac/VoiceMindMac/Speech/RemoteMicrophoneMonitorPlayer.swift VoiceMindMac/VoiceMindMac/Speech/RemoteMicrophoneMonitorController.swift VoiceMindMac/VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests.swift
git commit -m "feat(mac): add remote microphone monitor controller"
```

---

### Task 5: Integrate Playback With macOS ConnectionManager

**Files:**
- Modify: `VoiceMindMac/VoiceMindMac/Network/ConnectionManager.swift`

- [ ] **Step 1: Add the controller dependency and session cleanup points**

```swift
private let remoteMicrophoneMonitorController = RemoteMicrophoneMonitorController()
```

Call `stopSession(sessionId: nil)` anywhere the audio stream is torn down due to `audioEnd`, disconnect, or unrecoverable setup failure.

- [ ] **Step 2: Start relay sessions from `handleAudioStart(_:)`**

```swift
try remoteMicrophoneMonitorController.startSession(
    sessionId: payload.sessionId,
    sampleRate: payload.sampleRate,
    channels: payload.channels,
    format: payload.format,
    playThroughMacSpeaker: payload.playThroughMacSpeaker
)
```

Keep the existing `speechManager.startRecognition(...)` path intact. If relay startup fails, log a warning and continue into recognition.

- [ ] **Step 3: Mirror each `audioData` packet into the relay controller**

```swift
do {
    try speechManager.processAudioData(payload.audioData)
} catch {
    ...
}

try? remoteMicrophoneMonitorController.appendAudio(
    payload.audioData,
    sessionId: payload.sessionId
)
```

The relay append path must never prevent recognition from receiving audio.

- [ ] **Step 4: Stop relay playback on `audioEnd` and disconnect**

```swift
remoteMicrophoneMonitorController.stopSession(sessionId: payload.sessionId)
```

Also invoke `stopSession(sessionId: nil)` in any connection teardown path that resets the active stream.

- [ ] **Step 5: Run focused macOS tests and a build**

Run: `xcodebuild test -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests -only-testing:VoiceMindMacTests/ConnectionManagerTests -only-testing:VoiceMindMacTests/AudioFormatTests`

Expected: PASS.

Run: `xcodebuild build -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit the ConnectionManager integration**

```bash
git add VoiceMindMac/VoiceMindMac/Network/ConnectionManager.swift
git commit -m "feat(mac): play remote microphone audio through speakers"
```

---

### Task 6: Full Verification

**Files:**
- Modify: `SharedCore/...`
- Modify: `VoiceMindiOS/...`
- Modify: `VoiceMindMac/...`

- [ ] **Step 1: Run the full SharedCore test suite**

Run: `swift test --package-path /Users/cayden/Data/my-data/voiceMind/SharedCore`

Expected: All SharedCore tests pass.

- [ ] **Step 2: Run the focused iOS tests**

Run: `xcodebuild test -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorSettingsTests -only-testing:VoiceMindiOSTests/MacMicrophoneMonitorPolicyTests -only-testing:VoiceMindiOSTests/LocalTranscriptionPolicyTests`

Expected: PASS.

- [ ] **Step 3: Run the iOS build**

Run: `xcodebuild build -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'generic/platform=iOS Simulator'`

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the focused macOS tests**

Run: `xcodebuild test -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -only-testing:VoiceMindMacTests/RemoteMicrophoneMonitorControllerTests -only-testing:VoiceMindMacTests/ConnectionManagerTests -only-testing:VoiceMindMacTests/AudioFormatTests`

Expected: PASS.

- [ ] **Step 5: Run the macOS build**

Run: `xcodebuild build -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Manual sanity check**

1. Enable `发送到 Mac`
2. Enable the new `话筒` toggle
3. Switch the home screen to `Mac` mode
4. Hold to talk on iPhone
5. Confirm Mac speakers play the live microphone audio while recognition continues
6. Release to stop and confirm playback ends immediately

- [ ] **Step 7: Final commit**

```bash
git status --short
# If verification required follow-up edits, stage only the exact feature files you changed.
git add <exact feature file paths>
git commit -m "test: finish microphone monitor verification"
```
