import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';

void main() {
  group('Unified SQLite Implementation', () {
    test('can initialize SQLite', () async {
      final sqlite = createMinimalSqlite();
      await sqlite.initialize();
      sqlite.shutdown();
    });

    test('can get version string', () async {
      final sqlite = createMinimalSqlite();
      await sqlite.initialize();
      
      final version = sqlite.getVersion();
      print('📋 SQLite version: $version');
      
      expect(version, isNotEmpty);
      expect(version, startsWith('3.'));
      
      sqlite.shutdown();
    });

    test('can get version number', () async {
      final sqlite = createMinimalSqlite();
      await sqlite.initialize();
      
      final versionNumber = sqlite.getVersionNumber();
      print('🔢 SQLite version number: $versionNumber');
      
      expect(versionNumber, greaterThan(0));
      expect(versionNumber, equals(3050003)); // SQLite 3.50.3
      
      sqlite.shutdown();
    });

    test('version string and number are consistent', () async {
      final sqlite = createMinimalSqlite();
      await sqlite.initialize();
      
      final version = sqlite.getVersion();
      final versionNumber = sqlite.getVersionNumber();
      
      // SQLite 3.50.3 should have version number 3050003
      if (version == '3.50.3') {
        expect(versionNumber, equals(3050003));
        print('✅ Version consistency check passed: $version = $versionNumber');
      } else {
        print('ℹ️ Version: $version, Number: $versionNumber');
        expect(versionNumber, greaterThan(0));
      }
      
      sqlite.shutdown();
    });

    test('can shutdown gracefully', () async {
      final sqlite = createMinimalSqlite();
      await sqlite.initialize();
      
      // Should not throw
      expect(() => sqlite.shutdown(), returnsNormally);
    });

    test('can re-initialize after shutdown', () async {
      final sqlite = createMinimalSqlite();
      
      // First initialization cycle
      await sqlite.initialize();
      final version1 = sqlite.getVersion();
      sqlite.shutdown();
      
      // Second initialization cycle
      await sqlite.initialize();
      final version2 = sqlite.getVersion();
      sqlite.shutdown();
      
      // Should get the same version both times
      expect(version2, equals(version1));
    });
  });
}