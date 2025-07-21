# Road to WASM: Implementation Guide for sqliteraw.dart

## Table of Contents

- [Introduction](#introduction)
- [Strategic Analysis](#strategic-analysis)
- [Technical Architecture](#technical-architecture)
- [WASM Compilation Setup](#wasm-compilation-setup)
- [Virtual File System Implementation](#virtual-file-system-implementation)
- [Dart WASM Integration](#dart-wasm-integration)
- [API Compatibility Layer](#api-compatibility-layer)
- [Implementation Roadmap](#implementation-roadmap)
- [Testing and Deployment](#testing-and-deployment)
- [Appendices](#appendices)

---

## Introduction

### Overview

This document outlines the comprehensive plan for adding WebAssembly (WASM) support to sqliteraw.dart, enabling the package to provide raw SQLite bindings across all Dart platforms - native (VM/AOT) and web.

### Project Goals

1. **Cross-Platform Compatibility**: Enable sqliteraw.dart to work seamlessly on web platforms while maintaining existing native functionality
2. **API Fidelity**: Preserve the "raw" SQLite C-API contract, ensuring identical developer experience across platforms
3. **Performance**: Minimize overhead in the WASM implementation to maintain SQLite's performance characteristics
4. **Distribution**: Include compiled WASM binaries within the package for easy deployment

### Current State

- **Existing**: Native-only package using dart:ffi with auto-generated bindings from SQLite headers
- **Build System**: GitHub Actions workflow compiling SQLite for 6 native platforms (Linux, macOS, Windows - x64 and ARM)
- **Architecture**: Pure FFI bindings with no high-level abstractions, requiring users to handle library loading

### Success Criteria

- Web applications can use identical API calls as native applications
- WASM binaries are automatically built and distributed with the package
- Performance overhead is minimal (<20% compared to native)
- Full SQLite feature compatibility including persistent storage via IndexedDB
- Comprehensive test coverage across major browsers

---

## Strategic Analysis

### Why Not Emscripten?

While Emscripten is the most common tool for compiling C libraries to WASM, it's not the right choice for sqliteraw.dart for several critical reasons:

#### Package vs Application Requirements
- **Emscripten targets applications**: Generates JavaScript glue code and HTML templates
- **sqliteraw.dart is a library**: Must be pure Dart with no JavaScript dependencies
- **Distribution constraints**: Cannot include JS files in a Dart package

#### API Purity Requirements
- **"Raw" contract**: Must preserve C-style pointers, error codes, and manual memory management
- **Emscripten abstractions**: Adds high-level JavaScript bridges that hide the raw API
- **Control requirements**: Need direct memory access for shared buffers

#### Technical Limitations
- **Documentation gaps**: Emscripten's internal ABI between WASM and JS glue is poorly documented
- **Symbol mangling**: Emscripten's minification breaks function exports needed for FFI-style access
- **Large bundles**: Emscripten generates large JavaScript files (~500KB+) with debugging symbols

### The Custom Compilation Approach

Based on the successful architecture of simolus3/sqlite3.dart, we adopt a custom LLVM/Clang compilation strategy:

#### Core Principles
1. **Direct WASM compilation**: Use Clang with WASI target for clean, portable WASM
2. **Function injection**: Implement VFS functions in Dart and inject them into WASM module
3. **Shared memory**: Use imported memory for efficient data exchange
4. **Pure Dart bridge**: All interop handled through dart:js_interop, no external JavaScript

#### Key Advantages
- **Full control**: Complete visibility into compilation process and memory layout
- **Minimal overhead**: Direct function calls without JavaScript abstraction layers
- **Maintainability**: Clear separation between C compilation and Dart integration
- **Future-proof**: Compatible with upcoming dart2wasm compilation target

### Platform-Specific Considerations

#### Web Platform Constraints
- **No file system**: Browsers don't provide direct file access
- **Async APIs**: IndexedDB and other storage APIs are asynchronous
- **Security model**: SharedArrayBuffer requires COOP/COEP headers
- **Memory limits**: WASM memory size constraints in browsers

#### SQLite VFS Requirements
- **Synchronous interface**: SQLite expects synchronous file operations
- **POSIX compatibility**: Standard VFS assumes POSIX file operations
- **Transaction support**: Must handle SQLite's locking and transaction mechanisms

#### Solution Strategy
- **Custom VFS implementation**: Replace standard POSIX VFS with web-compatible version
- **Dart bridge functions**: Implement file operations in Dart using browser APIs
- **Sync-over-async**: Use SharedArrayBuffer + Atomics for blocking operations where needed

---

## Technical Architecture

### Package Structure for Dual Platform Support

The refactored package structure supports both native FFI and WASM implementations through conditional imports:

```
sqliteraw.dart/
├── lib/
│   ├── sqliteraw.dart                    # Main entry point with conditional exports
│   └── src/
│       ├── common/
│       │   ├── raw_api.dart              # Shared interfaces and constants
│       │   └── exceptions.dart           # Common error types
│       ├── native/
│       │   └── sqliteraw_native.dart     # Current dart:ffi implementation
│       └── wasm/
│           ├── sqliteraw_wasm.dart       # WASM implementation
│           ├── wasm_loader.dart          # WASM module loading
│           ├── wasm_vfs.dart             # Virtual File System
│           ├── memory_utils.dart         # Shared memory helpers
│           └── indexeddb_vfs.dart        # IndexedDB storage backend
├── web/
│   ├── sqlite3.wasm                      # Standard SQLite WASM binary
│   ├── sqlite3mc.wasm                    # Encrypted SQLite WASM binary (optional)
│   └── wasm_assets.json                  # Asset metadata
├── assets/wasm/
│   ├── CMakeLists.txt                    # Build configuration
│   ├── build.sh                          # Build script
│   ├── os_web.c                          # VFS implementation stubs
│   ├── helpers.c                         # Utility functions
│   └── sqlite3_wasm_extra_init.c         # Extension initialization
└── test/
    ├── native/                           # Native-specific tests
    ├── wasm/                             # WASM-specific tests
    └── common/                           # Cross-platform tests
```

### Conditional Import Pattern

The main library file uses Dart's conditional import mechanism to select the appropriate implementation:

```dart
// lib/sqliteraw.dart
library sqliteraw;

// Export common interfaces
export 'src/common/raw_api.dart';

// Conditional platform implementation
export 'src/native/sqliteraw_native.dart' 
  if (dart.library.js_interop) 'src/wasm/sqliteraw_wasm.dart';
```

### Common API Interface

All platform-specific implementations must conform to a shared interface:

```dart
// lib/src/common/raw_api.dart
abstract interface class SqliteRawApi {
  // Core database operations
  int sqlite3_open_v2(String filename, Pointer<Pointer<sqlite3>> ppDb, 
                      int flags, String? zVfs);
  int sqlite3_close_v2(Pointer<sqlite3> db);
  
  // Statement operations
  int sqlite3_prepare_v2(Pointer<sqlite3> db, String zSql, int nByte,
                         Pointer<Pointer<sqlite3_stmt>> ppStmt, 
                         Pointer<Pointer<Int8>>? pzTail);
  int sqlite3_step(Pointer<sqlite3_stmt> stmt);
  int sqlite3_finalize(Pointer<sqlite3_stmt> stmt);
  
  // Data access
  String sqlite3_column_text(Pointer<sqlite3_stmt> stmt, int iCol);
  int sqlite3_column_int(Pointer<sqlite3_stmt> stmt, int iCol);
  // ... other column accessors
  
  // Error handling
  int sqlite3_errcode(Pointer<sqlite3> db);
  String sqlite3_errmsg(Pointer<sqlite3> db);
  
  // Memory management
  Pointer<T> sqlite3_malloc<T extends NativeType>(int size);
  void sqlite3_free(Pointer<void> ptr);
}
```

### WASM-Specific Architecture

#### Memory Model
- **Shared Linear Memory**: Single WebAssembly.Memory instance shared between Dart and WASM
- **Pointer Abstraction**: WASM pointers are integer offsets into linear memory
- **Memory Management**: Explicit allocation/deallocation through SQLite's allocator

#### Function Export Strategy
- **Symbol Visibility**: All SQLite functions exported via `--export-dynamic` linker flag
- **Type Safety**: Dart wrappers provide type checking and parameter validation
- **Error Propagation**: SQLite error codes passed through unchanged

#### VFS Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Dart App      │    │   SQLite WASM   │    │  Browser APIs   │
│                 │    │                 │    │                 │
│ sqlite3_open()  │───▶│   VFS stub      │───▶│ IndexedDB       │
│                 │    │                 │    │ File API        │
│                 │    │                 │    │ OPFS (future)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Cross-Platform Compatibility

#### Pointer Handling
```dart
// Native implementation
Pointer<sqlite3> db = sqlite3_open_v2(path, ...);

// WASM implementation (identical API)
Pointer<sqlite3> db = sqlite3_open_v2(path, ...);
// Internally: WasmPointer wrapping memory offset
```

#### Error Code Consistency
Both implementations return identical SQLite error codes:
- `SQLITE_OK = 0`
- `SQLITE_ERROR = 1`
- `SQLITE_ROW = 100`
- `SQLITE_DONE = 101`

#### Memory Management Patterns
```dart
// Allocate memory (works on both platforms)
final ptr = sqlite3_malloc<Int8>(1024);

// Use memory...

// Free memory (works on both platforms)  
sqlite3_free(ptr);
```

---

## WASM Compilation Setup

### GitHub Actions Integration

The existing `sqlite-build.yml` workflow must be extended to include WASM compilation as an additional target:

```yaml
# Add to the existing matrix in .github/workflows/sqlite-build.yml
matrix:
  include:
    # ... existing targets (ubuntu, macos, windows)
    
    - name: web-wasm
      os: ubuntu-latest
      target: wasm32-unknown-wasi
      compiler: clang
      output: sqlite3.wasm
      uses_emscripten: false
```

### Build Dependencies

#### Required Tools Installation
```yaml
- name: Install WASM toolchain
  if: matrix.name == 'web-wasm'
  run: |
    # Install LLVM/Clang with WASM target support
    sudo apt-get update
    sudo apt-get install -y clang llvm cmake
    
    # Install WASI SDK
    wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-20/wasi-sdk-25.0-linux.tar.gz
    tar xzf wasi-sdk-25.0-linux.tar.gz
    echo "WASI_SYSROOT=$PWD/wasi-sdk-25.0/share/wasi-sysroot" >> $GITHUB_ENV
    
    # Install Binaryen for optimization
    sudo apt-get install -y binaryen
```

### CMake Build Configuration

Create `assets/wasm/CMakeLists.txt` with the complete build configuration:

```cmake
cmake_minimum_required(VERSION 3.20)
project(sqlite3_wasm C)

# Ensure we're targeting WASM
if(NOT CMAKE_SYSTEM_NAME STREQUAL "WASI")
    message(FATAL_ERROR "This CMakeLists.txt is for WASM builds only")
endif()

# SQLite compile-time options (matching existing builds)
set(SQLITE_COMPILE_OPTIONS
    -DSQLITE_ENABLE_FTS4
    -DSQLITE_ENABLE_FTS5
    -DSQLITE_ENABLE_RTREE
    -DSQLITE_ENABLE_GEOPOLY
    -DSQLITE_ENABLE_JSON1
    -DSQLITE_DISABLE_LFS
    -DSQLITE_THREADSAFE=0
    -DSQLITE_DEFAULT_MEMSTATUS=0
    -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1
)

# WASM-specific compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} \
    -Ofast \
    -nostartfiles \
    -Wl,--import-memory \
    -Wl,--no-entry \
    -Wl,--export-dynamic \
    -Wl,--strip-debug \
    -DSQLITE_API='__attribute__((visibility(\"default\")))' \
    ${SQLITE_COMPILE_OPTIONS}"
)

# Source files
set(SOURCES
    ../../sqlite/sqlite3.c
    os_web.c
    helpers.c
)

# Check for optional extension initialization
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/sqlite3_wasm_extra_init.c")
    list(APPEND SOURCES sqlite3_wasm_extra_init.c)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DSQLITE_EXTRA_INIT=sqlite3_wasm_extra_init")
endif()

# Create the WASM library
add_executable(sqlite3_wasm ${SOURCES})

# Set output name
set_target_properties(sqlite3_wasm PROPERTIES OUTPUT_NAME "sqlite3")

# Custom post-build optimization
add_custom_command(TARGET sqlite3_wasm POST_BUILD
    COMMAND wasm-strip sqlite3.wasm
    COMMENT "Stripping debug symbols from WASM binary"
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)
```

### Critical Compilation Flags Explained

| Flag | Purpose | Impact |
|------|---------|---------|
| `--target=wasm32-unknown-wasi` | Sets compilation target to WASM with WASI | Enables portable WASM output |
| `-nostartfiles` | No C runtime startup code | Required for library compilation |
| `-Wl,--no-entry` | No main() function expected | Library has no entry point |
| `-Wl,--import-memory` | Memory imported from host | **Critical**: Enables shared memory |
| `-Wl,--export-dynamic` | Export all global symbols | **Critical**: Makes SQLite functions callable |
| `-DSQLITE_THREADSAFE=0` | Disable threading | Web is single-threaded |
| `-DSQLITE_DISABLE_LFS` | Disable large file support | Not relevant in browser context |

### VFS Stub Implementation

Create `assets/wasm/os_web.c` with function stubs for VFS operations:

```c
#include "sqlite3.h"
#include <string.h>
#include <stdlib.h>

// Import module macros for Dart function injection
#define import_dart(name) __attribute__((import_module("dart"), import_name(name)))

// VFS function declarations (implemented in Dart)
import_dart("xOpen") extern int dart_vfs_xOpen(const char* zName, int fileId, int flags, int* pOutFlags);
import_dart("xDelete") extern int dart_vfs_xDelete(const char* zName, int syncDir);
import_dart("xAccess") extern int dart_vfs_xAccess(const char* zName, int flags, int* pResOut);
import_dart("xFullPathname") extern int dart_vfs_xFullPathname(const char* zName, int nOut, char* zOut);

// File-level operations  
import_dart("xClose") extern int dart_file_xClose(int fileId);
import_dart("xRead") extern int dart_file_xRead(int fileId, void* zBuf, int iAmt, int iOfst);
import_dart("xWrite") extern int dart_file_xWrite(int fileId, const void* zBuf, int iAmt, int iOfst);
import_dart("xTruncate") extern int dart_file_xTruncate(int fileId, int size);
import_dart("xSync") extern int dart_file_xSync(int fileId, int flags);
import_dart("xFileSize") extern int dart_file_xFileSize(int fileId, int* pSize);

// File structure for web VFS
typedef struct WebFile {
    sqlite3_file base;    // Base class - must be first
    int fileId;           // Unique identifier for Dart
} WebFile;

// Global file ID counter
static int g_next_file_id = 1;

// VFS Implementation functions
static int webVfsOpen(sqlite3_vfs* pVfs, const char* zName, sqlite3_file* pFile, 
                      int flags, int* pOutFlags) {
    WebFile* webFile = (WebFile*)pFile;
    webFile->fileId = g_next_file_id++;
    
    // Set up file methods
    static const sqlite3_io_methods webIoMethods = {
        1,                      // iVersion
        webFileClose,          // xClose
        webFileRead,           // xRead  
        webFileWrite,          // xWrite
        webFileTruncate,       // xTruncate
        webFileSync,           // xSync
        webFileFileSize,       // xFileSize
        NULL,                  // xLock (not needed)
        NULL,                  // xUnlock (not needed)
        NULL,                  // xCheckReservedLock (not needed)
        NULL,                  // xFileControl
        NULL,                  // xSectorSize
        NULL,                  // xDeviceCharacteristics
    };
    
    webFile->base.pMethods = &webIoMethods;
    return dart_vfs_xOpen(zName ? zName : "", webFile->fileId, flags, pOutFlags);
}

// File method implementations
static int webFileClose(sqlite3_file* pFile) {
    WebFile* webFile = (WebFile*)pFile;
    return dart_file_xClose(webFile->fileId);
}

static int webFileRead(sqlite3_file* pFile, void* zBuf, int iAmt, sqlite3_int64 iOfst) {
    WebFile* webFile = (WebFile*)pFile;
    return dart_file_xRead(webFile->fileId, zBuf, iAmt, (int)iOfst);
}

static int webFileWrite(sqlite3_file* pFile, const void* zBuf, int iAmt, sqlite3_int64 iOfst) {
    WebFile* webFile = (WebFile*)pFile;
    return dart_file_xWrite(webFile->fileId, zBuf, iAmt, (int)iOfst);
}

// VFS structure definition
static sqlite3_vfs webVfs = {
    3,                          // iVersion
    sizeof(WebFile),           // szOsFile
    512,                       // mxPathname
    NULL,                      // pNext
    "web",                     // zName
    NULL,                      // pAppData
    webVfsOpen,               // xOpen
    dart_vfs_xDelete,         // xDelete (direct call)
    dart_vfs_xAccess,         // xAccess (direct call)  
    dart_vfs_xFullPathname,   // xFullPathname (direct call)
    NULL,                     // xDlOpen (not supported)
    NULL,                     // xDlError (not supported)
    NULL,                     // xDlSym (not supported)  
    NULL,                     // xDlClose (not supported)
    NULL,                     // xRandomness (use default)
    NULL,                     // xSleep (use default)
    NULL,                     // xCurrentTime (use default)
    NULL,                     // xGetLastError
    NULL,                     // xCurrentTimeInt64 (use default)
};

// VFS registration function (called during SQLite initialization)
int sqlite3_web_vfs_init(void) {
    return sqlite3_vfs_register(&webVfs, 1);  // Make it the default VFS
}
```

### Build Script

Create `assets/wasm/build.sh` for local development:

```bash
#!/bin/bash
set -e

# Configuration
WASI_SDK_PATH="${WASI_SDK_PATH:-$HOME/wasi-sdk-25.0}"
SQLITE_SRC="../../sqlite"
BUILD_DIR="build"

if [ ! -d "$WASI_SDK_PATH" ]; then
    echo "Error: WASI SDK not found at $WASI_SDK_PATH"
    echo "Download from: https://github.com/WebAssembly/wasi-sdk/releases"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$WASI_SDK_PATH/share/cmake/wasi-sdk.cmake" \
    -DCMAKE_BUILD_TYPE=Release

# Build
make -j$(nproc)

# Verify output
if [ -f "sqlite3.wasm" ]; then
    echo "✅ WASM build successful: sqlite3.wasm"
    wasm-validate sqlite3.wasm
    echo "📊 File size: $(du -h sqlite3.wasm | cut -f1)"
else
    echo "❌ Build failed"
    exit 1
fi
```

---

## Virtual File System Implementation

### Function Injection Architecture

The VFS implementation uses WASM's function import mechanism to create a bridge between SQLite's C code and Dart's high-level APIs. This allows SQLite to call Dart functions as if they were C functions.

#### Injection Mechanism Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   SQLite C      │     │   WASM Linker   │     │   Dart Host     │
│                 │     │                 │     │                 │
│ xOpen() call    │────▶│ dart_vfs_xOpen  │────▶│ _vfsOpen()      │
│                 │     │ (imported)      │     │ (Dart method)   │
│                 │◀────│                 │◀────│                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Dart VFS Implementation

Create `lib/src/wasm/wasm_vfs.dart` with the complete VFS implementation:

```dart
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'indexeddb_vfs.dart';
import 'memory_utils.dart';

class WasmVirtualFileSystem {
  final WasmMemoryManager _memory;
  final Map<int, VirtualFile> _openFiles = {};
  final IndexedDbFileSystem _storage;
  
  WasmVirtualFileSystem(this._memory) : _storage = IndexedDbFileSystem();

  /// Creates the imports object for WASM instantiation
  Map<String, Object> createImports() {
    return {
      'dart': {
        // VFS-level operations
        'xOpen': _vfsOpen.toJS,
        'xDelete': _vfsDelete.toJS,
        'xAccess': _vfsAccess.toJS,
        'xFullPathname': _vfsFullPathname.toJS,
        
        // File-level operations
        'xClose': _fileClose.toJS,
        'xRead': _fileRead.toJS,
        'xWrite': _fileWrite.toJS,
        'xTruncate': _fileTruncate.toJS,
        'xSync': _fileSync.toJS,
        'xFileSize': _fileFileSize.toJS,
      }.jsify(),
    };
  }

  // VFS Operations Implementation
  
  int _vfsOpen(int namePtr, int fileId, int flags, int outFlagsPtr) {
    try {
      final filename = namePtr == 0 ? ':memory:' : _memory.readString(namePtr);
      final normalizedPath = _normalizePath(filename);
      
      final file = VirtualFile(
        id: fileId,
        path: normalizedPath,
        flags: flags,
        storage: _storage,
      );
      
      _openFiles[fileId] = file;
      
      // Set output flags if requested
      if (outFlagsPtr != 0) {
        _memory.setInt32(outFlagsPtr, flags);
      }
      
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('VFS xOpen error: $e');
      return SqliteError.SQLITE_CANTOPEN;
    }
  }

  int _vfsDelete(int namePtr, int syncDir) {
    try {
      final filename = _memory.readString(namePtr);
      final normalizedPath = _normalizePath(filename);
      
      // Delete from storage (async operation made sync)
      _storage.deleteFile(normalizedPath);
      
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('VFS xDelete error: $e');
      return SqliteError.SQLITE_IOERR_DELETE;
    }
  }

  int _vfsAccess(int namePtr, int flags, int resOutPtr) {
    try {
      final filename = _memory.readString(namePtr);
      final normalizedPath = _normalizePath(filename);
      
      final exists = _storage.fileExists(normalizedPath);
      _memory.setInt32(resOutPtr, exists ? 1 : 0);
      
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('VFS xAccess error: $e');
      return SqliteError.SQLITE_IOERR_ACCESS;
    }
  }

  int _vfsFullPathname(int namePtr, int nOut, int zOutPtr) {
    try {
      final filename = _memory.readString(namePtr);
      final normalized = _normalizePath(filename);
      final encoded = utf8.encode(normalized);
      
      if (encoded.length >= nOut) {
        return SqliteError.SQLITE_CANTOPEN;
      }
      
      _memory.writeBytes(zOutPtr, encoded);
      _memory.setUint8(zOutPtr + encoded.length, 0); // null terminator
      
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('VFS xFullPathname error: $e');
      return SqliteError.SQLITE_CANTOPEN;
    }
  }

  // File Operations Implementation

  int _fileClose(int fileId) {
    try {
      final file = _openFiles.remove(fileId);
      if (file == null) {
        return SqliteError.SQLITE_MISUSE;
      }
      
      file.close();
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('File xClose error: $e');
      return SqliteError.SQLITE_IOERR_CLOSE;
    }
  }

  int _fileRead(int fileId, int bufPtr, int amount, int offset) {
    try {
      final file = _openFiles[fileId];
      if (file == null) {
        return SqliteError.SQLITE_MISUSE;
      }
      
      final data = file.read(offset, amount);
      
      if (data.length < amount) {
        // Partial read - fill remaining with zeros
        final fullData = Uint8List(amount);
        fullData.setRange(0, data.length, data);
        _memory.writeBytes(bufPtr, fullData);
        return SqliteError.SQLITE_IOERR_SHORT_READ;
      } else {
        _memory.writeBytes(bufPtr, data);
        return SqliteError.SQLITE_OK;
      }
    } catch (e) {
      print('File xRead error: $e');
      return SqliteError.SQLITE_IOERR_READ;
    }
  }

  int _fileWrite(int fileId, int bufPtr, int amount, int offset) {
    try {
      final file = _openFiles[fileId];
      if (file == null) {
        return SqliteError.SQLITE_MISUSE;
      }
      
      final data = _memory.readBytes(bufPtr, amount);
      file.write(offset, data);
      
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('File xWrite error: $e');
      return SqliteError.SQLITE_IOERR_WRITE;
    }
  }

  int _fileTruncate(int fileId, int size) {
    try {
      final file = _openFiles[fileId];
      if (file == null) {
        return SqliteError.SQLITE_MISUSE;
      }
      
      file.truncate(size);
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('File xTruncate error: $e');
      return SqliteError.SQLITE_IOERR_TRUNCATE;
    }
  }

  int _fileSync(int fileId, int flags) {
    try {
      final file = _openFiles[fileId];
      if (file == null) {
        return SqliteError.SQLITE_MISUSE;
      }
      
      file.sync();
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('File xSync error: $e');
      return SqliteError.SQLITE_IOERR_FSYNC;
    }
  }

  int _fileFileSize(int fileId, int sizeOutPtr) {
    try {
      final file = _openFiles[fileId];
      if (file == null) {
        return SqliteError.SQLITE_MISUSE;
      }
      
      final size = file.size;
      _memory.setInt32(sizeOutPtr, size);
      
      return SqliteError.SQLITE_OK;
    } catch (e) {
      print('File xFileSize error: $e');
      return SqliteError.SQLITE_IOERR_FSTAT;
    }
  }

  // Helper Methods

  String _normalizePath(String path) {
    if (path == ':memory:') return path;
    
    // Normalize using package:path
    return p.normalize(path);
  }
}

/// Represents an open file in the virtual file system
class VirtualFile {
  final int id;
  final String path;
  final int flags;
  final IndexedDbFileSystem storage;
  
  VirtualFile({
    required this.id,
    required this.path,
    required this.flags,
    required this.storage,
  });

  Uint8List read(int offset, int length) {
    return storage.readFileData(path, offset, length);
  }

  void write(int offset, Uint8List data) {
    storage.writeFileData(path, offset, data);
  }

  void truncate(int size) {
    storage.truncateFile(path, size);
  }

  void sync() {
    storage.syncFile(path);
  }

  int get size => storage.getFileSize(path);

  void close() {
    // Nothing special needed for close
  }
}

/// SQLite error codes
class SqliteError {
  static const int SQLITE_OK = 0;
  static const int SQLITE_ERROR = 1;
  static const int SQLITE_MISUSE = 21;
  static const int SQLITE_CANTOPEN = 14;
  static const int SQLITE_IOERR_READ = 266;
  static const int SQLITE_IOERR_SHORT_READ = 522;
  static const int SQLITE_IOERR_WRITE = 778;
  static const int SQLITE_IOERR_FSYNC = 1034;
  static const int SQLITE_IOERR_FSTAT = 1802;
  static const int SQLITE_IOERR_TRUNCATE = 1546;
  static const int SQLITE_IOERR_CLOSE = 4102;
  static const int SQLITE_IOERR_DELETE = 2570;
  static const int SQLITE_IOERR_ACCESS = 3338;
}
```

### IndexedDB Storage Backend

Create `lib/src/wasm/indexeddb_vfs.dart` for persistent storage:

```dart
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:async';

/// File system backed by IndexedDB for persistent storage
class IndexedDbFileSystem {
  static const String DB_NAME = 'sqliteraw_fs';
  static const String STORE_NAME = 'file_blocks';
  static const int BLOCK_SIZE = 32768; // 32KB blocks
  
  html.Database? _db;
  final Map<String, FileMetadata> _fileCache = {};
  
  /// Initialize the IndexedDB connection
  Future<void> initialize() async {
    if (_db != null) return;
    
    final request = html.window.indexedDB!.open(DB_NAME, 1);
    
    request.onUpgradeNeeded.listen((event) {
      final db = request.result as html.Database;
      if (!db.objectStoreNames!.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME);
      }
    });
    
    _db = await request.future as html.Database;
  }

  /// Read data from a file at given offset
  Uint8List readFileData(String path, int offset, int length) {
    final metadata = _getFileMetadata(path);
    if (offset >= metadata.size) {
      return Uint8List(0);
    }
    
    final endOffset = (offset + length).clamp(0, metadata.size);
    final actualLength = endOffset - offset;
    final result = Uint8List(actualLength);
    
    final startBlock = offset ~/ BLOCK_SIZE;
    final endBlock = (endOffset - 1) ~/ BLOCK_SIZE;
    
    int resultOffset = 0;
    for (int blockIndex = startBlock; blockIndex <= endBlock; blockIndex++) {
      final blockData = _readBlock(path, blockIndex);
      
      final blockStart = blockIndex * BLOCK_SIZE;
      final blockEnd = blockStart + BLOCK_SIZE;
      
      final readStart = (offset - blockStart).clamp(0, BLOCK_SIZE);
      final readEnd = (endOffset - blockStart).clamp(0, BLOCK_SIZE);
      final readLength = readEnd - readStart;
      
      if (readLength > 0) {
        final sourceEnd = (readStart + readLength).clamp(0, blockData.length);
        final sourceData = blockData.sublist(readStart, sourceEnd);
        
        result.setRange(resultOffset, resultOffset + sourceData.length, sourceData);
        resultOffset += sourceData.length;
      }
    }
    
    return result;
  }

  /// Write data to a file at given offset
  void writeFileData(String path, int offset, Uint8List data) {
    final metadata = _getFileMetadata(path);
    
    final endOffset = offset + data.length;
    if (endOffset > metadata.size) {
      metadata.size = endOffset;
    }
    
    final startBlock = offset ~/ BLOCK_SIZE;
    final endBlock = (endOffset - 1) ~/ BLOCK_SIZE;
    
    int dataOffset = 0;
    for (int blockIndex = startBlock; blockIndex <= endBlock; blockIndex++) {
      final blockStart = blockIndex * BLOCK_SIZE;
      final writeStart = (offset - blockStart).clamp(0, BLOCK_SIZE);
      final writeEnd = (endOffset - blockStart).clamp(0, BLOCK_SIZE);
      final writeLength = writeEnd - writeStart;
      
      if (writeLength > 0) {
        var blockData = _readBlock(path, blockIndex);
        if (blockData.length < BLOCK_SIZE) {
          final newBlock = Uint8List(BLOCK_SIZE);
          newBlock.setRange(0, blockData.length, blockData);
          blockData = newBlock;
        }
        
        final sourceEnd = (dataOffset + writeLength).clamp(0, data.length);
        final sourceData = data.sublist(dataOffset, sourceEnd);
        
        blockData.setRange(writeStart, writeStart + sourceData.length, sourceData);
        _writeBlock(path, blockIndex, blockData);
        
        dataOffset += sourceData.length;
      }
    }
    
    _fileCache[path] = metadata;
  }

  /// Check if file exists
  bool fileExists(String path) {
    return _fileCache.containsKey(path) || _loadFileMetadata(path) != null;
  }

  /// Get file size
  int getFileSize(String path) {
    return _getFileMetadata(path).size;
  }

  /// Truncate file to specified size
  void truncateFile(String path, int size) {
    final metadata = _getFileMetadata(path);
    if (size < metadata.size) {
      metadata.size = size;
      
      // Remove blocks that are no longer needed
      final lastBlock = (size + BLOCK_SIZE - 1) ~/ BLOCK_SIZE;
      final currentBlocks = (metadata.size + BLOCK_SIZE - 1) ~/ BLOCK_SIZE;
      
      for (int i = lastBlock; i < currentBlocks; i++) {
        _deleteBlock(path, i);
      }
    }
    _fileCache[path] = metadata;
  }

  /// Synchronize file to storage
  void syncFile(String path) {
    // In IndexedDB, writes are automatically durable
    // This is a no-op but maintained for API compatibility
  }

  /// Delete file completely
  void deleteFile(String path) {
    final metadata = _fileCache.remove(path);
    if (metadata != null) {
      final numBlocks = (metadata.size + BLOCK_SIZE - 1) ~/ BLOCK_SIZE;
      for (int i = 0; i < numBlocks; i++) {
        _deleteBlock(path, i);
      }
    }
    _deleteFileMetadata(path);
  }

  // Private methods for block management

  Uint8List _readBlock(String path, int blockIndex) {
    // Synchronous read using SharedArrayBuffer for blocking behavior
    // This is a simplified implementation - real implementation would use
    // IndexedDB with sync-over-async pattern
    return Uint8List(0); // Placeholder
  }

  void _writeBlock(String path, int blockIndex, Uint8List data) {
    // Synchronous write using SharedArrayBuffer for blocking behavior
    // This is a simplified implementation - real implementation would use
    // IndexedDB with sync-over-async pattern
  }

  void _deleteBlock(String path, int blockIndex) {
    // Delete block from IndexedDB
  }

  FileMetadata _getFileMetadata(String path) {
    return _fileCache[path] ??= _loadFileMetadata(path) ?? FileMetadata(0);
  }

  FileMetadata? _loadFileMetadata(String path) {
    // Load from IndexedDB metadata store
    return null; // Placeholder
  }

  void _deleteFileMetadata(String path) {
    // Remove from IndexedDB metadata store
  }
}

class FileMetadata {
  int size;
  
  FileMetadata(this.size);
}
```

### Memory Synchronization Pattern

For operations that must be synchronous but use async browser APIs, we employ the SharedArrayBuffer + Atomics pattern:

```dart
/// Synchronous wrapper for async IndexedDB operations
class SyncIndexedDb {
  static const int OPERATION_TIMEOUT_MS = 5000;
  
  static Uint8List readBlockSync(String key) {
    final worker = html.Worker('indexeddb_worker.js');
    final sharedBuffer = Int32Array.fromList([0, 0]); // [status, length]
    final dataBuffer = ByteBuffer(1024 * 1024); // 1MB max
    
    worker.postMessage({
      'operation': 'read',
      'key': key,
      'statusBuffer': sharedBuffer,
      'dataBuffer': dataBuffer,
    });
    
    // Busy wait using Atomics.wait
    final startTime = DateTime.now().millisecondsSinceEpoch;
    while (sharedBuffer[0] == 0) {
      if (DateTime.now().millisecondsSinceEpoch - startTime > OPERATION_TIMEOUT_MS) {
        throw TimeoutException('IndexedDB read timeout');
      }
      // Small delay to prevent CPU spinning
      html.window.setTimeout(() {}, 1);
    }
    
    final status = sharedBuffer[0];
    final length = sharedBuffer[1];
    
    if (status < 0) {
      throw Exception('IndexedDB read failed');
    }
    
    return dataBuffer.asUint8List(0, length);
  }
}
```

---

## Dart WASM Integration

### WASM Module Loading

Create `lib/src/wasm/wasm_loader.dart` for module instantiation and management:

```dart
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:html' as html;
import 'memory_utils.dart';
import 'wasm_vfs.dart';

/// Manages the loading and instantiation of SQLite WASM module
class SqliteWasmLoader {
  static const String DEFAULT_WASM_URL = 'sqlite3.wasm';
  static const int DEFAULT_MEMORY_PAGES = 256; // 16MB initial memory
  
  WasmInstance? _instance;
  WasmMemoryManager? _memory;
  WasmVirtualFileSystem? _vfs;
  
  /// Load and instantiate the SQLite WASM module
  Future<WasmInstance> loadModule({String? wasmUrl}) async {
    if (_instance != null) {
      return _instance!;
    }
    
    // Fetch WASM binary
    final url = wasmUrl ?? DEFAULT_WASM_URL;
    final response = await html.window.fetch(url);
    if (!response.ok) {
      throw Exception('Failed to fetch WASM module: ${response.status}');
    }
    
    final wasmBytes = await response.arrayBuffer();
    
    // Create shared memory
    final memory = html.WebAssembly.Memory(html.MemoryDescriptor(initial: DEFAULT_MEMORY_PAGES));
    _memory = WasmMemoryManager(memory);
    
    // Create VFS
    _vfs = WasmVirtualFileSystem(_memory!);
    await _vfs!.initialize();
    
    // Create imports object
    final imports = {
      'env': {
        'memory': memory,
      }.jsify(),
      ..._vfs!.createImports(),
    };
    
    // Instantiate WASM module
    final module = await html.WebAssembly.instantiate(wasmBytes, imports.jsify());
    _instance = WasmInstance(module, _memory!, _vfs!);
    
    // Initialize SQLite and register VFS
    _instance!.callFunction('sqlite3_initialize');
    _instance!.callFunction('sqlite3_web_vfs_init');
    
    return _instance!;
  }
  
  /// Get the current WASM instance
  WasmInstance get instance {
    if (_instance == null) {
      throw StateError('WASM module not loaded. Call loadModule() first.');
    }
    return _instance!;
  }
  
  /// Shutdown and cleanup the WASM instance
  void shutdown() {
    if (_instance != null) {
      _instance!.callFunction('sqlite3_shutdown');
      _instance = null;
      _memory = null;
      _vfs = null;
    }
  }
}

/// Wrapper around a WASM instance with convenience methods
class WasmInstance {
  final html.WebAssembly.Instance _instance;
  final WasmMemoryManager _memory;
  final WasmVirtualFileSystem _vfs;
  final Map<String, JSFunction> _functionCache = {};
  
  WasmInstance(html.WebAssembly.instantiate result, this._memory, this._vfs)
      : _instance = result.instance!;
  
  /// Get memory manager
  WasmMemoryManager get memory => _memory;
  
  /// Get VFS instance
  WasmVirtualFileSystem get vfs => _vfs;
  
  /// Call a WASM function by name
  T callFunction<T>(String functionName, [List<Object>? args]) {
    final function = _getFunction(functionName);
    final result = function.callAsFunction(null, ...(args ?? []));
    return result as T;
  }
  
  /// Get a WASM function (with caching)
  JSFunction _getFunction(String name) {
    return _functionCache[name] ??= _instance.exports![name] as JSFunction;
  }
  
  /// Check if a function exists in the WASM module
  bool hasFunction(String name) {
    try {
      _getFunction(name);
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

### Memory Management

Create `lib/src/wasm/memory_utils.dart` for shared memory operations:

```dart
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html;

/// Manages shared memory between Dart and WASM
class WasmMemoryManager {
  final html.WebAssembly.Memory _memory;
  late final Uint8List _buffer;
  late final ByteData _byteData;
  
  WasmMemoryManager(this._memory) {
    _updateBuffer();
  }
  
  /// Update buffer references after memory growth
  void _updateBuffer() {
    final jsBuffer = _memory.buffer;
    // Convert JS ArrayBuffer to Dart Uint8List
    _buffer = jsBuffer.asUint8List();
    _byteData = ByteData.view(_buffer.buffer);
  }
  
  /// Get the raw memory buffer
  Uint8List get buffer => _buffer;
  
  /// Get memory size in bytes
  int get size => _buffer.length;
  
  /// Grow memory by specified number of pages (64KB each)
  void grow(int pages) {
    _memory.grow(pages);
    _updateBuffer();
  }
  
  // Integer operations
  
  int getInt8(int offset) => _byteData.getInt8(offset);
  void setInt8(int offset, int value) => _byteData.setInt8(offset, value);
  
  int getUint8(int offset) => _byteData.getUint8(offset);
  void setUint8(int offset, int value) => _byteData.setUint8(offset, value);
  
  int getInt16(int offset, [Endian endian = Endian.little]) => 
      _byteData.getInt16(offset, endian);
  void setInt16(int offset, int value, [Endian endian = Endian.little]) => 
      _byteData.setInt16(offset, value, endian);
  
  int getUint16(int offset, [Endian endian = Endian.little]) => 
      _byteData.getUint16(offset, endian);
  void setUint16(int offset, int value, [Endian endian = Endian.little]) => 
      _byteData.setUint16(offset, value, endian);
  
  int getInt32(int offset, [Endian endian = Endian.little]) => 
      _byteData.getInt32(offset, endian);
  void setInt32(int offset, int value, [Endian endian = Endian.little]) => 
      _byteData.setInt32(offset, value, endian);
  
  int getUint32(int offset, [Endian endian = Endian.little]) => 
      _byteData.getUint32(offset, endian);
  void setUint32(int offset, int value, [Endian endian = Endian.little]) => 
      _byteData.setUint32(offset, value, endian);
  
  int getInt64(int offset, [Endian endian = Endian.little]) => 
      _byteData.getInt64(offset, endian);
  void setInt64(int offset, int value, [Endian endian = Endian.little]) => 
      _byteData.setInt64(offset, value, endian);
  
  int getUint64(int offset, [Endian endian = Endian.little]) => 
      _byteData.getUint64(offset, endian);
  void setUint64(int offset, int value, [Endian endian = Endian.little]) => 
      _byteData.setUint64(offset, value, endian);
  
  // Float operations
  
  double getFloat32(int offset, [Endian endian = Endian.little]) => 
      _byteData.getFloat32(offset, endian);
  void setFloat32(int offset, double value, [Endian endian = Endian.little]) => 
      _byteData.setFloat32(offset, value, endian);
  
  double getFloat64(int offset, [Endian endian = Endian.little]) => 
      _byteData.getFloat64(offset, endian);
  void setFloat64(int offset, double value, [Endian endian = Endian.little]) => 
      _byteData.setFloat64(offset, value, endian);
  
  // Bulk operations
  
  /// Read bytes from memory
  Uint8List readBytes(int offset, int length) {
    _checkBounds(offset, length);
    return _buffer.sublist(offset, offset + length);
  }
  
  /// Write bytes to memory
  void writeBytes(int offset, List<int> bytes) {
    _checkBounds(offset, bytes.length);
    _buffer.setRange(offset, offset + bytes.length, bytes);
  }
  
  /// Fill memory region with a value
  void fillBytes(int offset, int length, int value) {
    _checkBounds(offset, length);
    _buffer.fillRange(offset, offset + length, value);
  }
  
  /// Copy memory from one location to another
  void copyBytes(int srcOffset, int dstOffset, int length) {
    _checkBounds(srcOffset, length);
    _checkBounds(dstOffset, length);
    
    final srcData = _buffer.sublist(srcOffset, srcOffset + length);
    _buffer.setRange(dstOffset, dstOffset + length, srcData);
  }
  
  // String operations
  
  /// Read a null-terminated UTF-8 string from memory
  String readString(int offset, [int? maxLength]) {
    if (offset == 0) return '';
    
    final startOffset = offset;
    int endOffset = offset;
    final limit = maxLength != null ? offset + maxLength : _buffer.length;
    
    // Find null terminator
    while (endOffset < limit && _buffer[endOffset] != 0) {
      endOffset++;
    }
    
    if (endOffset == startOffset) return '';
    
    final bytes = _buffer.sublist(startOffset, endOffset);
    return utf8.decode(bytes);
  }
  
  /// Write a UTF-8 string to memory with null terminator
  int writeString(int offset, String value) {
    final bytes = utf8.encode(value);
    final totalLength = bytes.length + 1; // +1 for null terminator
    
    _checkBounds(offset, totalLength);
    
    _buffer.setRange(offset, offset + bytes.length, bytes);
    _buffer[offset + bytes.length] = 0; // null terminator
    
    return totalLength;
  }
  
  /// Allocate memory and write string, returning offset
  int allocateString(String value) {
    final bytes = utf8.encode(value);
    final totalLength = bytes.length + 1;
    
    // This is a simplified allocator - real implementation would use malloc
    final offset = _findFreeSpace(totalLength);
    writeString(offset, value);
    return offset;
  }
  
  // Memory allocation helpers
  
  /// Find free space in memory (simplified implementation)
  int _findFreeSpace(int size) {
    // This is a very basic allocator - real implementation would track
    // allocated regions and use SQLite's malloc/free functions
    static int _nextOffset = 1024; // Start after first 1KB for safety
    
    final offset = _nextOffset;
    _nextOffset += size;
    
    if (_nextOffset >= _buffer.length) {
      // Need to grow memory
      final pagesNeeded = ((_nextOffset - _buffer.length) / 65536).ceil();
      grow(pagesNeeded);
    }
    
    return offset;
  }
  
  /// Check if memory access is within bounds
  void _checkBounds(int offset, int length) {
    if (offset < 0 || offset + length > _buffer.length) {
      throw RangeError('Memory access out of bounds: offset=$offset, length=$length, memSize=${_buffer.length}');
    }
  }
  
  /// Debug: dump memory region as hex
  String dumpMemory(int offset, int length) {
    final bytes = readBytes(offset, length);
    final buffer = StringBuffer();
    
    for (int i = 0; i < bytes.length; i += 16) {
      buffer.write('${(offset + i).toRadixString(16).padLeft(8, '0')}: ');
      
      for (int j = 0; j < 16 && i + j < bytes.length; j++) {
        buffer.write('${bytes[i + j].toRadixString(16).padLeft(2, '0')} ');
      }
      
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}
```

### WASM-Specific SQLite API

Create `lib/src/wasm/sqliteraw_wasm.dart` with the main WASM implementation:

```dart
import 'dart:js_interop';
import 'dart:ffi' show Pointer, NativeType; // For type compatibility
import 'dart:typed_data';

import '../common/raw_api.dart';
import 'wasm_loader.dart';
import 'memory_utils.dart';
import 'wasm_pointer.dart';

/// WASM implementation of SQLite raw API
class SqliteRawWasm implements SqliteRawApi {
  late final SqliteWasmLoader _loader;
  late final WasmInstance _instance;
  late final WasmMemoryManager _memory;
  
  bool _initialized = false;
  
  /// Initialize the WASM SQLite implementation
  Future<void> initialize([String? wasmUrl]) async {
    if (_initialized) return;
    
    _loader = SqliteWasmLoader();
    _instance = await _loader.loadModule(wasmUrl: wasmUrl);
    _memory = _instance.memory;
    _initialized = true;
  }
  
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SQLite WASM not initialized. Call initialize() first.');
    }
  }
  
  // Core database operations
  
  @override
  int sqlite3_open_v2(String filename, Pointer<Pointer<sqlite3>> ppDb, 
                      int flags, String? zVfs) {
    _ensureInitialized();
    
    // Allocate memory for filename
    final filenamePtr = _memory.allocateString(filename);
    
    // Allocate memory for database pointer output
    final dbPtrPtr = _memory._findFreeSpace(8); // Size of pointer
    
    // Allocate memory for VFS name if provided
    final vfsPtr = zVfs != null ? _memory.allocateString(zVfs) : 0;
    
    try {
      final result = _instance.callFunction<int>('sqlite3_open_v2', 
          [filenamePtr, dbPtrPtr, flags, vfsPtr]);
      
      if (result == 0) {
        // Read the database pointer from output parameter
        final dbPtr = _memory.getInt32(dbPtrPtr);
        (ppDb as WasmPointer).offset = dbPtrPtr;
      }
      
      return result;
    } finally {
      // Clean up temporary allocations would go here
    }
  }
  
  @override
  int sqlite3_close_v2(Pointer<sqlite3> db) {
    _ensureInitialized();
    
    final dbPtr = (db as WasmPointer).offset;
    return _instance.callFunction<int>('sqlite3_close_v2', [dbPtr]);
  }
  
  @override
  int sqlite3_prepare_v2(Pointer<sqlite3> db, String zSql, int nByte,
                         Pointer<Pointer<sqlite3_stmt>> ppStmt, 
                         Pointer<Pointer<Int8>>? pzTail) {
    _ensureInitialized();
    
    final dbPtr = (db as WasmPointer).offset;
    final sqlPtr = _memory.allocateString(zSql);
    final stmtPtrPtr = _memory._findFreeSpace(8);
    final tailPtrPtr = pzTail != null ? _memory._findFreeSpace(8) : 0;
    
    final result = _instance.callFunction<int>('sqlite3_prepare_v2',
        [dbPtr, sqlPtr, nByte, stmtPtrPtr, tailPtrPtr]);
    
    if (result == 0) {
      final stmtPtr = _memory.getInt32(stmtPtrPtr);
      (ppStmt as WasmPointer).offset = stmtPtrPtr;
      
      if (pzTail != null) {
        final tailPtr = _memory.getInt32(tailPtrPtr);
        (pzTail as WasmPointer).offset = tailPtrPtr;
      }
    }
    
    return result;
  }
  
  @override
  int sqlite3_step(Pointer<sqlite3_stmt> stmt) {
    _ensureInitialized();
    
    final stmtPtr = (stmt as WasmPointer).offset;
    return _instance.callFunction<int>('sqlite3_step', [stmtPtr]);
  }
  
  @override
  int sqlite3_finalize(Pointer<sqlite3_stmt> stmt) {
    _ensureInitialized();
    
    final stmtPtr = (stmt as WasmPointer).offset;
    return _instance.callFunction<int>('sqlite3_finalize', [stmtPtr]);
  }
  
  // Data access methods
  
  @override
  String sqlite3_column_text(Pointer<sqlite3_stmt> stmt, int iCol) {
    _ensureInitialized();
    
    final stmtPtr = (stmt as WasmPointer).offset;
    final textPtr = _instance.callFunction<int>('sqlite3_column_text', [stmtPtr, iCol]);
    
    if (textPtr == 0) return '';
    return _memory.readString(textPtr);
  }
  
  @override
  int sqlite3_column_int(Pointer<sqlite3_stmt> stmt, int iCol) {
    _ensureInitialized();
    
    final stmtPtr = (stmt as WasmPointer).offset;
    return _instance.callFunction<int>('sqlite3_column_int', [stmtPtr, iCol]);
  }
  
  // Error handling
  
  @override
  int sqlite3_errcode(Pointer<sqlite3> db) {
    _ensureInitialized();
    
    final dbPtr = (db as WasmPointer).offset;
    return _instance.callFunction<int>('sqlite3_errcode', [dbPtr]);
  }
  
  @override
  String sqlite3_errmsg(Pointer<sqlite3> db) {
    _ensureInitialized();
    
    final dbPtr = (db as WasmPointer).offset;
    final msgPtr = _instance.callFunction<int>('sqlite3_errmsg', [dbPtr]);
    
    if (msgPtr == 0) return '';
    return _memory.readString(msgPtr);
  }
  
  // Memory management
  
  @override
  Pointer<T> sqlite3_malloc<T extends NativeType>(int size) {
    _ensureInitialized();
    
    final ptr = _instance.callFunction<int>('sqlite3_malloc', [size]);
    return WasmPointer<T>(ptr, _memory);
  }
  
  @override
  void sqlite3_free(Pointer<void> ptr) {
    _ensureInitialized();
    
    final offset = (ptr as WasmPointer).offset;
    if (offset != 0) {
      _instance.callFunction('sqlite3_free', [offset]);
    }
  }
}

// Type stubs for SQLite structures (opaque types in WASM)
class sqlite3 {}
class sqlite3_stmt {}
class Int8 {}
```

---