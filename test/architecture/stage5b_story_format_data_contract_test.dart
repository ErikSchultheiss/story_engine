import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 5B public Story Format data contract', () {
    test('format identity/version is its own public compatibility axis', () {
      const metadata = StoryFormatMetadata.current();

      expect(metadata.formatId, 'story_engine.story_format');
      expect(metadata.formatVersion, 1);
      expect(StoryFormatMetadata.currentFormatVersion, 1);
    });

    test('format layer is authored-only and execution independent', () {
      final violations = <String>[];
      for (final entity in Directory('lib/src/format').listSync()) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        for (final forbidden in const [
          '../runtime/',
          '../persistence/',
          '../serialization/',
          '../validation/',
          'dart:convert',
          'dart:io',
          'package:flutter/',
        ]) {
          if (source.contains(forbidden)) {
            violations.add('${entity.path}: $forbidden');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'The Stage 5B data contract must remain authored-only and '
            'encoding/layout independent.\n${violations.join('\n')}',
      );
    });

    test('organization vocabulary is generic rather than chapter/section based', () {
      final sources = Directory('lib/src/format')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains("export 'src/format/story_format_group.dart' show"),
      );
      expect(
        barrel,
        contains("export 'src/format/story_format_tag.dart' show"),
      );
      expect(barrel, isNot(contains('story_format_chapter.dart')));
      expect(barrel, isNot(contains('story_format_section.dart')));
      expect(sources, isNot(contains('class StoryFormatChapter')));
      expect(sources, isNot(contains('class StoryFormatSection')));
    });

    test('format document projects explicitly to the runtime authored model', () {
      final project = StoryProject(id: StoryProjectId('project_5b_projection'));
      final document = StoryFormatDocument(
        project: project,
        organization: StoryFormatOrganization(
          tags: [StoryFormatTag(id: StoryFormatTagId('tag_5b'))],
        ),
        extensions: [
          StoryFormatExtensionAttachment(
            namespace: StoryFormatExtensionNamespace('dev.example.meta'),
            target: const StoryFormatProjectExtensionTarget(),
            payload: StoryFormatExtensionPayload({'note': 'authoring-only'}),
          ),
        ],
      );

      expect(document.toStoryProject(), same(project));
      expect(document.organization.isEmpty, isFalse);
      expect(document.extensions, hasLength(1));
    });

    test('5D codec stays separate from the 5B data-contract files', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final formatSources = Directory('lib/src/format')
          .listSync()
          .whereType<File>()
          .map((file) => file.path.split(Platform.pathSeparator).last)
          .toList();

      expect(
        barrel,
        contains("export 'src/format/story_format_bundle_layout.dart' show"),
      );
      expect(
        barrel,
        contains("export 'src/format/codec/story_format_codec.dart' show"),
      );
      expect(formatSources, contains('story_format_bundle_layout.dart'));
      expect(formatSources, isNot(contains('story_format_codec.dart')));
    });
  });
}
