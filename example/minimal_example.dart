/// Minimal example demonstrating SQLite WASM functionality
/// 
/// This example shows how to use the minimal SQLite API to get
/// version information. It works on both native and web platforms.

import 'package:sqliteraw/minimal_sqliteraw.dart';

Future<void> main() async {
  print('🚀 Starting minimal SQLite example...');
  
  final sqlite = createMinimalSqlite();
  
  try {
    // Initialize SQLite
    print('📦 Initializing SQLite...');
    await sqlite.initialize();
    print('✅ SQLite initialized successfully');
    
    // Get version information
    final version = sqlite.getVersion();
    final versionNumber = sqlite.getVersionNumber();
    
    print('');
    print('📋 SQLite Version: $version');
    print('🔢 Version Number: $versionNumber');
    print('');
    
    // Verify consistency
    final versionParts = version.split('.').map(int.parse).toList();
    final expectedNumber = versionParts[0] * 1000000 + 
                          versionParts[1] * 1000 + 
                          versionParts[2];
    
    if (versionNumber == expectedNumber) {
      print('✅ Version consistency check passed');
    } else {
      print('❌ Version mismatch: $versionNumber != $expectedNumber');
    }
    
    print('');
    print('🎉 Example completed successfully!');
    
  } catch (e) {
    print('❌ Error: $e');
    rethrow;
  } finally {
    // Always cleanup
    print('🧹 Shutting down SQLite...');
    sqlite.shutdown();
    print('✅ Shutdown complete');
  }
}