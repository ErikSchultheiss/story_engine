import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 5C Story Format bundle layout', () {
    test('layout stays public beside the Stage 5D codec', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains("export 'src/format/story_format_bundle_layout.dart' show"),
      );
      expect(
        barrel,
        contains("export 'src/format/codec/story_format_codec.dart' show"),
      );
      expect(
        File('lib/src/format/codec/story_format_codec.dart').existsSync(),
        isTrue,
      );
    });

    test('layout contract stays logical/pure Dart rather than doing filesystem IO', () {
      final source = File(
        'lib/src/format/story_format_bundle_layout.dart',
      ).readAsStringSync();

      for (final forbidden in const [
        'dart:io',
        'dart:convert',
        'File(',
        'Directory(',
        'package:flutter/',
        '../runtime/',
        '../persistence/',
        '../serialization/',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('v1 core layout owns only proven authored-format files', () {
      expect(StoryFormatBundleLayout.projectPath, 'project.json');
      expect(StoryFormatBundleLayout.eventsDirectory, 'events');
      expect(StoryFormatBundleLayout.organizationPath, 'organization.json');
      expect(StoryFormatBundleLayout.extensionsPath, 'extensions.json');

      final source = File(
        'lib/src/format/story_format_bundle_layout.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('localization/')));
      expect(source, isNot(contains('assets/')));
      expect(source, isNot(contains('chapters/')));
      expect(source, isNot(contains('sections/')));
    });

    test('group placement never determines event storage path', () {
      final eventId = StoryEventId('event_stage5c_group_move');
      final path = StoryFormatBundleLayout.eventPath(eventId);

      final first = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_stage5c_group_move'),
          events: [StoryEvent(id: eventId)],
        ),
        organization: StoryFormatOrganization(
          groups: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_stage5c_first'),
              eventIds: [eventId],
            ),
          ],
        ),
      );
      final second = StoryFormatDocument(
        project: first.project,
        organization: StoryFormatOrganization(
          groups: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_stage5c_second'),
              eventIds: [eventId],
            ),
          ],
        ),
      );

      expect(StoryFormatBundleLayout.eventPath(eventId), path);
      expect(
        StoryFormatBundleLayout.canonicalFilePaths(first)
            .where((entry) => entry.startsWith('events/'))
            .toList(),
        StoryFormatBundleLayout.canonicalFilePaths(second)
            .where((entry) => entry.startsWith('events/'))
            .toList(),
      );
    });
  });
}
