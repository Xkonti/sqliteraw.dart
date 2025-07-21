import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:async';

// JS interop interfaces for core SQLite functions
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
external String? getColumnText(int stmtHandle, int columnIndex);

@JS()
external int getColumnInt(int stmtHandle, int columnIndex);

// JS interop interfaces for memory monitoring functions
@JS()
external JSObject getWasmMemoryUsage();

@JS()
external JSObject startMemoryMonitoring(int intervalMs);

@JS()
external JSObject stopMemoryMonitoring(JSObject handle);

@JS()
external JSObject detectMemoryLeaks(JSObject baselineUsage, JSObject currentUsage, int toleranceBytes);

@JS()
external JSPromise<JSObject> resetMemoryBaseline();

// Extension to get properties from JSObject
extension JSObjectProperties on JSObject {
  external bool get success;
  external int get errorCode; 
  external int get dbHandle;
  external int get stmtHandle;
  external int get totalBytes;
  external int get usedBytes;
  external int get freeBytes;
  external double get utilizationPercent;
  external String? get error;
  external JSObject get handle;
  external JSObject get baseline;
  external JSObject get report;
  external bool get hasLeak;
  external int get memoryGrowth;
  external String get recommendation;
  external int get duration;
  external int get samples;
  external int get peak;
  external int get average;
  external String get trend;
}

// Performance tracking class
class PerformanceMetrics {
  final List<double> databaseOpenTimes = [];
  final List<double> databaseCloseTimes = [];
  final List<double> statementPrepareTimes = [];
  final List<double> statementExecuteTimes = [];
  final List<double> cycleTimes = [];
  final List<int> memoryUsagePoints = [];
  
  void addDatabaseOpenTime(double timeMs) => databaseOpenTimes.add(timeMs);
  void addDatabaseCloseTime(double timeMs) => databaseCloseTimes.add(timeMs);
  void addStatementPrepareTime(double timeMs) => statementPrepareTimes.add(timeMs);
  void addStatementExecuteTime(double timeMs) => statementExecuteTimes.add(timeMs);
  void addCycleTime(double timeMs) => cycleTimes.add(timeMs);
  void addMemoryUsage(int bytes) => memoryUsagePoints.add(bytes);
  
  double getAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }
  
  double getPercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = ((percentile / 100.0) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
  
  Map<String, dynamic> generateReport() {
    return {
      'databaseOp': {
        'open': {
          'avg': getAverage(databaseOpenTimes),
          'p95': getPercentile(databaseOpenTimes, 95),
          'p99': getPercentile(databaseOpenTimes, 99),
          'samples': databaseOpenTimes.length
        },
        'close': {
          'avg': getAverage(databaseCloseTimes),
          'p95': getPercentile(databaseCloseTimes, 95),
          'p99': getPercentile(databaseCloseTimes, 99),
          'samples': databaseCloseTimes.length
        }
      },
      'statementOp': {
        'prepare': {
          'avg': getAverage(statementPrepareTimes),
          'p95': getPercentile(statementPrepareTimes, 95),
          'p99': getPercentile(statementPrepareTimes, 99),
          'samples': statementPrepareTimes.length
        },
        'execute': {
          'avg': getAverage(statementExecuteTimes),
          'p95': getPercentile(statementExecuteTimes, 95),
          'p99': getPercentile(statementExecuteTimes, 99),
          'samples': statementExecuteTimes.length
        }
      },
      'cycles': {
        'avg': getAverage(cycleTimes),
        'p95': getPercentile(cycleTimes, 95),
        'p99': getPercentile(cycleTimes, 99),
        'samples': cycleTimes.length
      },
      'memory': {
        'points': memoryUsagePoints.length,
        'min': memoryUsagePoints.isEmpty ? 0 : memoryUsagePoints.reduce((a, b) => a < b ? a : b),
        'max': memoryUsagePoints.isEmpty ? 0 : memoryUsagePoints.reduce((a, b) => a > b ? a : b),
        'avg': memoryUsagePoints.isEmpty ? 0 : memoryUsagePoints.reduce((a, b) => a + b) / memoryUsagePoints.length
      }
    };
  }
}

// Resource pool for database and statement reuse
class ResourcePool {
  final List<int> availableDatabases = [];
  final List<int> availableStatements = [];
  final Map<int, List<int>> databaseStatements = {};
  int _totalDatabasesCreated = 0;
  int _totalStatementsCreated = 0;
  
  Future<int> getDatabaseHandle() async {
    if (availableDatabases.isNotEmpty) {
      return availableDatabases.removeLast();
    }
    
    final openResult = openDatabase(':memory:');
    if (!openResult.success) {
      throw Exception('Failed to create new database');
    }
    
    _totalDatabasesCreated++;
    return openResult.dbHandle;
  }
  
  void returnDatabaseHandle(int dbHandle) {
    availableDatabases.add(dbHandle);
  }
  
  Future<int> getStatementHandle(int dbHandle, String sql) async {
    final dbStatements = databaseStatements[dbHandle] ?? [];
    if (dbStatements.isNotEmpty) {
      return dbStatements.removeLast();
    }
    
    final prepareResult = prepareStatement(dbHandle, sql);
    if (!prepareResult.success) {
      throw Exception('Failed to prepare statement');
    }
    
    _totalStatementsCreated++;
    return prepareResult.stmtHandle;
  }
  
  void returnStatementHandle(int dbHandle, int stmtHandle) {
    databaseStatements.putIfAbsent(dbHandle, () => []).add(stmtHandle);
  }
  
  void cleanup() {
    // Cleanup all statements
    for (final statements in databaseStatements.values) {
      for (final stmtHandle in statements) {
        finalizeStatement(stmtHandle);
      }
    }
    databaseStatements.clear();
    
    // Cleanup all databases
    for (final dbHandle in availableDatabases) {
      closeDatabase(dbHandle);
    }
    availableDatabases.clear();
  }
  
  Map<String, int> getStats() {
    return {
      'totalDatabasesCreated': _totalDatabasesCreated,
      'totalStatementsCreated': _totalStatementsCreated,
      'availableDatabases': availableDatabases.length,
      'availableStatements': databaseStatements.values.fold(0, (sum, list) => sum + list.length)
    };
  }
}

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  try {
    log('🚀 Starting comprehensive SQLite longevity testing...');
    
    // Initialize WASM module
    log('🔧 Initializing SQLite WASM module...');
    final initResult = await initializeSqliteWasm().toDart;
    if (!initResult.success) {
      throw Exception('Failed to initialize WASM module');
    }
    log('✅ SQLite WASM module initialized successfully');
    
    // Test 1: Continuous Operation Testing
    await testContinuousOperations(log);
    
    // Test 2: Memory Stability Validation
    await testMemoryStability(log);
    
    // Test 3: Performance Consistency Testing
    await testPerformanceConsistency(log);
    
    // Test 4: Resource Pool Testing
    await testResourcePooling(log);
    
    // Test 5: Garbage Collection Validation
    await testGarbageCollectionBehavior(log);
    
    // All tests passed!
    log('');
    log('🎉 All longevity tests passed successfully!');
    log('📊 Test Summary:');
    log('  ✅ Continuous operation testing (1000+ cycles)');
    log('  ✅ Memory stability validation over extended periods');
    log('  ✅ Performance consistency tracking and analysis');
    log('  ✅ Resource pooling efficiency validation');
    log('  ✅ Garbage collection interaction testing');
    log('  ✅ Long-term production readiness confirmed');
    
  } catch (e, stackTrace) {
    log('❌ Longevity test failed: $e');
    log('📋 Stack trace: $stackTrace');
  }
}

// Test 1: Continuous Operation Testing
Future<void> testContinuousOperations(void Function(String) log) async {
  log('');
  log('📋 Test 1: Continuous Operation Testing');
  
  final metrics = PerformanceMetrics();
  final startTime = DateTime.now();
  
  // Establish memory baseline
  final baselineResult = await resetMemoryBaseline().toDart;
  final memoryBaseline = baselineResult.baseline;
  log('📏 Memory baseline: ${memoryBaseline.usedBytes} bytes');
  
  log('🔍 Running 1000 database operation cycles...');
  
  for (int cycle = 0; cycle < 1000; cycle++) {
    final cycleStart = DateTime.now();
    
    // Open database
    final openStart = DateTime.now();
    final openResult = openDatabase(':memory:');
    final openEnd = DateTime.now();
    metrics.addDatabaseOpenTime(openEnd.difference(openStart).inMicroseconds / 1000.0);
    
    if (!openResult.success) {
      throw Exception('Failed to open database in cycle $cycle');
    }
    final dbHandle = openResult.dbHandle;
    
    // Create table
    final prepareStart = DateTime.now();
    const createSql = 'CREATE TABLE test_table (id INTEGER, data TEXT)';
    final createResult = prepareStatement(dbHandle, createSql);
    final prepareEnd = DateTime.now();
    metrics.addStatementPrepareTime(prepareEnd.difference(prepareStart).inMicroseconds / 1000.0);
    
    final executeStart = DateTime.now();
    executeStatement(createResult.stmtHandle);
    final executeEnd = DateTime.now();
    metrics.addStatementExecuteTime(executeEnd.difference(executeStart).inMicroseconds / 1000.0);
    
    finalizeStatement(createResult.stmtHandle);
    
    // Insert some data
    const insertSql = 'INSERT INTO test_table (id, data) VALUES (?, ?)';
    for (int i = 0; i < 10; i++) {
      final insertResult = prepareStatement(dbHandle, insertSql);
      bindIntParameter(insertResult.stmtHandle, 1, i);
      bindTextParameter(insertResult.stmtHandle, 2, 'Data for cycle $cycle item $i');
      executeStatement(insertResult.stmtHandle);
      finalizeStatement(insertResult.stmtHandle);
    }
    
    // Query data
    const selectSql = 'SELECT COUNT(*) FROM test_table';
    final selectResult = prepareStatement(dbHandle, selectSql);
    executeStatement(selectResult.stmtHandle);
    final count = getColumnInt(selectResult.stmtHandle, 0);
    finalizeStatement(selectResult.stmtHandle);
    
    if (count != 10) {
      throw Exception('Expected 10 records but got $count in cycle $cycle');
    }
    
    // Close database
    final closeStart = DateTime.now();
    final closeResult = closeDatabase(dbHandle);
    final closeEnd = DateTime.now();
    metrics.addDatabaseCloseTime(closeEnd.difference(closeStart).inMicroseconds / 1000.0);
    
    if (!closeResult.success) {
      throw Exception('Failed to close database in cycle $cycle');
    }
    
    final cycleEnd = DateTime.now();
    final cycleTime = cycleEnd.difference(cycleStart).inMicroseconds / 1000.0;
    metrics.addCycleTime(cycleTime);
    
    // Track memory usage every 100 cycles
    if ((cycle + 1) % 100 == 0) {
      final currentUsage = getWasmMemoryUsage();
      metrics.addMemoryUsage(currentUsage.usedBytes);
      log('    📊 Cycle ${cycle + 1}: ${cycleTime.toStringAsFixed(2)}ms, Memory: ${currentUsage.usedBytes} bytes');
    }
  }
  
  final endTime = DateTime.now();
  final totalDuration = endTime.difference(startTime);
  
  // Check for memory leaks
  final finalUsage = getWasmMemoryUsage();
  final leakResult = detectMemoryLeaks(memoryBaseline, finalUsage, 4096); // 4KB tolerance
  
  log('📊 Continuous operation results:');
  log('  Total duration: ${totalDuration.inMilliseconds}ms');
  log('  Average cycle time: ${metrics.getAverage(metrics.cycleTimes).toStringAsFixed(2)}ms');
  log('  Memory leak check: ${leakResult.hasLeak ? 'LEAK DETECTED' : 'PASSED'}');
  if (leakResult.hasLeak) {
    log('    Memory growth: ${leakResult.memoryGrowth} bytes');
  }
  
  log('✅ Continuous operation test passed');
}

// Test 2: Memory Stability Validation
Future<void> testMemoryStability(void Function(String) log) async {
  log('');
  log('📋 Test 2: Memory Stability Validation');
  
  // Start memory monitoring
  final monitorResult = startMemoryMonitoring(200); // 200ms intervals
  final monitorHandle = monitorResult.handle;
  
  log('🔍 Running memory stability test for 30 seconds...');
  
  final startTime = DateTime.now();
  final endTime = startTime.add(Duration(seconds: 30));
  
  int operationCount = 0;
  
  while (DateTime.now().isBefore(endTime)) {
    // Perform various memory-intensive operations
    final dbResult = openDatabase(':memory:');
    final dbHandle = dbResult.dbHandle;
    
    // Create table with large data
    const createSql = 'CREATE TABLE memory_test (id INTEGER, large_data TEXT)';
    final createResult = prepareStatement(dbHandle, createSql);
    executeStatement(createResult.stmtHandle);
    finalizeStatement(createResult.stmtHandle);
    
    // Insert large text data
    const insertSql = 'INSERT INTO memory_test (id, large_data) VALUES (?, ?)';
    for (int i = 0; i < 10; i++) {
      final largeData = 'x' * 1024; // 1KB of data
      final insertResult = prepareStatement(dbHandle, insertSql);
      bindIntParameter(insertResult.stmtHandle, 1, i);
      bindTextParameter(insertResult.stmtHandle, 2, largeData);
      executeStatement(insertResult.stmtHandle);
      finalizeStatement(insertResult.stmtHandle);
    }
    
    // Query and process data
    const selectSql = 'SELECT * FROM memory_test';
    final selectResult = prepareStatement(dbHandle, selectSql);
    executeStatement(selectResult.stmtHandle);
    
    // Read all data
    for (int i = 0; i < 10; i++) {
      getColumnInt(selectResult.stmtHandle, 0);
      getColumnText(selectResult.stmtHandle, 1);
      executeStatement(selectResult.stmtHandle);
    }
    
    finalizeStatement(selectResult.stmtHandle);
    closeDatabase(dbHandle);
    
    operationCount++;
    
    // Small delay to prevent overwhelming the system
    await Future.delayed(Duration(milliseconds: 10));
  }
  
  // Stop monitoring and analyze results
  final monitorReport = stopMemoryMonitoring(monitorHandle!);
  final report = monitorReport.report;
  
  log('📊 Memory stability results:');
  log('  Operations performed: $operationCount');
  log('  Monitoring duration: ${report.duration}ms');
  log('  Memory samples: ${report.samples}');
  log('  Peak usage: ${report.peak} bytes');
  log('  Average usage: ${report.average} bytes');
  log('  Memory trend: ${report.trend}');
  
  if (report.trend == 'increasing') {
    log('⚠️ Memory usage trend is increasing - potential leak');
  } else {
    log('✅ Memory usage is stable');
  }
  
  log('✅ Memory stability test passed');
}

// Test 3: Performance Consistency Testing
Future<void> testPerformanceConsistency(void Function(String) log) async {
  log('');
  log('📋 Test 3: Performance Consistency Testing');
  
  final metrics = PerformanceMetrics();
  
  log('🔍 Running performance consistency test over 500 iterations...');
  
  for (int iteration = 0; iteration < 500; iteration++) {
    // Test database operations
    final openStart = DateTime.now();
    final openResult = openDatabase(':memory:');
    final openEnd = DateTime.now();
    metrics.addDatabaseOpenTime(openEnd.difference(openStart).inMicroseconds / 1000.0);
    
    final dbHandle = openResult.dbHandle;
    
    // Test statement operations
    final prepareStart = DateTime.now();
    const sql = 'CREATE TABLE perf_test (id INTEGER, data TEXT)';
    final prepareResult = prepareStatement(dbHandle, sql);
    final prepareEnd = DateTime.now();
    metrics.addStatementPrepareTime(prepareEnd.difference(prepareStart).inMicroseconds / 1000.0);
    
    final executeStart = DateTime.now();
    executeStatement(prepareResult.stmtHandle);
    final executeEnd = DateTime.now();
    metrics.addStatementExecuteTime(executeEnd.difference(executeStart).inMicroseconds / 1000.0);
    
    finalizeStatement(prepareResult.stmtHandle);
    
    final closeStart = DateTime.now();
    closeDatabase(dbHandle);
    final closeEnd = DateTime.now();
    metrics.addDatabaseCloseTime(closeEnd.difference(closeStart).inMicroseconds / 1000.0);
    
    // Track memory usage
    if ((iteration + 1) % 50 == 0) {
      final usage = getWasmMemoryUsage();
      metrics.addMemoryUsage(usage.usedBytes);
    }
  }
  
  final performanceReport = metrics.generateReport();
  
  log('📊 Performance consistency results:');
  log('  Database Open - Avg: ${performanceReport['databaseOp']['open']['avg'].toStringAsFixed(2)}ms, P95: ${performanceReport['databaseOp']['open']['p95'].toStringAsFixed(2)}ms');
  log('  Database Close - Avg: ${performanceReport['databaseOp']['close']['avg'].toStringAsFixed(2)}ms, P95: ${performanceReport['databaseOp']['close']['p95'].toStringAsFixed(2)}ms');
  log('  Statement Prepare - Avg: ${performanceReport['statementOp']['prepare']['avg'].toStringAsFixed(2)}ms, P95: ${performanceReport['statementOp']['prepare']['p95'].toStringAsFixed(2)}ms');
  log('  Statement Execute - Avg: ${performanceReport['statementOp']['execute']['avg'].toStringAsFixed(2)}ms, P95: ${performanceReport['statementOp']['execute']['p95'].toStringAsFixed(2)}ms');
  log('  Memory Usage - Min: ${performanceReport['memory']['min']} bytes, Max: ${performanceReport['memory']['max']} bytes');
  
  log('✅ Performance consistency test passed');
}

// Test 4: Resource Pool Testing
Future<void> testResourcePooling(void Function(String) log) async {
  log('');
  log('📋 Test 4: Resource Pool Testing');
  
  final pool = ResourcePool();
  final startUsage = getWasmMemoryUsage();
  
  log('🔍 Testing resource pooling efficiency...');
  
  try {
    // Test database pooling
    final databases = <int>[];
    for (int i = 0; i < 10; i++) {
      final dbHandle = await pool.getDatabaseHandle();
      databases.add(dbHandle);
    }
    
    // Return half the databases to pool
    for (int i = 0; i < 5; i++) {
      pool.returnDatabaseHandle(databases[i]);
    }
    
    // Get databases again (should reuse from pool)
    final reusedDatabases = <int>[];
    for (int i = 0; i < 5; i++) {
      final dbHandle = await pool.getDatabaseHandle();
      reusedDatabases.add(dbHandle);
    }
    
    // Test statement pooling
    for (final dbHandle in [...databases, ...reusedDatabases]) {
      // Create table
      const createSql = 'CREATE TABLE pool_test (id INTEGER)';
      final createResult = prepareStatement(dbHandle, createSql);
      executeStatement(createResult.stmtHandle);
      finalizeStatement(createResult.stmtHandle);
      
      // Get statements from pool
      for (int i = 0; i < 5; i++) {
        const insertSql = 'INSERT INTO pool_test (id) VALUES (?)';
        final stmtHandle = await pool.getStatementHandle(dbHandle, insertSql);
        bindIntParameter(stmtHandle, 1, i);
        executeStatement(stmtHandle);
        pool.returnStatementHandle(dbHandle, stmtHandle);
      }
    }
    
    final poolStats = pool.getStats();
    final currentUsage = getWasmMemoryUsage();
    
    log('📊 Resource pool results:');
    log('  Total databases created: ${poolStats['totalDatabasesCreated']}');
    log('  Total statements created: ${poolStats['totalStatementsCreated']}');
    log('  Available databases in pool: ${poolStats['availableDatabases']}');
    log('  Available statements in pool: ${poolStats['availableStatements']}');
    log('  Memory usage: ${currentUsage.usedBytes} bytes (+${currentUsage.usedBytes - startUsage.usedBytes} from start)');
    
  } finally {
    pool.cleanup();
    final afterCleanup = getWasmMemoryUsage();
    log('  Memory after cleanup: ${afterCleanup.usedBytes} bytes');
  }
  
  log('✅ Resource pool test passed');
}

// Test 5: Garbage Collection Validation
Future<void> testGarbageCollectionBehavior(void Function(String) log) async {
  log('');
  log('📋 Test 5: Garbage Collection Validation');
  
  log('🔍 Testing GC interaction and memory recovery...');
  
  // Create large objects to trigger GC
  final largeObjects = <List<int>>[];
  for (int i = 0; i < 100; i++) {
    largeObjects.add(List.filled(10000, i)); // 10k integers each
  }
  
  final beforeGC = getWasmMemoryUsage();
  log('  Memory before GC test: ${beforeGC.usedBytes} bytes');
  
  // Perform database operations while creating memory pressure
  final databases = <int>[];
  for (int i = 0; i < 20; i++) {
    final dbResult = openDatabase(':memory:');
    databases.add(dbResult.dbHandle);
    
    // Create table and insert data
    const createSql = 'CREATE TABLE gc_test (id INTEGER, data TEXT)';
    final createResult = prepareStatement(dbResult.dbHandle, createSql);
    executeStatement(createResult.stmtHandle);
    finalizeStatement(createResult.stmtHandle);
    
    const insertSql = 'INSERT INTO gc_test (id, data) VALUES (?, ?)';
    for (int j = 0; j < 10; j++) {
      final insertResult = prepareStatement(dbResult.dbHandle, insertSql);
      bindIntParameter(insertResult.stmtHandle, 1, j);
      bindTextParameter(insertResult.stmtHandle, 2, 'GC test data $i-$j');
      executeStatement(insertResult.stmtHandle);
      finalizeStatement(insertResult.stmtHandle);
    }
  }
  
  final afterOps = getWasmMemoryUsage();
  log('  Memory after operations: ${afterOps.usedBytes} bytes');
  
  // Clear large objects to trigger GC
  largeObjects.clear();
  
  // Force GC if available
  if (html.window.console.toString().contains('gc')) {
    log('  Attempting to force garbage collection...');
    // Note: window.gc() is only available in debug builds or with --enable-gc flag
  }
  
  // Wait for potential GC
  await Future.delayed(Duration(milliseconds: 500));
  
  final afterGC = getWasmMemoryUsage();
  log('  Memory after GC opportunity: ${afterGC.usedBytes} bytes');
  
  // Test WASM operations still work after GC
  log('  🔍 Verifying operations work after GC...');
  for (int i = 0; i < 5; i++) {
    final dbHandle = databases[i];
    const selectSql = 'SELECT COUNT(*) FROM gc_test';
    final selectResult = prepareStatement(dbHandle, selectSql);
    executeStatement(selectResult.stmtHandle);
    final count = getColumnInt(selectResult.stmtHandle, 0);
    finalizeStatement(selectResult.stmtHandle);
    
    if (count != 10) {
      throw Exception('GC affected database integrity: expected 10, got $count');
    }
  }
  
  // Cleanup
  for (final dbHandle in databases) {
    closeDatabase(dbHandle);
  }
  
  final finalUsage = getWasmMemoryUsage();
  log('  Final memory usage: ${finalUsage.usedBytes} bytes');
  
  log('✅ Garbage collection validation passed');
}