#!/usr/bin/env bash
# Re-run after moving the clone because the installed symlink is absolute.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$HOME/.local/bin}"
SOURCE_PATH="$SCRIPT_DIR/ghopen"

mkdir -p "$TARGET_DIR"
chmod +x "$SOURCE_PATH"
ln -sf "$SOURCE_PATH" "$TARGET_DIR/ghopen"
echo "Installed ghopen to $TARGET_DIR/ghopen"

case ":$PATH:" in
  *":$TARGET_DIR:"*) echo "ghopen is ready to use." ;;
  *)
    echo "Add the install directory to PATH in your shell profile:"
    echo "  export PATH=\"$TARGET_DIR:\$PATH\""
    ;;
esac
