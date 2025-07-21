#!/bin/bash
set -e

# Minimal WASM build script for sqliteraw.dart
# This script compiles SQLite to WASM using WASI SDK

# Configuration
WASI_SDK_PATH="${WASI_SDK_PATH:-$HOME/wasi-sdk-25.0}"
BUILD_DIR="build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Building minimal SQLite WASM..."

# Check for WASI SDK
if [ ! -d "$WASI_SDK_PATH" ]; then
    echo "❌ Error: WASI SDK not found at $WASI_SDK_PATH"
    echo "Please download WASI SDK from: https://github.com/WebAssembly/wasi-sdk/releases"
    echo "Extract it and set WASI_SDK_PATH environment variable"
    echo "Example: export WASI_SDK_PATH=\$HOME/wasi-sdk-25.0"
    exit 1
fi

# Create build directory
cd "$SCRIPT_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo "📦 Configuring build..."
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$WASI_SDK_PATH/share/cmake/wasi-sdk.cmake" \
    -DCMAKE_BUILD_TYPE=Release

# Build
echo "🔨 Compiling..."
make -j$(nproc 2>/dev/null || echo 4)

# Verify output
if [ -f "sqlite3.wasm" ]; then
    echo "✅ WASM build successful!"
    echo "📊 File size: $(du -h sqlite3.wasm | cut -f1)"
    
    # Validate WASM file
    if command -v wasm-validate >/dev/null 2>&1; then
        if wasm-validate sqlite3.wasm; then
            echo "✅ WASM file is valid"
        else
            echo "⚠️  WASM file validation failed"
        fi
    else
        echo "ℹ️  Install wabt tools for WASM validation: sudo apt install wabt"
    fi
    
    # Copy to web directory
    WEB_DIR="../../web"
    mkdir -p "$WEB_DIR"
    cp sqlite3.wasm "$WEB_DIR/"
    echo "📁 Copied sqlite3.wasm to $WEB_DIR/"
    
else
    echo "❌ Build failed - sqlite3.wasm not found"
    exit 1
fi

echo "🎉 Minimal WASM build complete!"
echo "Next steps:"
echo "  1. Run: dart test test/minimal_wasm_test.dart"
echo "  2. Test in browser with: dart run test/web_test.dart"