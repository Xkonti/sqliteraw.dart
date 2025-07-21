import 'dart:html' as html;
import 'dart:js_interop';

@JS()
external JSPromise<JSString> testSqliteWasm();

void main() async {
  final output = html.querySelector('#test-output')!;
  
  void log(String message) {
    print(message);
    output.appendHtml('<div>$message</div>');
  }
  
  try {
    log('🚀 Starting simple Dart WASM test...');
    log('📦 Calling JavaScript helper function...');
    
    final result = await testSqliteWasm().toDart;
    final resultString = result.toDart;
    
    log('✅ Test completed successfully!');
    log('📋 Result: $resultString');
    
  } catch (e, stackTrace) {
    log('❌ Error: $e');
    log('Stack trace: $stackTrace');
  }
}