# Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the iOS settings screen into a device-first layout with a compact account status header and a secondary account-and-membership destination for purchase actions.

**Architecture:** Keep `SettingsView` as the root orchestration view, but extract focused SwiftUI subviews and small presentation policies so high-level information hierarchy is testable without snapshot-heavy UI tests. Preserve the existing `ContentViewModel` integration and move billing UI from the main settings list into a dedicated secondary screen reached from the new status header.

**Tech Stack:** SwiftUI, Swift Testing, `ContentViewModel`, `@AppStorage`, StoreKit-backed billing state already exposed through the view model, `xcodebuild`

---

## File Map

- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
  Responsibility: Reorganize the settings screen, extract/host new subviews, remove purchase controls from the main list, and wire navigation to the account-and-membership destination.
- Create: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests.swift`
  Responsibility: Verify free vs paid status presentation and account header copy/icon policy.
- Create: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests.swift`
  Responsibility: Verify section ordering and that purchase actions no longer belong on the root settings surface.
- Optional modify if extraction is warranted during implementation: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsAccountMembershipView.swift`
  Responsibility: Hold the secondary account-and-membership UI if `SettingsView.swift` would otherwise become too large.

## Task 1: Add presentation policies for the new information hierarchy

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- Test: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests.swift`
- Test: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests.swift`

- [ ] **Step 1: Write the failing tests for header state and settings hierarchy**

```swift
import Testing
@testable import VoiceMind

struct SettingsMembershipPresentationPolicyTests {
    @Test
    func freeUsersUseRegularAccountPresentation() {
        let presentation = SettingsMembershipPresentationPolicy.presentation(isUnlimited: false)

        #expect(presentation.title == "regular")
        #expect(presentation.symbol == "person.crop.circle")
    }
}

struct SettingsInformationHierarchyPolicyTests {
    @Test
    func settingsSectionsPrioritizeDeviceManagement() {
        #expect(SettingsInformationHierarchyPolicy.rootSections == [.status, .pairing, .appearance, .support])
    }
}
```

- [ ] **Step 2: Run the new tests to verify they fail**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests -only-testing:VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests`

Expected: FAIL because the new policy types do not exist yet.

- [ ] **Step 3: Add minimal policy types to support the new presentation rules**

Implement lightweight policy types near `SettingsView` or in a dedicated file only if extraction improves clarity:

```swift
enum SettingsRootSection: CaseIterable {
    case status
    case pairing
    case appearance
    case support
}

enum SettingsInformationHierarchyPolicy {
    static let rootSections: [SettingsRootSection] = [.status, .pairing, .appearance, .support]
    static let showsPurchaseActionsOnRoot = false
}

struct SettingsMembershipPresentation {
    let title: String
    let symbol: String
}

enum SettingsMembershipPresentationPolicy {
    static func presentation(isUnlimited: Bool) -> SettingsMembershipPresentation {
        isUnlimited
            ? SettingsMembershipPresentation(title: "member", symbol: "person.crop.circle.badge.checkmark")
            : SettingsMembershipPresentation(title: "regular", symbol: "person.crop.circle")
    }
}
```

- [ ] **Step 4: Run the tests to verify the policies pass**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests -only-testing:VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift \
        VoiceMindiOS/VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests.swift \
        VoiceMindiOS/VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests.swift
git commit -m "test: add settings presentation policies"
```

## Task 2: Refactor the root settings screen into focused sections

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- Test: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests.swift`

- [ ] **Step 1: Extend the hierarchy test to lock the new root-screen behavior**

Add assertions covering:

```swift
@Test
func purchaseActionsAreNotShownOnRootSettingsSurface() {
    #expect(!SettingsInformationHierarchyPolicy.showsPurchaseActionsOnRoot)
}
```

- [ ] **Step 2: Run the targeted hierarchy test**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests`

Expected: FAIL until the policy and root-screen structure agree.

- [ ] **Step 3: Refactor `SettingsView` into dedicated sections**

Implementation checklist:

- add a compact tappable account status header at the top of the list
- extract dedicated subviews for:
  - account status header
  - pairing and connection section
  - appearance and language section
  - permissions and support section
- move `sendResultsToMacEnabled` into the pairing section
- combine help, logs, version, and permissions into the final support-oriented group
- compute permission state once per render path instead of calling `viewModel.checkPermissions()` repeatedly
- keep alerts, onboarding, and billing refresh behavior intact

- [ ] **Step 4: Run the hierarchy test and a full iOS unit-test pass**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16'`

Expected: PASS for the existing suite plus the new hierarchy test.

- [ ] **Step 5: Commit**

```bash
git add VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift \
        VoiceMindiOS/VoiceMindiOSTests/SettingsInformationHierarchyPolicyTests.swift
git commit -m "refactor: simplify settings root hierarchy"
```

## Task 3: Move billing actions into an account-and-membership destination

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- Create or Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsAccountMembershipView.swift`
- Test: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests.swift`

- [ ] **Step 1: Add a failing test describing paid-user presentation**

```swift
@Test
func paidUsersUseMemberPresentation() {
    let presentation = SettingsMembershipPresentationPolicy.presentation(isUnlimited: true)

    #expect(presentation.title == "member")
    #expect(presentation.symbol == "person.crop.circle.badge.checkmark")
}
```

- [ ] **Step 2: Run the membership presentation test**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests`

Expected: FAIL until the paid-state presentation and related wiring are complete.

- [ ] **Step 3: Implement the secondary account-and-membership destination**

Implementation checklist:

- add navigation from the top account header into the secondary screen
- move all current purchase buttons and restore purchases action off the root screen
- keep:
  - status summary
  - entitlement detail text
  - monthly/yearly/lifetime actions
  - restore purchases
  - purchase error messaging
- use neutral labeling such as `账户与会员` / `Account & Membership`
- ensure the root header only summarizes status and does not read like an ad surface

- [ ] **Step 4: Run targeted tests plus a scheme build**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests`

Run: `xcodebuild build -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'generic/platform=iOS Simulator'`

Expected: PASS and BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift \
        VoiceMindiOS/VoiceMindiOS/Views/SettingsAccountMembershipView.swift \
        VoiceMindiOS/VoiceMindiOSTests/SettingsMembershipPresentationPolicyTests.swift
git commit -m "feat: add account membership settings screen"
```

## Task 4: Localization, polish, and verification

**Files:**
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings`
- Modify: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`

- [ ] **Step 1: Add failing tests only if new pure policy helpers are introduced for labels**

If new label policies are added, cover them in the existing settings policy tests. Otherwise skip directly to implementation.

- [ ] **Step 2: Add new localized strings for the account header and destination**

Include strings for:

- regular user / member user labels
- account-and-membership title
- concise account header subtitle

- [ ] **Step 3: Run a full iOS build and test verification**

Run: `xcodebuild test -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 16'`

Run: `xcodebuild build -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'generic/platform=iOS Simulator'`

Expected: all tests pass and the scheme builds successfully.

- [ ] **Step 4: Manual QA on the simulator**

Check:

- free user root header shows regular-user presentation
- paid entitlement state shows member-user presentation
- pairing state is the first operational section on the page
- purchase buttons appear only after entering the account-and-membership screen
- language/theme/permissions/help/logs remain reachable
- permission alert, language alert, onboarding cover, and reconnect feedback still work

- [ ] **Step 5: Commit**

```bash
git add VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift \
        VoiceMindiOS/VoiceMindiOS/Resources/zh-Hans.lproj/Localizable.strings \
        VoiceMindiOS/VoiceMindiOS/Resources/en.lproj/Localizable.strings
git commit -m "feat: polish redesigned settings screen"
```

## Notes For Execution

- Prefer extracting a new `SettingsAccountMembershipView` file once `SettingsView.swift` exceeds comfortable size; otherwise keep private subviews in the same file first, then split if clarity improves.
- Follow the existing `Swift Testing` style used in `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests`.
- Before claiming success, run the build and test commands listed above and record any simulator/device-name adjustments needed in this environment.
- A separate plan-review subagent loop is normally part of this workflow, but if tool permissions in the active session prevent delegation, surface that limitation and proceed with human review rather than silently skipping verification.
