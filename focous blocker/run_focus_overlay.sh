#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BIN="$ROOT_DIR/.build/debug/FocusOverlay"

mkdir -p "$ROOT_DIR/.swiftpm-cache/clang"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.swiftpm-cache/clang"

cd "$ROOT_DIR"
swift build

if pgrep -x "FocusOverlay" >/dev/null 2>&1; then
  echo "FocusOverlay is already running."
  exit 0
fi

nohup "$APP_BIN" >/tmp/focus-overlay.log 2>&1 &
disown
echo "FocusOverlay started. Check /tmp/focus-overlay.log if needed."
