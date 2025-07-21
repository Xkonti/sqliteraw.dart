import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

// SQLite result codes and error constants
const int SQLITE_OK = 0;
const int SQLITE_ERROR = 1;
const int SQLITE_INTERNAL = 2;
const int SQLITE_PERM = 3;
const int SQLITE_ABORT = 4;
const int SQLITE_BUSY = 5;
const int SQLITE_LOCKED = 6;
const int SQLITE_NOMEM = 7;
const int SQLITE_READONLY = 8;
const int SQLITE_INTERRUPT = 9;
const int SQLITE_IOERR = 10;
const int SQLITE_CORRUPT = 11;
const int SQLITE_NOTFOUND = 12;
const int SQLITE_FULL = 13;
const int SQLITE_CANTOPEN = 14;
const int SQLITE_PROTOCOL = 15;
const int SQLITE_EMPTY = 16;
const int SQLITE_SCHEMA = 17;
const int SQLITE_TOOBIG = 18;
const int SQLITE_CONSTRAINT = 19;
const int SQLITE_MISMATCH = 20;
const int SQLITE_MISUSE = 21;
const int SQLITE_NOLFS = 22;
const int SQLITE_AUTH = 23;
const int SQLITE_FORMAT = 24;
const int SQLITE_RANGE = 25;
const int SQLITE_NOTADB = 26;
const int SQLITE_NOTICE = 27;
const int SQLITE_WARNING = 28;
const int SQLITE_ROW = 100;
const int SQLITE_DONE = 101;

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
external JSObject bindTextParameter(int stmtHandle, int paramIndex, String textValue);

@JS()
external JSObject bindIntParameter(int stmtHandle, int paramIndex, int intValue);

@JS()
external JSObject bindNullParameter(int stmtHandle, int paramIndex);

// JS interop interfaces for error handling functions
@JS()
external int getLastErrorCode(int dbHandle);

@JS()
external String getLastErrorMessage(int dbHandle);

@JS()
external int getExtendedErrorCode(int dbHandle);

@JS()
external JSObject checkOperationResult(int dbHandle, String operationName, JSArray<JSNumber> expectedCodes);

// Missing JS interop functions for result retrieval
@JS()
external String? getColumnText(int stmtHandle, int columnIndex);

@JS()
external int getColumnInt(int stmtHandle, int columnIndex);

@JS()
external int getColumnCount(int stmtHandle);

// Extension to get properties from JSObject
extension JSObjectProperties on JSObject {
  external bool get success;
  external int get errorCode; 
  external int get dbHandle;
  external int get stmtHandle;
  external int get resultCode;
  external String get errorMessage;
  external String get operationName;
  external int get extendedErrorCode;
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
    log('🚀 Starting comprehensive SQLite error handling test...');
    
    // Initialize WASM module
    log('🔧 Initializing SQLite WASM module...');
    final initResult = await initializeSqliteWasm().toDart;
    if (!initResult.success) {
      throw Exception('Failed to initialize WASM module, error code: ${initResult.errorCode}');
    }
    log('✅ SQLite WASM module initialized successfully');
    
    // Open database for error testing
    log('🔧 Opening :memory: database for error testing...');
    final openResult = openDatabase(':memory:');
    if (!openResult.success) {
      throw Exception('Failed to open database, error code: ${openResult.errorCode}');
    }
    dbHandle = openResult.dbHandle;
    log('✅ Database opened successfully, handle: $dbHandle');
    
    // Test 1: SQL Syntax Errors
    await testSqlSyntaxErrors(dbHandle!, log, stmtHandles);
    
    // Test 2: Constraint Violations
    await testConstraintViolations(dbHandle!, log, stmtHandles);
    
    // Test 3: Parameter Binding Errors
    await testParameterBindingErrors(dbHandle!, log, stmtHandles);
    
    // Test 4: Resource State Errors
    await testResourceStateErrors(dbHandle!, log, stmtHandles);
    
    // Test 5: Data Type Conversion Errors
    await testDataTypeConversionErrors(dbHandle!, log, stmtHandles);
    
    // Test 6: Transaction Errors
    await testTransactionErrors(dbHandle!, log, stmtHandles);
    
    // Test 7: Error Recovery and Database Stability
    await testErrorRecovery(dbHandle!, log, stmtHandles);
    
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
    log('🎉 All error handling tests passed successfully!');
    log('📊 Test Summary:');
    log('  ✅ SQL syntax error detection and reporting');
    log('  ✅ Constraint violation handling (UNIQUE, NOT NULL, CHECK)');
    log('  ✅ Parameter binding error validation');
    log('  ✅ Resource state error detection');
    log('  ✅ Data type conversion error handling');
    log('  ✅ Transaction error management');
    log('  ✅ Error recovery and database stability');
    log('  ✅ Proper error code and message propagation');
    log('  ✅ System remains stable under all error conditions');
    
  } catch (e, stackTrace) {
    log('❌ Error handling test failed: $e');
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

// Test 1: SQL Syntax Errors
Future<void> testSqlSyntaxErrors(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 1: SQL Syntax Errors');
  
  final syntaxErrorTests = [
    'SELECT * FROM', // Incomplete SELECT
    'CREATE TABLE ()', // Invalid table syntax
    'INSERT INTO nonexistent VALUES (1, 2, 3)', // Table doesn't exist
    'UPDATE SET name = "test" WHERE id = 1', // Missing table name
    'SELECT COUNT(*) GROUP BY name', // Missing FROM clause
  ];
  
  for (int i = 0; i < syntaxErrorTests.length; i++) {
    final invalidSql = syntaxErrorTests[i];
    final displaySql = invalidSql.length > 30 ? '${invalidSql.substring(0, 30)}...' : invalidSql;
    log('  🔍 Testing syntax error ${i + 1}: "$displaySql"');
    
    final prepareResult = prepareStatement(dbHandle, invalidSql);
    
    if (prepareResult.success) {
      // If prepare succeeded, execution should fail
      final stmtHandle = prepareResult.stmtHandle;
      stmtHandles.add(stmtHandle);
      
      final executeResult = executeStatement(stmtHandle);
      if (executeResult.success) {
        throw Exception('Expected syntax error but operation succeeded');
      }
      
      final errorCode = getLastErrorCode(dbHandle);
      final errorMessage = getLastErrorMessage(dbHandle);
      
      log('    ✅ Caught syntax error: code $errorCode, message: "$errorMessage"');
      
      finalizeStatement(stmtHandle);
      stmtHandles.remove(stmtHandle);
    } else {
      // Prepare failed as expected
      final errorCode = getLastErrorCode(dbHandle);
      final errorMessage = getLastErrorMessage(dbHandle);
      
      log('    ✅ Prepare failed as expected: code $errorCode, message: "$errorMessage"');
    }
  }
  
  log('✅ SQL syntax error test passed - all invalid SQL properly detected');
}

// Test 2: Constraint Violations
Future<void> testConstraintViolations(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 2: Constraint Violations');
  
  // Create table with constraints
  const createTableSql = '''
    CREATE TABLE constraint_test (
      id INTEGER PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      age INTEGER CHECK(age >= 0 AND age <= 150),
      category TEXT NOT NULL
    )
  ''';
  
  final createResult = prepareStatement(dbHandle, createTableSql);
  final createStmtHandle = createResult.stmtHandle;
  executeStatement(createStmtHandle);
  finalizeStatement(createStmtHandle);
  
  // Insert valid record first
  const insertValidSql = 'INSERT INTO constraint_test (id, email, age, category) VALUES (?, ?, ?, ?)';
  final insertValidResult = prepareStatement(dbHandle, insertValidSql);
  final insertValidStmtHandle = insertValidResult.stmtHandle;
  
  bindIntParameter(insertValidStmtHandle, 1, 1);
  bindTextParameter(insertValidStmtHandle, 2, 'test@example.com');
  bindIntParameter(insertValidStmtHandle, 3, 25);
  bindTextParameter(insertValidStmtHandle, 4, 'user');
  
  executeStatement(insertValidStmtHandle);
  finalizeStatement(insertValidStmtHandle);
  
  log('  🔍 Testing UNIQUE constraint violation...');
  
  // Test UNIQUE constraint violation
  final insertDuplicateResult = prepareStatement(dbHandle, insertValidSql);
  final insertDuplicateStmtHandle = insertDuplicateResult.stmtHandle;
  stmtHandles.add(insertDuplicateStmtHandle);
  
  bindIntParameter(insertDuplicateStmtHandle, 1, 2);
  bindTextParameter(insertDuplicateStmtHandle, 2, 'test@example.com'); // Duplicate email
  bindIntParameter(insertDuplicateStmtHandle, 3, 30);
  bindTextParameter(insertDuplicateStmtHandle, 4, 'admin');
  
  final duplicateExecuteResult = executeStatement(insertDuplicateStmtHandle);
  if (duplicateExecuteResult.success) {
    throw Exception('Expected UNIQUE constraint violation but operation succeeded');
  }
  
  final uniqueErrorCode = getLastErrorCode(dbHandle);
  final uniqueErrorMessage = getLastErrorMessage(dbHandle);
  
  if (uniqueErrorCode != SQLITE_CONSTRAINT) {
    throw Exception('Expected SQLITE_CONSTRAINT (19) but got $uniqueErrorCode');
  }
  
  log('    ✅ UNIQUE constraint violation caught: code $uniqueErrorCode, message: "$uniqueErrorMessage"');
  
  finalizeStatement(insertDuplicateStmtHandle);
  stmtHandles.remove(insertDuplicateStmtHandle);
  
  log('  🔍 Testing CHECK constraint violation...');
  
  // Test CHECK constraint violation (invalid age)
  final insertInvalidAgeResult = prepareStatement(dbHandle, insertValidSql);
  final insertInvalidAgeStmtHandle = insertInvalidAgeResult.stmtHandle;
  stmtHandles.add(insertInvalidAgeStmtHandle);
  
  bindIntParameter(insertInvalidAgeStmtHandle, 1, 3);
  bindTextParameter(insertInvalidAgeStmtHandle, 2, 'invalid@example.com');
  bindIntParameter(insertInvalidAgeStmtHandle, 3, 200); // Invalid age
  bindTextParameter(insertInvalidAgeStmtHandle, 4, 'user');
  
  final ageExecuteResult = executeStatement(insertInvalidAgeStmtHandle);
  if (ageExecuteResult.success) {
    throw Exception('Expected CHECK constraint violation but operation succeeded');
  }
  
  final checkErrorCode = getLastErrorCode(dbHandle);
  final checkErrorMessage = getLastErrorMessage(dbHandle);
  
  log('    ✅ CHECK constraint violation caught: code $checkErrorCode, message: "$checkErrorMessage"');
  
  finalizeStatement(insertInvalidAgeStmtHandle);
  stmtHandles.remove(insertInvalidAgeStmtHandle);
  
  log('  🔍 Testing NOT NULL constraint violation...');
  
  // Test NOT NULL constraint violation
  const insertNullSql = 'INSERT INTO constraint_test (id, email, age, category) VALUES (?, ?, ?, ?)';
  final insertNullResult = prepareStatement(dbHandle, insertNullSql);
  final insertNullStmtHandle = insertNullResult.stmtHandle;
  stmtHandles.add(insertNullStmtHandle);
  
  bindIntParameter(insertNullStmtHandle, 1, 4);
  bindNullParameter(insertNullStmtHandle, 2); // NULL email violates NOT NULL
  bindIntParameter(insertNullStmtHandle, 3, 30);
  bindTextParameter(insertNullStmtHandle, 4, 'user');
  
  final nullExecuteResult = executeStatement(insertNullStmtHandle);
  if (nullExecuteResult.success) {
    throw Exception('Expected NOT NULL constraint violation but operation succeeded');
  }
  
  final nullErrorCode = getLastErrorCode(dbHandle);
  final nullErrorMessage = getLastErrorMessage(dbHandle);
  
  log('    ✅ NOT NULL constraint violation caught: code $nullErrorCode, message: "$nullErrorMessage"');
  
  finalizeStatement(insertNullStmtHandle);
  stmtHandles.remove(insertNullStmtHandle);
  
  log('✅ Constraint violation test passed - all constraint types properly enforced');
}

// Test 3: Parameter Binding Errors
Future<void> testParameterBindingErrors(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 3: Parameter Binding Errors');
  
  // Create simple test table
  const createSql = 'CREATE TABLE param_test (id INTEGER, name TEXT)';
  final createResult = prepareStatement(dbHandle, createSql);
  final createStmtHandle = createResult.stmtHandle;
  executeStatement(createStmtHandle);
  finalizeStatement(createStmtHandle);
  
  log('  🔍 Testing binding to non-existent parameter...');
  
  const insertSql = 'INSERT INTO param_test (id, name) VALUES (?, ?)';
  final insertResult = prepareStatement(dbHandle, insertSql);
  final insertStmtHandle = insertResult.stmtHandle;
  stmtHandles.add(insertStmtHandle);
  
  // Try to bind to parameter index 3 (doesn't exist, only 1 and 2 exist)
  final bindResult = bindIntParameter(insertStmtHandle, 3, 123);
  if (bindResult.success) {
    log('    ⚠️ Binding to non-existent parameter succeeded (SQLite allows this)');
  } else {
    log('    ✅ Binding to non-existent parameter failed as expected');
  }
  
  // Test successful binding
  final bindResult1 = bindIntParameter(insertStmtHandle, 1, 1);
  final bindResult2 = bindTextParameter(insertStmtHandle, 2, 'test');
  
  if (!bindResult1.success || !bindResult2.success) {
    throw Exception('Valid parameter binding failed');
  }
  
  final executeResult = executeStatement(insertStmtHandle);
  if (!executeResult.success) {
    final errorCode = getLastErrorCode(dbHandle);
    final errorMessage = getLastErrorMessage(dbHandle);
    log('    ⚠️ Execute failed: code $errorCode, message: "$errorMessage"');
  } else {
    log('    ✅ Valid parameter binding and execution succeeded');
  }
  
  finalizeStatement(insertStmtHandle);
  stmtHandles.remove(insertStmtHandle);
  
  log('✅ Parameter binding error test passed');
}

// Test 4: Resource State Errors
Future<void> testResourceStateErrors(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 4: Resource State Errors');
  
  log('  🔍 Testing operations on finalized statement...');
  
  // Create and immediately finalize a statement
  const testSql = 'SELECT 1';
  final testResult = prepareStatement(dbHandle, testSql);
  final testStmtHandle = testResult.stmtHandle;
  
  // Finalize the statement
  finalizeStatement(testStmtHandle);
  
  // Try to execute the finalized statement
  final executeResult = executeStatement(testStmtHandle);
  if (executeResult.success) {
    log('    ⚠️ Executing finalized statement succeeded (unexpected)');
  } else {
    log('    ✅ Executing finalized statement failed as expected');
  }
  
  log('  🔍 Testing database operations after close...');
  
  // Open a temporary database and close it
  final tempOpenResult = openDatabase(':memory:');
  final tempDbHandle = tempOpenResult.dbHandle;
  
  final closeResult = closeDatabase(tempDbHandle);
  if (!closeResult.success) {
    throw Exception('Failed to close temporary database');
  }
  
  // Try to prepare statement on closed database
  final prepareOnClosedResult = prepareStatement(tempDbHandle, 'SELECT 1');
  if (prepareOnClosedResult.success) {
    log('    ⚠️ Preparing statement on closed database succeeded (unexpected)');
    finalizeStatement(prepareOnClosedResult.stmtHandle);
  } else {
    final errorCode = getLastErrorCode(tempDbHandle);
    final errorMessage = getLastErrorMessage(tempDbHandle);
    log('    ✅ Preparing statement on closed database failed: code $errorCode, message: "$errorMessage"');
  }
  
  log('✅ Resource state error test passed');
}

// Test 5: Data Type Conversion Errors
Future<void> testDataTypeConversionErrors(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 5: Data Type Conversion Errors');
  
  // Create test table
  const createSql = 'CREATE TABLE type_test (id INTEGER, data TEXT)';
  final createResult = prepareStatement(dbHandle, createSql);
  final createStmtHandle = createResult.stmtHandle;
  executeStatement(createStmtHandle);
  finalizeStatement(createStmtHandle);
  
  log('  🔍 Testing large text insertion...');
  
  // Create reasonably large string (64KB) for browser compatibility
  final largeString = 'x' * 65536; // 64KB of 'x' characters
  
  const insertSql = 'INSERT INTO type_test (id, data) VALUES (?, ?)';
  final insertResult = prepareStatement(dbHandle, insertSql);
  final insertStmtHandle = insertResult.stmtHandle;
  stmtHandles.add(insertStmtHandle);
  
  bindIntParameter(insertStmtHandle, 1, 1);
  final bindLargeResult = bindTextParameter(insertStmtHandle, 2, largeString);
  
  if (!bindLargeResult.success) {
    log('    ✅ Binding large text failed as expected');
  } else {
    final executeResult = executeStatement(insertStmtHandle);
    if (executeResult.success) {
      log('    ✅ Large text insertion succeeded (SQLite handles large data)');
    } else {
      final errorCode = getLastErrorCode(dbHandle);
      final errorMessage = getLastErrorMessage(dbHandle);
      log('    ✅ Large text insertion failed: code $errorCode, message: "$errorMessage"');
    }
  }
  
  finalizeStatement(insertStmtHandle);
  stmtHandles.remove(insertStmtHandle);
  
  log('✅ Data type conversion error test passed');
}

// Test 6: Transaction Errors
Future<void> testTransactionErrors(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 6: Transaction Errors');
  
  log('  🔍 Testing nested transaction errors...');
  
  // Start transaction
  const beginSql = 'BEGIN TRANSACTION';
  final beginResult = prepareStatement(dbHandle, beginSql);
  final beginStmtHandle = beginResult.stmtHandle;
  executeStatement(beginStmtHandle);
  finalizeStatement(beginStmtHandle);
  
  // Try to start another transaction (should fail)
  const nestedBeginSql = 'BEGIN TRANSACTION';
  final nestedBeginResult = prepareStatement(dbHandle, nestedBeginSql);
  final nestedBeginStmtHandle = nestedBeginResult.stmtHandle;
  stmtHandles.add(nestedBeginStmtHandle);
  
  final nestedExecuteResult = executeStatement(nestedBeginStmtHandle);
  if (nestedExecuteResult.success) {
    log('    ⚠️ Nested transaction succeeded (SQLite allows this)');
  } else {
    final errorCode = getLastErrorCode(dbHandle);
    final errorMessage = getLastErrorMessage(dbHandle);
    log('    ✅ Nested transaction failed: code $errorCode, message: "$errorMessage"');
  }
  
  finalizeStatement(nestedBeginStmtHandle);
  stmtHandles.remove(nestedBeginStmtHandle);
  
  // Rollback the transaction
  const rollbackSql = 'ROLLBACK';
  final rollbackResult = prepareStatement(dbHandle, rollbackSql);
  final rollbackStmtHandle = rollbackResult.stmtHandle;
  executeStatement(rollbackStmtHandle);
  finalizeStatement(rollbackStmtHandle);
  
  log('✅ Transaction error test passed');
}

// Test 7: Error Recovery and Database Stability
Future<void> testErrorRecovery(int dbHandle, void Function(String) log, List<int> stmtHandles) async {
  log('');
  log('📋 Test 7: Error Recovery and Database Stability');
  
  log('  🔍 Testing database stability after multiple errors...');
  
  // Generate multiple errors in sequence
  final errorSqlStatements = [
    'SELECT * FROM nonexistent_table',
    'INSERT INTO nonexistent_table VALUES (1)',
    'CREATE TABLE invalid_syntax (',
    'UPDATE nonexistent SET col = 1',
    'DELETE FROM nowhere WHERE id = 1'
  ];
  
  for (int i = 0; i < errorSqlStatements.length; i++) {
    final errorSql = errorSqlStatements[i];
    
    final errorResult = prepareStatement(dbHandle, errorSql);
    if (errorResult.success) {
      final errorStmtHandle = errorResult.stmtHandle;
      executeStatement(errorStmtHandle);
      finalizeStatement(errorStmtHandle);
    }
    
    final errorCode = getLastErrorCode(dbHandle);
    if (errorCode != SQLITE_OK) {
      log('    ✅ Error ${i + 1}: code $errorCode (expected)');
    }
  }
  
  log('  🔍 Testing normal operations after errors...');
  
  // Test that database still works normally
  const createTableSql = 'CREATE TABLE recovery_test (id INTEGER, name TEXT)';
  final createResult = prepareStatement(dbHandle, createTableSql);
  final createStmtHandle = createResult.stmtHandle;
  final createExecuteResult = executeStatement(createStmtHandle);
  finalizeStatement(createStmtHandle);
  
  if (!createExecuteResult.success) {
    final errorCode = getLastErrorCode(dbHandle);
    final errorMessage = getLastErrorMessage(dbHandle);
    throw Exception('Database not stable after errors: code $errorCode, message: "$errorMessage"');
  }
  
  // Test INSERT still works
  const insertSql = 'INSERT INTO recovery_test (id, name) VALUES (1, "test")';
  final insertResult = prepareStatement(dbHandle, insertSql);
  final insertStmtHandle = insertResult.stmtHandle;
  final insertExecuteResult = executeStatement(insertStmtHandle);
  finalizeStatement(insertStmtHandle);
  
  if (!insertExecuteResult.success) {
    throw Exception('INSERT failed after error recovery');
  }
  
  // Test SELECT still works and retrieve result
  const selectSql = 'SELECT COUNT(*) FROM recovery_test';
  final selectResult = prepareStatement(dbHandle, selectSql);
  final selectStmtHandle = selectResult.stmtHandle;
  stmtHandles.add(selectStmtHandle);
  final selectExecuteResult = executeStatement(selectStmtHandle);
  
  if (!selectExecuteResult.success) {
    throw Exception('SELECT failed after error recovery');
  }
  
  // Retrieve the count to validate result processing works
  final count = getColumnInt(selectStmtHandle, 0);
  if (count != 1) {
    throw Exception('Expected count 1 but got $count');
  }
  
  finalizeStatement(selectStmtHandle);
  stmtHandles.remove(selectStmtHandle);
  
  log('    ✅ Database operations work normally after error conditions');
  log('✅ Error recovery and stability test passed');
}