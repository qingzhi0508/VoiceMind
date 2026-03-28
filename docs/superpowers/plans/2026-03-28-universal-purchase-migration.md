# Universal Purchase Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert VoiceMind billing and project settings from separate iOS/macOS purchases to a single Universal Purchase setup.

**Architecture:** Use one shared bundle identifier and one shared StoreKit product catalog across iOS and macOS. Keep the existing shared billing store, but simplify its product mapping back to a single canonical product ID per entitlement so restore and entitlement checks operate on the same app record.

**Tech Stack:** Xcode project settings, StoreKit 2, local `.storekit` configs, SharedCore Swift package, XCTest

---

### Task 1: Lock Universal Purchase product catalog behavior

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/SharedCore/Tests/SharedCoreTests/TwoDeviceSyncProductCatalogTests.swift`
- Modify: `/Users/cayden/Data/my-data/voiceMind/SharedCore/Sources/SharedCore/Billing/TwoDeviceSyncPurchaseStore.swift`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run `swift test` and verify the catalog test fails for `.mac` assumptions**
- [ ] **Step 3: Replace dual-platform product aliases with one shared product ID per entitlement**
- [ ] **Step 4: Run `swift test` and verify SharedCore passes**

### Task 2: Align local StoreKit configuration with one shared product set

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac/Resources/VoiceMind.storekit`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/VoiceMind.storekit`

- [ ] **Step 1: Point macOS StoreKit products back to the shared iOS product IDs**
- [ ] **Step 2: Verify both local StoreKit files expose the same three product IDs**

### Task 3: Align macOS app bundle identity with the iOS app record

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindMac/VoiceMindMac.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write a minimal verification that the mac target still uses a distinct bundle ID**
- [ ] **Step 2: Change the mac target bundle ID from `cayden.VoiceMindMac` to `cayden.VoiceMind`**
- [ ] **Step 3: Re-check project settings to confirm both app targets use the same bundle ID**

### Task 4: Verify the workspace still builds

**Files:**
- Verify: `/Users/cayden/Data/my-data/voiceMind/VoiceMind.xcworkspace`

- [ ] **Step 1: Build SharedCore tests**
- [ ] **Step 2: Build `VoiceMindMac`**
- [ ] **Step 3: Build `VoiceMindiOS`**
- [ ] **Step 4: Summarize any remaining App Store Connect work that must still be done manually**
