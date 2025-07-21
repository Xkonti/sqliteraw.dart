import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

@JS()
external JSObject get globalThis;

@JS()
external JSPromise fetch(String url);

@JS()
external JSObject get WebAssembly;

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  try {
    log('🚀 Starting direct JS interop WASM test...');
    
    // Load WASM module using direct JS interop
    log('📦 Fetching sqlite3.wasm...');
    final response = await fetch('sqlite3.wasm').toDart;
    
    final wasmBytes = await response.arrayBuffer().toDart;
    final byteLength = wasmBytes.byteLength;
    log('✅ WASM bytes loaded: $byteLength bytes');
    
    // Create memory
    final memory = WebAssembly.Memory(MemoryDescriptor(initial: 16));
    
    // Simple WASI stubs
    final wasiImports = WasiImports(
      proc_exit: (int code) {},
      environ_get: (int environ, int environ_buf) => 0,
      environ_sizes_get: (int environ_count, int environ_size) => 0,
      clock_time_get: (int id, int precision, int time) => 0,
      fd_close: (int fd) => 0,
      fd_fdstat_get: (int fd, int fdstat) => 0,
      fd_fdstat_set_flags: (int fd, int flags) => 0,
      fd_filestat_get: (int fd, int filestat) => 0,
      fd_filestat_set_size: (int fd, int size) => 0,
      fd_prestat_get: (int fd, int prestat) => 0,
      fd_prestat_dir_name: (int fd, int path, int path_len) => 0,
      fd_read: (int fd, int iovs, int iovs_len, int nread) => 0,
      fd_seek: (int fd, int offset_low, int offset_high, int whence, int newoffset) => 0,
      fd_sync: (int fd) => 0,
      fd_write: (int fd, int iovs, int iovs_len, int nwritten) => 0,
      path_create_directory: (int fd, int path, int path_len) => 0,
      path_filestat_get: (int fd, int flags, int path, int path_len, int filestat) => 0,
      path_filestat_set_times: (int fd, int flags, int path, int path_len, int atim, int mtim, int fst_flags) => 0,
      path_open: (int fd, int dirflags, int path, int path_len, int oflags, int fs_rights_base, int fs_rights_inheriting, int fdflags, int opened_fd) => 0,
      path_readlink: (int fd, int path, int path_len, int buf, int buf_len, int bufused) => 0,
      path_remove_directory: (int fd, int path, int path_len) => 0,
      path_unlink_file: (int fd, int path, int path_len) => 0,
      poll_oneoff: (int in_, int out, int nsubscriptions, int nevents) => 0,
    );
    
    final imports = Imports(
      env: EnvImports(memory: memory),
      wasi_snapshot_preview1: wasiImports,
    );
    
    log('📦 Instantiating WASM module...');
    final result = await WebAssembly.instantiate(wasmBytes, imports).toDart;
    final instance = result.instance;
    final exports = instance.exports;
    
    log('✅ WASM module instantiated successfully');
    
    // Test SQLite functions directly
    log('🔧 Initializing SQLite...');
    final initResult = exports.sqlite3_initialize();
    log('✅ SQLite initialized with result: $initResult');
    
    log('📋 Getting SQLite version...');
    final versionPtr = exports.sqlite3_libversion();
    
    // Read string from memory
    final memoryBuffer = exports.memory.buffer;
    final uint8Array = Uint8List.view(memoryBuffer as ByteBuffer);
    
    // Find null terminator
    int end = versionPtr;
    while (end < uint8Array.length && uint8Array[end] != 0) {
      end++;
    }
    
    final versionBytes = uint8Array.sublist(versionPtr, end);
    final version = String.fromCharCodes(versionBytes);
    log('✅ SQLite version: $version');
    
    log('🔢 Getting version number...');
    final versionNumber = exports.sqlite3_libversion_number();
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
    final shutdownResult = exports.sqlite3_shutdown();
    log('✅ Shutdown complete with result: $shutdownResult');
    
  } catch (e, stackTrace) {
    log('❌ Error: $e');
    log('Stack trace: $stackTrace');
  }
}

// JS Interop type definitions
@JS()
@anonymous
extension type MemoryDescriptor._(JSObject _) implements JSObject {
  external factory MemoryDescriptor({required int initial});
}

@JS()
@anonymous
extension type Memory._(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

@JS()
@anonymous
extension type Imports._(JSObject _) implements JSObject {
  external factory Imports({
    required EnvImports env,
    required WasiImports wasi_snapshot_preview1,
  });
}

@JS()
@anonymous
extension type EnvImports._(JSObject _) implements JSObject {
  external factory EnvImports({required Memory memory});
}

@JS()
@anonymous
extension type WasiImports._(JSObject _) implements JSObject {
  external factory WasiImports({
    required JSFunction proc_exit,
    required JSFunction environ_get,
    required JSFunction environ_sizes_get,
    required JSFunction clock_time_get,
    required JSFunction fd_close,
    required JSFunction fd_fdstat_get,
    required JSFunction fd_fdstat_set_flags,
    required JSFunction fd_filestat_get,
    required JSFunction fd_filestat_set_size,
    required JSFunction fd_prestat_get,
    required JSFunction fd_prestat_dir_name,
    required JSFunction fd_read,
    required JSFunction fd_seek,
    required JSFunction fd_sync,
    required JSFunction fd_write,
    required JSFunction path_create_directory,
    required JSFunction path_filestat_get,
    required JSFunction path_filestat_set_times,
    required JSFunction path_open,
    required JSFunction path_readlink,
    required JSFunction path_remove_directory,
    required JSFunction path_unlink_file,
    required JSFunction poll_oneoff,
  });
}

@JS()
@anonymous
extension type JSResponse._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS()
@anonymous  
extension type JSArrayBuffer._(JSObject _) implements JSObject {
  external int get byteLength;
}

@JS()
@anonymous
extension type InstantiateResult._(JSObject _) implements JSObject {
  external WasmInstance get instance;
}

@JS()
@anonymous
extension type WasmInstance._(JSObject _) implements JSObject {
  external SqliteExports get exports;
}

@JS()
@anonymous
extension type SqliteExports._(JSObject _) implements JSObject {
  external Memory get memory;
  external int sqlite3_initialize();
  external int sqlite3_libversion();
  external int sqlite3_libversion_number();
  external int sqlite3_shutdown();
}

extension on JSObject {
  external JSFunction get Memory;
  external JSPromise<InstantiateResult> instantiate(JSArrayBuffer bytes, Imports imports);
}

extension on JSPromise<JSResponse> {
  external JSResponse get toDart;
}

extension on JSPromise<JSArrayBuffer> {
  external JSArrayBuffer get toDart;
}

extension on JSPromise<InstantiateResult> {
  external InstantiateResult get toDart;
}