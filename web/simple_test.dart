import 'dart:html' as html;
import 'dart:js_util' as js;
import 'dart:typed_data';

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  try {
    log('🚀 Starting simple WASM SQLite test...');
    
    // Load WASM module
    log('📦 Fetching sqlite3.wasm...');
    final response = await html.window.fetch('sqlite3.wasm');
    
    // Check response status using js_util
    final status = js.getProperty(response, 'status');
    if (status != 200) {
      throw Exception('Failed to fetch WASM: $status');
    }
    
    final wasmBytes = await js.promiseToFuture(
      js.callMethod(response, 'arrayBuffer', [])
    );
    final wasmBytesLength = js.getProperty(wasmBytes, 'byteLength');
    log('✅ WASM bytes loaded: $wasmBytesLength bytes');
    
    // Create basic imports
    final memory = js.callConstructor(
      js.getProperty(js.getProperty(html.window, 'WebAssembly'), 'Memory'),
      [js.jsify({'initial': 16})]
    );
    
    // Provide complete WASI imports (all functions are stubs since we don't use them)
    final wasiStub = js.allowInterop(() => 0);
    final wasiVoidStub = js.allowInterop(() {});
    
    final imports = js.jsify({
      'env': {'memory': memory},
      'wasi_snapshot_preview1': {
        // Process and environment
        'proc_exit': wasiVoidStub,
        'environ_get': wasiStub,
        'environ_sizes_get': wasiStub,
        
        // Time
        'clock_time_get': wasiStub,
        
        // File descriptors  
        'fd_close': wasiStub,
        'fd_fdstat_get': wasiStub,
        'fd_fdstat_set_flags': wasiStub,
        'fd_filestat_get': wasiStub,
        'fd_filestat_set_size': wasiStub,
        'fd_prestat_get': wasiStub,
        'fd_prestat_dir_name': wasiStub,
        'fd_read': wasiStub,
        'fd_seek': wasiStub,
        'fd_sync': wasiStub,
        'fd_write': wasiStub,
        
        // Path operations
        'path_create_directory': wasiStub,
        'path_filestat_get': wasiStub,
        'path_filestat_set_times': wasiStub,
        'path_open': wasiStub,
        'path_readlink': wasiStub,
        'path_remove_directory': wasiStub,
        'path_unlink_file': wasiStub,
        
        // Polling
        'poll_oneoff': wasiStub,
      }
    });
    
    log('📦 Instantiating WASM module...');
    final result = await js.promiseToFuture(
      js.callMethod(
        js.getProperty(html.window, 'WebAssembly'),
        'instantiate',
        [wasmBytes, imports]
      )
    );
    
    final instance = js.getProperty(result, 'instance');
    final exports = js.getProperty(instance, 'exports');
    
    log('✅ WASM module instantiated successfully');
    
    // Test SQLite initialization
    log('🔧 Initializing SQLite...');
    final initFunc = js.getProperty(exports, 'sqlite3_initialize');
    final initResult = js.callMethod(initFunc, '', []);
    log('✅ SQLite initialized with result: $initResult');
    
    // Test version function
    log('📋 Getting SQLite version...');
    final versionFunc = js.getProperty(exports, 'sqlite3_libversion');
    final versionPtr = js.callMethod(versionFunc, '', []);
    
    // Read string from memory
    final memoryObj = js.getProperty(exports, 'memory');
    final buffer = js.getProperty(memoryObj, 'buffer');
    final uint8Array = Uint8List.view(buffer as ByteBuffer);
    
    // Find null terminator and read string
    int end = versionPtr;
    while (end < uint8Array.length && uint8Array[end] != 0) {
      end++;
    }
    
    final versionBytes = uint8Array.sublist(versionPtr, end);
    final version = String.fromCharCodes(versionBytes);
    log('✅ SQLite version: $version');
    
    // Test version number function
    log('🔢 Getting version number...');
    final versionNumFunc = js.getProperty(exports, 'sqlite3_libversion_number');
    final versionNumber = js.callMethod(versionNumFunc, '', []);
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
    
    // Test shutdown
    log('🧹 Shutting down SQLite...');
    final shutdownFunc = js.getProperty(exports, 'sqlite3_shutdown');
    final shutdownResult = js.callMethod(shutdownFunc, '', []);
    log('✅ Shutdown complete with result: $shutdownResult');
    
  } catch (e, stackTrace) {
    log('❌ Error: $e');
    log('Stack trace: $stackTrace');
  }
}