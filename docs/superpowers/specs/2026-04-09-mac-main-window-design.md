# VoiceMind Mac Main Window Redesign

## Goal

Rebuild the VoiceMind macOS main window into a cleaner Apple-aligned workspace that feels closer to a native Mac utility: clearer hierarchy, calmer surfaces, stronger overview-first navigation, and a more cohesive visual language across the home and speech pages.

## Design Standard

This redesign follows:

- `/Users/cayden/Data/my-data/voiceMind/docs/design/README.md`
- `/Users/cayden/Data/my-data/voiceMind/docs/design/vendor/apple-design-md/DESIGN.md`

VoiceMind-specific interpretation:

- prefer macOS utility usability over decorative product marketing
- borrow Apple product-page rhythm mainly for the top summary area
- keep accent color restrained and status colors localized to status chips

## Problems In The Current UI

- The main window feels assembled from multiple visual directions rather than one system.
- The home page lacks a strong top-level summary and asks the user to parse too many similarly-weighted blocks.
- Decorative fills and gradients contribute visual noise without improving hierarchy.
- Cards, side navigation, and secondary pages do not feel like they belong to the same app.
- The speech page is functional but visually disconnected from the rest of the main window.

## Redesign Direction

The new main window should feel like:

- a native-feeling Mac productivity tool
- overview first, details second
- restrained, spacious, and typography-led

The visual tone should sit between:

- macOS Settings / Music style utility surfaces
- Apple product-page style hero framing for the main summary area

## Scope

### Included In This Phase

- main window shell and navigation styling
- home page information architecture and visual hierarchy
- shared cards / section surfaces / status chips / action button styling
- speech page restyling to align with the new system

### Explicitly Not Included In This Phase

- pairing popup redesign
- onboarding and usage guide redesign
- deep settings page information architecture changes
- animation-heavy transitions

## Information Architecture

### Main Window Shell

- Keep the left navigation model.
- Make the sidebar feel quieter and closer to a macOS source list.
- Reduce visual weight in the navigation so content becomes the hero.

### Home Page Structure

The home page becomes a true overview dashboard with four layers:

1. Hero summary
2. Core status strip
3. Primary actions and active system cards
4. Detailed entry points and recent content

### Reading Order

When the user opens the app, they should immediately understand:

- what VoiceMind is for
- current pairing / connection / recognition readiness
- what the primary next action is
- where to go next for deeper work

## Visual System

### Color

- Use a restrained neutral canvas.
- Remove prominent blue-gray gradients from the main shell.
- Use blue only for selected navigation, primary buttons, links, and focus states.
- Use green / orange / red only in compact status treatments.

### Surfaces

- Use subtle layer separation rather than heavy shadows.
- Keep cards bright, soft, and lightly outlined.
- Prefer tonal separation to decorative fills.

### Typography

- Strengthen the top title and page section hierarchy.
- Use larger, tighter hero typography at the top of home.
- Keep supporting descriptions concise and subdued.

### Buttons

- One clear primary action per major area.
- Secondary actions use bordered or low-emphasis treatments.
- Avoid mixing multiple competing button styles in the same block.

## Component Plan

### Sidebar

- simplify background treatment
- refine selection state to feel more native
- reduce contrast of non-selected items
- preserve existing navigation structure

### Home Hero

- prominent title and concise subtitle
- compact summary of service readiness and collaboration state
- one primary CTA and one secondary CTA

### Status Cards

- pairing / connection status
- speech engine / local recognition readiness
- current session or recent sync status

These should read as high-signal summaries, not verbose panels.

### Detailed Blocks

- recent voice records
- collaboration entry points
- log and settings shortcuts

These blocks remain available but visually step back from the hero and status area.

### Speech Page

- align with the same card and section styling
- improve spacing and grouping
- keep existing model-management workflows intact

## Implementation Notes

- Keep the existing page model and navigation enum structure.
- Prefer adding shared visual building blocks inside the current file structure before attempting large file splits.
- Do not rewrite business logic when only presentation needs to change.
- Preserve all current behaviors around pairing, speech recognition, and records.

## Validation

- Build the macOS target successfully with `xcodebuild`.
- Verify the home page hierarchy is visibly simpler and calmer.
- Verify speech page remains functional and visually consistent with the new shell.
