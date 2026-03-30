# VoiceMind Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the iOS and macOS onboarding flows into a unified, release-ready VoiceMind experience and restore public-facing branding from `语灵` back to `VoiceMind`.

**Architecture:** Keep the existing onboarding entry points and state machines, but replace the current utility-style layouts with a more product-led four-page/four-step structure. Update the public-facing copy, localized strings, and permission-facing naming so onboarding, App Store material, and runtime branding are consistent.

**Tech Stack:** SwiftUI, Xcode project build settings, localized `.strings`, `Info.plist`, xcodebuild

---

### Task 1: Restore VoiceMind Branding In Public-Facing Copy

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Info.plist`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist`
- Modify: `/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md`
- Modify: `/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md`
- Modify: `/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-submission-notes.md`
- Modify: `/Users/cayden/Data/my-data/voiceMind/docs/app-build/submission-checklist.md`

- [ ] **Step 1: Write the failing check**

Run:

```bash
rg -n "语灵|Yuling \\(语灵\\)" /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Info.plist /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist /Users/cayden/Data/my-data/voiceMind/docs/app-build
```

Expected: matches are found in app-facing strings and submission docs.

- [ ] **Step 2: Update the branding**

Replace public-facing references so the app name is `VoiceMind` in:

- both `Info.plist` files
- both App Store metadata drafts
- macOS submission notes
- submission checklist title if it is user-facing

Keep technical file and scheme names unchanged.

- [ ] **Step 3: Re-run the check**

Run:

```bash
rg -n "语灵|Yuling \\(语灵\\)" /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Info.plist /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist /Users/cayden/Data/my-data/voiceMind/docs/app-build
```

Expected: no matches.

- [ ] **Step 4: Validate plist syntax**

Run:

```bash
plutil -lint /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Info.plist /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist
```

Expected: both files report `OK`.

- [ ] **Step 5: Commit**

```bash
git add /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Info.plist /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Info.plist /Users/cayden/Data/my-data/voiceMind/docs/app-build
git commit -m "Restore VoiceMind release branding"
```

### Task 2: Redesign iOS Onboarding Structure And Copy

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/OnboardingView.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Write the failing checks**

Run:

```bash
rg -n "Welcome to VoiceMind|首次使用需要与 Mac 配对|onboarding_how_it_works_title|onboarding_pairing_title" /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/OnboardingView.swift /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings
```

Expected: current onboarding copy and structure markers are still present.

- [ ] **Step 2: Refactor the onboarding layout**

Update `OnboardingView.swift` so the four iOS pages become:

- brand/promise
- iPhone-first voice input
- Mac collaboration
- start now

Implementation constraints:

- keep the existing page-based navigation shell
- keep the existing completion callback
- make the visual style more product-led and tech-forward
- avoid long instructional paragraphs

- [ ] **Step 3: Update the localized copy**

Rewrite the onboarding strings in both English and Simplified Chinese so they match the new four-page narrative and use `VoiceMind`.

- [ ] **Step 4: Build the iOS app**

Run:

```bash
xcodebuild -project /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS.xcodeproj -scheme VoiceMindiOS -configuration Release -destination 'generic/platform=iOS' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/OnboardingView.swift /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "Redesign iOS onboarding experience"
```

### Task 3: Redesign macOS Onboarding Structure And Copy

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/MenuBar/OnboardingFlow.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/zh-Hant.lproj/Localizable.strings`

- [ ] **Step 1: Write the failing checks**

Run:

```bash
rg -n "欢迎使用 语灵|使用准备|准备就绪|ReadinessCheckView|高精度识别" /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/MenuBar/OnboardingFlow.swift /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/zh-Hant.lproj/Localizable.strings
```

Expected: current macOS onboarding labels and structure markers are still present.

- [ ] **Step 2: Refactor the macOS onboarding layout**

Update `OnboardingFlow.swift` so the four macOS steps feel like a single polished onboarding:

- VoiceMind for Mac
- capture/review on Mac
- connect iPhone and Mac
- start VoiceMind

Implementation constraints:

- keep onboarding trigger behavior unchanged
- preserve the ability to start network services from onboarding
- preserve the running state screen if it is still part of the flow
- visually align with the new iOS onboarding language

- [ ] **Step 3: Update localized copy**

Rewrite the related macOS onboarding strings in English, Simplified Chinese, and Traditional Chinese so they use `VoiceMind` and match the new structure.

- [ ] **Step 4: Build the macOS app**

Run:

```bash
xcodebuild -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMindMac.xcworkspace -scheme VoiceMindMac -configuration Release -destination 'platform=macOS,arch=arm64' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/MenuBar/OnboardingFlow.swift /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/zh-Hant.lproj/Localizable.strings
git commit -m "Redesign macOS onboarding experience"
```

### Task 4: Final Consistency Verification

**Files:**
- Review: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/OnboardingView.swift`
- Review: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/MenuBar/OnboardingFlow.swift`
- Review: `/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md`
- Review: `/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md`

- [ ] **Step 1: Check for removed-feature references**

Run:

```bash
rg -n "语灵|text injection|hotkey|SenseVoice|ONNX|sherpa-onnx|模型下载|自动输入" /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS /Users/cayden/Data/my-data/voiceMind/VoiceMindMac /Users/cayden/Data/my-data/voiceMind/docs/app-build
```

Expected: no public-facing onboarding or submission text references removed features; technical leftovers are reviewed intentionally.

- [ ] **Step 2: Verify both release builds again**

Run:

```bash
xcodebuild -project /Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS.xcodeproj -scheme VoiceMindiOS -configuration Release -destination 'generic/platform=iOS' build
xcodebuild -workspace /Users/cayden/Data/my-data/voiceMind/VoiceMindMac.xcworkspace -scheme VoiceMindMac -configuration Release -destination 'platform=macOS,arch=arm64' build
```

Expected: both builds succeed.

- [ ] **Step 3: Review worktree**

Run:

```bash
git status --short
```

Expected: only intentional onboarding/branding changes remain.

- [ ] **Step 4: Commit**

```bash
git add /Users/cayden/Data/my-data/voiceMind
git commit -m "Finalize VoiceMind onboarding refresh"
```
