#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/organizer.sh"

# Trap Ctrl+C
trap cleanup SIGINT

# Forward arguments ($@) to main() in organizer.sh
main "$@"
