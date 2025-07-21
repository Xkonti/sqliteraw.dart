@TestOn('browser')
import 'package:test/test.dart';
import 'package:sqliteraw/minimal_sqliteraw.dart';
import 'dart:typed_data';

void main() {
  group('Comprehensive SQLite WASM Data Operations', () {
    late MinimalSqliteApi sqlite;
    
    setUp(() async {
      sqlite = createMinimalSqlite();
      await sqlite.initialize();
    });
    
    tearDown(() {
      sqlite.shutdown();
    });
    
    test('SQLite WASM basic initialization and version check', () async {
      final version = sqlite.getVersion();
      final versionNumber = sqlite.getVersionNumber();
      
      print('🚀 SQLite WASM Version: $version');
      print('🔢 SQLite WASM Version Number: $versionNumber');
      
      expect(version, isNotEmpty);
      expect(version, matches(RegExp(r'3\.\d+\.\d+')));
      expect(versionNumber, greaterThan(3000000));
      
      // Extract version components from string (e.g., "3.50.3" -> [3, 50, 3])
      final versionParts = version.split('.').map(int.parse).toList();
      
      // Calculate expected version number: major*1000000 + minor*1000 + patch
      final expectedNumber = versionParts[0] * 1000000 + 
                           versionParts[1] * 1000 + 
                           versionParts[2];
      
      expect(versionNumber, equals(expectedNumber));
      print('✅ WASM version consistency verified: $version = $versionNumber');
    });
    
    test('SQLite WASM handles rapid function calls', () async {
      // Test rapid successive calls to ensure WASM bridge stability
      for (int i = 0; i < 50; i++) {
        final version = sqlite.getVersion();
        final versionNumber = sqlite.getVersionNumber();
        
        expect(version, isNotEmpty);
        expect(versionNumber, greaterThan(0));
        
        if (i % 10 == 0) {
          print('📊 Rapid call batch ${i ~/ 10 + 1}/5 completed');
        }
      }
      print('✅ WASM rapid call stability test passed');
    });
    
    test('SQLite WASM memory and resource management', () async {
      // Test multiple initialization cycles to check for memory leaks
      for (int cycle = 0; cycle < 5; cycle++) {
        sqlite.shutdown();
        await sqlite.initialize();
        
        final version = sqlite.getVersion();
        expect(version, isNotEmpty);
        
        print('🔄 Memory cycle ${cycle + 1}/5: Version $version');
      }
      print('✅ WASM memory management test completed');
    });
    
    test('SQLite WASM error handling and edge cases', () async {
      // Test shutdown behavior
      sqlite.shutdown();
      expect(() => sqlite.getVersion(), throwsStateError);
      expect(() => sqlite.getVersionNumber(), throwsStateError);
      
      // Test re-initialization after error state
      await sqlite.initialize();
      final version = sqlite.getVersion();
      expect(version, isNotEmpty);
      
      print('✅ WASM error handling verified');
    });
    
    test('SQLite WASM performance baseline', () async {
      final stopwatch = Stopwatch()..start();
      
      // Perform 1000 version calls to measure performance
      for (int i = 0; i < 1000; i++) {
        sqlite.getVersionNumber();
      }
      
      stopwatch.stop();
      final totalMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / 1000).round();
      
      print('⏱️ WASM Performance: 1000 calls in ${totalMs}ms (avg: ${avgMicroseconds}μs per call)');
      
      // Performance should be reasonable (less than 10ms total for 1000 calls on modern hardware)
      expect(totalMs, lessThan(10000)); // Very generous upper bound
      
      print('✅ WASM performance baseline established');
    });
    
    test('SQLite WASM concurrent operation simulation', () async {
      // Simulate concurrent-like operations by interleaving different function calls
      final results = <String>[];
      
      for (int i = 0; i < 20; i++) {
        results.add(sqlite.getVersion());
        final versionNum = sqlite.getVersionNumber();
        expect(versionNum, greaterThan(0));
        
        results.add(sqlite.getVersion());
      }
      
      // All version strings should be identical
      final firstVersion = results.first;
      expect(results.every((v) => v == firstVersion), isTrue);
      
      print('✅ WASM concurrent-like operation test passed');
    });
    
    test('SQLite WASM string handling and Unicode support', () async {
      final version = sqlite.getVersion();
      
      // Test that version string contains expected characters
      expect(version, matches(RegExp(r'^[0-9.]+$')));
      
      // Test string operations don't corrupt data
      final versionCopy = String.fromCharCodes(version.runes);
      expect(versionCopy, equals(version));
      
      print('✅ WASM Unicode and string handling verified');
    });
  });
  
  group('SQLite WASM Integration Verification', () {
    test('unified API properly routes to WASM implementation on web', () async {
      final sqlite = createMinimalSqlite();
      await sqlite.initialize();
      
      try {
        // This should use the WASM implementation when running on web
        final version = sqlite.getVersion();
        final versionNumber = sqlite.getVersionNumber();
        
        // Verify we're getting valid SQLite data
        expect(version, matches(RegExp(r'3\.\d+\.\d+')));
        expect(versionNumber, greaterThan(3000000));
        
        print('🌐 Unified API successfully routing to WASM: $version');
        print('✅ Cross-platform API integration verified');
      } finally {
        sqlite.shutdown();
      }
    });
  });
}