# 语灵 macOS App Store Metadata Draft

Last updated: 2026-03-22

## Positioning

- Product name: `语灵`
- Narrative strategy: Mac-first voice-to-text utility, with iPhone collaboration as an enhancement
- Core value: a fast and lightweight voice-to-text tool that also works with iPhone to improve productivity

## App Store Fields

### App Name

`语灵`

### Subtitle

`轻量语音转文字与协作输入`

### Promotional Text

`快速轻量的 Mac 语音转文字工具，支持本地识别与 iPhone 协作，帮助你更高效地记录、整理和输出内容。`

### Description

`语灵 是一款轻量的 Mac 语音转文字工具。你可以直接在 Mac 上进行本地语音识别，也可以与 iPhone 配合使用，将语音转写结果同步到 Mac 中查看与整理。`

`无论是记录灵感、整理会议内容，还是快速输入短文本，语灵 都能帮助你减少打字负担，把注意力放回内容本身。`

`你可以用 语灵：`

- `在 Mac 上直接开始语音识别，快速查看转写结果`
- `通过局域网与 iPhone 配对，让 iPhone 成为更灵活的语音输入端`
- `在菜单栏中快速打开应用，查看最近结果`
- `集中查看本地识别结果与来自 iPhone 的同步内容`

`主要特性：`

- `轻量菜单栏体验，启动快、占用低`
- `支持 Mac 本地语音识别`
- `支持与 iPhone 协作同步语音结果`
- `集中查看和整理最近的语音转写内容`
- `适合记录、输入与轻量生产力场景`

`语灵 需要以下权限以提供完整功能：`

- `麦克风权限：用于 Mac 本地语音输入`
- `语音识别权限：用于将语音转换为文本`
- `本地网络权限：用于发现并连接同一局域网中的 iPhone 设备`

### Keywords

`语音转文字,语音输入,听写,转写,效率,生产力,菜单栏,语音记录,iPhone,Mac`

## Screenshot Copy Suggestions

### Screenshot 1

- Title: `轻量的菜单栏语音工具`
- Caption: `常驻菜单栏，随时开始语音转文字`

### Screenshot 2

- Title: `Mac 本地识别更直接`
- Caption: `在 Mac 上快速完成语音输入和结果查看`

### Screenshot 3

- Title: `与 iPhone 协作更灵活`
- Caption: `配对后可将 iPhone 的语音结果同步到 Mac`

### Screenshot 4

- Title: `结果集中查看与整理`
- Caption: `统一查看最近的转写内容，减少来回切换`

### Screenshot 5

- Title: `为效率场景而设计`
- Caption: `适合灵感记录、会议整理与轻量文本输入`

## Review Notes

Use the English version below in App Store Connect review notes:

`Yuling (语灵) is a lightweight macOS voice-to-text utility.`

`The macOS app supports two usage modes:`

- `Local speech recognition on Mac using Apple's built-in Speech framework`
- `Optional collaboration with the companion iPhone app over the local network`

`How to review:`

`1. Launch the macOS app and keep it running.`
`2. If testing the collaboration flow, open the companion iPhone app on the same local network.`
`3. Pair the devices using the in-app pairing flow.`
`4. Speak on iPhone and confirm the recognized text appears inside the macOS app.`
`5. You may also test the local macOS speech recognition flow directly in the Mac app.`

`Permissions used:`

- `Local Network: used for Bonjour discovery and communication with the paired iPhone on the same Wi-Fi network`
- `Microphone: used only for optional local speech capture on macOS`
- `Speech Recognition: used to convert local Mac audio into text`

`Important clarifications:`

- `The macOS app no longer requests Accessibility permission`
- `The macOS app does not request Input Monitoring permission`
- `The macOS app does not use Apple Events or AppleScript automation`
- `The macOS app does not download third-party speech models`
- `Speech recognition on macOS uses Apple's built-in Speech framework only`

## Submission Checklist

- Use screenshots that only show currently available UI and features
- Do not mention hotkeys, automatic text injection, model downloads, SenseVoice, ONNX, or sherpa-onnx
- Keep the public-facing description focused on Mac voice-to-text first, with iPhone collaboration as an enhancement
- Make sure the review account or review path clearly explains how to access the iPhone collaboration flow
