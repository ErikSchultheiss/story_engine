import 'package:story_engine/src/persistence/story_runtime_snapshot_migrations.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeSnapshotMigrationPipeline', () {
    test('applies deterministic consecutive N -> N+1 migrations', () {
      final pipeline = StoryRuntimeSnapshotMigrationPipeline(
        steps: const [_Migration1To2(), _Migration2To3()],
      );
      final original = <String, Object?>{
        'formatVersion': 1,
        'payload': 'original',
      };

      final migrated = pipeline.migrate(
        document: original,
        fromVersion: 1,
        toVersion: 3,
      );

      expect(original['formatVersion'], 1);
      expect(original, isNot(contains('migrated1')));
      expect(migrated['formatVersion'], 3);
      expect(migrated['migrated1'], true);
      expect(migrated['migrated2'], true);
    });

    test('reports incomplete migration paths before attempting them', () {
      final pipeline = StoryRuntimeSnapshotMigrationPipeline(
        steps: const [_Migration1To2()],
      );

      expect(
        pipeline.canMigrate(fromVersion: 1, toVersion: 3),
        isFalse,
      );
      expect(
        () => pipeline.migrate(
          document: const {'formatVersion': 1},
          fromVersion: 1,
          toVersion: 3,
        ),
        throwsStateError,
      );
    });

    test('rejects non-consecutive and duplicate migration registrations', () {
      expect(
        () => StoryRuntimeSnapshotMigrationPipeline(
          steps: const [_Migration1To3()],
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryRuntimeSnapshotMigrationPipeline(
          steps: const [_Migration1To2(), _Migration1To2()],
        ),
        throwsArgumentError,
      );
    });
  });
}

final class _Migration1To2 implements StoryRuntimeSnapshotMigrationStep {
  const _Migration1To2();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  Map<String, Object?> migrate(Map<String, Object?> document) =>
      <String, Object?>{
        ...document,
        'formatVersion': 2,
        'migrated1': true,
      };
}

final class _Migration2To3 implements StoryRuntimeSnapshotMigrationStep {
  const _Migration2To3();

  @override
  int get fromVersion => 2;

  @override
  int get toVersion => 3;

  @override
  Map<String, Object?> migrate(Map<String, Object?> document) =>
      <String, Object?>{
        ...document,
        'formatVersion': 3,
        'migrated2': true,
      };
}

final class _Migration1To3 implements StoryRuntimeSnapshotMigrationStep {
  const _Migration1To3();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 3;

  @override
  Map<String, Object?> migrate(Map<String, Object?> document) => document;
}
