import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 9D5 history A/B isolation benchmark', () {
    test('runner keeps the accepted baseline benchmark untouched', () {
      final baseline = File(
        'benchmark/stage9d5_optimization_baseline.dart',
      ).readAsStringSync();
      final diagnostic = File(
        'benchmark/stage9d5_history_ab_isolation.dart',
      ).readAsStringSync();

      expect(
        baseline,
        contains('story_engine.stage9d5.optimization_baseline.v1'),
      );
      expect(
        diagnostic,
        contains('story_engine.stage9d5.history_ab_isolation.v1'),
      );
      expect(diagnostic, contains('restore_control_combined_large_long'));
      expect(diagnostic, contains("'sharedStateChanges': false"));
      expect(diagnostic, contains('prewarmedProjectPreparation'));
    });

    test('PowerShell runner alternates variants in fresh Dart processes', () {
      final script = File(
        'tool/stage9d5/run_history_ab_isolation.ps1',
      ).readAsStringSync();

      expect(script, contains("@('A','D','B','C')"));
      expect(script, contains("@('C','B','D','A')"));
      expect(
        script,
        contains('dart run benchmark/stage9d5_history_ab_isolation.dart'),
      );
      expect(script, contains('runtimeSourceSha256'));
      expect(script, contains('benchmarkSourceSha256'));
    });
  });
}
