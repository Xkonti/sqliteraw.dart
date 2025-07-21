import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'minimal_api.dart';

/// Native FFI implementation of minimal SQLite API
/// 
/// This implementation uses dart:ffi to call SQLite functions
/// from dynamically loaded native libraries.
class MinimalSqliteNativeImpl implements MinimalSqliteApi {
  DynamicLibrary? _lib;
  Pointer<Char> Function()? _libversion;
  int Function()? _libversionNumber;
  int Function()? _initialize;
  int Function()? _shutdown;
  
  bool _initialized = false;
  
  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Load platform-specific SQLite library
      _lib = _loadNativeLibrary();
      
      // Bind functions
      _libversion = _lib!
          .lookup<NativeFunction<Pointer<Char> Function()>>('sqlite3_libversion')
          .asFunction<Pointer<Char> Function()>();
      
      _libversionNumber = _lib!
          .lookup<NativeFunction<Int32 Function()>>('sqlite3_libversion_number')
          .asFunction<int Function()>();
      
      _initialize = _lib!
          .lookup<NativeFunction<Int32 Function()>>('sqlite3_initialize')
          .asFunction<int Function()>();
      
      _shutdown = _lib!
          .lookup<NativeFunction<Int32 Function()>>('sqlite3_shutdown')
          .asFunction<int Function()>();
      
      // Initialize SQLite
      final result = _initialize!();
      if (result != 0) {
        throw Exception('SQLite initialization failed with error code: $result');
      }
      
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize SQLite native: $e');
    }
  }
  
  @override
  String getVersion() {
    _ensureInitialized();
    return _libversion!().cast<Utf8>().toDartString();
  }
  
  @override
  int getVersionNumber() {
    _ensureInitialized();
    return _libversionNumber!();
  }
  
  @override
  void shutdown() {
    if (_initialized && _lib != null) {
      try {
        _shutdown?.call();
      } catch (e) {
        // Ignore shutdown errors
      }
      _lib?.close();
      _lib = null;
      _libversion = null;
      _libversionNumber = null;
      _initialize = null;
      _shutdown = null;
      _initialized = false;
    }
  }
  
  /// Load the appropriate native SQLite library for the current platform
  DynamicLibrary _loadNativeLibrary() {
    // Try to load SQLite from common locations
    final possibleNames = _getPlatformLibraryNames();
    
    for (final name in possibleNames) {
      try {
        return DynamicLibrary.open(name);
      } catch (e) {
        // Continue to next option
        continue;
      }
    }
    
    // If all failed, throw a helpful error
    throw Exception(
      'Could not load SQLite library. Tried: ${possibleNames.join(', ')}\n'
      'Please ensure SQLite is installed on your system:\n'
      '  - Linux: sudo apt install sqlite3 libsqlite3-dev\n'
      '  - macOS: brew install sqlite\n'
      '  - Windows: Download SQLite from https://sqlite.org/download.html'
    );
  }
  
  /// Get platform-specific library names to try
  List<String> _getPlatformLibraryNames() {
    if (Platform.isWindows) {
      return [
        'sqlite3.dll',
        'winsqlite3.dll', // Windows 10+ built-in SQLite
      ];
    } else if (Platform.isMacOS) {
      return [
        'sqlite3.dylib',
        'libsqlite3.dylib',
        '/usr/lib/libsqlite3.dylib',
        '/usr/local/lib/libsqlite3.dylib',
      ];
    } else if (Platform.isLinux) {
      return [
        'sqlite3.so',
        'libsqlite3.so',
        'libsqlite3.so.0',
        '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
        '/usr/lib/libsqlite3.so.0',
      ];
    } else {
      // Generic Unix-like
      return [
        'sqlite3.so',
        'libsqlite3.so',
        'sqlite3.dylib',
        'libsqlite3.dylib',
      ];
    }
  }
  
  /// Ensure the native library is initialized
  void _ensureInitialized() {
    if (!_initialized || _lib == null || _libversion == null) {
      throw StateError('SQLite native not initialized. Call initialize() first.');
    }
  }
}