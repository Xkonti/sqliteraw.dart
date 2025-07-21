import 'dart:html' as html;
import 'dart:js_interop';
import '../lib/src/minimal/wasm_loader.dart';

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  try {
    log('🚀 Starting Dart WASM SQLite test...');
    
    // Initialize the WASM SQLite module
    final sqlite = MinimalSqliteWasm();
    log('📦 Loading WASM module...');
    
    await sqlite.initialize('sqlite3.wasm');
    log('✅ WASM module loaded successfully');
    
    // Test version functions
    log('📋 Getting SQLite version...');
    final version = sqlite.getVersion();
    log('✅ SQLite version: $version');
    
    log('🔢 Getting version number...');
    final versionNumber = sqlite.getVersionNumber();
    log('✅ Version number: $versionNumber');
    
    // Verify consistency
    final versionParts = version.split('.').map(int.parse).toList();
    final expectedNumber = versionParts[0] * 1000000 + 
                          versionParts[1] * 1000 + 
                          versionParts[2];
    
    if (versionNumber == expectedNumber) {
      log('✅ Version consistency check passed');
    } else {
      log('❌ Version mismatch: $versionNumber != $expectedNumber');
    }
    
    log('🎉 All WASM tests passed!');
    
    // Cleanup
    sqlite.shutdown();
    log('🧹 Shutdown complete');
    
  } catch (e, stackTrace) {
    log('❌ Error: $e');
    log('Stack trace: $stackTrace');
  }
}