#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Keep the old setup entry point working for existing users.
exec bash "$SCRIPT_DIR/install.sh" "$@"
