#!/bin/bash
# Compatibility entry point; all installation logic lives in the platform scripts.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
case "$OSTYPE" in
  linux*) exec bash "$SCRIPT_DIR/debian.sh" "$@" ;;
  darwin*) exec bash "$SCRIPT_DIR/macos.sh" "$@" ;;
  *) printf 'Unsupported platform: %s\n' "$OSTYPE" >&2; exit 1 ;;
esac
