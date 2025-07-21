import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

void main() {
  group('File Operations on Native SQLite', () {
    late MinimalSqliteApi sqlite;
    final testDbPath = 'test_database.db';
    
    setUp(() async {
      sqlite = createMinimalSqlite();
      await sqlite.initialize();
      
      // Clean up any existing test database
      final file = File(testDbPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
    
    tearDown(() {
      sqlite.shutdown();
      
      // Clean up test database
      final file = File(testDbPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
    
    test('can create and use file-based database', () {
      final dbPtr = calloc<Pointer<sqlite3>>();
      final stmtPtr = calloc<Pointer<sqlite3_stmt>>();
      
      try {
        // Open file-based database (should create the file)
        final filename = testDbPath.toNativeUtf8();
        final openResult = sqlite.sqlite3_open(filename, dbPtr);
        
        print('📁 Opening database file: $testDbPath');
        print('🔍 Open result: $openResult (SQLITE_OK = $SQLITE_OK)');
        
        expect(openResult, equals(SQLITE_OK));
        expect(dbPtr.value, isNot(nullptr));
        
        final db = dbPtr.value;
        
        // Check if file was created
        final file = File(testDbPath);
        expect(file.existsSync(), isTrue);
        print('✅ Database file created successfully');
        
        // Create a table
        final createSql = 'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, createSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(stmtPtr.value), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(stmtPtr.value), equals(SQLITE_OK));
        
        // Insert data
        final insertSql = 'INSERT INTO users (name) VALUES (?)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db, insertSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final insertStmt = stmtPtr.value;
        
        final nameValue = 'Alice'.toNativeUtf8();
        expect(sqlite.sqlite3_bind_text(insertStmt, 1, nameValue, -1, SQLITE_TRANSIENT), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(insertStmt), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(insertStmt), equals(SQLITE_OK));
        
        print('✅ Data inserted successfully');
        
        // Close database
        expect(sqlite.sqlite3_close(db), equals(SQLITE_OK));
        
        print('✅ Database closed, file should contain persisted data');
        
      } finally {
        calloc.free(dbPtr);
        calloc.free(stmtPtr);
      }
    });
    
    test('can reopen database file and read persisted data', () {
      // First, create a database with data
      final dbPtr = calloc<Pointer<sqlite3>>();
      final stmtPtr = calloc<Pointer<sqlite3_stmt>>();
      
      try {
        // Create and populate database
        final filename = testDbPath.toNativeUtf8();
        expect(sqlite.sqlite3_open(filename, dbPtr), equals(SQLITE_OK));
        final db1 = dbPtr.value;
        
        // Create table and insert data
        final createSql = 'CREATE TABLE test_persistence (id INTEGER, message TEXT)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db1, createSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(stmtPtr.value), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(stmtPtr.value), equals(SQLITE_OK));
        
        final insertSql = 'INSERT INTO test_persistence (id, message) VALUES (?, ?)'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db1, insertSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final insertStmt = stmtPtr.value;
        
        expect(sqlite.sqlite3_bind_int(insertStmt, 1, 123), equals(SQLITE_OK));
        final messageValue = 'Hello, persistent world!'.toNativeUtf8();
        expect(sqlite.sqlite3_bind_text(insertStmt, 2, messageValue, -1, SQLITE_TRANSIENT), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(insertStmt), equals(SQLITE_DONE));
        expect(sqlite.sqlite3_finalize(insertStmt), equals(SQLITE_OK));
        
        // Close first connection
        expect(sqlite.sqlite3_close(db1), equals(SQLITE_OK));
        
        print('✅ Database created and closed with persistent data');
        
        // Reopen database and read data
        expect(sqlite.sqlite3_open(filename, dbPtr), equals(SQLITE_OK));
        final db2 = dbPtr.value;
        
        final selectSql = 'SELECT id, message FROM test_persistence WHERE id = ?'.toNativeUtf8();
        expect(sqlite.sqlite3_prepare_v2(db2, selectSql, -1, stmtPtr, nullptr), equals(SQLITE_OK));
        final selectStmt = stmtPtr.value;
        
        expect(sqlite.sqlite3_bind_int(selectStmt, 1, 123), equals(SQLITE_OK));
        expect(sqlite.sqlite3_step(selectStmt), equals(SQLITE_ROW));
        
        // Verify data
        final retrievedId = sqlite.sqlite3_column_int(selectStmt, 0);
        final retrievedMessagePtr = sqlite.sqlite3_column_text(selectStmt, 1);
        final retrievedMessage = retrievedMessagePtr.cast<Utf8>().toDartString();
        
        expect(retrievedId, equals(123));
        expect(retrievedMessage, equals('Hello, persistent world!'));
        
        print('✅ Successfully read persisted data from reopened database');
        print('📄 Retrieved: ID=$retrievedId, Message="$retrievedMessage"');
        
        expect(sqlite.sqlite3_finalize(selectStmt), equals(SQLITE_OK));
        expect(sqlite.sqlite3_close(db2), equals(SQLITE_OK));
        
      } finally {
        calloc.free(dbPtr);
        calloc.free(stmtPtr);
      }
    });
    
    test('file operations work with relative and absolute paths', () {
      final dbPtr = calloc<Pointer<sqlite3>>();
      
      try {
        // Test relative path
        final relativeDb = 'relative_test.db';
        final relativeFilename = relativeDb.toNativeUtf8();
        expect(sqlite.sqlite3_open(relativeFilename, dbPtr), equals(SQLITE_OK));
        expect(sqlite.sqlite3_close(dbPtr.value), equals(SQLITE_OK));
        
        expect(File(relativeDb).existsSync(), isTrue);
        File(relativeDb).deleteSync(); // Cleanup
        
        // Test absolute path  
        final absoluteDb = '${Directory.current.path}/absolute_test.db';
        final absoluteFilename = absoluteDb.toNativeUtf8();
        expect(sqlite.sqlite3_open(absoluteFilename, dbPtr), equals(SQLITE_OK));
        expect(sqlite.sqlite3_close(dbPtr.value), equals(SQLITE_OK));
        
        expect(File(absoluteDb).existsSync(), isTrue);
        File(absoluteDb).deleteSync(); // Cleanup
        
        print('✅ Both relative and absolute paths work correctly');
        
      } finally {
        calloc.free(dbPtr);
      }
    });
  });
}