import 'dart:io';

import 'package:test/test.dart';

/// Explicit test-first implementation gates for Stage 9A.
///
/// This file intentionally lives outside default `dart test` discovery. Run it
/// explicitly during Stage 9A development. All tests are expected to be red
/// immediately after 9A1 and to turn green at the noted implementation stage.
/// After Stage 9A5 all three implementation gates are expected to be green;
/// the `RED until ...` names are retained as stage-provenance documentation.
void main() {
  group('Stage 9A expected-red aggregate persistence implementation gates', () {
    test('RED until 9A2: aggregate snapshot model is public', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains('StoryNarrativeRuntimeSnapshot'),
        reason: 'Stage 9A2 must add the immutable aggregate snapshot model.',
      );
    });

    test('RED until 9A4: aggregate snapshot codec is public', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains('StoryNarrativeRuntimeSnapshotCodec'),
        reason:
            'Stage 9A4 must add the deterministic aggregate snapshot codec.',
      );
    });

    test('RED until 9A5: runtime exposes aggregate capture and restore', () {
      final source = File(
        'lib/src/orchestration/story_narrative_runtime.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('StoryNarrativeRuntimeSnapshot createSnapshot()'),
        reason: 'Stage 9A5 must capture the complete orchestration runtime.',
      );
      expect(
        source,
        contains('factory StoryNarrativeRuntime.restore('),
        reason: 'Stage 9A5 must restore without replaying normal activation.',
      );
    });
  });
}
