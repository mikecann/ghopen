#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Use an explicit destination so tests never change the user's installed command.
TARGET_DIR="$TEST_ROOT/bin with spaces"
for installer in install.sh setup_mac.sh; do
  bash "$SCRIPT_DIR/$installer" "$TARGET_DIR"
  bash "$SCRIPT_DIR/$installer" "$TARGET_DIR"
  [ "$(readlink "$TARGET_DIR/ghopen")" = "$SCRIPT_DIR/ghopen" ] || fail "$installer linked the wrong launcher"
  [ -x "$TARGET_DIR/ghopen" ] || fail "$installer launcher is not executable"
done

mkdir -p "$TEST_ROOT/not a repo"
if output="$(cd "$TEST_ROOT/not a repo" && "$TARGET_DIR/ghopen" 2>&1)"; then
  fail "installed launcher should reject a directory outside git"
fi
[[ "$output" == *"Not a git repository."* ]] || fail "installed launcher did not run ghopen"

bash "$SCRIPT_DIR/uninstall.sh" "$TARGET_DIR"
[ ! -L "$TARGET_DIR/ghopen" ] || fail "uninstall left the symlink behind"
bash "$SCRIPT_DIR/uninstall.sh" "$TARGET_DIR"

# Another checkout or an unrelated executable is not ours to remove.
ln -s "$TEST_ROOT/another-ghopen" "$TARGET_DIR/ghopen"
bash "$SCRIPT_DIR/uninstall.sh" "$TARGET_DIR"
[ -L "$TARGET_DIR/ghopen" ] || fail "uninstall removed another checkout's symlink"
rm "$TARGET_DIR/ghopen"
printf 'unrelated command\n' > "$TARGET_DIR/ghopen"
bash "$SCRIPT_DIR/uninstall.sh" "$TARGET_DIR"
[ -f "$TARGET_DIR/ghopen" ] || fail "uninstall removed an unrelated file"

echo "ghopen installer tests passed"
