import 'minimal_api.dart';
import 'wasm_loader.dart';

/// WASM implementation of minimal SQLite API
class MinimalSqliteWasmImpl implements MinimalSqliteApi {
  final MinimalSqliteWasm _wasm = MinimalSqliteWasm();
  
  @override
  Future<void> initialize() => _wasm.initialize();
  
  @override
  String getVersion() => _wasm.getVersion();
  
  @override
  int getVersionNumber() => _wasm.getVersionNumber();
  
  @override
  void shutdown() => _wasm.shutdown();
}