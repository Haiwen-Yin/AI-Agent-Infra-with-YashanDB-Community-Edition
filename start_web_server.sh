#!/bin/bash
# Auto-generated start script for editions without a custom start_web_server.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# First-run config wizard: prompts if config.json still has <PLACEHOLDER> tokens
if [ -x "$SCRIPT_DIR/scripts/config_wizard.sh" ]; then
    "$SCRIPT_DIR/scripts/config_wizard.sh" || true
fi

cd "$SCRIPT_DIR"
python3.14 scripts/visualization/server.py
