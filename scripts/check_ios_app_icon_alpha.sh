#!/bin/zsh

set -euo pipefail

icon_path="${1:-/Users/cayden/Data/my-data/voiceMind/VoiceMindiOS/VoiceMindiOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png}"

if [[ ! -f "$icon_path" ]]; then
  echo "App icon not found: $icon_path" >&2
  exit 1
fi

has_alpha="$(sips -g hasAlpha "$icon_path" | awk -F': ' '/hasAlpha/ {print $2}')"

if [[ "$has_alpha" != "no" ]]; then
  echo "Invalid app icon: alpha channel present in $icon_path" >&2
  exit 1
fi

echo "App icon alpha check passed: $icon_path"
