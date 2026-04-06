# Mac Text Auto Injection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reintroduce macOS auto-injection of recognized text into the currently focused cursor position without regressing the current VoiceMind macOS UI and speech architecture.

**Architecture:** Add a focused text-injection subsystem that is isolated from the menu bar UI and exposed through a small coordinator used by `MenuBarController`. Keep the current window and navigation design intact, and restore only the runtime behavior needed for accessibility permission handling, text insertion, and fallback copy alerts.

**Tech Stack:** Swift, AppKit, ApplicationServices Accessibility APIs, XCTest, xcodebuild

---

### Task 1: Define testable delivery seams

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/TextInjection/TextInjection.swift`
- Create: `VoiceMindMac/VoiceMindMacTests/TextInjectionCoordinatorTests.swift`
- Modify: `VoiceMindMac/VoiceMindMac/MenuBar/MenuBarController.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that prove:
- a successful injection path forwards text to the injector
- accessibility denial returns a permission outcome
- generic injector failures return a copy-fallback outcome

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -only-testing:VoiceMindMacTests/TextInjectionCoordinatorTests`
Expected: FAIL because the coordinator and injection abstractions do not exist yet

- [ ] **Step 3: Write minimal implementation**

Create small protocols and a coordinator that wraps injection outcomes without depending on `NSAlert` or `NSWindow`.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command and confirm the new tests pass.

### Task 2: Restore runtime injection and permission behavior

**Files:**
- Create: `VoiceMindMac/VoiceMindMac/Permissions/PermissionsManager.swift`
- Create: `VoiceMindMac/VoiceMindMac/TextInjection/AccessibilityTextInjector.swift`
- Create: `VoiceMindMac/VoiceMindMac/TextInjection/FocusedInputDetector.swift`
- Modify: `VoiceMindMac/VoiceMindMac/MenuBar/MenuBarController.swift`
- Modify: `VoiceMindMac/VoiceMindMac/MenuBar/MenuBarController+Delegates.swift`
- Modify: `VoiceMindMac/VoiceMindMac/Resources/en.lproj/Localizable.strings`
- Modify: `VoiceMindMac/VoiceMindMac/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Write the failing controller tests**

Add tests for the pure coordinator or routing logic that verify:
- received recognized text triggers injection
- permission denial maps to the permission alert path
- injection failure maps to the copy alert path

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -only-testing:VoiceMindMacTests/TextInjectionCoordinatorTests`
Expected: FAIL until the controller-facing integration is wired in

- [ ] **Step 3: Write minimal implementation**

Implement:
- accessibility permission checks and prompt/open-settings helpers
- focused element lookup and writable target detection
- in-place text insertion at the current cursor
- controller hooks to invoke injection after remote recognition/text messages
- fallback alerts and clipboard copy on failure

- [ ] **Step 4: Run test to verify it passes**

Run the same targeted test command and confirm it passes.

### Task 3: Verify the macOS app still builds

**Files:**
- Verify only

- [ ] **Step 1: Run the focused test suite**

Run: `xcodebuild test -project VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -only-testing:VoiceMindMacTests/TextInjectionCoordinatorTests -only-testing:VoiceMindMacTests/AppSettingsTests`
Expected: PASS

- [ ] **Step 2: Run the macOS build**

Run: `xcodebuild build -project VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Review final diff**

Check the edited files and verify the change only restores auto-injection behavior and supporting permission UX.
