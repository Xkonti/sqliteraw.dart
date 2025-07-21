import 'dart:js_interop';
import 'dart:html' as html;

/// Minimal WASM loader for SQLite
/// 
/// This class handles loading and initializing the SQLite WASM module
/// with just enough functionality to test basic operations.
class MinimalSqliteWasm {
  html.WebAssembly.Instance? _instance;
  html.WebAssembly.Memory? _memory;
  bool _initialized = false;
  
  /// Load and initialize the SQLite WASM module
  Future<void> initialize([String wasmUrl = 'sqlite3.wasm']) async {
    if (_initialized) return;
    
    try {
      // Fetch WASM binary
      final response = await html.window.fetch(wasmUrl);
      if (!response.ok) {
        throw Exception('Failed to fetch WASM module: ${response.status} ${response.statusText}');
      }
      
      final wasmBytes = await response.arrayBuffer();
      
      // Create shared memory (1MB initial)
      _memory = html.WebAssembly.Memory(html.MemoryDescriptor(initial: 16));
      
      // Minimal imports - just memory
      final imports = {
        'env': {
          'memory': _memory!,
        }.jsify(),
      }.jsify();
      
      // Instantiate WASM module
      final result = await html.WebAssembly.instantiate(wasmBytes, imports);
      _instance = result.instance!;
      
      // Initialize SQLite
      _callFunction('sqlite3_initialize');
      
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize SQLite WASM: $e');
    }
  }
  
  /// Get SQLite version string
  String getVersion() {
    _ensureInitialized();
    final versionPtr = _callFunction<int>('sqlite3_libversion');
    return _readString(versionPtr);
  }
  
  /// Get SQLite version number
  int getVersionNumber() {
    _ensureInitialized();
    return _callFunction<int>('sqlite3_libversion_number');
  }
  
  /// Shutdown SQLite
  void shutdown() {
    if (_initialized && _instance != null) {
      try {
        _callFunction('sqlite3_shutdown');
      } catch (e) {
        // Ignore shutdown errors
      }
      _instance = null;
      _memory = null;
      _initialized = false;
    }
  }
  
  /// Call a WASM function by name
  T _callFunction<T>(String name, [List<Object>? args]) {
    _ensureInitialized();
    
    final exports = _instance!.exports!;
    if (!exports.has(name)) {
      throw Exception('Function $name not found in WASM module');
    }
    
    final function = exports[name] as JSFunction;
    final result = function.callAsFunction(null, ...(args ?? []));
    return result as T;
  }
  
  /// Read a null-terminated string from WASM memory
  String _readString(int ptr) {
    if (ptr == 0) return '';
    
    _ensureInitialized();
    final buffer = _memory!.buffer.asUint8List();
    
    // Find null terminator
    int end = ptr;
    while (end < buffer.length && buffer[end] != 0) {
      end++;
    }
    
    if (end == ptr) return '';
    
    // Convert bytes to string
    final bytes = buffer.sublist(ptr, end);
    return String.fromCharCodes(bytes);
  }
  
  /// Ensure the WASM module is initialized
  void _ensureInitialized() {
    if (!_initialized || _instance == null) {
      throw StateError('SQLite WASM not initialized. Call initialize() first.');
    }
  }
}