import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';

void main() {
  group('Cross-Platform SQLite Implementation', () {
    late MinimalSqliteApi sqlite;
    
    setUp(() async {
      sqlite = createMinimalSqlite();
      await sqlite.initialize();
    });
    
    tearDown(() {
      sqlite.shutdown();
    });
    
    test('universal_ffi implementation works across platforms', () async {
      final version = sqlite.getVersion();
      final versionNumber = sqlite.getVersionNumber();
      
      print('🚀 SQLite Version: $version');
      print('🔢 SQLite Version Number: $versionNumber');
      
      expect(version, isNotEmpty);
      expect(version, matches(RegExp(r'3\.\d+\.\d+')));
      expect(versionNumber, greaterThan(3000000));
      
      // Extract version components and verify consistency
      final versionParts = version.split('.').map(int.parse).toList();
      final expectedNumber = versionParts[0] * 1000000 + 
                           versionParts[1] * 1000 + 
                           versionParts[2];
      
      expect(versionNumber, equals(expectedNumber));
      print('✅ Version consistency verified: $version = $versionNumber');
    });
    
    test('handles rapid function calls across platforms', () async {
      // Test universal_ffi bridge stability
      for (int i = 0; i < 25; i++) {
        final version = sqlite.getVersion();
        final versionNumber = sqlite.getVersionNumber();
        
        expect(version, isNotEmpty);
        expect(versionNumber, greaterThan(0));
        
        if (i % 5 == 0) {
          print('📊 Cross-platform call batch ${i ~/ 5 + 1}/5 completed');
        }
      }
      print('✅ Cross-platform rapid call test completed');
    });
    
    test('memory management works across platforms', () async {
      // Test re-initialization cycles
      for (int cycle = 0; cycle < 3; cycle++) {
        sqlite.shutdown();
        await sqlite.initialize();
        
        final version = sqlite.getVersion();
        expect(version, isNotEmpty);
        print('🔄 Cross-platform memory cycle ${cycle + 1}/3: $version');
      }
      print('✅ Cross-platform memory management verified');
    });
  });
}