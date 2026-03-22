# VoiceMind macOS Submission Notes

Last updated: 2026-03-22

## Current Product Shape

VoiceMind for macOS is a menu bar app that connects to the companion iPhone app over the local network.
The Mac app receives transcribed text from iPhone and inserts it into the currently focused text field.
The Mac app also supports local speech recognition using Apple's built-in Speech framework.

The current macOS build no longer includes:

- global hotkey monitoring
- input monitoring permission requests
- downloadable speech models
- third-party ONNX / sherpa-onnx speech engines
- Apple Events / AppleScript automation

## Permissions Used

### Accessibility

Why it is needed:

- detect the currently focused editable control
- insert recognized text into the current app
- send a Return key event when the recognized command is exactly "执行"

User-facing explanation:

- VoiceMind uses Accessibility permission only to place recognized text into the current text input area the user is actively using.

### Local Network

Why it is needed:

- discover the paired iPhone on the same Wi-Fi network using Bonjour
- exchange transcription messages between Mac and iPhone

### Microphone

Why it is needed:

- allow optional local speech capture on macOS using Apple Speech

### Speech Recognition

Why it is needed:

- convert local Mac audio to text
- support text recognition workflows exposed in the Mac app

## Suggested App Review Notes

You can paste and adapt the following into App Store Connect review notes:

VoiceMind is a Mac companion app for an iPhone speech input workflow.

How to review:

1. Launch the macOS app and keep it running.
2. Open the companion iPhone app on the same local network.
3. Pair the devices using the in-app pairing flow.
4. On macOS, place the cursor in any editable text field.
5. Speak on iPhone and confirm the recognized text is inserted into the focused text field on macOS.

Permissions used:

- Accessibility: required to insert recognized text into the currently focused text field.
- Local Network: required for Bonjour discovery and communication with the paired iPhone.
- Microphone and Speech Recognition: used only for the optional local speech recognition feature on macOS.

Important clarifications:

- The macOS app does not use Apple Events or AppleScript automation.
- The macOS app does not request Input Monitoring permission.
- The macOS app does not download third-party speech models.
- Speech recognition on macOS uses Apple's built-in Speech framework only.

## Remaining Review Risks

These are the main remaining risks for Mac App Store review:

- The app still uses Accessibility APIs to modify text in other apps. This is the biggest remaining policy risk and should be explained clearly in review notes.
- The app can simulate a Return key for the exact recognized command "执行". This should be documented in review notes so it is not interpreted as hidden automation.
- The bundle still uses an App Sandbox entitlement set that should be reviewed once the final feature set is frozen.

## Pre-Submission Checklist

- Verify `Release` build succeeds from `VoiceMindMac.xcworkspace`.
- Re-check that `NSAppleEventsUsageDescription` is absent from the final app bundle.
- Confirm the app never prompts for Input Monitoring during onboarding or normal use.
- Capture fresh screenshots that do not show removed hotkey settings or model download UI.
- Make sure App Store metadata does not mention hotkeys, model downloads, SenseVoice, ONNX, or sherpa-onnx.
