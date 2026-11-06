import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Story presentation identity', () {
    test('canonicalizes stable units independently from source locations', () {
      final eventId = StoryEventId('evt_gate');
      final choiceId = StoryChoiceId('choice_leave');
      final catalog = StoryPresentationIdentityCatalog(
        projectId: StoryProjectId('project_example'),
        units: [
          StoryPresentationUnitRecord(
            unitId: StoryPresentationUnitId('line_z'),
            location: StoryPresentationUnitLocation.choiceText(
              eventId: eventId,
              choiceId: choiceId,
            ),
            sourceRevision: 2,
          ),
          StoryPresentationUnitRecord(
            unitId: StoryPresentationUnitId('line_a'),
            location: StoryPresentationUnitLocation.eventBody(eventId),
            sourceRevision: 7,
          ),
        ],
      );

      expect(catalog.units.map((unit) => unit.unitId.value), [
        'line_a',
        'line_z',
      ]);
      expect(
        catalog
            .unitAt(StoryPresentationUnitLocation.eventBody(eventId))
            ?.sourceRevision,
        7,
      );
    });

    test(
      'rejects duplicate identities, locations, and nonportable revisions',
      () {
        final eventId = StoryEventId('evt_gate');
        final location = StoryPresentationUnitLocation.eventBody(eventId);

        expect(
          () => StoryPresentationIdentityCatalog(
            projectId: StoryProjectId('project_example'),
            units: [
              StoryPresentationUnitRecord(
                unitId: StoryPresentationUnitId('line_same'),
                location: location,
                sourceRevision: 1,
              ),
              StoryPresentationUnitRecord(
                unitId: StoryPresentationUnitId('line_same'),
                location: StoryPresentationUnitLocation.eventTitle(eventId),
                sourceRevision: 1,
              ),
            ],
          ),
          throwsArgumentError,
        );
        expect(
          () => StoryPresentationIdentityCatalog(
            projectId: StoryProjectId('project_example'),
            units: [
              StoryPresentationUnitRecord(
                unitId: StoryPresentationUnitId('line_a'),
                location: location,
                sourceRevision: 1,
              ),
              StoryPresentationUnitRecord(
                unitId: StoryPresentationUnitId('line_b'),
                location: location,
                sourceRevision: 1,
              ),
            ],
          ),
          throwsArgumentError,
        );
        expect(
          () => StoryPresentationUnitRecord(
            unitId: StoryPresentationUnitId('line_bad_revision'),
            location: location,
            sourceRevision: 0,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'reference catalog round-trips through the public deterministic codec',
      () {
        final source = File(
          'conformance/presentation/identity-v1/example.json',
        ).readAsStringSync();
        const codec = StoryPresentationIdentityCatalogCodec();
        final catalog = codec.decode(source);

        expect(catalog.projectId, StoryProjectId('project_example'));
        expect(catalog.units, hasLength(3));
        expect(codec.decode(codec.encode(catalog)).units.length, 3);
        expect(
          codec.encode(catalog),
          source,
          reason: 'The reference vector must already use canonical encoding.',
        );
      },
    );

    test(
      'strict codec rejects choice IDs on non-choice presentation slots',
      () {
        const source = '''
{
  "contract": "open_story.presentation_identity_catalog",
  "contractVersion": 1,
  "projectId": "project_example",
  "units": [
    {
      "unitId": "line_bad",
      "sourceRevision": 1,
      "kind": "event_body",
      "eventId": "evt_gate",
      "choiceId": "choice_wrong"
    }
  ]
}
''';

        expect(
          () => const StoryPresentationIdentityCatalogCodec().decode(source),
          throwsA(isA<StoryPresentationIdentityFormatException>()),
        );
      },
    );
  });
}
