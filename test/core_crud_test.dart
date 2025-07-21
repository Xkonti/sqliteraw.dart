import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() {
  group('Core SQLite CRUD Operations', () {
    late MinimalSqliteApi sqlite;
    
    setUp(() async {
      sqlite = createMinimalSqlite();
      await sqlite.initialize();
    });
    
    tearDown(() {
      sqlite.shutdown();
    });
    
    test('can create and use a memory database', () {
      // Allocate memory for database handle
      final dbPtr = calloc<Pointer<sqlite3>>();
      
      try {
        // Open memory database
        final filename = ':memory:'.toNativeUtf8();
        final result = sqlite.sqlite3_open(filename, dbPtr);
        
        expect(result, equals(SQLITE_OK));
        expect(dbPtr.value, isNot(nullptr));
        
        final db = dbPtr.value;
        
        // Close database
        final closeResult = sqlite.sqlite3_close(db);
        expect(closeResult, equals(SQLITE_OK));
        
      } finally {
        calloc.free(dbPtr);
      }
    });
    
    test('can execute basic SQL statements', () {
      final dbPtr = calloc<Pointer<sqlite3>>();
      final stmtPtr = calloc<Pointer<sqlite3_stmt>>();
      
      try {
        // Open database
        final filename = ':memory:'.toNativeUtf8();
        expect(sqlite.sqlite3_open(filename, dbPtr), equals(SQLITE_OK));
        final db = dbPtr.value;
        
        // Create table
        final createSql = 'CREATE TABLE test (id INTEGER, name TEXT)'.toNativeUtf8();
        final prepResult = sqlite.sqlite3_prepare_v2(
          db, 
          createSql, 
          -1, 
          stmtPtr, 
          nullptr,
        );
        expect(prepResult, equals(SQLITE_OK));
        
        final stmt = stmtPtr.value;
        expect(stmt, isNot(nullptr));
        
        // Execute create table
        final stepResult = sqlite.sqlite3_step(stmt);
        expect(stepResult, equals(SQLITE_DONE));
        
        // Finalize statement
        expect(sqlite.sqlite3_finalize(stmt), equals(SQLITE_OK));
        
        // Close database
        expect(sqlite.sqlite3_close(db), equals(SQLITE_OK));
        
      } finally {
        calloc.free(dbPtr);
        calloc.free(stmtPtr);
      }
    });
    
    test('can insert and select data with parameter binding', () {
      final dbPtr = calloc<Pointer<sqlite3>>();
      final stmtPtr = calloc<Pointer<sqlite3_stmt>>();
      
      try {
        // Open database and create table
        final filename = ':memory:'.toNativeUtf8();
        expect(sqlite.sqlite3_open(filename, dbPtr), equals(SQLITE_OK));
        final db = dbPtr.value;
        
        // Create table
        final createSql = 'CREATE TABLE users (id INTEGER, name TEXT)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, createSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(stmtPtr.value), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(stmtPtr.value), equals(SQLITE_OK));
        
        // Insert data with parameter binding
        final insertSql = 'INSERT INTO users (id, name) VALUES (?, ?)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, insertSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final insertStmt = stmtPtr.value;
        
        // Bind parameters
        expect(sqlite.sqlite3_bind_int(insertStmt, 1, 42), equals(SQLITE_OK));
        final nameValue = 'John Doe'.toNativeUtf8();
        expect(sqlite.sqlite3_bind_text(insertStmt, 2, nameValue, -1, SQLITE_TRANSIENT), equals(SQLITE_OK));
        
        // Execute insert
        expect(sqlite.sqlite3_step(insertStmt), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(insertStmt), equals(SQLITE_OK));
        
        // Select data back
        final selectSql = 'SELECT id, name FROM users WHERE id = ?'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, selectSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final selectStmt = stmtPtr.value;
        
        // Bind parameter for WHERE clause
        expect(sqlite.sqlite3_bind_int(selectStmt, 1, 42), equals(SQLITE_OK));
        
        // Execute and fetch result
        final stepResult = sqlite.sqlite3_step(selectStmt);
        expect(stepResult, equals(SQLITE_ROW));
        
        // Check column count
        expect(sqlite.sqlite3_column_count(selectStmt), equals(2));
        
        // Retrieve values
        final retrievedId = sqlite.sqlite3_column_int(selectStmt, 0);
        expect(retrievedId, equals(42));
        
        final retrievedNamePtr = sqlite.sqlite3_column_text(selectStmt, 1);
        final retrievedName = retrievedNamePtr.cast<Utf8>().toDartString();
        expect(retrievedName, equals('John Doe'));
        
        // Check column types
        expect(sqlite.sqlite3_column_type(selectStmt, 0), equals(SQLITE_INTEGER));
        expect(sqlite.sqlite3_column_type(selectStmt, 1), equals(SQLITE_TEXT));
        
        // Check column names
        final col0NamePtr = sqlite.sqlite3_column_name(selectStmt, 0);
        final col0Name = col0NamePtr.cast<Utf8>().toDartString();
        expect(col0Name, equals('id'));
        
        final col1NamePtr = sqlite.sqlite3_column_name(selectStmt, 1);
        final col1Name = col1NamePtr.cast<Utf8>().toDartString();
        expect(col1Name, equals('name'));
        
        expect(sqlite.sqlite3_finalize(selectStmt), equals(SQLITE_OK));
        expect(sqlite.sqlite3_close(db), equals(SQLITE_OK));
        
        print('✅ Complete CRUD cycle successful: CREATE TABLE → INSERT → SELECT with parameter binding');
        
      } finally {
        calloc.free(dbPtr);
        calloc.free(stmtPtr);
      }
    });
    
    test('handles NULL values correctly', () {
      final dbPtr = calloc<Pointer<sqlite3>>();
      final stmtPtr = calloc<Pointer<sqlite3_stmt>>();
      
      try {
        // Setup database and table
        final filename = ':memory:'.toNativeUtf8();
        expect(sqlite.sqlite3_open(filename, dbPtr), equals(SQLITE_OK));
        final db = dbPtr.value;
        
        final createSql = 'CREATE TABLE nulltest (id INTEGER, value TEXT)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, createSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(stmtPtr.value), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(stmtPtr.value), equals(SQLITE_OK));
        
        // Insert NULL value
        final insertSql = 'INSERT INTO nulltest (id, value) VALUES (?, ?)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, insertSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final insertStmt = stmtPtr.value;
        
        expect(sqlite.sqlite3_bind_int(insertStmt, 1, 1), equals(SQLITE_OK));
        expect(sqlite.sqlite3_bind_null(insertStmt, 2), equals(SQLITE_OK));
        
        expect(sqlite.sqlite3_step(insertStmt), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(insertStmt), equals(SQLITE_OK));
        
        // Select and verify NULL
        final selectSql = 'SELECT value FROM nulltest WHERE id = 1'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, selectSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final selectStmt = stmtPtr.value;
        
        expect(sqlite.sqlite3_step(selectStmt), equals(SQLITE_ROW));
        expect(sqlite.sqlite3_column_type(selectStmt, 0), equals(SQLITE_NULL));
        
        expect(sqlite.sqlite3_finalize(selectStmt), equals(SQLITE_OK));
        expect(sqlite.sqlite3_close(db), equals(SQLITE_OK));
        
        print('✅ NULL value handling verified');
        
      } finally {
        calloc.free(dbPtr);
        calloc.free(stmtPtr);
      }
    });
    
    test('error handling works correctly', () {
      final dbPtr = calloc<Pointer<sqlite3>>();
      final stmtPtr = calloc<Pointer<sqlite3_stmt>>();
      
      try {
        // Open database
        final filename = ':memory:'.toNativeUtf8();
        expect(sqlite.sqlite3_open(filename, dbPtr), equals(SQLITE_OK));
        final db = dbPtr.value;
        
        // Try to prepare invalid SQL
        final invalidSql = 'INVALID SQL STATEMENT'.toNativeUtf8();
        final result = sqlite.sqlite3_prepare_v2(db, invalidSql, -1, stmtPtr, nullptr);
        
        expect(result, isNot(SQLITE_OK));  // Should return an error
        
        // Check error code and message
        final errorCode = sqlite.sqlite3_errcode(db);
        expect(errorCode, isNot(SQLITE_OK));
        
        final errorMsgPtr = sqlite.sqlite3_errmsg(db);
        final errorMsg = errorMsgPtr.cast<Utf8>().toDartString();
        expect(errorMsg, isNotEmpty);
        
        print('✅ Error handling verified - Error: $errorMsg');
        
        expect(sqlite.sqlite3_close(db), equals(SQLITE_OK));
        
      } finally {
        calloc.free(dbPtr);
        calloc.free(stmtPtr);
      }
    });
  });
}