import 'package:story_engine/src/format/codec/story_format_migrations.dart';
import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryFormatMigrationPipeline', () {
    test('applies deterministic consecutive bundle migrations', () {
      final pipeline = StoryFormatMigrationPipeline(
        steps: const [_Migration1To2(), _Migration2To3()],
      );
      final original = StoryFormatBundle(
        files: const {
          'project.json': '{"formatVersion":1}',
          'events/legacy.json': '{"legacy":true}',
        },
      );

      final first = pipeline.migrate(
        bundle: original,
        fromVersion: 1,
        toVersion: 3,
      );
      final second = pipeline.migrate(
        bundle: original,
        fromVersion: 1,
        toVersion: 3,
      );

      expect(first, second);
      expect(original.file('project.json'), '{"formatVersion":1}');
      expect(first.file('project.json'), '{"formatVersion":3}');
      expect(first.file('migration-1-to-2.json'), '{"migrated":true}');
      expect(first.file('migration-2-to-3.json'), '{"migrated":true}');
    });

    test('reports incomplete migration paths before attempting them', () {
      final pipeline = StoryFormatMigrationPipeline(
        steps: const [_Migration1To2()],
      );

      expect(
        pipeline.canMigrate(fromVersion: 1, toVersion: 3),
        isFalse,
      );
      expect(
        () => pipeline.migrate(
          bundle: StoryFormatBundle(
            files: const {'project.json': '{"formatVersion":1}'},
          ),
          fromVersion: 1,
          toVersion: 3,
        ),
        throwsStateError,
      );
    });

    test('rejects non-consecutive and duplicate step registrations', () {
      expect(
        () => StoryFormatMigrationPipeline(
          steps: const [_Migration1To3()],
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryFormatMigrationPipeline(
          steps: const [_Migration1To2(), _Migration1To2()],
        ),
        throwsArgumentError,
      );
    });

    test('built-in pipeline contains no fictional pre-v1 migration', () {
      final pipeline = StoryFormatMigrationPipeline.builtIn();

      expect(
        pipeline.canMigrate(fromVersion: 1, toVersion: 2),
        isFalse,
      );
      expect(
        pipeline.canMigrate(fromVersion: 1, toVersion: 1),
        isTrue,
      );
    });
  });
}

final class _Migration1To2 implements StoryFormatMigrationStep {
  const _Migration1To2();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  StoryFormatBundle migrate(StoryFormatBundle bundle) => StoryFormatBundle(
    files: {
      ...bundle.files,
      'project.json': '{"formatVersion":2}',
      'migration-1-to-2.json': '{"migrated":true}',
    },
  );
}

final class _Migration2To3 implements StoryFormatMigrationStep {
  const _Migration2To3();

  @override
  int get fromVersion => 2;

  @override
  int get toVersion => 3;

  @override
  StoryFormatBundle migrate(StoryFormatBundle bundle) => StoryFormatBundle(
    files: {
      ...bundle.files,
      'project.json': '{"formatVersion":3}',
      'migration-2-to-3.json': '{"migrated":true}',
    },
  );
}

final class _Migration1To3 implements StoryFormatMigrationStep {
  const _Migration1To3();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 3;

  @override
  StoryFormatBundle migrate(StoryFormatBundle bundle) => bundle;
}
