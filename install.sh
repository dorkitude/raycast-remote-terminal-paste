#!/usr/bin/env bash
set -eu

[ "$(uname)" = Darwin ] || { echo "This command requires macOS."; exit 1; }
dir=$(cd -- "$(dirname -- "$0")" && pwd)
chmod +x "$dir/paste-image-remote.sh"
cat <<EOF
In Raycast Settings > Script Commands:
  1. Add this script folder: $dir
  2. Assign "Paste Image to Remote" a hotkey (suggested: Command-Option-Shift-V).

Allow Raycast to control your terminal when macOS asks.
Apple Terminal also needs Raycast enabled under:
  System Settings > Privacy & Security > Accessibility
EOF
