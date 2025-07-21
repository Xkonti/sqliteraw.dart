import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

// SQLite result codes and data types
const int SQLITE_OK = 0;
const int SQLITE_ROW = 100;
const int SQLITE_DONE = 101;
const int SQLITE_INTEGER = 1;
const int SQLITE_FLOAT = 2;
const int SQLITE_TEXT = 3;
const int SQLITE_BLOB = 4;
const int SQLITE_NULL = 5;

// JS interop interfaces for core functions
@JS()
external JSPromise<JSObject> initializeSqliteWasm();

@JS()
external JSObject openDatabase(String path);

@JS()
external JSObject closeDatabase(int dbHandle);

@JS()
external JSObject prepareStatement(int dbHandle, String sql);

@JS()
external JSObject executeStatement(int stmtHandle);

@JS()
external JSObject finalizeStatement(int stmtHandle);

@JS()
external String getErrorMessage(int dbHandle);

// JS interop interfaces for data binding functions
@JS()
external JSObject bindTextParameter(int stmtHandle, int paramIndex, String textValue);

@JS()
external JSObject bindIntParameter(int stmtHandle, int paramIndex, int intValue);

@JS()
external JSObject bindBlobParameter(int stmtHandle, int paramIndex, JSUint8Array blobData);

@JS()
external JSObject bindNullParameter(int stmtHandle, int paramIndex);

@JS()
external int getParameterCount(int stmtHandle);

// JS interop interfaces for data retrieval functions
@JS()
external int getColumnCount(int stmtHandle);

@JS()
external int getColumnType(int stmtHandle, int columnIndex);

@JS()
external String? getColumnText(int stmtHandle, int columnIndex);

@JS()
external int getColumnInt(int stmtHandle, int columnIndex);

@JS()
external JSUint8Array getColumnBlob(int stmtHandle, int columnIndex);

@JS()
external String? getColumnName(int stmtHandle, int columnIndex);

// Extension to get properties from JSObject
extension JSObjectProperties on JSObject {
  external bool get success;
  external int get errorCode; 
  external int get dbHandle;
  external int get stmtHandle;
  external int get resultCode;
}

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  // Track resources for cleanup
  int? dbHandle;
  List<int> stmtHandles = [];
  
  try {
    log('🚀 Starting comprehensive SQLite data types test...');
    
    // Initialize WASM module
    log('🔧 Initializing SQLite WASM module...');
    final initResult = await initializeSqliteWasm().toDart;
    if (!initResult.success) {
      throw Exception('Failed to initialize WASM module, error code: ${initResult.errorCode}');
    }
    log('✅ SQLite WASM module initialized successfully');
    
    // Open database
    log('🔧 Opening :memory: database...');
    final openResult = openDatabase(':memory:');
    if (!openResult.success) {
      throw Exception('Failed to open database, error code: ${openResult.errorCode}');
    }
    dbHandle = openResult.dbHandle;
    log('✅ Database opened successfully, handle: $dbHandle');
    
    // Create test table
    log('🔧 Creating test table with all data types...');
    const createTableSql = '''
      CREATE TABLE data_test (
        id INTEGER PRIMARY KEY,
        text_col TEXT,
        int_col INTEGER,
        blob_col BLOB,
        null_col TEXT
      )
    ''';
    
    final createResult = prepareStatement(dbHandle!, createTableSql);
    if (!createResult.success) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to prepare CREATE TABLE: ${createResult.errorCode}, $errorMsg');
    }
    
    final createStmtHandle = createResult.stmtHandle;
    stmtHandles.add(createStmtHandle);
    
    final executeCreateResult = executeStatement(createStmtHandle);
    if (!executeCreateResult.success || executeCreateResult.resultCode != SQLITE_DONE) {
      throw Exception('Failed to execute CREATE TABLE: ${executeCreateResult.resultCode}');
    }
    
    finalizeStatement(createStmtHandle);
    stmtHandles.remove(createStmtHandle);
    log('✅ Test table created successfully');
    
    // Test 1: UTF-8 Text Data with International Characters and Emojis
    log('');
    log('📋 Test 1: UTF-8 Text Data with International Characters');
    final testTexts = [
      'Hello World',
      'Café français',
      '日本語テスト',
      'Русский текст',
      '🌟 Unicode emojis 🚀',
      'Mixed: café + 日本語 + 🎯',
      '',  // Empty string
    ];
    
    for (int i = 0; i < testTexts.length; i++) {
      final originalText = testTexts[i];
      
      // Insert data
      const insertSql = 'INSERT INTO data_test (id, text_col) VALUES (?, ?)';
      final insertResult = prepareStatement(dbHandle!, insertSql);
      if (!insertResult.success) {
        throw Exception('Failed to prepare INSERT: ${insertResult.errorCode}');
      }
      
      final insertStmtHandle = insertResult.stmtHandle;
      stmtHandles.add(insertStmtHandle);
      
      // Bind parameters
      final bindIdResult = bindIntParameter(insertStmtHandle, 1, i + 1);
      final bindTextResult = bindTextParameter(insertStmtHandle, 2, originalText);
      
      if (!bindIdResult.success || !bindTextResult.success) {
        throw Exception('Failed to bind parameters');
      }
      
      final executeInsertResult = executeStatement(insertStmtHandle);
      if (!executeInsertResult.success || executeInsertResult.resultCode != SQLITE_DONE) {
        throw Exception('Failed to execute INSERT: ${executeInsertResult.resultCode}');
      }
      
      finalizeStatement(insertStmtHandle);
      stmtHandles.remove(insertStmtHandle);
      
      // Retrieve and verify data
      const selectSql = 'SELECT text_col FROM data_test WHERE id = ?';
      final selectResult = prepareStatement(dbHandle!, selectSql);
      if (!selectResult.success) {
        throw Exception('Failed to prepare SELECT: ${selectResult.errorCode}');
      }
      
      final selectStmtHandle = selectResult.stmtHandle;
      stmtHandles.add(selectStmtHandle);
      
      final bindSelectResult = bindIntParameter(selectStmtHandle, 1, i + 1);
      if (!bindSelectResult.success) {
        throw Exception('Failed to bind SELECT parameter');
      }
      
      final executeSelectResult = executeStatement(selectStmtHandle);
      if (!executeSelectResult.success || executeSelectResult.resultCode != SQLITE_ROW) {
        throw Exception('Failed to execute SELECT: ${executeSelectResult.resultCode}');
      }
      
      final columnType = getColumnType(selectStmtHandle, 0);
      final retrievedText = getColumnText(selectStmtHandle, 0);
      
      finalizeStatement(selectStmtHandle);
      stmtHandles.remove(selectStmtHandle);
      
      // Verify data integrity
      final expectedType = originalText.isEmpty ? SQLITE_TEXT : SQLITE_TEXT;  // SQLite stores empty string as TEXT
      if (columnType != expectedType) {
        throw Exception('Text type mismatch: expected $expectedType, got $columnType');
      }
      
      if (retrievedText != originalText) {
        throw Exception('Text content mismatch: expected "$originalText", got "$retrievedText"');
      }
      
      log('✅ Text ${i + 1}: "${originalText.length > 20 ? originalText.substring(0, 20) + '...' : originalText}" ✓');
    }
    
    // Clear table for next test
    final deleteResult = prepareStatement(dbHandle!, 'DELETE FROM data_test');
    final deleteStmtHandle = deleteResult.stmtHandle;
    executeStatement(deleteStmtHandle);
    finalizeStatement(deleteStmtHandle);
    
    // Test 2: Integer Data with Various Values
    log('');
    log('📋 Test 2: Integer Data with Various Values');
    final testIntegers = [
      0,
      1,
      -1,
      42,
      -42,
      1000000,
      -1000000,
      2147483647,   // Max 32-bit signed int
      -2147483648,  // Min 32-bit signed int
    ];
    
    for (int i = 0; i < testIntegers.length; i++) {
      final originalInt = testIntegers[i];
      
      // Insert data
      const insertSql = 'INSERT INTO data_test (id, int_col) VALUES (?, ?)';
      final insertResult = prepareStatement(dbHandle!, insertSql);
      final insertStmtHandle = insertResult.stmtHandle;
      stmtHandles.add(insertStmtHandle);
      
      bindIntParameter(insertStmtHandle, 1, i + 1);
      bindIntParameter(insertStmtHandle, 2, originalInt);
      executeStatement(insertStmtHandle);
      finalizeStatement(insertStmtHandle);
      stmtHandles.remove(insertStmtHandle);
      
      // Retrieve and verify data
      const selectSql = 'SELECT int_col FROM data_test WHERE id = ?';
      final selectResult = prepareStatement(dbHandle!, selectSql);
      final selectStmtHandle = selectResult.stmtHandle;
      stmtHandles.add(selectStmtHandle);
      
      bindIntParameter(selectStmtHandle, 1, i + 1);
      executeStatement(selectStmtHandle);
      
      final columnType = getColumnType(selectStmtHandle, 0);
      final retrievedInt = getColumnInt(selectStmtHandle, 0);
      
      finalizeStatement(selectStmtHandle);
      stmtHandles.remove(selectStmtHandle);
      
      // Verify data integrity
      if (columnType != SQLITE_INTEGER) {
        throw Exception('Integer type mismatch: expected $SQLITE_INTEGER, got $columnType');
      }
      
      if (retrievedInt != originalInt) {
        throw Exception('Integer content mismatch: expected $originalInt, got $retrievedInt');
      }
      
      log('✅ Integer ${i + 1}: $originalInt ✓');
    }
    
    // Clear table for next test
    final deleteResult2 = prepareStatement(dbHandle!, 'DELETE FROM data_test');
    final deleteStmtHandle2 = deleteResult2.stmtHandle;
    executeStatement(deleteStmtHandle2);
    finalizeStatement(deleteStmtHandle2);
    
    // Test 3: BLOB Data with Binary Content Including Null Bytes
    log('');
    log('📋 Test 3: BLOB Data with Binary Content');
    final testBlobs = [
      Uint8List.fromList([]),  // Empty blob
      Uint8List.fromList([0]),  // Single null byte
      Uint8List.fromList([1, 2, 3, 4, 5]),  // Simple sequence
      Uint8List.fromList([0, 1, 0, 2, 0, 3]),  // With null bytes
      Uint8List.fromList([255, 254, 253, 252]),  // High values
      Uint8List.fromList(List.generate(256, (i) => i)),  // All byte values 0-255
    ];
    
    for (int i = 0; i < testBlobs.length; i++) {
      final originalBlob = testBlobs[i];
      
      // Convert Dart Uint8List to JSUint8Array
      final jsBlob = originalBlob.toJS;
      
      // Insert data
      const insertSql = 'INSERT INTO data_test (id, blob_col) VALUES (?, ?)';
      final insertResult = prepareStatement(dbHandle!, insertSql);
      final insertStmtHandle = insertResult.stmtHandle;
      stmtHandles.add(insertStmtHandle);
      
      bindIntParameter(insertStmtHandle, 1, i + 1);
      bindBlobParameter(insertStmtHandle, 2, jsBlob);
      executeStatement(insertStmtHandle);
      finalizeStatement(insertStmtHandle);
      stmtHandles.remove(insertStmtHandle);
      
      // Retrieve and verify data
      const selectSql = 'SELECT blob_col FROM data_test WHERE id = ?';
      final selectResult = prepareStatement(dbHandle!, selectSql);
      final selectStmtHandle = selectResult.stmtHandle;
      stmtHandles.add(selectStmtHandle);
      
      bindIntParameter(selectStmtHandle, 1, i + 1);
      executeStatement(selectStmtHandle);
      
      final columnType = getColumnType(selectStmtHandle, 0);
      final retrievedJsBlob = getColumnBlob(selectStmtHandle, 0);
      final retrievedBlob = retrievedJsBlob.toDart;
      
      finalizeStatement(selectStmtHandle);
      stmtHandles.remove(selectStmtHandle);
      
      // Verify data integrity
      final expectedType = originalBlob.isEmpty ? SQLITE_BLOB : SQLITE_BLOB;
      if (columnType != expectedType) {
        throw Exception('BLOB type mismatch: expected $expectedType, got $columnType');
      }
      
      if (retrievedBlob.length != originalBlob.length) {
        throw Exception('BLOB length mismatch: expected ${originalBlob.length}, got ${retrievedBlob.length}');
      }
      
      // Byte-level comparison
      for (int j = 0; j < originalBlob.length; j++) {
        if (retrievedBlob[j] != originalBlob[j]) {
          throw Exception('BLOB byte mismatch at index $j: expected ${originalBlob[j]}, got ${retrievedBlob[j]}');
        }
      }
      
      log('✅ BLOB ${i + 1}: ${originalBlob.length} bytes ✓');
    }
    
    // Clear table for next test
    final deleteResult3 = prepareStatement(dbHandle!, 'DELETE FROM data_test');
    final deleteStmtHandle3 = deleteResult3.stmtHandle;
    executeStatement(deleteStmtHandle3);
    finalizeStatement(deleteStmtHandle3);
    
    // Test 4: NULL Values in Different Column Types
    log('');
    log('📋 Test 4: NULL Values in Different Column Types');
    
    // Insert NULL values
    const insertSql = 'INSERT INTO data_test (id, text_col, int_col, blob_col, null_col) VALUES (?, ?, ?, ?, ?)';
    final insertResult = prepareStatement(dbHandle!, insertSql);
    final insertStmtHandle = insertResult.stmtHandle;
    stmtHandles.add(insertStmtHandle);
    
    bindIntParameter(insertStmtHandle, 1, 1);
    bindNullParameter(insertStmtHandle, 2);  // text_col
    bindNullParameter(insertStmtHandle, 3);  // int_col
    bindNullParameter(insertStmtHandle, 4);  // blob_col
    bindNullParameter(insertStmtHandle, 5);  // null_col
    executeStatement(insertStmtHandle);
    finalizeStatement(insertStmtHandle);
    stmtHandles.remove(insertStmtHandle);
    
    // Retrieve and verify NULL values
    const selectSql = 'SELECT text_col, int_col, blob_col, null_col FROM data_test WHERE id = 1';
    final selectResult = prepareStatement(dbHandle!, selectSql);
    final selectStmtHandle = selectResult.stmtHandle;
    stmtHandles.add(selectStmtHandle);
    
    executeStatement(selectStmtHandle);
    
    final columnCount = getColumnCount(selectStmtHandle);
    if (columnCount != 4) {
      throw Exception('Expected 4 columns, got $columnCount');
    }
    
    for (int i = 0; i < 4; i++) {
      final columnType = getColumnType(selectStmtHandle, i);
      final columnName = getColumnName(selectStmtHandle, i);
      
      if (columnType != SQLITE_NULL) {
        throw Exception('Column $i ($columnName) should be NULL, got type $columnType');
      }
      
      final textValue = getColumnText(selectStmtHandle, i);
      if (textValue != null) {
        throw Exception('Column $i ($columnName) should return null, got "$textValue"');
      }
      
      log('✅ NULL column ${i + 1} ($columnName): NULL ✓');
    }
    
    finalizeStatement(selectStmtHandle);
    stmtHandles.remove(selectStmtHandle);
    
    // Test 5: Mixed Data Types in Single Operation
    log('');
    log('📋 Test 5: Mixed Data Types in Single INSERT/SELECT');
    
    final deleteResult4 = prepareStatement(dbHandle!, 'DELETE FROM data_test');
    final deleteStmtHandle4 = deleteResult4.stmtHandle;
    executeStatement(deleteStmtHandle4);
    finalizeStatement(deleteStmtHandle4);
    
    // Insert mixed data
    const mixedInsertSql = 'INSERT INTO data_test (id, text_col, int_col, blob_col, null_col) VALUES (?, ?, ?, ?, ?)';
    final mixedInsertResult = prepareStatement(dbHandle!, mixedInsertSql);
    final mixedInsertStmtHandle = mixedInsertResult.stmtHandle;
    stmtHandles.add(mixedInsertStmtHandle);
    
    final mixedText = 'Mixed test 🎯';
    final mixedInt = 12345;
    final mixedBlob = Uint8List.fromList([1, 2, 3, 0, 4, 5]);
    
    bindIntParameter(mixedInsertStmtHandle, 1, 1);
    bindTextParameter(mixedInsertStmtHandle, 2, mixedText);
    bindIntParameter(mixedInsertStmtHandle, 3, mixedInt);
    bindBlobParameter(mixedInsertStmtHandle, 4, mixedBlob.toJS);
    bindNullParameter(mixedInsertStmtHandle, 5);
    executeStatement(mixedInsertStmtHandle);
    finalizeStatement(mixedInsertStmtHandle);
    stmtHandles.remove(mixedInsertStmtHandle);
    
    // Retrieve and verify mixed data
    const mixedSelectSql = 'SELECT text_col, int_col, blob_col, null_col FROM data_test WHERE id = 1';
    final mixedSelectResult = prepareStatement(dbHandle!, mixedSelectSql);
    final mixedSelectStmtHandle = mixedSelectResult.stmtHandle;
    stmtHandles.add(mixedSelectStmtHandle);
    
    executeStatement(mixedSelectStmtHandle);
    
    // Verify TEXT column
    final retrievedText = getColumnText(mixedSelectStmtHandle, 0);
    if (retrievedText != mixedText) {
      throw Exception('Mixed text mismatch: expected "$mixedText", got "$retrievedText"');
    }
    
    // Verify INTEGER column
    final retrievedInt = getColumnInt(mixedSelectStmtHandle, 1);
    if (retrievedInt != mixedInt) {
      throw Exception('Mixed int mismatch: expected $mixedInt, got $retrievedInt');
    }
    
    // Verify BLOB column
    final retrievedMixedBlob = getColumnBlob(mixedSelectStmtHandle, 2).toDart;
    if (retrievedMixedBlob.length != mixedBlob.length) {
      throw Exception('Mixed blob length mismatch');
    }
    for (int i = 0; i < mixedBlob.length; i++) {
      if (retrievedMixedBlob[i] != mixedBlob[i]) {
        throw Exception('Mixed blob byte mismatch at index $i');
      }
    }
    
    // Verify NULL column
    final retrievedNull = getColumnText(mixedSelectStmtHandle, 3);
    if (retrievedNull != null) {
      throw Exception('Mixed null should be null, got "$retrievedNull"');
    }
    
    finalizeStatement(mixedSelectStmtHandle);
    stmtHandles.remove(mixedSelectStmtHandle);
    
    log('✅ Mixed data types: TEXT, INTEGER, BLOB, NULL ✓');
    
    // Close database
    log('');
    log('🔧 Closing database...');
    final closeResult = closeDatabase(dbHandle!);
    if (!closeResult.success) {
      throw Exception('Failed to close database: ${closeResult.errorCode}');
    }
    dbHandle = null;
    log('✅ Database closed successfully');
    
    // All tests passed!
    log('');
    log('🎉 All SQLite data type tests passed successfully!');
    log('📊 Test Summary:');
    log('  ✅ UTF-8 text with international characters and emojis');
    log('  ✅ Integer values including edge cases');
    log('  ✅ BLOB data with binary content and null bytes');
    log('  ✅ NULL values in all column types');
    log('  ✅ Mixed data types in single operations');
    log('  ✅ Round-trip data integrity validation');
    log('  ✅ SQLite storage class verification');
    
  } catch (e, stackTrace) {
    log('❌ Data types test failed: $e');
    log('📋 Stack trace: $stackTrace');
    
    // Cleanup remaining resources
    log('🧹 Attempting cleanup of remaining resources...');
    
    for (final stmtHandle in stmtHandles) {
      try {
        finalizeStatement(stmtHandle);
        log('🧹 Cleaned up statement handle $stmtHandle');
      } catch (cleanupError) {
        log('⚠️ Failed to cleanup statement $stmtHandle: $cleanupError');
      }
    }
    
    if (dbHandle != null) {
      try {
        closeDatabase(dbHandle!);
        log('🧹 Cleaned up database handle');
      } catch (cleanupError) {
        log('⚠️ Failed to cleanup database: $cleanupError');
      }
    }
    
    log('🧹 Cleanup complete');
  }
}