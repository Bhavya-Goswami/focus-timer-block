#!/bin/zsh
set -euo pipefail

if pgrep -x "FocusOverlay" >/dev/null 2>&1; then
  pkill -x "FocusOverlay"
  echo "FocusOverlay stopped."
else
  echo "FocusOverlay is not running."
fi
