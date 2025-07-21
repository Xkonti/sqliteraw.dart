import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

@JS()
external JSAny callFunction0(JSFunction function);

@JS()
external JSAny callConstructor(JSFunction constructor, JSAny arg);

// WebAssembly API bindings
@JS('WebAssembly.Memory')
external JSFunction get _MemoryConstructor;

@JS('WebAssembly.instantiate')
external JSPromise<WasmInstantiateResult> _instantiate(
  JSArrayBuffer bytes, 
  JSObject imports
);

@JS('fetch')
external JSPromise<JSResponse> _fetch(String url);

// Type definitions for JS interop
extension type WasmInstantiateResult._(JSObject _) implements JSObject {
  external WasmInstance get instance;
}

extension type WasmInstance._(JSObject _) implements JSObject {
  external SqliteExports get exports;
}

extension type SqliteExports._(JSObject _) implements JSObject {
  external JSFunction get sqlite3_initialize;
  external JSFunction get sqlite3_libversion;
  external JSFunction get sqlite3_libversion_number;
  external JSFunction get sqlite3_shutdown;
}

extension type JSResponse._(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension type JSArrayBuffer._(JSObject _) implements JSObject {
  external int get byteLength;
}

extension type WasmMemory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  try {
    log('🚀 Starting Dart JS interop WASM test...');
    
    // Load WASM module
    log('📦 Fetching sqlite3.wasm...');
    final response = await _fetch('sqlite3.wasm').toDart;
    
    if (!response.ok) {
      throw Exception('Failed to fetch WASM: ${response.status}');
    }
    
    final wasmBytes = await response.arrayBuffer().toDart;
    log('✅ WASM bytes loaded: ${wasmBytes.byteLength} bytes');
    
    // Create memory
    final memory = callConstructor(_MemoryConstructor, {'initial': 16}.jsify()) as WasmMemory;
    
    // Create WASI stubs using allowInterop
    final wasiStub = (() => 0).toJS;
    final wasiVoidStub = (() {}).toJS;
    
    final imports = {
      'env': {'memory': memory},
      'wasi_snapshot_preview1': {
        'proc_exit': wasiVoidStub,
        'environ_get': wasiStub,
        'environ_sizes_get': wasiStub,
        'clock_time_get': wasiStub,
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
        'path_create_directory': wasiStub,
        'path_filestat_get': wasiStub,
        'path_filestat_set_times': wasiStub,
        'path_open': wasiStub,
        'path_readlink': wasiStub,
        'path_remove_directory': wasiStub,
        'path_unlink_file': wasiStub,
        'poll_oneoff': wasiStub,
      }
    }.jsify() as JSObject;
    
    log('📦 Instantiating WASM module...');
    final result = await _instantiate(wasmBytes, imports).toDart;
    final exports = result.instance.exports;
    
    log('✅ WASM module instantiated successfully');
    
    // Test SQLite functions using callFunction0
    log('🔧 Initializing SQLite...');
    final initResult = callFunction0(exports.sqlite3_initialize) as int;
    log('✅ SQLite initialized with result: $initResult');
    
    log('📋 Getting SQLite version...');
    final versionPtr = callFunction0(exports.sqlite3_libversion) as int;
    
    // Read string from memory
    final memoryBuffer = memory.buffer;
    final uint8Array = Uint8List.view(memoryBuffer.dartify() as ByteBuffer);
    
    // Find null terminator
    int end = versionPtr;
    while (end < uint8Array.length && uint8Array[end] != 0) {
      end++;
    }
    
    final versionBytes = uint8Array.sublist(versionPtr, end);
    final version = String.fromCharCodes(versionBytes);
    log('✅ SQLite version: $version');
    
    log('🔢 Getting version number...');
    final versionNumber = callFunction0(exports.sqlite3_libversion_number) as int;
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
    
    log('🎉 All Dart WASM interop tests passed!');
    
    // Test shutdown
    log('🧹 Shutting down SQLite...');
    final shutdownResult = callFunction0(exports.sqlite3_shutdown) as int;
    log('✅ Shutdown complete with result: $shutdownResult');
    
  } catch (e, stackTrace) {
    log('❌ Error: $e');
    log('Stack trace: $stackTrace');
  }
}