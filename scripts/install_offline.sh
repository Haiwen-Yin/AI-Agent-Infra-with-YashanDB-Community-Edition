#!/bin/bash
# AI Agent Infra v3.10.2 - YashanDB Edition - Offline Installation
# Usage: bash scripts/install_offline.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[offline] Starting offline installation..."

# Step 1: Install yaspy driver + YashanDB client libraries
echo "[offline] Step 1: Installing yaspy driver..."
bash "$SCRIPT_DIR/install_yaspy.sh"

# Step 2: Install Python dependencies from vendor/
echo "[offline] Step 2: Installing Python dependencies..."
pip install --no-index --find-links "$PROJECT_DIR/vendor/" -r "$PROJECT_DIR/requirements.txt" 2>/dev/null || \
pip3.14 install --no-index --find-links "$PROJECT_DIR/vendor/" -r "$PROJECT_DIR/requirements.txt"

echo "[offline] Verifying dependencies..."
python3.14 "$SCRIPT_DIR/verify_deps.py" 2>/dev/null || python3 "$SCRIPT_DIR/verify_deps.py"

echo "[offline] Installation complete."
