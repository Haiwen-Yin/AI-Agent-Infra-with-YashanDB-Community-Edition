#!/bin/bash
# Install yaspy driver and YashanDB client libraries
# Usage: bash scripts/install_yaspy.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$SCRIPT_DIR/python_runtime.sh" ]; then
    RUNTIME_HELPER="$SCRIPT_DIR/python_runtime.sh"
elif [ -f "$SCRIPT_DIR/../../shared/scripts/python_runtime.sh" ]; then
    RUNTIME_HELPER="$SCRIPT_DIR/../../shared/scripts/python_runtime.sh"
else
    echo "[install] ERROR: Python runtime helper is missing." >&2
    exit 1
fi
source "$RUNTIME_HELPER"
if ! PYTHON_BIN="$(cx_resolve_python "${PYTHON_BIN:-}")"; then
    echo "[install] ERROR: Python 3.14+ was not found; set PYTHON_BIN." >&2
    exit 1
fi
cx_prepare_python_environment "$PYTHON_BIN"
PYTHON_SITE=$("$PYTHON_BIN" -c "import site; print(site.getsitepackages()[0])")

echo "[install] Installing yaspy driver..."

# Install yaspy .so file
if [ -f "$PROJECT_DIR/vendor/yaspy/yaspy.cpython-314-x86_64-linux-gnu.so" ]; then
    cp "$PROJECT_DIR/vendor/yaspy/yaspy.cpython-314-x86_64-linux-gnu.so" "$PYTHON_SITE/"
    echo "[install] yaspy driver installed to $PYTHON_SITE"
else
    echo "[install] ERROR: yaspy .so file not found in vendor/yaspy/"
    exit 1
fi

# Install YashanDB client libraries beside the package by default. Operators
# can override CX_YASHAN_LIB_DIR for an approved shared client location.
YASHAN_LIB_DIR="${CX_YASHAN_LIB_DIR:-$PROJECT_DIR/.runtime/yashandb-client/lib}"
mkdir -p "$YASHAN_LIB_DIR"

if [ -d "$PROJECT_DIR/vendor/yaspy/client_lib" ]; then
    cp "$PROJECT_DIR/vendor/yaspy/client_lib/"* "$YASHAN_LIB_DIR/" 2>/dev/null
    
    # Create symlinks for shared library versioning
    cd "$YASHAN_LIB_DIR"
    for lib in *.so.*.*.*; do
        base=$(echo "$lib" | sed 's/\.so\..*//')
        ver_major=$(echo "$lib" | sed 's/.*\.so\.//' | cut -d. -f1)
        # Create .so.${ver_major} symlink
        ln -sf "$lib" "${base}.so.${ver_major}"
        # Create .so symlink
        ln -sf "$lib" "${base}.so"
    done
    
    echo "[install] YashanDB client libraries installed to $YASHAN_LIB_DIR"
    
    # Keep loader configuration process-local. The Web start script applies
    # the same path on every launch, so installation never modifies ~/.bashrc.
    export LD_LIBRARY_PATH="$YASHAN_LIB_DIR:$LD_LIBRARY_PATH"
else
    echo "[install] WARNING: YashanDB client libraries not found in vendor/yaspy/client_lib/"
fi

# Verify installation
if "$PYTHON_BIN" -c "import yaspy; print('[install] yaspy driver import verified')"; then
    :
else
    echo "[install] ERROR: yaspy import failed - check the package-local client library path" >&2
    exit 1
fi

echo "[install] Done."
