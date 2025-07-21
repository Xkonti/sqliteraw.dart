/// Minimal SQLite Raw API using universal_ffi for cross-platform support
/// 
/// This library provides a minimal interface that works seamlessly across
/// native platforms (using dart:ffi) and web platforms (using WASM).
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
export 'src/minimal/unified_native_impl.dart'
    if (dart.library.js_interop) 'src/minimal/unified_web_impl.dart';

import 'src/minimal/minimal_api.dart';
import 'src/minimal/unified_native_impl.dart'
    if (dart.library.js_interop) 'src/minimal/unified_web_impl.dart';

/// Create a cross-platform minimal SQLite implementation
/// 
/// Uses universal_ffi to automatically select the appropriate implementation:
/// - Native platforms (VM, AOT): Uses dart:ffi with system SQLite libraries
/// - Web platforms: Uses WASM with minimal JavaScript bridge
MinimalSqliteApi createMinimalSqlite() {
  return MinimalSqliteUnifiedImpl();
}