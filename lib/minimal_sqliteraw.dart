/// Minimal SQLite Raw API for testing WASM compilation
/// 
/// This library provides a minimal interface to test that WASM compilation
/// works and basic SQLite functions can be called through both FFI and WASM.
/// 
/// Example usage:
/// ```dart
/// import 'package:sqliteraw/minimal_sqliteraw.dart';
/// 
/// void main() async {
///   final sqlite = createMinimalSqlite();
///   await sqlite.initialize();
///   
///   print('SQLite version: ${sqlite.getVersion()}');
///   print('Version number: ${sqlite.getVersionNumber()}');
///   
///   sqlite.shutdown();
/// }
/// ```
library minimal_sqliteraw;

// Export the common interface
export 'src/minimal/minimal_api.dart';

// Conditional exports for platform-specific implementations
export 'src/minimal/native_impl.dart'
    if (dart.library.js_interop) 'src/minimal/wasm_impl.dart';

import 'src/minimal/minimal_api.dart';
import 'src/minimal/native_impl.dart'
    if (dart.library.js_interop) 'src/minimal/wasm_impl.dart';

/// Create a platform-appropriate minimal SQLite implementation
/// 
/// On native platforms (VM, AOT), this returns a native FFI implementation.
/// On web platforms, this returns a WASM implementation.
MinimalSqliteApi createMinimalSqlite() {
  // The conditional import ensures the right implementation is used
  return MinimalSqliteNativeImpl();
}