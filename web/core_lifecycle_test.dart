import 'dart:html' as html;
import 'dart:js_interop';

// SQLite result codes
const int SQLITE_OK = 0;
const int SQLITE_ROW = 100;
const int SQLITE_DONE = 101;

// JS interop interfaces for sqlite_wasm_core.js functions
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

// Helper function to get property from JSObject
@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getPropertyDescriptor(JSObject obj, String property);

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
  int? createStmtHandle;
  int? insertStmtHandle;
  
  try {
    log('🚀 Starting core SQLite lifecycle test...');
    
    // Initialize WASM module first
    log('🔧 Initializing SQLite WASM module...');
    final initResult = await initializeSqliteWasm().toDart;
    final initSuccess = initResult.success;
    
    if (!initSuccess) {
      final initErrorCode = initResult.errorCode;
      throw Exception('Failed to initialize WASM module, error code: $initErrorCode');
    }
    
    log('✅ SQLite WASM module initialized successfully');
    
    // Test 1: Open :memory: database
    log('🔧 Test 1: Opening :memory: database...');
    final openResult = openDatabase(':memory:');
    final openSuccess = openResult.success;
    final openErrorCode = openResult.errorCode;
    
    if (!openSuccess) {
      throw Exception('Failed to open database, error code: $openErrorCode');
    }
    
    dbHandle = openResult.dbHandle;
    log('✅ Database opened successfully, handle: $dbHandle');
    
    // Test 2: Prepare CREATE TABLE statement
    log('🔧 Test 2: Preparing CREATE TABLE statement...');
    final createSql = 'CREATE TABLE test (id INTEGER, name TEXT)';
    final prepareCreateResult = prepareStatement(dbHandle!, createSql);
    final prepareCreateSuccess = prepareCreateResult.success;
    final prepareCreateErrorCode = prepareCreateResult.errorCode;
    
    if (!prepareCreateSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to prepare CREATE TABLE statement, error code: $prepareCreateErrorCode, message: $errorMsg');
    }
    
    createStmtHandle = prepareCreateResult.stmtHandle;
    log('✅ CREATE TABLE prepared successfully, handle: $createStmtHandle');
    
    // Test 3: Execute CREATE TABLE
    log('🔧 Test 3: Executing CREATE TABLE...');
    final executeCreateResult = executeStatement(createStmtHandle!);
    final executeCreateSuccess = executeCreateResult.success;
    final executeCreateResultCode = executeCreateResult.resultCode;
    
    if (!executeCreateSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to execute CREATE TABLE, result code: $executeCreateResultCode, message: $errorMsg');
    }
    
    if (executeCreateResultCode != SQLITE_DONE) {
      throw Exception('CREATE TABLE returned unexpected result code: $executeCreateResultCode (expected $SQLITE_DONE)');
    }
    
    log('✅ CREATE TABLE executed successfully (SQLITE_DONE: $executeCreateResultCode)');
    
    // Test 4: Finalize CREATE TABLE statement
    log('🔧 Test 4: Finalizing CREATE TABLE statement...');
    final finalizeCreateResult = finalizeStatement(createStmtHandle!);
    final finalizeCreateSuccess = finalizeCreateResult.success;
    final finalizeCreateErrorCode = finalizeCreateResult.errorCode;
    
    if (!finalizeCreateSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to finalize CREATE TABLE statement, error code: $finalizeCreateErrorCode, message: $errorMsg');
    }
    
    createStmtHandle = null; // Mark as cleaned up
    log('✅ CREATE TABLE statement finalized successfully');
    
    // Test 5: Prepare INSERT statement
    log('🔧 Test 5: Preparing INSERT statement...');
    final insertSql = 'INSERT INTO test (id, name) VALUES (1, \'test\')';
    final prepareInsertResult = prepareStatement(dbHandle!, insertSql);
    final prepareInsertSuccess = prepareInsertResult.success;
    final prepareInsertErrorCode = prepareInsertResult.errorCode;
    
    if (!prepareInsertSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to prepare INSERT statement, error code: $prepareInsertErrorCode, message: $errorMsg');
    }
    
    insertStmtHandle = prepareInsertResult.stmtHandle;
    log('✅ INSERT prepared successfully, handle: $insertStmtHandle');
    
    // Test 6: Execute INSERT
    log('🔧 Test 6: Executing INSERT...');
    final executeInsertResult = executeStatement(insertStmtHandle!);
    final executeInsertSuccess = executeInsertResult.success;
    final executeInsertResultCode = executeInsertResult.resultCode;
    
    if (!executeInsertSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to execute INSERT, result code: $executeInsertResultCode, message: $errorMsg');
    }
    
    if (executeInsertResultCode != SQLITE_DONE) {
      throw Exception('INSERT returned unexpected result code: $executeInsertResultCode (expected $SQLITE_DONE)');
    }
    
    log('✅ INSERT executed successfully (SQLITE_DONE: $executeInsertResultCode)');
    
    // Test 7: Finalize INSERT statement
    log('🔧 Test 7: Finalizing INSERT statement...');
    final finalizeInsertResult = finalizeStatement(insertStmtHandle!);
    final finalizeInsertSuccess = finalizeInsertResult.success;
    final finalizeInsertErrorCode = finalizeInsertResult.errorCode;
    
    if (!finalizeInsertSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to finalize INSERT statement, error code: $finalizeInsertErrorCode, message: $errorMsg');
    }
    
    insertStmtHandle = null; // Mark as cleaned up
    log('✅ INSERT statement finalized successfully');
    
    // Test 8: Close database
    log('🔧 Test 8: Closing database...');
    final closeResult = closeDatabase(dbHandle!);
    final closeSuccess = closeResult.success;
    final closeErrorCode = closeResult.errorCode;
    
    if (!closeSuccess) {
      final errorMsg = getErrorMessage(dbHandle!);
      throw Exception('Failed to close database, error code: $closeErrorCode, message: $errorMsg');
    }
    
    dbHandle = null; // Mark as cleaned up
    log('✅ Database closed successfully');
    
    // All tests passed!
    log('🎉 All core SQLite lifecycle tests passed successfully!');
    log('📊 Test Summary:');
    log('  ✅ WASM module initialization');
    log('  ✅ Database open/close lifecycle');
    log('  ✅ CREATE TABLE statement preparation and execution');
    log('  ✅ INSERT statement preparation and execution');
    log('  ✅ Statement finalization and resource cleanup');
    log('  ✅ Proper error handling and validation');
    
  } catch (e, stackTrace) {
    log('❌ Core lifecycle test failed: $e');
    log('📋 Stack trace: $stackTrace');
    
    // Attempt cleanup of any remaining resources
    log('🧹 Attempting cleanup of remaining resources...');
    
    try {
      if (insertStmtHandle != null) {
        finalizeStatement(insertStmtHandle!);
        log('🧹 Cleaned up INSERT statement handle');
      }
    } catch (cleanupError) {
      log('⚠️ Failed to cleanup INSERT statement: $cleanupError');
    }
    
    try {
      if (createStmtHandle != null) {
        finalizeStatement(createStmtHandle!);
        log('🧹 Cleaned up CREATE statement handle');
      }
    } catch (cleanupError) {
      log('⚠️ Failed to cleanup CREATE statement: $cleanupError');
    }
    
    try {
      if (dbHandle != null) {
        closeDatabase(dbHandle!);
        log('🧹 Cleaned up database handle');
      }
    } catch (cleanupError) {
      log('⚠️ Failed to cleanup database: $cleanupError');
    }
    
    log('🧹 Cleanup complete');
  }
}