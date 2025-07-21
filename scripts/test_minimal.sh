#!/bin/bash
set -e

# Test script for minimal SQLite WASM implementation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Testing minimal SQLite implementation..."

cd "$ROOT_DIR"

# Test 1: Native FFI test
echo ""
echo "1️⃣ Testing native FFI implementation..."
if dart test test/minimal_wasm_test.dart; then
    echo "✅ Native FFI tests passed"
else
    echo "❌ Native FFI tests failed"
    exit 1
fi

# Test 2: Build WASM
echo ""
echo "2️⃣ Building WASM module..."
if [ ! -f "assets/wasm/build.sh" ]; then
    echo "❌ Build script not found"
    exit 1
fi

cd assets/wasm
if ./build.sh; then
    echo "✅ WASM build completed"
else
    echo "❌ WASM build failed"
    echo "Make sure you have WASI SDK installed:"
    echo "  export WASI_SDK_PATH=\$HOME/wasi-sdk-25.0"
    exit 1
fi

cd "$ROOT_DIR"

# Test 3: Verify WASM file
echo ""
echo "3️⃣ Verifying WASM output..."
if [ -f "web/sqlite3.wasm" ]; then
    echo "✅ sqlite3.wasm found in web/ directory"
    echo "📊 File size: $(du -h web/sqlite3.wasm | cut -f1)"
    
    # Validate WASM if wabt tools are available
    if command -v wasm-validate >/dev/null 2>&1; then
        if wasm-validate web/sqlite3.wasm; then
            echo "✅ WASM file is valid"
        else
            echo "❌ WASM file validation failed"
            exit 1
        fi
    fi
else
    echo "❌ sqlite3.wasm not found in web/ directory"
    exit 1
fi

# Test 4: Check WASM exports
echo ""
echo "4️⃣ Checking WASM exports..."
if command -v wasm-objdump >/dev/null 2>&1; then
    echo "🔍 Checking for required SQLite exports..."
    
    # Check for essential functions
    if wasm-objdump -x web/sqlite3.wasm | grep -q "sqlite3_libversion"; then
        echo "✅ sqlite3_libversion export found"
    else
        echo "❌ sqlite3_libversion export missing"
        exit 1
    fi
    
    if wasm-objdump -x web/sqlite3.wasm | grep -q "sqlite3_libversion_number"; then
        echo "✅ sqlite3_libversion_number export found"
    else
        echo "❌ sqlite3_libversion_number export missing"
        exit 1
    fi
    
    if wasm-objdump -x web/sqlite3.wasm | grep -q "sqlite3_initialize"; then
        echo "✅ sqlite3_initialize export found"
    else
        echo "❌ sqlite3_initialize export missing"
        exit 1
    fi
else
    echo "ℹ️  Install wabt tools for detailed WASM inspection: sudo apt install wabt"
fi

# Test 5: Run example
echo ""
echo "5️⃣ Testing example..."
if dart run example/minimal_example.dart; then
    echo "✅ Example ran successfully"
else
    echo "❌ Example failed"
    exit 1
fi

echo ""
echo "🎉 All minimal tests passed!"
echo ""
echo "Next steps for web testing:"
echo "  1. Start a local web server: python3 -m http.server 8000"
echo "  2. Open: http://localhost:8000/web/"
echo "  3. Click 'Run Test' to verify WASM loading"
echo ""
echo "For browser tests with Dart:"
echo "  dart test -p chrome test/minimal_web_test.dart"