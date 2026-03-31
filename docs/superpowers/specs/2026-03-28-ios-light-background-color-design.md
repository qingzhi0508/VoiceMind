# iOS Light Background Color Design

Date: 2026-03-28
Scope: `VoiceMindiOS` light-theme background color customization
Primary files:
- `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/SettingsView.swift`
- `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Views/ContentView.swift`
- `/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOSTests/AppBackgroundStylePolicyTests.swift`

## Goal

Add a manual background color setting for the explicit iOS `Light` theme so users can personalize the Sky Pop look without affecting `System` or `Dark`.

The result should keep the current soft gradient and bubble treatment, while letting users shift the overall color family from the default sky blue to another light-friendly tone.

## User Intent

The user wants a setting in the iOS settings screen that behaves like a standard theme-editor background control:

- visible from settings
- manually selectable through a native color picker
- applied only when the app theme is explicitly set to `Light`
- still visually softer than a flat white background

The user explicitly does **not** want this setting to affect:

- `System`
- `Dark`

## Recommended Approach

Keep the existing `app_theme` values and the approved `Sky Pop` design direction. Add one light-only customization setting that stores a background tint color and feeds that tint into the existing light-theme background and surface policies.

This is preferred because it:

- preserves the current theme model instead of introducing a new theme type
- keeps `System` and `Dark` fully stable
- gives users direct control while retaining the polished Sky Pop gradients, bubbles, and glass surfaces

## Settings UI

The new control should live inside the existing `Appearance` section in `SettingsView`.

Structure:

1. Theme segmented control
2. Background color row, shown only when `appTheme == "light"`
3. Language controls

### Background Color Row

The row should communicate the current selection clearly and feel native to the existing settings layout.

Content:

- leading label: `背景颜色` / `Background Color`
- trailing preview:
  - a small circular color swatch
  - current hex value in uppercase, such as `#66BDC9`

Interaction:

- tapping the trailing control opens the iOS native `ColorPicker`
- opacity editing should be disabled
- the control should feel like a compact settings accessory, not a large custom editor

The row should be hidden whenever the current theme is `System` or `Dark`.

## Persistence Model

Store the selected light background color separately from the theme selection.

Recommended storage:

- `@AppStorage("light_theme_background_hex")`

Format:

- six-digit uppercase hex string with leading `#`
- example: `#66BDC9`

Rules:

- if no value exists, use the current Sky Pop default color
- if the stored value is invalid, ignore it and fall back to the default
- changing away from `Light` does not clear the stored value
- returning to `Light` restores the previous chosen background color

## Rendering Behavior

The selected color should not replace the whole background with a flat fill. Instead, it becomes the base tint that drives the existing Sky Pop light palette.

### Background

For explicit `Light` only:

- use the stored color as the base tint for the main gradient
- keep the soft airy gradient structure
- keep the rainbow bubble overlays
- keep enough whitening and desaturation so the result remains calm and readable

For `System` and `Dark`:

- keep the current rendering unchanged

### Surface Styling

The selected light background tint should also slightly influence light-only surfaces so the app still feels like one theme.

Affected light-only surfaces:

- root page background
- major cards
- grouped settings rows
- soft panels
- bottom bars

Constraints:

- preserve strong text readability
- keep cards brighter than the page background
- do not tint dark mode surfaces
- do not alter `System` light behavior

## Style Policy Changes

The current light-theme styling already routes through small policy helpers. Extend those helpers instead of scattering color logic through individual views.

Recommended additions:

- a helper that resolves the effective light background tint from stored hex or default fallback
- a small palette model or helper functions derived from that tint
- updated background and surface policy methods that accept the optional stored light color

The background style identity should remain:

- `mutedMistLight`
- `skyPopLight`
- `darkSystem`

Only the tint used by `skyPopLight` becomes customizable.

## Error Handling

This feature should fail softly.

- invalid hex input falls back to the default Sky Pop tint
- if `ColorPicker` returns an unexpected value, save the last valid hex or fallback default
- missing stored value should never produce a blank or white screen

## Testing

Add or update focused tests around the theme policy layer.

Required coverage:

- explicit `Light` with no stored color uses the default Sky Pop tint
- explicit `Light` with a stored hex uses the custom tint path
- `System` light ignores the stored light background color
- `Dark` ignores the stored light background color
- invalid stored hex falls back to the default

UI behavior that can be verified cheaply should also be covered where practical:

- background color row visibility is tied to `appTheme == "light"`

## Non-Goals

This design does not include:

- custom background color support for `System`
- custom background color support for `Dark`
- a separate theme preset system
- opacity controls
- per-page background customization

## Verification

Implementation should be considered complete only after:

- focused iOS theme tests pass
- the `VoiceMindiOS` scheme builds successfully
- manual simulator verification confirms that the background color row appears only in `Light` and that changing the color visibly retints the Sky Pop background
