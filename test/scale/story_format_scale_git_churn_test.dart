import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../support/synthetic_story_project_generator.dart';

void main() {
  const codec = StoryFormatCodec();
  group('Stage 5G Story Format scale and determinism', () {
    test('structured 100/500/1000-event profiles round-trip canonically', () {
      const expectations = <SyntheticStoryProfile, ({int events, int choices})>{
        SyntheticStoryProfile.small: (events: 100, choices: 389),
        SyntheticStoryProfile.medium: (events: 500, choices: 1949),
        SyntheticStoryProfile.large: (events: 1000, choices: 4876),
      };

      for (final entry in expectations.entries) {
        final fixture = SyntheticStoryProjectGenerator.structured(entry.key);
        final document = StoryFormatDocument(project: fixture.project);

        final encodeWatch = Stopwatch()..start();
        final firstBundle = codec.encode(document);
        encodeWatch.stop();

        final decodeWatch = Stopwatch()..start();
        final decoded = codec.decode(firstBundle);
        decodeWatch.stop();

        final secondBundle = codec.encode(decoded);
        final repeatedBundle = codec.encode(document);
        final report = StoryValidator.validate(decoded.project);

        expect(fixture.metrics.eventCount, entry.value.events);
        expect(fixture.metrics.choiceCount, entry.value.choices);
        expect(firstBundle.files, hasLength(entry.value.events + 1));
        expect(secondBundle, firstBundle, reason: entry.key.name);
        expect(repeatedBundle, firstBundle, reason: entry.key.name);
        expect(report.errors, isEmpty, reason: entry.key.name);

        final byteCount = firstBundle.files.values.fold<int>(
          0,
          (total, source) => total + utf8.encode(source).length,
        );

        // Stage 5G observes realistic local/CI cost without making machine-
        // specific wall-clock budgets part of Story Format v1.
        // ignore: avoid_print
        print(
          'Stage 5G Story Format observation: ${entry.key.name} '
          '${entry.value.events} events / ${entry.value.choices} choices -> '
          '${firstBundle.files.length} files / $byteCount bytes; '
          'encode ${encodeWatch.elapsedMicroseconds} us, '
          'decode ${decodeWatch.elapsedMicroseconds} us',
        );
      }
    });

    test('12 randomized projects have deterministic independent encodings', () {
      for (var seed = 0; seed < 12; seed++) {
        final firstFixture = SyntheticStoryProjectGenerator.randomized(
          seed: seed,
        );
        final secondFixture = SyntheticStoryProjectGenerator.randomized(
          seed: seed,
        );

        final first = codec.encode(
          StoryFormatDocument(project: firstFixture.project),
        );
        final independentlyRegenerated = codec.encode(
          StoryFormatDocument(project: secondFixture.project),
        );
        final decoded = codec.decode(first);
        final reencoded = codec.encode(decoded);

        expect(independentlyRegenerated, first, reason: 'seed $seed');
        expect(reencoded, first, reason: 'seed $seed');
        expect(
          StoryValidator.validate(decoded.project).errors,
          isEmpty,
          reason: 'seed $seed',
        );
      }
    });
  });

  group('Stage 5G bounded Git churn', () {
    test('editing one event presentation changes only that event file', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final middle = beforeDocument.project.events[1];
      final editedMiddle = _copyEvent(
        middle,
        alias: StoryAlias('middle_event_renamed'),
        presentation: StoryEventPresentation(
          title: const StoryText('Middle renamed'),
          body: const StoryText('Only this event file should change.'),
        ),
      );
      final after = codec.encode(
        _withEvents(beforeDocument, [
          beforeDocument.project.events[0],
          editedMiddle,
          beforeDocument.project.events[2],
        ]),
      );

      expect(
        _changedPaths(before, after),
        {StoryFormatBundleLayout.eventPath(middle.id)},
      );
    });

    test('editing one choice presentation changes only its owning event file', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final first = beforeDocument.project.events.first;
      final choice = first.choices.single;
      final editedChoice = StoryChoice(
        id: choice.id,
        alias: choice.alias,
        presentation: const StoryChoicePresentation(
          text: StoryText('Continue through the renamed door'),
        ),
        availabilityCondition: choice.availabilityCondition,
        effects: choice.effects,
        transition: choice.transition,
      );
      final editedFirst = _copyEvent(first, choices: [editedChoice]);
      final after = codec.encode(
        _withEvents(beforeDocument, [
          editedFirst,
          ...beforeDocument.project.events.skip(1),
        ]),
      );

      expect(
        _changedPaths(before, after),
        {StoryFormatBundleLayout.eventPath(first.id)},
      );
    });

    test('reordering events changes only project.json', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final events = beforeDocument.project.events;
      final after = codec.encode(
        _withEvents(beforeDocument, [events[2], events[0], events[1]]),
      );

      expect(_changedPaths(before, after), {StoryFormatBundleLayout.projectPath});
    });

    test('renaming project alias changes only project.json', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final after = codec.encode(
        StoryFormatDocument(
          project: StoryProject(
            id: beforeDocument.project.id,
            alias: StoryAlias('git_churn_project_renamed'),
            stateSchema: beforeDocument.project.stateSchema,
            events: beforeDocument.project.events,
            entryEventId: beforeDocument.project.entryEventId,
          ),
          organization: beforeDocument.organization,
          extensions: beforeDocument.extensions,
        ),
      );

      expect(_changedPaths(before, after), {StoryFormatBundleLayout.projectPath});
    });

    test('moving and renaming groups changes only organization.json', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final ids = beforeDocument.project.events.map((event) => event.id).toList();
      final tag = beforeDocument.organization.tags.single;
      final after = codec.encode(
        StoryFormatDocument(
          project: beforeDocument.project,
          organization: StoryFormatOrganization(
            groups: [
              StoryFormatGroup(
                id: StoryFormatGroupId('group_main'),
                alias: StoryAlias('main_group_renamed'),
                label: const StoryText('Main group renamed'),
                eventIds: [ids[0]],
                children: [
                  StoryFormatGroup(
                    id: StoryFormatGroupId('group_tail'),
                    alias: StoryAlias('tail_group'),
                    label: const StoryText('Later events'),
                    eventIds: [ids[1], ids[2]],
                  ),
                ],
              ),
            ],
            tags: [tag],
          ),
          extensions: beforeDocument.extensions,
        ),
      );

      expect(
        _changedPaths(before, after),
        {StoryFormatBundleLayout.organizationPath},
      );
      for (final event in beforeDocument.project.events) {
        expect(
          StoryFormatBundleLayout.eventPath(event.id),
          before.files.keys.singleWhere(
            (path) => path == StoryFormatBundleLayout.eventPath(event.id),
          ),
        );
      }
    });

    test('changing tag membership changes only organization.json', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final ids = beforeDocument.project.events.map((event) => event.id).toList();
      final after = codec.encode(
        StoryFormatDocument(
          project: beforeDocument.project,
          organization: StoryFormatOrganization(
            groups: beforeDocument.organization.groups,
            tags: [
              StoryFormatTag(
                id: StoryFormatTagId('tag_focus'),
                alias: StoryAlias('focus'),
                label: const StoryText('Focus'),
                eventIds: [ids[1], ids[2]],
              ),
            ],
          ),
          extensions: beforeDocument.extensions,
        ),
      );

      expect(
        _changedPaths(before, after),
        {StoryFormatBundleLayout.organizationPath},
      );
    });

    test('changing opaque extension payload changes only extensions.json', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final after = codec.encode(
        StoryFormatDocument(
          project: beforeDocument.project,
          organization: beforeDocument.organization,
          extensions: [
            StoryFormatExtensionAttachment(
              namespace: StoryFormatExtensionNamespace(
                'com.example.editor_notes',
              ),
              target: const StoryFormatProjectExtensionTarget(),
              payload: StoryFormatExtensionPayload(<String, Object?>{
                'note': 'changed without touching story semantics',
                'revision': 2,
              }),
            ),
          ],
        ),
      );

      expect(
        _changedPaths(before, after),
        {StoryFormatBundleLayout.extensionsPath},
      );
    });

    test('adding one event changes only project.json plus the new event file', () {
      final beforeDocument = _churnBaseline();
      final before = codec.encode(beforeDocument);
      final added = StoryEvent(
        id: StoryEventId('event_added'),
        alias: StoryAlias('added_event'),
        presentation: StoryEventPresentation(
          title: const StoryText('Added'),
          body: const StoryText('New independent authored event.'),
        ),
        continuationTransition: const StoryTerminalTransition(),
      );
      final after = codec.encode(
        _withEvents(beforeDocument, [...beforeDocument.project.events, added]),
      );

      expect(
        _changedPaths(before, after),
        {
          StoryFormatBundleLayout.projectPath,
          StoryFormatBundleLayout.eventPath(added.id),
        },
      );
    });
  });
}

StoryFormatDocument _churnBaseline() {
  final startId = StoryEventId('event_start');
  final middleId = StoryEventId('event_middle');
  final endId = StoryEventId('event_end');

  return StoryFormatDocument(
    project: StoryProject(
      id: StoryProjectId('project_git_churn'),
      alias: StoryAlias('git_churn_project'),
      entryEventId: startId,
      events: [
        StoryEvent(
          id: startId,
          alias: StoryAlias('start_event'),
          presentation: StoryEventPresentation(
            title: const StoryText('Start'),
            body: const StoryText('Start body.'),
          ),
          choices: [
            StoryChoice(
              id: StoryChoiceId('choice_start_continue'),
              alias: StoryAlias('continue_from_start'),
              presentation: const StoryChoicePresentation(
                text: StoryText('Continue'),
              ),
              transition: StoryEventTransition(destinationEventId: middleId),
            ),
          ],
        ),
        StoryEvent(
          id: middleId,
          alias: StoryAlias('middle_event'),
          presentation: StoryEventPresentation(
            title: const StoryText('Middle'),
            body: const StoryText('Middle body.'),
          ),
          continuationTransition: StoryEventTransition(destinationEventId: endId),
        ),
        StoryEvent(
          id: endId,
          alias: StoryAlias('end_event'),
          presentation: StoryEventPresentation(
            title: const StoryText('End'),
            body: const StoryText('End body.'),
          ),
          continuationTransition: const StoryTerminalTransition(),
        ),
      ],
    ),
    organization: StoryFormatOrganization(
      groups: [
        StoryFormatGroup(
          id: StoryFormatGroupId('group_main'),
          alias: StoryAlias('main_group'),
          label: const StoryText('Main group'),
          eventIds: [startId, middleId],
          children: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_tail'),
              alias: StoryAlias('tail_group'),
              label: const StoryText('Tail'),
              eventIds: [endId],
            ),
          ],
        ),
      ],
      tags: [
        StoryFormatTag(
          id: StoryFormatTagId('tag_focus'),
          alias: StoryAlias('focus'),
          label: const StoryText('Focus'),
          eventIds: [startId, endId],
        ),
      ],
    ),
    extensions: [
      StoryFormatExtensionAttachment(
        namespace: StoryFormatExtensionNamespace('com.example.editor_notes'),
        target: const StoryFormatProjectExtensionTarget(),
        payload: StoryFormatExtensionPayload(<String, Object?>{
          'note': 'baseline',
          'revision': 1,
        }),
      ),
    ],
  );
}

StoryEvent _copyEvent(
  StoryEvent source, {
  StoryAlias? alias,
  StoryEventPresentation? presentation,
  Iterable<StoryChoice>? choices,
}) => StoryEvent(
  id: source.id,
  alias: alias ?? source.alias,
  presentation: presentation ?? source.presentation,
  availabilityCondition: source.availabilityCondition,
  entryEffects: source.entryEffects,
  choices: choices ?? source.choices,
  continuationTransition: source.continuationTransition,
  automaticTransition: source.automaticTransition,
);

StoryFormatDocument _withEvents(
  StoryFormatDocument source,
  Iterable<StoryEvent> events,
) => StoryFormatDocument(
  project: StoryProject(
    id: source.project.id,
    alias: source.project.alias,
    stateSchema: source.project.stateSchema,
    events: events,
    entryEventId: source.project.entryEventId,
  ),
  organization: source.organization,
  extensions: source.extensions,
);

Set<String> _changedPaths(StoryFormatBundle before, StoryFormatBundle after) {
  final paths = <String>{...before.files.keys, ...after.files.keys};
  return {
    for (final path in paths)
      if (before.files[path] != after.files[path]) path,
  };
}
