#!/bin/bash
# Install yaspy driver and YashanDB client libraries
# Usage: bash scripts/install_yaspy.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PYTHON_SITE=$(python3.14 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || python3 -c "import site; print(site.getsitepackages()[0])")

echo "[install] Installing yaspy driver..."

# Install yaspy .so file
if [ -f "$PROJECT_DIR/vendor/yaspy/yaspy.cpython-314-x86_64-linux-gnu.so" ]; then
    cp "$PROJECT_DIR/vendor/yaspy/yaspy.cpython-314-x86_64-linux-gnu.so" "$PYTHON_SITE/"
    echo "[install] yaspy driver installed to $PYTHON_SITE"
else
    echo "[install] ERROR: yaspy .so file not found in vendor/yaspy/"
    exit 1
fi

# Install YashanDB client libraries
YASHAN_LIB_DIR="$HOME/.yashandb/client/lib"
mkdir -p "$YASHAN_LIB_DIR"

if [ -d "$PROJECT_DIR/vendor/yaspy/client_lib" ]; then
    cp "$PROJECT_DIR/vendor/yaspy/client_lib/"* "$YASHAN_LIB_DIR/" 2>/dev/null
    echo "[install] YashanDB client libraries installed to $YASHAN_LIB_DIR"
    
    # Add to LD_LIBRARY_PATH
    EXPORT_LINE="export LD_LIBRARY_PATH=\"$YASHAN_LIB_DIR:\$LD_LIBRARY_PATH\""
    if ! grep -q "YASHANDB" ~/.bashrc 2>/dev/null; then
        echo "$EXPORT_LINE  # YashanDB client libraries" >> ~/.bashrc
        echo "[install] Added LD_LIBRARY_PATH to ~/.bashrc"
    fi
    export LD_LIBRARY_PATH="$YASHAN_LIB_DIR:$LD_LIBRARY_PATH"
else
    echo "[install] WARNING: YashanDB client libraries not found in vendor/yaspy/client_lib/"
fi

# Verify installation
python3.14 -c "import yaspy; print('[install] yaspy version:', yaspy.version)" 2>/dev/null || \
python3 -c "import yaspy; print('[install] yaspy version:', yaspy.version)" 2>/dev/null || \
echo "[install] WARNING: yaspy import failed - check LD_LIBRARY_PATH"

echo "[install] Done."
