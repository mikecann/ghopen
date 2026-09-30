#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_PATH="${1:-$HOME/.local/bin}/ghopen"

# Leave other checkouts and regular files alone.
if [ -L "$TARGET_PATH" ] && [ "$(readlink "$TARGET_PATH")" = "$SCRIPT_DIR/ghopen" ]; then
  rm "$TARGET_PATH"
  echo "Removed $TARGET_PATH"
else
  echo "No ghopen symlink belonging to this clone at $TARGET_PATH"
fi
