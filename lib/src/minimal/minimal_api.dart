/// Minimal SQLite API interface for testing WASM compilation
/// 
/// This interface provides just enough functionality to test that
/// WASM compilation works and we can call basic SQLite functions.
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
}