@TestOn('vm')
import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';

void main() {
  group('Minimal SQLite Native FFI', () {
    late MinimalSqliteApi sqlite;
    
    setUp(() {
      sqlite = createMinimalSqlite();
    });
    
    tearDown(() {
      sqlite.shutdown();
    });
    
    test('can initialize SQLite', () async {
      await expectLater(sqlite.initialize(), completes);
    });
    
    test('can get version string', () async {
      await sqlite.initialize();
      
      final version = sqlite.getVersion();
      print('📋 SQLite version: $version');
      
      expect(version, isNotEmpty);
      expect(version, contains('3.'));
      expect(version, matches(RegExp(r'3\.\d+\.\d+')));
    });
    
    test('can get version number', () async {
      await sqlite.initialize();
      
      final versionNumber = sqlite.getVersionNumber();
      print('🔢 SQLite version number: $versionNumber');
      
      expect(versionNumber, greaterThan(0));
      expect(versionNumber, greaterThan(3000000)); // At least SQLite 3.0.0
    });
    
    test('version string and number are consistent', () async {
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
      print('✅ Version consistency check passed: $version = $versionNumber');
    });
    
    test('can shutdown gracefully', () async {
      await sqlite.initialize();
      
      expect(() => sqlite.shutdown(), returnsNormally);
      
      // After shutdown, operations should fail
      expect(() => sqlite.getVersion(), throwsStateError);
    });
    
    test('can re-initialize after shutdown', () async {
      await sqlite.initialize();
      final version1 = sqlite.getVersion();
      
      sqlite.shutdown();
      
      await sqlite.initialize();
      final version2 = sqlite.getVersion();
      
      expect(version2, equals(version1));
    });
  });
}