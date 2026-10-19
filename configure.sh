#!/bin/bash
# Configuration uses the platform installer, without package changes or downloads.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$SCRIPT_DIR/install.sh" --configure-only "$@"
