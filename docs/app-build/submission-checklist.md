# 语灵 Submission Checklist

Last updated: 2026-03-23

## Before Submission

- Confirm the git worktree is clean
- Confirm the final App Store screenshots only show currently available features
- Confirm no public-facing text mentions removed features such as hotkeys, text injection, model downloads, SenseVoice, ONNX, or sherpa-onnx

## iOS Submission

### App Store Connect Fields

- App Name: use the final value from [ios-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md)
- Subtitle: use the final value from [ios-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md)
- Promotional Text: use the final value from [ios-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md)
- Description: use the final value from [ios-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md)
- Keywords: use the final value from [ios-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md)

### Screenshots

- Prepare iPhone screenshots that clearly show standalone voice-to-text use
- Include at least one screenshot that suggests optional Mac collaboration
- Make sure screenshots do not imply features that require hidden setup or removed functionality

### Review Notes

- Paste the English review notes from [ios-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/ios-app-store-metadata.md)
- Explicitly state that the iPhone app can be used independently
- Explicitly state that Mac collaboration is optional and only works on the same local network

### Permissions

- Verify microphone permission wording is accurate
- Verify speech recognition permission wording is accurate
- Verify local network permission wording is accurate

## macOS Submission

### App Store Connect Fields

- App Name: use the final value from [macos-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md)
- Subtitle: use the final value from [macos-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md)
- Promotional Text: use the final value from [macos-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md)
- Description: use the final value from [macos-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md)
- Keywords: use the final value from [macos-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md)

### Screenshots

- Prepare screenshots that show the current menu bar app flow
- Include screenshots for local Mac speech recognition
- Include screenshots for iPhone collaboration if that flow is part of the listing
- Make sure screenshots do not show hotkey settings, permission windows, model download UI, or text injection behavior

### Review Notes

- Paste the English review notes from [macos-app-store-metadata.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-app-store-metadata.md)
- Keep [macos-submission-notes.md](/Users/cayden/Data/my-data/voiceMind/docs/app-build/macos-submission-notes.md) as the internal reference for reviewer messaging
- Explicitly state that the app no longer requests Accessibility or Input Monitoring permission
- Explicitly state that speech recognition on macOS uses Apple's built-in Speech framework only

### Permissions

- Verify local network permission wording is accurate
- Verify microphone permission wording is accurate
- Verify speech recognition permission wording is accurate
- Re-check that `NSAppleEventsUsageDescription` is absent from the final bundle

## Build Verification

- Run `xcodebuild -project VoiceMindiOS/VoiceMindiOS.xcodeproj -scheme VoiceMindiOS -configuration Release -destination 'generic/platform=iOS' build`
- Run `xcodebuild -workspace VoiceMindMac.xcworkspace -scheme VoiceMindMac -configuration Release -destination 'platform=macOS,arch=arm64' build`
- Run `plutil -lint VoiceMindiOS/VoiceMindiOS/Info.plist VoiceMindiOS/VoiceMindiOS/PrivacyInfo.xcprivacy`
- Run `plutil -lint VoiceMindMac/VoiceMindMac/Info.plist VoiceMindMac/VoiceMindMac/PrivacyInfo.xcprivacy`

## Runtime Verification

### iOS

- Launch the app on iPhone
- Confirm microphone permission flow appears only when needed
- Confirm speech recognition permission flow appears only when needed
- Confirm standalone speech-to-text works
- Confirm local network flow is understandable if Mac collaboration is used

### macOS

- Launch the app on macOS
- Confirm local speech recognition works
- Confirm onboarding and status screens match the current feature set
- Confirm the app never requests Accessibility permission
- Confirm the app never requests Input Monitoring permission
- Confirm paired iPhone results appear inside the app

## Final Review

- Re-read both App Store descriptions once inside App Store Connect formatting
- Re-check both apps' Bundle IDs match the intended store records
- Confirm privacy answers in App Store Connect match actual data usage and permissions
- Confirm screenshots, subtitle, and promotional text all tell the same product story
- Confirm reviewer notes describe the shortest successful review path
