# iOS Local Transcription Default Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS app usable on its own by defaulting the home screen to on-device speech-to-text, while keeping Mac forwarding as an optional setting.

**Architecture:** Rework the iOS primary interaction so the press-and-hold flow always drives local speech recognition first and stores the recognized text in view-model state for display on the main screen. Preserve the current pairing and Mac connection stack, but gate result forwarding behind a persisted settings toggle and only send to Mac when the toggle is enabled and a paired connection is active.

**Tech Stack:** SwiftUI, Combine, SFSpeechRecognizer, AVFoundation, existing VoiceMindiOS view model/network stack

---

### Task 1: Lock The New Local-First Behavior In Tests

**Files:**
- Create: `VoiceMindiOS/VoiceMindiOSTests/ContentViewModelBehaviorTests.swift`

- [ ] Add tests covering: local speech is allowed without Mac pairing, forwarding is disabled by default, forwarding only happens when the setting is on and the app is connected.
- [ ] Run the focused test target and confirm the new assertions fail for the right reason.

### Task 2: Add View Model State For Local Transcript And Forwarding Preference

**Files:**
- Modify: `VoiceMindiOS/VoiceMindiOS/ViewModels/ContentViewModel.swift`

- [ ] Add published state for the current local transcript text and the “send to Mac” preference.
- [ ] Update the primary button flow so hold-to-talk works with only local permissions.
- [ ] Update speech result handling so local text is always stored, and Mac forwarding only happens when enabled and connected.
- [ ] Keep existing pairing/reconnect behavior intact for optional Mac use.

### Task 3: Redesign The Main Screen Around Local Transcription

**Files:**
- Modify: `VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift`

- [ ] Add a transcript/result card near the top of the main page.
- [ ] Update button labels and empty states so the default story is “hold to record and transcribe locally”.
- [ ] Keep Mac connection status visible as a secondary enhancement instead of the primary gate.

### Task 4: Add Settings Toggle For Optional Mac Forwarding

**Files:**
- Modify: `VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- Modify: `VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings`
- Modify: `VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] Add a persisted toggle for sending recordings/results to a connected Mac.
- [ ] Explain in settings that local transcription works without Mac, and the toggle only enables sync/forwarding when a Mac is connected.
- [ ] Keep pairing management available but no longer frame it as required setup.

### Task 5: Verify With Focused Tests And App Build

**Files:**
- Test: `VoiceMindiOS/VoiceMindiOSTests/ContentViewModelBehaviorTests.swift`

- [ ] Run focused iOS tests for the new view-model behavior.
- [ ] Run the iOS build to confirm the updated UI and state compile cleanly.
- [ ] Note any follow-up gaps, especially around partial-result UX and future history storage.
