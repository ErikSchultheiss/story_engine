import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 5F canonical fixtures and migration architecture', () {
    test('canonical Story Format v1 fixture corpus is committed', () {
      for (final fixture in const [
        'minimal',
        'lantern_mystery',
        'incomplete_editor',
        'structured_large',
        'migration_source_v1',
      ]) {
        expect(
          File('test/fixtures/story_format_v1/$fixture/project.json').existsSync(),
          isTrue,
          reason: fixture,
        );
      }
    });

    test('migration source is v1 and no fictional v0 fixture exists', () {
      final source = File(
        'test/fixtures/story_format_v1/migration_source_v1/project.json',
      ).readAsStringSync();

      expect(source, contains('"formatVersion": 1'));
      expect(
        Directory('test/fixtures/story_format_v1/migration_source_v0').existsSync(),
        isFalse,
      );
    });

    test('codec owns an internal built-in migration gate before v1 decode', () {
      final codecSource = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();
      final migrationSource = File(
        'lib/src/format/codec/story_format_migrations.dart',
      ).readAsStringSync();
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(codecSource, contains('StoryFormatMigrationPipeline.builtIn()'));
      expect(codecSource, contains('_migrateToCurrent(bundle)'));
      expect(
        codecSource.indexOf('_migrateToCurrent(bundle)'),
        lessThan(codecSource.indexOf('_decodeProjectManifest(')),
      );
      expect(migrationSource, contains('fromVersion + 1'));
      expect(
        barrel,
        isNot(contains('story_format_migrations.dart')),
        reason: 'Core Story Format migrations remain package-owned.',
      );
    });

    test('Story Format migrations stay authored-format-only', () {
      final source = File(
        'lib/src/format/codec/story_format_migrations.dart',
      ).readAsStringSync();

      for (final forbidden in const [
        '../runtime/',
        '../persistence/',
        '../serialization/',
        '../validation/',
        'package:flutter/',
        'StoryRuntimeSnapshot',
        'TimeTwirlers',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
