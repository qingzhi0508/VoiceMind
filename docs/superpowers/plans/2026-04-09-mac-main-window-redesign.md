# Mac Main Window Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the macOS main window into a cleaner Apple-aligned workspace with a stronger home overview and unified visual language.

**Architecture:** Keep the existing navigation and content structure, but replace the main shell styling, home-page hierarchy, and shared surface components. Reuse current business logic and page switching so the work stays presentation-focused and low risk.

**Tech Stack:** SwiftUI, AppKit-backed macOS app shell, existing `MenuBarController` view state, `xcodebuild`

---

### Task 1: Establish Shared Visual Language

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Views/MainWindow.swift`

- [ ] Add or refine the main window color tokens to remove the old decorative look and support calmer neutral surfaces.
- [ ] Introduce reusable SwiftUI building blocks for section surfaces, hero blocks, and compact status chips inside the existing file.
- [ ] Keep the new components presentation-only so no existing controller behavior changes.

### Task 2: Rebuild Main Window Shell

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Views/MainWindow.swift`

- [ ] Update sidebar styling to feel closer to a macOS source list with quieter background and clearer selection state.
- [ ] Adjust the main content container, spacing, and title presentation to support the new hierarchy.
- [ ] Preserve current navigation items and page switching.

### Task 3: Redesign Home Page

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Views/MainWindow.swift`

- [ ] Replace the current home composition with a hero summary section.
- [ ] Add a compact status area for pairing, connection, and recognition readiness.
- [ ] Reorganize primary actions and detailed blocks into a clearer overview-first sequence.
- [ ] Keep current actions wired to the same controller methods.

### Task 4: Bring Speech Page Into The New System

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Views/SpeechRecognitionTab.swift`

- [ ] Restyle the speech page containers to match the new shell.
- [ ] Improve spacing, row rhythm, and action emphasis without changing engine/model workflows.
- [ ] Keep all current download / select / delete actions intact.

### Task 5: Verify

**Files:**
- Verify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj`

- [ ] Run `xcodebuild -project /Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj -scheme VoiceMindMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
- [ ] Fix any compile issues introduced by the redesign.
- [ ] Summarize the redesign outcome and any residual visual follow-up opportunities.
