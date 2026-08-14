import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 3B structural and identity validation', () {
    test('engine-owned Stage 3B diagnostic code tokens stay stable', () {
      expect(
        [
          StoryDiagnosticCode.structureMissingEntryEvent.value,
          StoryDiagnosticCode.structureEntryEventNotFound.value,
          StoryDiagnosticCode.identityDuplicateEventId.value,
          StoryDiagnosticCode.identityDuplicateChoiceId.value,
          StoryDiagnosticCode.structureChoiceMissingTransition.value,
          StoryDiagnosticCode.structureEventMissingFlow.value,
          StoryDiagnosticCode.structureEventAmbiguousFlow.value,
        ],
        [
          'structure.missing_entry_event',
          'structure.entry_event_not_found',
          'identity.duplicate_event_id',
          'identity.duplicate_choice_id',
          'structure.choice_missing_transition',
          'structure.event_missing_flow',
          'structure.event_ambiguous_flow',
        ],
      );
    });

    test('missing project entry event is an error without crashing', () {
      final project = StoryProject(
        id: StoryProjectId('project_missing_entry'),
        events: [
          StoryEvent(
            id: StoryEventId('event_only'),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.structureMissingEntryEvent,
      );
      expect(diagnostic.location.kind, StoryDiagnosticLocationKind.project);
      expect(diagnostic.location.pathString, 'entryEventId');
      expect(diagnostic.references, isEmpty);
      expect(report.isValid, isFalse);
    });

    test('entry event ID that resolves nowhere carries missing ID reference', () {
      final missingId = StoryEventId('event_missing');
      final project = StoryProject(
        id: StoryProjectId('project_bad_entry_reference'),
        entryEventId: missingId,
        events: [
          StoryEvent(
            id: StoryEventId('event_other'),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.structureEntryEventNotFound,
      );
      expect(diagnostic.location.pathString, 'entryEventId');
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.event(missingId)],
      );
    });

    test('valid interactive, continuation, and automatic events pass 3B', () {
      final interactiveId = StoryEventId('event_interactive');
      final continuationId = StoryEventId('event_continuation');
      final automaticId = StoryEventId('event_automatic');
      final project = StoryProject(
        id: StoryProjectId('project_valid_flow_modes'),
        entryEventId: interactiveId,
        events: [
          StoryEvent(
            id: interactiveId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_continue'),
                transition: StoryEventTransition(
                  destinationEventId: continuationId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: continuationId,
            continuationTransition: StoryEventTransition(
              destinationEventId: automaticId,
            ),
          ),
          StoryEvent(
            id: automaticId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(_isStage3BDiagnostic),
        isEmpty,
      );
      expect(report.isValid, isTrue);
    });

    test('duplicate event ID flags each later occurrence and points to first', () {
      final duplicateId = StoryEventId('event_duplicate');
      final project = StoryProject(
        id: StoryProjectId('project_duplicate_events'),
        entryEventId: duplicateId,
        events: [
          StoryEvent(
            id: duplicateId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: duplicateId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: duplicateId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final duplicates = report.errors
          .where(
            (diagnostic) =>
                diagnostic.code == StoryDiagnosticCode.identityDuplicateEventId,
          )
          .toList();

      expect(duplicates, hasLength(2));
      expect(duplicates[0].location.pathString, 'events[1]');
      expect(duplicates[1].location.pathString, 'events[2]');
      for (final diagnostic in duplicates) {
        expect(
          diagnostic.references,
          [StoryDiagnosticReference.event(duplicateId)],
        );
        expect(diagnostic.relatedLocations, hasLength(1));
        expect(diagnostic.relatedLocations.single.pathString, 'events[0]');
      }
    });

    test('choice IDs are unique across the whole project', () {
      final firstEventId = StoryEventId('event_first');
      final secondEventId = StoryEventId('event_second');
      final duplicateChoiceId = StoryChoiceId('choice_duplicate');
      final project = StoryProject(
        id: StoryProjectId('project_duplicate_choices'),
        entryEventId: firstEventId,
        events: [
          StoryEvent(
            id: firstEventId,
            choices: [
              StoryChoice(
                id: duplicateChoiceId,
                transition: StoryEventTransition(
                  destinationEventId: secondEventId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: secondEventId,
            choices: [
              StoryChoice(
                id: duplicateChoiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.errors.singleWhere(
        (candidate) =>
            candidate.code == StoryDiagnosticCode.identityDuplicateChoiceId,
      );

      expect(diagnostic.location.pathString, 'events[1].choices[0]');
      expect(diagnostic.location.eventId, secondEventId);
      expect(diagnostic.location.choiceId, duplicateChoiceId);
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.choice(duplicateChoiceId)],
      );
      expect(diagnostic.relatedLocations, hasLength(1));
      expect(
        diagnostic.relatedLocations.single.pathString,
        'events[0].choices[0]',
      );
    });

    test('interactive choice without transition is diagnosed as incomplete', () {
      final eventId = StoryEventId('event_incomplete_choice');
      final choiceId = StoryChoiceId('choice_incomplete');
      final project = StoryProject(
        id: StoryProjectId('project_incomplete_choice'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [StoryChoice(id: choiceId)],
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.structureChoiceMissingTransition,
      );
      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].transition',
      );
      expect(diagnostic.location.eventId, eventId);
      expect(diagnostic.location.choiceId, choiceId);
    });

    test('event with no flow is diagnosed as structurally incomplete', () {
      final eventId = StoryEventId('event_no_flow');
      final project = StoryProject(
        id: StoryProjectId('project_no_flow'),
        entryEventId: eventId,
        events: [StoryEvent(id: eventId)],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.structureEventMissingFlow,
      );
      expect(diagnostic.location.pathString, 'events[0]');
      expect(diagnostic.location.eventId, eventId);
    });

    for (final scenario in <({
      String name,
      bool choices,
      bool continuation,
      bool automatic,
    })>[
      (
        name: 'choices + continuation',
        choices: true,
        continuation: true,
        automatic: false,
      ),
      (
        name: 'choices + automatic',
        choices: true,
        continuation: false,
        automatic: true,
      ),
      (
        name: 'continuation + automatic',
        choices: false,
        continuation: true,
        automatic: true,
      ),
      (
        name: 'all three modes',
        choices: true,
        continuation: true,
        automatic: true,
      ),
    ]) {
      test('${scenario.name} is one ambiguous-flow error', () {
        final eventId = StoryEventId(
          'event_${scenario.name.replaceAll(' ', '_').replaceAll('+', 'and')}',
        );
        final project = StoryProject(
          id: StoryProjectId(
            'project_${scenario.name.replaceAll(' ', '_').replaceAll('+', 'and')}',
          ),
          entryEventId: eventId,
          events: [
            StoryEvent(
              id: eventId,
              choices: scenario.choices
                  ? [
                      StoryChoice(
                        id: StoryChoiceId('choice_finish'),
                        transition: const StoryTerminalTransition(),
                      ),
                    ]
                  : const [],
              continuationTransition: scenario.continuation
                  ? const StoryTerminalTransition()
                  : null,
              automaticTransition: scenario.automatic
                  ? const StoryTerminalTransition()
                  : null,
            ),
          ],
        );

        final report = StoryValidator.validate(project);

        expect(report.errors, hasLength(1));
        expect(
          report.errors.single.code,
          StoryDiagnosticCode.structureEventAmbiguousFlow,
        );
        expect(report.errors.single.location.pathString, 'events[0]');
      });
    }

    test('event and choice alias uniqueness is not invented by Stage 3B', () {
      final firstEventId = StoryEventId('event_alias_first');
      final secondEventId = StoryEventId('event_alias_second');
      final project = StoryProject(
        id: StoryProjectId('project_alias_scope'),
        entryEventId: firstEventId,
        events: [
          StoryEvent(
            id: firstEventId,
            alias: StoryAlias('shared_event_alias'),
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_alias_first'),
                alias: StoryAlias('shared_choice_alias'),
                transition: StoryEventTransition(
                  destinationEventId: secondEventId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: secondEventId,
            alias: StoryAlias('shared_event_alias'),
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_alias_second'),
                alias: StoryAlias('shared_choice_alias'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      expect(
        StoryValidator.validate(project)
            .diagnostics
            .where(_isStage3BDiagnostic),
        isEmpty,
      );
    });

    test('diagnostics are deterministic across repeated validation', () {
      final eventId = StoryEventId('event_repeatable');
      final project = StoryProject(
        id: StoryProjectId('project_repeatable'),
        entryEventId: StoryEventId('event_missing_repeatable'),
        events: [
          StoryEvent(
            id: eventId,
            choices: [StoryChoice(id: StoryChoiceId('choice_missing'))],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final first = StoryValidator.validate(project);
      final second = StoryValidator.validate(project);

      expect(second.diagnostics, first.diagnostics);
      expect(
        first.diagnostics
            .where(_isStage3BDiagnostic)
            .map((diagnostic) => diagnostic.code.value),
        [
          'structure.entry_event_not_found',
          'structure.event_ambiguous_flow',
          'structure.choice_missing_transition',
        ],
      );
    });
  });
}

bool _isStage3BDiagnostic(StoryDiagnostic diagnostic) =>
    diagnostic.code.value.startsWith('structure.') ||
    diagnostic.code.value.startsWith('identity.');
