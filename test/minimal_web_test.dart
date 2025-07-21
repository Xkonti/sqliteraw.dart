@TestOn('browser')
import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';

void main() {
  group('Minimal SQLite WASM', () {
    late MinimalSqliteApi sqlite;
    
    setUp(() {
      sqlite = createMinimalSqlite();
    });
    
    tearDown(() {
      sqlite.shutdown();
    });
    
    test('can initialize SQLite WASM', () async {
      await expectLater(sqlite.initialize(), completes);
    });
    
    test('can get version string from WASM', () async {
      await sqlite.initialize();
      
      final version = sqlite.getVersion();
      print('📋 SQLite WASM version: $version');
      
      expect(version, isNotEmpty);
      expect(version, contains('3.'));
      expect(version, matches(RegExp(r'3\.\d+\.\d+')));
    });
    
    test('can get version number from WASM', () async {
      await sqlite.initialize();
      
      final versionNumber = sqlite.getVersionNumber();
      print('🔢 SQLite WASM version number: $versionNumber');
      
      expect(versionNumber, greaterThan(0));
      expect(versionNumber, greaterThan(3000000)); // At least SQLite 3.0.0
    });
    
    test('WASM version string and number are consistent', () async {
      await sqlite.initialize();
      
      final version = sqlite.getVersion();
      final versionNumber = sqlite.getVersionNumber();
      
      // Extract version components from string (e.g., "3.45.1" -> [3, 45, 1])
      final versionParts = version.split('.').map(int.parse).toList();
      
      // Calculate expected version number: major*1000000 + minor*1000 + patch
      final expectedNumber = versionParts[0] * 1000000 + 
                           versionParts[1] * 1000 + 
                           versionParts[2];
      
      expect(versionNumber, equals(expectedNumber));
      print('✅ WASM version consistency check passed: $version = $versionNumber');
    });
    
    test('can shutdown WASM gracefully', () async {
      await sqlite.initialize();
      
      expect(() => sqlite.shutdown(), returnsNormally);
      
      // After shutdown, operations should fail
      expect(() => sqlite.getVersion(), throwsStateError);
    });
    
    test('WASM module can be re-initialized', () async {
      await sqlite.initialize();
      final version1 = sqlite.getVersion();
      
      sqlite.shutdown();
      
      await sqlite.initialize();
      final version2 = sqlite.getVersion();
      
      expect(version2, equals(version1));
    });
    
    test('WASM handles multiple rapid calls', () async {
      await sqlite.initialize();
      
      // Call version functions multiple times rapidly
      for (int i = 0; i < 10; i++) {
        final version = sqlite.getVersion();
        final versionNumber = sqlite.getVersionNumber();
        
        expect(version, isNotEmpty);
        expect(versionNumber, greaterThan(0));
      }
    });
  });
}