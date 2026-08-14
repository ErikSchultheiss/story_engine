import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 5A Story Format design gate', () {
    test('later Story Format layers preserve the original 5A public boundary', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains("export 'src/format/story_format_document.dart' show"),
      );
      expect(barrel, isNot(contains('serialization/')));
      expect(barrel, isNot(contains('StoryProjectDraftCodec')));
      expect(barrel, isNot(contains('StoryDraftSerializationException')));
      expect(
        barrel,
        contains("export 'src/format/story_format_bundle_layout.dart' show"),
      );
      expect(
        barrel,
        contains("export 'src/format/codec/story_format_codec.dart' show"),
      );
    });

    test('withdrawn section vocabulary remains outside the public barrel', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(barrel, isNot(contains('story_section.dart')));
      expect(barrel, isNot(contains('story_section_id.dart')));
      expect(barrel, isNot(contains('StorySection')));
      expect(barrel, isNot(contains('StorySectionId')));
    });

    test('internal draft codec remains explicitly revision 3 evidence', () {
      final source = File(
        'lib/src/serialization/story_project_draft_codec.dart',
      ).readAsStringSync();

      expect(source, contains("documentType = 'story_engine_project_draft'"));
      expect(source, contains('draftRevision = 3'));
      expect(source, contains('oldestSupportedDraftRevision = 1'));
      expect(source, isNot(contains('StoryFormatV1')));
    });

    test('authored draft and runtime snapshot document identities stay separate', () {
      final draftSource = File(
        'lib/src/serialization/story_project_draft_codec.dart',
      ).readAsStringSync();
      final snapshotSource = File(
        'lib/src/persistence/story_runtime_snapshot_codec.dart',
      ).readAsStringSync();

      expect(draftSource, contains('story_engine_project_draft'));
      expect(draftSource, isNot(contains('story_engine_runtime_snapshot')));
      expect(snapshotSource, contains('story_engine_runtime_snapshot'));
      expect(snapshotSource, isNot(contains('story_engine_project_draft')));
    });

    test('current authored model preserves explicit event and choice order', () {
      final eventA = StoryEventId('event_stage5a_a');
      final eventB = StoryEventId('event_stage5a_b');
      final firstChoice = StoryChoiceId('choice_stage5a_first');
      final secondChoice = StoryChoiceId('choice_stage5a_second');

      final project = StoryProject(
        id: StoryProjectId('project_stage5a_order'),
        entryEventId: eventB,
        events: [
          StoryEvent(
            id: eventB,
            choices: [
              StoryChoice(
                id: secondChoice,
                transition: const StoryTerminalTransition(),
              ),
              StoryChoice(
                id: firstChoice,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
          StoryEvent(
            id: eventA,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(project.events.map((event) => event.id).toList(), [eventB, eventA]);
      expect(
        project.events.first.choices.map((choice) => choice.id).toList(),
        [secondChoice, firstChoice],
      );
    });

    test('incomplete authored work stays constructible before validation', () {
      final project = StoryProject(
        id: StoryProjectId('project_stage5a_incomplete'),
        events: [
          StoryEvent(
            id: StoryEventId('event_stage5a_incomplete'),
            choices: [
              StoryChoice(id: StoryChoiceId('choice_stage5a_incomplete')),
            ],
          ),
        ],
      );

      final document = StoryFormatDocument(project: project);
      final report = StoryValidator.validate(document.toStoryProject());

      expect(document.project.entryEventId, isNull);
      expect(report.errors, isNotEmpty);
    });

    test('5D adds the public codec without reviving draft serialization', () {
      expect(Directory('lib/src/format').existsSync(), isTrue);
      expect(File('lib/src/format/story_format_document.dart').existsSync(), isTrue);
      expect(
        File('lib/src/format/story_format_bundle_layout.dart').existsSync(),
        isTrue,
      );
      expect(
        File('lib/src/format/codec/story_format_codec.dart').existsSync(),
        isTrue,
      );
      expect(File('lib/src/format/story_format_codec.dart').existsSync(), isFalse);
    });
  });
}
