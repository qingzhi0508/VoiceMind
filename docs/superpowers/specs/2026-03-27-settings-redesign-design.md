# iOS Settings Redesign Design

Date: 2026-03-27
Scope: `VoiceMindiOS` settings screen refactor
Primary file: `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`

## Goal

Refactor the iOS settings screen so it feels lighter and easier to scan, with device management as the primary task. The current screen mixes high-frequency pairing actions with lower-priority purchases, permissions, appearance, language, logs, and onboarding in one long list. This makes the page feel crowded and action-heavy.

The redesign should:

- make pairing and connection management the first-class action area
- reduce the number of top-level sections visible at once
- hide subscription upsell from the main settings list
- preserve access to billing, restore purchases, and sync status in a secondary surface
- keep the screen compliant with App Store expectations around subscriptions

## User Intent

The user identified two main problems:

- too many top-level options, making the page hard to scan
- too many heavy actions exposed on the same screen

The user also clarified:

- the most important settings task is pairing and device management
- subscription content should not be directly expanded on the main page
- the preferred direction is a small status avatar at the top that shows identity state:
  - free users show a normal-user status
  - paid users show a member-user status
- tapping the avatar/status area should open a dedicated account and membership area where purchase-related actions live

## Recommended Approach

Use the previously selected "Option A" direction as the base:

- a device-first settings home
- a lightweight status header at the top
- a collapsed membership entry hidden behind the status header
- fewer, broader top-level setting groups

This is recommended because it keeps the highest-frequency task on the main screen while removing the purchase-heavy section from the initial scan path.

## Information Architecture

The settings screen should be reorganized into these top-level zones:

1. Status header
2. Pairing and connection
3. Appearance and language
4. Permissions and support

### 1. Status Header

The screen begins with a compact tappable card or row that communicates account state without exposing purchase buttons.

Content:

- avatar or profile-style icon
- primary label:
  - `普通用户` for free users
  - `会员用户` for paid users
- secondary label derived from the sync entitlement state:
  - remaining free sync availability for free users
  - unlimited sync active for paid users
- trailing chevron or subtle affordance to indicate navigation

Behavior:

- tapping opens a dedicated account and membership destination
- the main settings page should not directly show monthly/yearly/lifetime purchase buttons

### 2. Pairing and Connection

This becomes the highest-priority block on the page.

Content when paired:

- paired Mac name
- current connection status badge
- reconnect action when disconnected
- reconnect status feedback when available
- unpair action
- send-to-Mac toggle remains within this area because it is functionally tied to device collaboration

Content when not paired:

- open pairing action
- collaboration toggle can be hidden or visually deprioritized when pairing is unavailable, depending on current product logic

Design intent:

- users should be able to land on settings and immediately understand device state
- the pairing section should feel operational, not buried under unrelated preference controls

### 3. Appearance and Language

These two low-risk personalization controls should be combined into one calmer section.

Content:

- theme segmented control
- language selection rows

Intent:

- reduce top-level section count
- keep visual customization separate from device management

### 4. Permissions and Support

Combine lower-frequency system and support items into a final section group.

Content:

- microphone and speech permission status
- request permissions action when needed
- help/onboarding entry
- logs/debug entry
- app version row

Intent:

- move support and diagnostics away from the primary operational area
- shorten the page by consolidating utility items

## Account And Membership Destination

Create a dedicated secondary surface opened from the status header. This can be a pushed SwiftUI destination or sheet, depending on the existing navigation context. A pushed destination is preferred if navigation stack context is available.

Content:

- current identity state
- sync entitlement summary
- purchase options:
  - monthly
  - yearly
  - lifetime
- restore purchases action
- purchase error message area
- explanatory footer about free vs unlimited sync usage

This secondary surface should carry all current purchase functionality that is now embedded in `SettingsView`.

## App Store Review Considerations

This design is compatible with common App Store review expectations if implemented carefully.

Allowed pattern:

- showing a non-deceptive account or membership summary on the main settings page
- using a dedicated page for subscription details and purchase actions
- distinguishing free and paid states through accurate labels and benefit summaries

Implementation constraints:

- do not use misleading marketing language in the header
- do not imply purchase is required for unrelated core settings such as permissions, appearance, or pairing access unless the actual product policy requires it
- show accurate pricing, entitlement descriptions, and restore purchases in the account and membership destination
- keep the free-tier limits clearly and truthfully described

Suggested neutral labels for the destination:

- `账户与会员`
- `身份与权益`

Avoid framing that makes the main settings page feel like an ad surface.

## View Structure Guidance

The current `SettingsView` is a long single file with many inline sections and side effects. The refactor should preserve behavior while making the view easier to read and evolve.

Recommended structure:

- keep `SettingsView` as the orchestration root
- extract dedicated subviews for:
  - status header
  - pairing section
  - appearance/language section
  - permissions/support section
  - account and membership view

Implementation principles:

- move non-trivial button actions out of `body`
- avoid repeating `viewModel.checkPermissions()` calls inline
- keep the root tree stable instead of branching entire page structure
- preserve current `ContentViewModel` integration instead of introducing a new view model layer just for this screen

## Data And State Mapping

Existing state appears sufficient for the redesign:

- `viewModel.pairingState`
- `viewModel.connectionState`
- `viewModel.reconnectStatusMessage`
- `viewModel.sendResultsToMacEnabled`
- `viewModel.twoDeviceSyncStatusText`
- `viewModel.twoDeviceSyncDetailText`
- `viewModel.isPurchasingTwoDeviceSync`
- `viewModel.activeTwoDeviceSyncPurchaseProductID`
- `viewModel.isRestoringTwoDeviceSyncPurchases`
- `viewModel.purchaseErrorMessage`
- `viewModel.twoDeviceSyncProducts`
- `appLanguage`
- `appTheme`

Potential helper additions:

- a small computed membership presentation model for icon, title, and subtitle
- a cached permission state value evaluated once per render path

## Error Handling

The redesign should preserve current error handling behavior:

- permission denial still triggers the existing alert
- language change still triggers the restart guidance alert
- purchase restoration and purchase errors remain visible in the secondary membership surface
- reconnect status feedback remains visible in the pairing area

## Testing

Behavior-focused coverage should be added or updated around the new structure.

Recommended tests:

- settings surface keeps pairing controls above lower-priority preferences
- free users see normal-user status presentation in the header
- paid users see member-user status presentation in the header
- purchase actions are absent from the main settings surface
- account and membership destination contains restore purchase and plan actions
- permissions and support items remain reachable after consolidation

If the current test style in `VoiceMindiOSTests` prefers policy-style assertions, add narrow policy tests to describe the intended hierarchy rather than snapshot-heavy UI tests.

## Out Of Scope

This redesign does not change:

- product pricing
- sync entitlement rules
- onboarding content
- actual pairing protocol behavior
- localization copy beyond new labels needed for the redesigned information architecture

## Implementation Summary

The implementation should convert settings from a long all-in-one list into a device-first home screen with a compact membership/status entry. Purchase actions move into a dedicated account and membership destination, reducing clutter on the main page while keeping review-safe subscription access and restore flows intact.
