import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 4B runtime snapshot persistence boundary', () {
    test('runtime persistence adapter is separate from authored serialization', () {
      final codec = File(
        'lib/src/persistence/story_runtime_snapshot_codec.dart',
      ).readAsStringSync();
      final migrations = File(
        'lib/src/persistence/story_runtime_snapshot_migrations.dart',
      ).readAsStringSync();

      expect(codec, isNot(contains('StoryProjectDraftCodec')));
      expect(codec, isNot(contains('story_project_draft_codec.dart')));
      expect(migrations, isNot(contains('StoryProjectDraftCodec')));
      expect(migrations, isNot(contains('story_project_draft_codec.dart')));
    });

    test('runtime/domain code never depends on persistence adapters', () {
      final violations = <String>[];
      for (final entity in Directory('lib/src').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized.contains('/lib/src/persistence/')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (RegExp(
          r'''(?:import|export)\s+['"][^'"]*persistence/''',
        ).hasMatch(source)) {
          violations.add(entity.path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Snapshot persistence is an adapter leaf; runtime values and '
            'execution must not depend on JSON/storage representation.\n'
            '${violations.join('\n')}',
      );
    });

    test('persistence production code stays platform and Studio independent', () {
      final violations = <String>[];
      for (final entity in Directory(
        'lib/src/persistence',
      ).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        for (final forbidden in const [
          'package:flutter/',
          'package:cyoa_studio/',
          'dart:io',
          'dart:ui',
          'dart:html',
          'timetwirlers',
          'time_twirlers',
        ]) {
          if (source.toLowerCase().contains(forbidden.toLowerCase())) {
            violations.add('${entity.path}: $forbidden');
          }
        }
      }

      expect(violations, isEmpty);
    });

    test('snapshot codec does not duplicate authored schema definitions', () {
      final source = File(
        'lib/src/persistence/story_runtime_snapshot_codec.dart',
      ).readAsStringSync();

      expect(source, contains("'variableId'"));
      expect(source, isNot(contains("'stateSchema'")));
      expect(source, isNot(contains("'initialValue'")));
      expect(source, isNot(contains("'alias'")));
    });
  });
}
