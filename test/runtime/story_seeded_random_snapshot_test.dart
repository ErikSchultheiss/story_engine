import 'package:story_engine/src/runtime/story_seeded_random_source.dart';
import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StorySeededRandomSource snapshot contract', () {
    test('lcg32 v1 reference vector is stable', () {
      final source = StorySeededRandomSource.fromSeed(42);
      final bounds = <int>[
        1,
        2,
        3,
        7,
        10,
        65537,
        4294967295,
        StoryIntegerValue.maxPortableValue,
      ];

      final actual = [for (final bound in bounds) source.nextInt(bound)];

      expect(
        actual,
        [0, 0, 2, 2, 0, 52948, 3701641493, 5135024634160890],
      );
      expect(
        source.createRuntimeState(),
        StoryRuntimeRandomState(
          algorithmId: 'story_engine.lcg32',
          algorithmVersion: 1,
          stateWords: const [42, 389768954],
        ),
      );
    });

    test('lcg32 v1 seed reference vectors stay stable', () {
      final expectedBySeed = <int, List<int>>{
        0: [2, 3, 6, 3, 6, 6, 6, 2],
        1: [6, 2, 3, 0, 0, 0, 1, 3],
        42: [1, 3, 2, 2, 1, 4, 5, 0],
        4294967295: [5, 4, 2, 2, 1, 1, 1, 4],
      };

      for (final entry in expectedBySeed.entries) {
        final source = StorySeededRandomSource.fromSeed(entry.key);
        final actual = [for (var index = 0; index < 8; index++) source.nextInt(7)];
        expect(actual, entry.value, reason: 'seed ${entry.key}');
      }
    });

    test('persisted current state includes rejection-sampling consumption', () {
      final source = StorySeededRandomSource.fromSeed(3);

      // For this bound and seed, the first exact-53 candidate is rejected.
      // The accepted result therefore consumes four uint32 LCG steps rather
      // than the normal two. Persisting only a logical "draw count" or seed
      // without the actual current state would be insufficient here.
      final sampled = source.nextInt(4503599627370497);

      expect(sampled, 2276713969420775);
      expect(
        source.createRuntimeState().stateWords,
        const [3, 3345418727],
      );
    });

    test('restored source continues the exact future sequence', () {
      final uninterrupted = StorySeededRandomSource.fromSeed(4294967295);
      for (final bound in const [7, 13, 997, 65537, 1000003]) {
        uninterrupted.nextInt(bound);
      }
      final saved = uninterrupted.createRuntimeState();
      final restored = StorySeededRandomSource.restoreRuntimeState(saved);

      final futureBounds = <int>[
        2,
        3,
        17,
        1009,
        4294967295,
        4503599627370497,
        StoryIntegerValue.maxPortableValue,
      ];

      for (final bound in futureBounds) {
        expect(restored.nextInt(bound), uninterrupted.nextInt(bound));
        expect(restored.createRuntimeState(), uninterrupted.createRuntimeState());
      }
    });

    test('frozen v1 state shape rejects wrong word count and range', () {
      expect(
        () => StorySeededRandomSource.validateRuntimeState(
          StoryRuntimeRandomState(
            algorithmId: StorySeededRandomSource.runtimeStateAlgorithmId,
            algorithmVersion:
                StorySeededRandomSource.runtimeStateAlgorithmVersion,
            stateWords: const [1],
          ),
        ),
        throwsA(isA<StorySeededRandomStateException>()),
      );
      expect(
        () => StorySeededRandomSource.validateRuntimeState(
          StoryRuntimeRandomState(
            algorithmId: StorySeededRandomSource.runtimeStateAlgorithmId,
            algorithmVersion:
                StorySeededRandomSource.runtimeStateAlgorithmVersion,
            stateWords: const [1, 4294967296],
          ),
        ),
        throwsA(isA<StorySeededRandomStateException>()),
      );
    });
  });
}
