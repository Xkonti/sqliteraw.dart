import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';
import 'minimal_api.dart';

/// Native-specific SQLite implementation using dart:ffi
class MinimalSqliteUnifiedImpl implements MinimalSqliteApi {
  DynamicLibrary? _library;
  bool _initialized = false;

  // Function pointers (nullable for re-initialization support)
  Pointer<Char> Function()? _libversion;
  int Function()? _libversionNumber;
  int Function()? _initialize;
  int Function()? _shutdown;

  // Core database operation function pointers
  int Function(Pointer<Utf8>, Pointer<Pointer<sqlite3>>)? _sqlite3_open;
  int Function(Pointer<sqlite3>)? _sqlite3_close;
  int Function(Pointer<sqlite3>, Pointer<Utf8>, int, Pointer<Pointer<sqlite3_stmt>>, Pointer<Pointer<Utf8>>)? _sqlite3_prepare_v2;
  int Function(Pointer<sqlite3_stmt>)? _sqlite3_step;
  int Function(Pointer<sqlite3_stmt>)? _sqlite3_finalize;
  int Function(Pointer<sqlite3_stmt>)? _sqlite3_reset;
  int Function(Pointer<sqlite3_stmt>, int, Pointer<Utf8>, int, Pointer<NativeFunction<Void Function(Pointer<Void>)>>)? _sqlite3_bind_text;
  int Function(Pointer<sqlite3_stmt>, int, int)? _sqlite3_bind_int;
  int Function(Pointer<sqlite3_stmt>, int)? _sqlite3_bind_null;
  int Function(Pointer<sqlite3_stmt>)? _sqlite3_column_count;
  int Function(Pointer<sqlite3_stmt>, int)? _sqlite3_column_type;
  Pointer<Utf8> Function(Pointer<sqlite3_stmt>, int)? _sqlite3_column_text;
  int Function(Pointer<sqlite3_stmt>, int)? _sqlite3_column_int;
  Pointer<Utf8> Function(Pointer<sqlite3_stmt>, int)? _sqlite3_column_name;
  int Function(Pointer<sqlite3>)? _sqlite3_errcode;
  Pointer<Utf8> Function(Pointer<sqlite3>)? _sqlite3_errmsg;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load native SQLite library using dart:ffi
      _library = DynamicLibrary.open(_getNativeLibraryPath());

      // Bind functions using the library
      _libversion = _library!
          .lookup<NativeFunction<Pointer<Char> Function()>>('sqlite3_libversion')
          .asFunction<Pointer<Char> Function()>();

      _libversionNumber = _library!
          .lookup<NativeFunction<Int32 Function()>>('sqlite3_libversion_number')
          .asFunction<int Function()>();

      _initialize = _library!
          .lookup<NativeFunction<Int32 Function()>>('sqlite3_initialize')
          .asFunction<int Function()>();

      _shutdown = _library!
          .lookup<NativeFunction<Int32 Function()>>('sqlite3_shutdown')
          .asFunction<int Function()>();

      // Bind core database operation functions
      _sqlite3_open = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<Utf8>, Pointer<Pointer<sqlite3>>)>>('sqlite3_open')
          .asFunction<int Function(Pointer<Utf8>, Pointer<Pointer<sqlite3>>)>();

      _sqlite3_close = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3>)>>('sqlite3_close')
          .asFunction<int Function(Pointer<sqlite3>)>();

      _sqlite3_prepare_v2 = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3>, Pointer<Utf8>, Int32, Pointer<Pointer<sqlite3_stmt>>, Pointer<Pointer<Utf8>>)>>('sqlite3_prepare_v2')
          .asFunction<int Function(Pointer<sqlite3>, Pointer<Utf8>, int, Pointer<Pointer<sqlite3_stmt>>, Pointer<Pointer<Utf8>>)>();

      _sqlite3_step = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>)>>('sqlite3_step')
          .asFunction<int Function(Pointer<sqlite3_stmt>)>();

      _sqlite3_finalize = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>)>>('sqlite3_finalize')
          .asFunction<int Function(Pointer<sqlite3_stmt>)>();

      _sqlite3_reset = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>)>>('sqlite3_reset')
          .asFunction<int Function(Pointer<sqlite3_stmt>)>();

      _sqlite3_bind_text = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>, Int32, Pointer<Utf8>, Int32, Pointer<NativeFunction<Void Function(Pointer<Void>)>>)>>('sqlite3_bind_text')
          .asFunction<int Function(Pointer<sqlite3_stmt>, int, Pointer<Utf8>, int, Pointer<NativeFunction<Void Function(Pointer<Void>)>>)>();

      _sqlite3_bind_int = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>, Int32, Int32)>>('sqlite3_bind_int')
          .asFunction<int Function(Pointer<sqlite3_stmt>, int, int)>();

      _sqlite3_bind_null = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>, Int32)>>('sqlite3_bind_null')
          .asFunction<int Function(Pointer<sqlite3_stmt>, int)>();

      _sqlite3_column_count = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>)>>('sqlite3_column_count')
          .asFunction<int Function(Pointer<sqlite3_stmt>)>();

      _sqlite3_column_type = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>, Int32)>>('sqlite3_column_type')
          .asFunction<int Function(Pointer<sqlite3_stmt>, int)>();

      _sqlite3_column_text = _library!
          .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<sqlite3_stmt>, Int32)>>('sqlite3_column_text')
          .asFunction<Pointer<Utf8> Function(Pointer<sqlite3_stmt>, int)>();

      _sqlite3_column_int = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3_stmt>, Int32)>>('sqlite3_column_int')
          .asFunction<int Function(Pointer<sqlite3_stmt>, int)>();

      _sqlite3_column_name = _library!
          .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<sqlite3_stmt>, Int32)>>('sqlite3_column_name')
          .asFunction<Pointer<Utf8> Function(Pointer<sqlite3_stmt>, int)>();

      _sqlite3_errcode = _library!
          .lookup<NativeFunction<Int32 Function(Pointer<sqlite3>)>>('sqlite3_errcode')
          .asFunction<int Function(Pointer<sqlite3>)>();

      _sqlite3_errmsg = _library!
          .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<sqlite3>)>>('sqlite3_errmsg')
          .asFunction<Pointer<Utf8> Function(Pointer<sqlite3>)>();

      // Initialize SQLite
      final result = _initialize!();
      if (result != SQLITE_OK) {
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
    if (_initialized) {
      try {
        _shutdown?.call();
      } catch (e) {
        // Ignore shutdown errors
      }
      
      // Clean up the library
      _library?.close();
      _library = null;
      
      // Clear function pointers for re-initialization
      _libversion = null;
      _libversionNumber = null;
      _initialize = null;
      _shutdown = null;
      _sqlite3_open = null;
      _sqlite3_close = null;
      _sqlite3_prepare_v2 = null;
      _sqlite3_step = null;
      _sqlite3_finalize = null;
      _sqlite3_reset = null;
      _sqlite3_bind_text = null;
      _sqlite3_bind_int = null;
      _sqlite3_bind_null = null;
      _sqlite3_column_count = null;
      _sqlite3_column_type = null;
      _sqlite3_column_text = null;
      _sqlite3_column_int = null;
      _sqlite3_column_name = null;
      _sqlite3_errcode = null;
      _sqlite3_errmsg = null;
      
      _initialized = false;
    }
  }

  // === CORE DATABASE OPERATIONS ===
  
  @override
  int sqlite3_open(Pointer<Utf8> filename, Pointer<Pointer<sqlite3>> ppDb) {
    _ensureInitialized();
    return _sqlite3_open!(filename, ppDb);
  }

  @override
  int sqlite3_close(Pointer<sqlite3> db) {
    _ensureInitialized();
    return _sqlite3_close!(db);
  }

  @override
  int sqlite3_prepare_v2(Pointer<sqlite3> db, Pointer<Utf8> zSql, int nByte, Pointer<Pointer<sqlite3_stmt>> ppStmt, Pointer<Pointer<Utf8>> pzTail) {
    _ensureInitialized();
    return _sqlite3_prepare_v2!(db, zSql, nByte, ppStmt, pzTail);
  }

  @override
  int sqlite3_step(Pointer<sqlite3_stmt> stmt) {
    _ensureInitialized();
    return _sqlite3_step!(stmt);
  }

  @override
  int sqlite3_finalize(Pointer<sqlite3_stmt> stmt) {
    _ensureInitialized();
    return _sqlite3_finalize!(stmt);
  }

  @override
  int sqlite3_reset(Pointer<sqlite3_stmt> stmt) {
    _ensureInitialized();
    return _sqlite3_reset!(stmt);
  }

  @override
  int sqlite3_bind_text(Pointer<sqlite3_stmt> stmt, int index, Pointer<Utf8> text, int nBytes, Pointer<NativeFunction<Void Function(Pointer<Void>)>> destructor) {
    _ensureInitialized();
    return _sqlite3_bind_text!(stmt, index, text, nBytes, destructor);
  }

  @override
  int sqlite3_bind_int(Pointer<sqlite3_stmt> stmt, int index, int value) {
    _ensureInitialized();
    return _sqlite3_bind_int!(stmt, index, value);
  }

  @override
  int sqlite3_bind_null(Pointer<sqlite3_stmt> stmt, int index) {
    _ensureInitialized();
    return _sqlite3_bind_null!(stmt, index);
  }

  @override
  int sqlite3_column_count(Pointer<sqlite3_stmt> stmt) {
    _ensureInitialized();
    return _sqlite3_column_count!(stmt);
  }

  @override
  int sqlite3_column_type(Pointer<sqlite3_stmt> stmt, int iCol) {
    _ensureInitialized();
    return _sqlite3_column_type!(stmt, iCol);
  }

  @override
  Pointer<Utf8> sqlite3_column_text(Pointer<sqlite3_stmt> stmt, int iCol) {
    _ensureInitialized();
    return _sqlite3_column_text!(stmt, iCol);
  }

  @override
  int sqlite3_column_int(Pointer<sqlite3_stmt> stmt, int iCol) {
    _ensureInitialized();
    return _sqlite3_column_int!(stmt, iCol);
  }

  @override
  Pointer<Utf8> sqlite3_column_name(Pointer<sqlite3_stmt> stmt, int N) {
    _ensureInitialized();
    return _sqlite3_column_name!(stmt, N);
  }

  @override
  int sqlite3_errcode(Pointer<sqlite3> db) {
    _ensureInitialized();
    return _sqlite3_errcode!(db);
  }

  @override
  Pointer<Utf8> sqlite3_errmsg(Pointer<sqlite3> db) {
    _ensureInitialized();
    return _sqlite3_errmsg!(db);
  }

  /// Get native library path for the current platform
  String _getNativeLibraryPath() {
    if (Platform.isWindows) {
      return 'sqlite3.dll';
    } else if (Platform.isMacOS) {
      return '/usr/lib/libsqlite3.dylib';
    } else if (Platform.isLinux) {
      // Use the locally compiled SQLite library
      return 'sqlite/libsqlite3.so';
    } else {
      return 'sqlite3'; // Fallback
    }
  }

  /// Ensure the SQLite library is initialized
  void _ensureInitialized() {
    if (!_initialized || _library == null) {
      throw StateError('SQLite native not initialized. Call initialize() first.');
    }
  }
}