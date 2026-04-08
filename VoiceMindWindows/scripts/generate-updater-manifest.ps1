param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$ArtifactUrl,

  [Parameter(Mandatory = $true)]
  [string]$SignaturePath,

  [string]$Platform = "windows-x86_64",
  [string]$NotesPath,
  [string]$OutputPath = "latest.json",
  [string]$PubDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SignaturePath)) {
  throw "Signature file not found: $SignaturePath"
}

$signature = (Get-Content -LiteralPath $SignaturePath -Raw).Trim()
$notes = ""

if ($NotesPath) {
  if (-not (Test-Path -LiteralPath $NotesPath)) {
    throw "Notes file not found: $NotesPath"
  }
  $notes = Get-Content -LiteralPath $NotesPath -Raw
}

$manifest = [ordered]@{
  version = $Version
  notes = $notes
  pub_date = $PubDate
  platforms = [ordered]@{
    $Platform = [ordered]@{
      signature = $signature
      url = $ArtifactUrl
    }
  }
}

$directory = Split-Path -Parent $OutputPath
if ($directory) {
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath
Write-Host "Updater manifest written to $OutputPath"
