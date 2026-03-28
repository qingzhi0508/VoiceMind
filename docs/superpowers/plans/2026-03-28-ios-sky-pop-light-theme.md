# iOS Sky Pop Light Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current explicit iOS light theme visuals with the approved Sky Pop background and card treatment while keeping system and dark behavior unchanged.

**Architecture:** Keep the existing `app_theme` setting values (`system`, `light`, `dark`) and only reinterpret the explicit `light` selection as the new Sky Pop visual style. Route both background painting and card surfaces through small style policies so the new look remains testable and localized to the root iOS surfaces.

**Tech Stack:** SwiftUI, `@AppStorage`, view style policies, Testing, xcodebuild

---

### Task 1: Lock the Sky Pop theme policy in tests

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/AppBackgroundStylePolicyTests.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/ContentTabTests.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift`

- [ ] **Step 1: Write failing tests for explicit light theme using Sky Pop while system light remains unchanged**
- [ ] **Step 2: Run the targeted test command and verify it fails for the missing Sky Pop policy**
- [ ] **Step 3: Add minimal style-policy helpers for theme-aware background/card selection**
- [ ] **Step 4: Re-run targeted tests and verify they pass**

### Task 2: Apply Sky Pop visuals to the iOS root surfaces

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift`

- [ ] **Step 1: Replace the current explicit light theme background with the approved Sky Pop gradients and softer bubble treatment**
- [ ] **Step 2: Update card fill, border, and shadow treatment for the explicit light theme only**
- [ ] **Step 3: Keep dark mode and system-following visuals untouched**

### Task 3: Verify the iOS app still builds

**Files:**
- Verify: `/Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace`

- [ ] **Step 1: Run the targeted iOS theme tests**
- [ ] **Step 2: Build the `VoiceMindiOS` scheme**
- [ ] **Step 3: Summarize the final theme behavior and any remaining visual follow-up items**
