param(
  [string]$Version,
  [string]$Tag,
  [string]$Repo = "qingzhi0508/VoiceMind",
  [string]$ReleaseTitle,
  [string]$ReleaseNotesPath,
  [string]$Target = "all",
  [switch]$SkipBuild,
  [switch]$Draft,
  [switch]$Prerelease,
  [switch]$DryRun,
  [switch]$GenerateNotes,
  [string]$UpdaterArtifactPath,
  [string]$UpdaterSignaturePath,
  [string[]]$InstallerAssetPaths
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..\")).Path
}

function Get-WindowsRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..\")).Path
}

function Get-TauriConfigVersion {
  param([string]$ConfigPath)
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  return [string]$config.version
}

function Assert-CommandExists {
  param(
    [string]$CommandName,
    [string]$HelpMessage
  )

  if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
    throw $HelpMessage
  }
}

function Invoke-Step {
  param(
    [string]$Title,
    [scriptblock]$Action
  )

  Write-Host "==> $Title" -ForegroundColor Cyan
  & $Action
}

function Get-ReleaseBundleArtifacts {
  param(
    [string]$BundleRoot
  )

  if (-not (Test-Path -LiteralPath $BundleRoot)) {
    throw "Bundle directory not found: $BundleRoot"
  }

  $allFiles = Get-ChildItem -LiteralPath $BundleRoot -Recurse -File

  $installerCandidates = $allFiles | Where-Object {
    $_.Extension -in @(".msi", ".exe") -and $_.Name -match "setup|VoiceMind_"
  }

  $updaterPairs = foreach ($sig in $allFiles | Where-Object { $_.Name.EndsWith(".sig") }) {
    $artifactPath = $sig.FullName.Substring(0, $sig.FullName.Length - 4)
    if (Test-Path -LiteralPath $artifactPath) {
      $artifact = Get-Item -LiteralPath $artifactPath
      [PSCustomObject]@{
        Artifact = $artifact
        Signature = $sig
      }
    }
  }

  [PSCustomObject]@{
    Installers = @($installerCandidates | Sort-Object FullName -Unique)
    UpdaterPairs = @($updaterPairs | Sort-Object { $_.Artifact.FullName } -Unique)
  }
}

function Select-UpdaterPair {
  param(
    [object[]]$UpdaterPairs,
    [string]$ExplicitArtifactPath,
    [string]$ExplicitSignaturePath
  )

  if ($ExplicitArtifactPath -or $ExplicitSignaturePath) {
    if (-not $ExplicitArtifactPath -or -not $ExplicitSignaturePath) {
      throw "UpdaterArtifactPath and UpdaterSignaturePath must be provided together."
    }

    if (-not (Test-Path -LiteralPath $ExplicitArtifactPath)) {
      throw "Updater artifact not found: $ExplicitArtifactPath"
    }

    if (-not (Test-Path -LiteralPath $ExplicitSignaturePath)) {
      throw "Updater signature not found: $ExplicitSignaturePath"
    }

    return [PSCustomObject]@{
      Artifact = Get-Item -LiteralPath $ExplicitArtifactPath
      Signature = Get-Item -LiteralPath $ExplicitSignaturePath
    }
  }

  if (-not $UpdaterPairs -or $UpdaterPairs.Count -eq 0) {
    throw "No updater artifact with matching .sig file was found. Make sure the release build is signed and createUpdaterArtifacts is enabled."
  }

  $preferred = $UpdaterPairs | Where-Object {
    $_.Artifact.Name.EndsWith(".zip") -or $_.Artifact.Name.EndsWith(".tar.gz")
  } | Select-Object -First 1

  if ($preferred) {
    return $preferred
  }

  return $UpdaterPairs | Select-Object -First 1
}

function Resolve-InstallerAssets {
  param(
    [object[]]$DetectedInstallers,
    [string[]]$ExplicitInstallerAssetPaths
  )

  if ($ExplicitInstallerAssetPaths -and $ExplicitInstallerAssetPaths.Count -gt 0) {
    $resolved = foreach ($path in $ExplicitInstallerAssetPaths) {
      if (-not (Test-Path -LiteralPath $path)) {
        throw "Installer asset not found: $path"
      }
      Get-Item -LiteralPath $path
    }
    return @($resolved)
  }

  if (-not $DetectedInstallers -or $DetectedInstallers.Count -eq 0) {
    throw "No installer assets were found under the release bundle directory."
  }

  return @($DetectedInstallers)
}

$repoRoot = Get-RepoRoot
$windowsRoot = Get-WindowsRoot
$tauriConfigPath = Join-Path $windowsRoot "src-tauri\tauri.conf.json"
$manifestScriptPath = Join-Path $windowsRoot "scripts\generate-updater-manifest.ps1"
$bundleRoot = Join-Path $windowsRoot "src-tauri\target\release\bundle"
$releaseVersion = if ($Version) { $Version } else { Get-TauriConfigVersion -ConfigPath $tauriConfigPath }
$releaseTag = if ($Tag) { $Tag } else { "v$releaseVersion" }
$releaseTitleValue = if ($ReleaseTitle) { $ReleaseTitle } else { "VoiceMind Windows $releaseTag" }
$manifestOutputPath = Join-Path $bundleRoot "latest.json"

if (-not $SkipBuild) {
  if (-not $env:TAURI_SIGNING_PRIVATE_KEY_PATH -and -not $env:TAURI_SIGNING_PRIVATE_KEY) {
    throw "TAURI_SIGNING_PRIVATE_KEY_PATH or TAURI_SIGNING_PRIVATE_KEY must be set before building a signed updater release."
  }

  Invoke-Step "Building Windows release bundles" {
    Push-Location $windowsRoot
    try {
      npm run build
      if ($Target -and $Target -ne "all") {
        npx tauri build --target $Target
      } else {
        npx tauri build
      }
    } finally {
      Pop-Location
    }
  }
}

$artifacts = Get-ReleaseBundleArtifacts -BundleRoot $bundleRoot
$updaterPair = Select-UpdaterPair -UpdaterPairs $artifacts.UpdaterPairs -ExplicitArtifactPath $UpdaterArtifactPath -ExplicitSignaturePath $UpdaterSignaturePath
$installerAssets = Resolve-InstallerAssets -DetectedInstallers $artifacts.Installers -ExplicitInstallerAssetPaths $InstallerAssetPaths
$artifactUrl = "https://github.com/$Repo/releases/download/$releaseTag/$($updaterPair.Artifact.Name)"

Invoke-Step "Generating latest.json updater manifest" {
  & $manifestScriptPath `
    -Version $releaseVersion `
    -ArtifactUrl $artifactUrl `
    -SignaturePath $updaterPair.Signature.FullName `
    -NotesPath $ReleaseNotesPath `
    -OutputPath $manifestOutputPath
}

$uploadAssets = @()
$uploadAssets += $installerAssets
$uploadAssets += $updaterPair.Artifact
$uploadAssets += $updaterPair.Signature
$uploadAssets += Get-Item -LiteralPath $manifestOutputPath
$uploadAssets = @($uploadAssets | Sort-Object FullName -Unique)

Write-Host "Release repo: $Repo"
Write-Host "Release tag: $releaseTag"
Write-Host "Updater artifact: $($updaterPair.Artifact.FullName)"
Write-Host "Updater signature: $($updaterPair.Signature.FullName)"
Write-Host "Installer assets:"
$installerAssets | ForEach-Object { Write-Host "  - $($_.FullName)" }
Write-Host "Manifest: $manifestOutputPath"

if ($DryRun) {
  Write-Host "Dry run enabled. Skipping GitHub release creation and upload." -ForegroundColor Yellow
  exit 0
}

Assert-CommandExists -CommandName "gh" -HelpMessage "GitHub CLI 'gh' is required. Install it from https://cli.github.com/ and authenticate before publishing."

$releaseExists = $true
try {
  gh release view $releaseTag --repo $Repo *> $null
} catch {
  $releaseExists = $false
}

if (-not $releaseExists) {
  Invoke-Step "Creating GitHub release $releaseTag" {
    $args = @("release", "create", $releaseTag, "--repo", $Repo, "--title", $releaseTitleValue)

    if ($Draft) { $args += "--draft" }
    if ($Prerelease) { $args += "--prerelease" }

    if ($GenerateNotes) {
      $args += "--generate-notes"
    } elseif ($ReleaseNotesPath) {
      $args += @("--notes-file", $ReleaseNotesPath)
    } else {
      $args += @("--notes", "Windows release $releaseTag")
    }

    & gh @args
  }
} else {
  Write-Host "GitHub release $releaseTag already exists. Assets will be updated with --clobber." -ForegroundColor Yellow
}

Invoke-Step "Uploading assets to GitHub release $releaseTag" {
  $uploadArgs = @("release", "upload", $releaseTag, "--repo", $Repo, "--clobber")
  foreach ($asset in $uploadAssets) {
    $uploadArgs += $asset.FullName
  }
  & gh @uploadArgs
}

Write-Host "GitHub release publish complete for $releaseTag" -ForegroundColor Green
