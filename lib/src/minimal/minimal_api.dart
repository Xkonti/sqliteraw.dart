import 'dart:ffi';
import 'package:universal_ffi/ffi.dart' as uffi;
import 'package:ffi/ffi.dart';

// Opaque types for SQLite handles  
final class sqlite3 extends uffi.Opaque {}
final class sqlite3_stmt extends uffi.Opaque {}

/// SQLite API interface with core database operations
/// 
/// This interface provides raw FFI bindings that work identically across
/// native and web platforms using universal_ffi.
abstract interface class MinimalSqliteApi {
  /// Initialize the SQLite implementation
  Future<void> initialize();
  
  /// Get SQLite library version string
  /// Equivalent to calling sqlite3_libversion()
  String getVersion();
  
  /// Get SQLite library version number
  /// Equivalent to calling sqlite3_libversion_number()
  int getVersionNumber();
  
  /// Cleanup and shutdown
  void shutdown();
  
  // === CORE DATABASE OPERATIONS ===
  
  /// Open a database connection
  /// Returns SQLITE_OK (0) on success
  int sqlite3_open(Pointer<Utf8> filename, Pointer<Pointer<sqlite3>> ppDb);
  
  /// Close a database connection
  /// Returns SQLITE_OK (0) on success
  int sqlite3_close(Pointer<sqlite3> db);
  
  /// Prepare an SQL statement for execution
  /// Returns SQLITE_OK (0) on success
  int sqlite3_prepare_v2(
    Pointer<sqlite3> db,
    Pointer<Utf8> zSql,
    int nByte,
    Pointer<Pointer<sqlite3_stmt>> ppStmt,
    Pointer<Pointer<Utf8>> pzTail,
  );
  
  /// Execute a prepared statement
  /// Returns SQLITE_ROW (100), SQLITE_DONE (101), or error code
  int sqlite3_step(Pointer<sqlite3_stmt> stmt);
  
  /// Finalize (destroy) a prepared statement
  /// Returns SQLITE_OK (0) on success
  int sqlite3_finalize(Pointer<sqlite3_stmt> stmt);
  
  /// Reset a prepared statement for re-execution
  /// Returns SQLITE_OK (0) on success
  int sqlite3_reset(Pointer<sqlite3_stmt> stmt);
  
  /// Bind a UTF-8 text value to a parameter
  int sqlite3_bind_text(
    Pointer<sqlite3_stmt> stmt,
    int index,
    Pointer<Utf8> text,
    int nBytes,
    Pointer<NativeFunction<Void Function(Pointer<Void>)>> destructor,
  );
  
  /// Bind an integer value to a parameter
  int sqlite3_bind_int(Pointer<sqlite3_stmt> stmt, int index, int value);
  
  /// Bind a NULL value to a parameter
  int sqlite3_bind_null(Pointer<sqlite3_stmt> stmt, int index);
  
  /// Get the number of columns in the result set
  int sqlite3_column_count(Pointer<sqlite3_stmt> stmt);
  
  /// Get the data type of a column
  int sqlite3_column_type(Pointer<sqlite3_stmt> stmt, int iCol);
  
  /// Get text value from a column
  Pointer<Utf8> sqlite3_column_text(Pointer<sqlite3_stmt> stmt, int iCol);
  
  /// Get integer value from a column
  int sqlite3_column_int(Pointer<sqlite3_stmt> stmt, int iCol);
  
  /// Get column name
  Pointer<Utf8> sqlite3_column_name(Pointer<sqlite3_stmt> stmt, int N);
  
  /// Get the error code from the most recent SQLite operation
  int sqlite3_errcode(Pointer<sqlite3> db);
  
  /// Get error message for the most recent SQLite operation
  Pointer<Utf8> sqlite3_errmsg(Pointer<sqlite3> db);
}

// SQLite constants
const int SQLITE_OK = 0;
const int SQLITE_ERROR = 1;
const int SQLITE_ROW = 100;
const int SQLITE_DONE = 101;

// Data types
const int SQLITE_INTEGER = 1;
const int SQLITE_FLOAT = 2;
const int SQLITE_TEXT = 3;
const int SQLITE_BLOB = 4;
const int SQLITE_NULL = 5;

// Special destructor values
final SQLITE_STATIC = Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(0);
final SQLITE_TRANSIENT = Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(-1);