# VoiceMind Onboarding Redesign Design

Last updated: 2026-03-23

## Goal

Redesign the onboarding flows for both iOS and macOS so they feel like a coherent product experience for release, while also restoring the public-facing brand name to `VoiceMind`.

The new onboarding should feel more intentional and more premium than the current step-by-step utility walkthroughs. It should present VoiceMind as a fast, lightweight voice-to-text product with optional cross-device collaboration between iPhone and Mac.

## Scope

This redesign covers:

- iOS onboarding UI and copy
- macOS onboarding UI and copy
- shared onboarding narrative and branding
- public-facing onboarding references that currently use `语灵`
- permission-facing naming in `Info.plist` for iOS and macOS

This redesign does not cover:

- App Store metadata changes outside of the brand-name rollback
- feature changes to pairing, speech recognition, or networking
- main app redesign outside onboarding-related screens

## Product Narrative

The product narrative should be consistent across both platforms:

- Brand: `VoiceMind`
- Tone: lightweight, capable, modern
- Positioning: voice-to-text first, cross-device collaboration second
- Visual feel: tech-forward, but still Apple-platform appropriate

The onboarding should no longer feel like a checklist-heavy setup flow. Instead, it should introduce value first, then explain platform-specific use, then show collaboration, then guide the user into the first real action.

## Shared Onboarding Structure

Both platforms will use the same four-part story:

1. Brand and promise
2. Platform-primary workflow
3. Cross-device collaboration
4. Start now

Each platform will keep its own wording and action emphasis, but the structure, pacing, and visual style should feel like the same product family.

## Visual Direction

The visual direction should feel noticeably more technical and product-like than the current onboarding, without becoming flashy or game-like.

Design traits:

- strong visual hierarchy
- darker accent surfaces or gradients layered over the existing platform background
- glowing blue / cyan accent color language
- large product hero sections
- device relationship visuals for iPhone and Mac
- fewer explanatory paragraphs, more concise value-led blocks

The visual language should suggest:

- speech
- transfer / sync
- active flow
- lightweight productivity

## iOS Onboarding Design

### Page 1: VoiceMind

Purpose:
Introduce the brand and product promise.

Content:

- `VoiceMind`
- short value statement focused on fast voice-to-text on iPhone
- visual hero using the existing app icon plus a more premium treatment

Tone:
Confident and modern, not instructional.

### Page 2: Speak Naturally

Purpose:
Explain the iPhone-first value.

Content:

- voice input as the primary interaction
- reduced typing effort
- suitable for quick capture, notes, and lightweight productivity

Visual:

- waveform or input-state presentation
- short benefit cards rather than long paragraph copy

### Page 3: Sync with Mac

Purpose:
Present Mac collaboration as an enhancement, not a dependency.

Content:

- pairing on the same local network
- recognized text can appear on Mac after pairing
- collaboration is optional

Visual:

- iPhone to Mac connection diagram
- concise 3-step sync story

### Page 4: Start Using VoiceMind

Purpose:
Transition into real usage.

Content:

- confirm what happens next
- mention permissions in a calm way
- primary CTA to begin
- secondary action to dismiss

The final page should feel like a launchpad, not a warning or setup checklist.

## macOS Onboarding Design

### Page 1: VoiceMind for Mac

Purpose:
Introduce the Mac companion and its core value.

Content:

- `VoiceMind`
- short statement about lightweight voice-to-text and result review on Mac
- emphasize menu bar convenience

Visual:

- large hero section with Mac-centric iconography
- more premium card background than the current plain welcome screen

### Page 2: Capture and Review

Purpose:
Show how Mac fits into the workflow.

Content:

- local speech recognition support on Mac
- results appear inside the app
- suitable for reviewing and organizing voice text

This page replaces the current “准备” feeling with a product-use explanation.

### Page 3: Connect iPhone and Mac

Purpose:
Explain collaboration flow clearly.

Content:

- same local network
- start pairing on Mac
- enter or scan pairing flow from iPhone
- results sync into the Mac app

Visual:

- strong device-to-device relationship diagram
- clearer than the current checklist framing

### Page 4: Start VoiceMind

Purpose:
Move from onboarding into the real app state.

Content:

- explain the immediate next step
- make the primary CTA obvious
- reduce text density from the current ready/running sequence

The current four-step macOS flow can remain technically multi-step, but it should feel like one polished onboarding sequence rather than separate utility panels.

## Branding Rollback

Public-facing product naming should be restored to `VoiceMind`.

This includes:

- onboarding titles and copy
- `Info.plist` display names and permission strings
- App Store submission support docs that were recently converted to `语灵`

For review notes, the app name should be written as `VoiceMind`, without introducing a secondary Chinese brand unless explicitly needed later.

## Copy Rules

Copy should follow these principles:

- short sentences
- product-first, not engineering-first
- avoid sounding like setup instructions until the final page
- avoid deprecated capability references
- avoid mentioning removed features such as hotkeys, text injection, or model downloads

## Implementation Notes

The redesign should preserve existing onboarding triggers and completion logic wherever possible.

Expected implementation approach:

- keep current onboarding entry points
- refactor view layouts and copy rather than replacing onboarding state management entirely
- introduce shared visual patterns separately for iOS and macOS if platform constraints differ
- update localized strings where needed
- keep existing accessibility semantics and platform conventions

## Verification

After implementation:

- verify first-launch onboarding still appears correctly on both platforms
- verify dismiss / continue flows still complete
- verify no removed-feature text remains in onboarding
- verify `Info.plist` naming and permission text show `VoiceMind`
- verify screenshots and App Store materials are not contradicted by onboarding copy

## Risks

- Brand rollback may conflict with recently updated submission materials if not changed consistently
- A more visual onboarding can accidentally become less clear if copy is too sparse
- macOS onboarding currently blends setup state and education; redesign must avoid breaking startup flow

## Acceptance Criteria

- Both iOS and macOS onboarding flows feel visually related and release-ready
- Both flows use `VoiceMind` branding
- iOS onboarding is clearly iPhone-first with optional Mac collaboration
- macOS onboarding is clearly Mac-first with optional iPhone collaboration
- No onboarding screen references removed capabilities
