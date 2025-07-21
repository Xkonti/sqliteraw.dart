import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';

void main() {
  test('platform detection works correctly', () async {
    final sqlite = createMinimalSqlite();
    
    // This will print different information based on platform
    print('🔍 Implementation type: ${sqlite.runtimeType}');
    print('🔍 Implementation string: $sqlite');
    
    await sqlite.initialize();
    
    final version = sqlite.getVersion();
    print('🔍 SQLite version: $version');
    
    // The exact same API call works on both platforms!
    expect(version, isNotEmpty);
    expect(version, matches(RegExp(r'3\.\d+\.\d+')));
    
    sqlite.shutdown();
    
    print('✅ Platform-specific implementation working correctly');
  });
}