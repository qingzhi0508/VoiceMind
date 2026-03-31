# iOS Light Background Color Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a light-theme-only background color setting in iOS Settings that retints the approved Sky Pop theme without affecting System or Dark.

**Architecture:** Keep the existing `app_theme` values and add a separate persisted hex value for the explicit `light` theme background tint. Extend the existing background and surface style policies so the chosen tint flows through the shared visual system, then expose the setting through a native `ColorPicker` row in Settings.

**Tech Stack:** SwiftUI, UIKit color bridging, `@AppStorage`, Testing, `xcodebuild`

---

### Task 1: Lock the light background tint policy with tests

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/AppBackgroundStylePolicyTests.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift`

- [ ] **Step 1: Write failing tests for default, custom, and invalid light background tint resolution**
- [ ] **Step 2: Run the targeted test command and verify it fails for the missing tint policy**
- [ ] **Step 3: Add the minimal light background tint helper and palette resolution code**
- [ ] **Step 4: Re-run the targeted test command and verify the new tests pass**

### Task 2: Add the Settings entry for light-only background color selection

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsPresentationPolicy.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Write a failing test for the appearance section showing the background color row only for the explicit light theme**
- [ ] **Step 2: Run the targeted test command and verify it fails for the missing visibility policy**
- [ ] **Step 3: Add the visibility policy, localized label, and native `ColorPicker` settings row with swatch and hex preview**
- [ ] **Step 4: Re-run the targeted test command and verify the new settings behavior tests pass**

### Task 3: Apply the custom light tint across shared surfaces and verify the app

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift`
- Verify: `/Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace`

- [ ] **Step 1: Route the explicit light theme background and surface colors through the resolved custom tint while keeping System and Dark unchanged**
- [ ] **Step 2: Run the focused iOS tests for theme and settings policies**
- [ ] **Step 3: Build the `VoiceMindiOS` scheme and confirm it succeeds**
