# Windows Auto Update

## Current design

- The Windows app uses the official Tauri updater plugin.
- Update source points to GitHub Releases for `qingzhi0508/VoiceMind`.
- The app checks updates silently after startup and also exposes a manual update entry on the About page.
- When a new version is found, the app can download and install it directly inside the client.
- After installation, the app relaunches automatically.

## Configured endpoint

- `https://github.com/qingzhi0508/VoiceMind/releases/latest/download/latest.json`

## Signing key

- Public key is embedded in `src-tauri/tauri.conf.json`.
- Private key must stay outside the repository.
- Current local private key path:
  `C:\Users\cayden.xie\.tauri\voicemind-updater.key`

## Release process

1. Increase the app version in:
   `VoiceMindWindows/package.json`
   `VoiceMindWindows/src-tauri/Cargo.toml`
   `VoiceMindWindows/src-tauri/tauri.conf.json`
2. Export the signing key path before building:

```powershell
$env:TAURI_SIGNING_PRIVATE_KEY_PATH="C:\Users\cayden.xie\.tauri\voicemind-updater.key"
```

3. Build the signed release bundle:

```powershell
cd D:\data\voice-mind\VoiceMindWindows
npm run build
npx tauri build
```

4. Find the updater archive and signature under `src-tauri\target\release\bundle\`.
   Commonly this will be the generated Windows updater archive plus its `.sig` file.
5. Generate `latest.json` with the helper script:

```powershell
pwsh .\scripts\generate-updater-manifest.ps1 `
  -Version "0.1.0" `
  -ArtifactUrl "https://github.com/qingzhi0508/VoiceMind/releases/download/v0.1.0/REPLACE_ME.zip" `
  -SignaturePath "D:\data\voice-mind\VoiceMindWindows\src-tauri\target\release\bundle\REPLACE_ME.zip.sig" `
  -NotesPath "D:\data\voice-mind\release-notes.txt" `
  -OutputPath "D:\data\voice-mind\VoiceMindWindows\latest.json"
```

6. Upload these files to the GitHub Release in `qingzhi0508/VoiceMind`:
   updater archive
   updater archive `.sig`
   `latest.json`
7. Mark the Release as the latest stable release.

## Notes

- If `latest.json` or the signed archive is missing, the client will show an update check failure or no update available.
- Changing the signing key later will break updates for already released clients, so keep the private key safe.

