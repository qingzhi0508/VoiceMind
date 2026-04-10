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
2. Make sure GitHub CLI is logged in and the release repository is writable:

```powershell
gh auth status
```

3. Export the signing key path before building:

```powershell
$env:TAURI_SIGNING_PRIVATE_KEY_PATH="C:\Users\cayden.xie\.tauri\voicemind-updater.key"
```

4. Publish the Windows release directly to GitHub Releases:

```powershell
cd D:\data\voice-mind\VoiceMindWindows
npm run release:github -- `
  -ReleaseNotesPath "D:\data\voice-mind\release-notes.txt"
```

The publish script will:

- build signed release bundles
- detect the Windows installer assets
- detect the signed updater artifact and its `.sig`
- generate `latest.json`
- create or update the matching GitHub Release tag
- upload installer assets, updater artifact, updater signature, and `latest.json`

5. For historical versions or reruns, point the script at the exact tag/version you want to publish:

```powershell
cd D:\data\voice-mind\VoiceMindWindows
npm run release:github -- `
  -Version "0.1.0" `
  -Tag "v0.1.0" `
  -ReleaseNotesPath "D:\data\voice-mind\release-notes.txt" `
  -SkipBuild
```

6. If you only want to inspect the generated manifest and resolved asset list without uploading, use dry run:

```powershell
cd D:\data\voice-mind\VoiceMindWindows
npm run release:github -- -DryRun
```

7. `latest.json` continues to be served from the latest GitHub Release and points to the updater archive under the matching tag, so the in-app auto update always installs the asset from the corresponding GitHub Release.

## Notes

- If `latest.json` or the signed archive is missing, the client will show an update check failure or no update available.
- Changing the signing key later will break updates for already released clients, so keep the private key safe.
- `npm run release:github` requires `gh` to be installed and authenticated.

