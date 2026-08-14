import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';
import '../support/story_format_fixture_loader.dart';

void main() {
  const codec = StoryFormatCodec();
  group('Story Format v1 canonical fixture corpus', () {
    for (final fixtureName in const [
      'minimal',
      'lantern_mystery',
      'incomplete_editor',
      'structured_large',
      'migration_source_v1',
    ]) {
      test('$fixtureName decode -> encode is byte-for-byte canonical', () {
        final golden = loadStoryFormatFixture(fixtureName);
        final decoded = codec.decode(golden);
        final encoded = codec.encode(decoded);

        expect(encoded, golden);
      });
    }

    test('minimal fixture matches the smallest programmatic document', () {
      final expected = codec.encode(
        StoryFormatDocument(
          project: StoryProject(id: StoryProjectId('fixture_minimal')),
        ),
      );

      expect(loadStoryFormatFixture('minimal'), expected);
    });

    test('Lantern Mystery golden matches the canonical semantic fixture', () {
      final expected = codec.encode(
        StoryFormatDocument(project: LanternMysteryFixture.buildProject()),
      );
      final golden = loadStoryFormatFixture('lantern_mystery');

      expect(golden, expected);

      final decoded = codec.decode(golden);
      final report = StoryValidator.validate(decoded.project);
      expect(report.errors, isEmpty);
    });

    test('incomplete-editor golden remains reopenable and diagnosable', () {
      final decoded = codec.decode(loadStoryFormatFixture('incomplete_editor'));
      final report = StoryValidator.validate(decoded.project);
      final codes = report.errors.map((item) => item.code).toSet();

      expect(decoded.project.events, hasLength(1));
      expect(decoded.project.entryEventId, isNull);
      expect(
        codes,
        containsAll({
          StoryDiagnosticCode.structureMissingEntryEvent,
          StoryDiagnosticCode.structureChoiceMissingTransition,
        }),
      );
      expect(
        decoded.organization.groups.single.eventIds,
        contains(StoryEventId('event_missing_001')),
      );
    });

    test('structured-large golden fixes a 100-event / 99-choice profile', () {
      final expected = codec.encode(_structuredLargeDocument());
      final golden = loadStoryFormatFixture('structured_large');
      final decoded = codec.decode(golden);

      expect(golden, expected);
      expect(decoded.project.events, hasLength(100));
      expect(
        decoded.project.events.fold<int>(
          0,
          (count, event) => count + event.choices.length,
        ),
        99,
      );
      expect(StoryValidator.validate(decoded.project).errors, isEmpty);
    });

    test('migration-source fixture is genuine current Story Format v1', () {
      final golden = loadStoryFormatFixture('migration_source_v1');
      final decoded = codec.decode(golden);

      expect(decoded.metadata.formatId, StoryFormatMetadata.currentFormatId);
      expect(
        decoded.metadata.formatVersion,
        StoryFormatMetadata.currentFormatVersion,
      );
      expect(decoded.project.id, StoryProjectId('fixture_migration_v1'));
      expect(decoded.organization.groups, hasLength(1));
      expect(decoded.organization.tags, hasLength(1));
      expect(decoded.extensions, hasLength(1));
      expect(codec.encode(decoded), golden);
    });
  });
}

StoryFormatDocument _structuredLargeDocument() {
  final ids = [
    for (var index = 0; index < 100; index++)
      StoryEventId('event_structured_${index.toString().padLeft(4, '0')}'),
  ];

  return StoryFormatDocument(
    project: StoryProject(
      id: StoryProjectId('fixture_structured_large'),
      alias: StoryAlias('structured_large'),
      entryEventId: ids.first,
      events: [
        for (var index = 0; index < ids.length; index++)
          if (index < ids.length - 1)
            StoryEvent(
              id: ids[index],
              alias: StoryAlias(
                'structured_${index.toString().padLeft(4, '0')}',
              ),
              presentation: StoryEventPresentation(
                title: StoryText(
                  'Structured Event ${index.toString().padLeft(4, '0')}',
                ),
                body: StoryText(
                  'Deterministic structured fixture event '
                  '${index.toString().padLeft(4, '0')}.',
                ),
              ),
              choices: [
                StoryChoice(
                  id: StoryChoiceId(
                    'choice_structured_${index.toString().padLeft(4, '0')}',
                  ),
                  presentation: const StoryChoicePresentation(
                    text: StoryText('Continue'),
                  ),
                  transition: StoryEventTransition(
                    destinationEventId: ids[index + 1],
                  ),
                ),
              ],
            )
          else
            StoryEvent(
              id: ids[index],
              alias: StoryAlias(
                'structured_${index.toString().padLeft(4, '0')}',
              ),
              presentation: StoryEventPresentation(
                title: StoryText(
                  'Structured Event ${index.toString().padLeft(4, '0')}',
                ),
                body: const StoryText(
                  'Deterministic structured fixture terminal event.',
                ),
              ),
              continuationTransition: const StoryTerminalTransition(),
            ),
      ],
    ),
  );
}
