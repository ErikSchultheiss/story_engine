import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  group('Stage 3G presentation and authoring-quality validation', () {
    test('engine-owned Stage 3G diagnostic code tokens stay stable', () {
      expect(
        [
          StoryDiagnosticCode.presentationChoiceMissingText.value,
          StoryDiagnosticCode.presentationEventEmptyText.value,
          StoryDiagnosticCode
              .presentationContinuationWithoutMeaningfulPresentation.value,
          StoryDiagnosticCode
              .presentationAutomaticEventPresentationNotHostVisible.value,
        ],
        [
          'presentation.choice_missing_text',
          'presentation.event_empty_text',
          'presentation.continuation_without_meaningful_presentation',
          'presentation.automatic_event_presentation_not_host_visible',
        ],
      );
    });

    test('choice without presentation text is non-blocking information', () {
      final eventId = StoryEventId('event_choice_without_text');
      final choiceId = StoryChoiceId('choice_without_text');
      final project = StoryProject(
        id: StoryProjectId('project_choice_without_text'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.information.singleWhere(
        (item) =>
            item.code == StoryDiagnosticCode.presentationChoiceMissingText,
      );

      expect(diagnostic.location.choiceId, choiceId);
      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].presentation',
      );
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.choice(choiceId)],
      );
      expect(report.errors, isEmpty);
      expect(report.warnings, isEmpty);
    });

    test('whitespace-only choice text is located at the text field', () {
      final eventId = StoryEventId('event_blank_choice_text');
      final choiceId = StoryChoiceId('choice_blank_text');
      final project = StoryProject(
        id: StoryProjectId('project_blank_choice_text'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: choiceId,
                presentation: const StoryChoicePresentation(
                  text: StoryText('   '),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final diagnostic = StoryValidator.validate(project).information.singleWhere(
        (item) =>
            item.code == StoryDiagnosticCode.presentationChoiceMissingText,
      );

      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].presentation.text',
      );
    });

    test('empty authored event title and body fields are information', () {
      final eventId = StoryEventId('event_empty_presentation_fields');
      final project = StoryProject(
        id: StoryProjectId('project_empty_presentation_fields'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            presentation: StoryEventPresentation(
              title: const StoryText('  '),
              body: const StoryText(''),
            ),
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_visible'),
                presentation: const StoryChoicePresentation(
                  text: StoryText('Continue'),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final diagnostics = StoryValidator.validate(project)
          .information
          .where(
            (item) =>
                item.code == StoryDiagnosticCode.presentationEventEmptyText,
          )
          .toList();

      expect(diagnostics, hasLength(2));
      expect(
        diagnostics.map((item) => item.location.pathString).toList(),
        [
          'events[0].presentation.body',
          'events[0].presentation.title',
        ],
      );
    });

    test('continuation pause without presentation is a warning', () {
      final eventId = StoryEventId('event_blank_continuation');
      final project = StoryProject(
        id: StoryProjectId('project_blank_continuation'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final diagnostic = StoryValidator.validate(project).warnings.singleWhere(
        (item) =>
            item.code == StoryDiagnosticCode
                .presentationContinuationWithoutMeaningfulPresentation,
      );

      expect(diagnostic.location.eventId, eventId);
      expect(diagnostic.location.pathString, 'events[0].presentation');
    });

    test('whitespace continuation presentation is still not meaningful', () {
      final eventId = StoryEventId('event_whitespace_continuation');
      final project = StoryProject(
        id: StoryProjectId('project_whitespace_continuation'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            presentation: StoryEventPresentation(
              title: const StoryText('   '),
            ),
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.warnings.where(
          (item) =>
              item.code == StoryDiagnosticCode
                  .presentationContinuationWithoutMeaningfulPresentation,
        ),
        hasLength(1),
      );
      expect(
        report.information.where(
          (item) =>
              item.code == StoryDiagnosticCode.presentationEventEmptyText,
        ),
        hasLength(1),
      );
    });

    test('meaningful continuation presentation avoids the warning', () {
      final eventId = StoryEventId('event_visible_continuation');
      final project = StoryProject(
        id: StoryProjectId('project_visible_continuation'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            presentation: StoryEventPresentation(
              body: const StoryText('The door opens slowly.'),
            ),
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) =>
              item.code == StoryDiagnosticCode
                  .presentationContinuationWithoutMeaningfulPresentation,
        ),
        isEmpty,
      );
    });

    test('presentation on a valid automatic event warns that it is hidden', () {
      final eventId = StoryEventId('event_hidden_automatic_presentation');
      final project = StoryProject(
        id: StoryProjectId('project_hidden_automatic_presentation'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            presentation: StoryEventPresentation(
              body: const StoryText('The author expects this to be visible.'),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final diagnostic = StoryValidator.validate(project).warnings.singleWhere(
        (item) =>
            item.code == StoryDiagnosticCode
                .presentationAutomaticEventPresentationNotHostVisible,
      );

      expect(diagnostic.location.eventId, eventId);
      expect(diagnostic.location.pathString, 'events[0].presentation');
    });

    test('automatic event without presentation remains valid and quiet', () {
      final eventId = StoryEventId('event_nonprose_automatic');
      final project = StoryProject(
        id: StoryProjectId('project_nonprose_automatic'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(_stage3GDiagnostics(StoryValidator.validate(project)), isEmpty);
    });

    test('ambiguous flow does not guess automatic host visibility', () {
      final eventId = StoryEventId('event_ambiguous_presentation');
      final project = StoryProject(
        id: StoryProjectId('project_ambiguous_presentation'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            presentation: StoryEventPresentation(
              body: const StoryText('Visible only if this becomes a pause.'),
            ),
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_ambiguous_presentation'),
                presentation: const StoryChoicePresentation(
                  text: StoryText('Choose'),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.errors.where(
          (item) =>
              item.code == StoryDiagnosticCode.structureEventAmbiguousFlow,
        ),
        hasLength(1),
      );
      expect(
        report.diagnostics.where(
          (item) =>
              item.code == StoryDiagnosticCode
                  .presentationAutomaticEventPresentationNotHostVisible,
        ),
        isEmpty,
      );
    });

    test('Lantern Mystery has no Stage 3G authoring-quality findings', () {
      final report = StoryValidator.validate(LanternMysteryFixture.buildProject());

      expect(_stage3GDiagnostics(report), isEmpty);
    });

    test('Stage 3G findings remain deterministic across validation runs', () {
      final eventId = StoryEventId('event_presentation_determinism');
      final project = StoryProject(
        id: StoryProjectId('project_presentation_determinism'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            presentation: StoryEventPresentation(
              title: const StoryText(' '),
            ),
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(
        _stage3GDiagnostics(StoryValidator.validate(project)),
        _stage3GDiagnostics(StoryValidator.validate(project)),
      );
    });
  });
}

List<StoryDiagnostic> _stage3GDiagnostics(StoryValidationReport report) =>
    report.diagnostics
        .where((diagnostic) => _stage3GCodes.contains(diagnostic.code))
        .toList();

final _stage3GCodes = <StoryDiagnosticCode>{
  StoryDiagnosticCode.presentationChoiceMissingText,
  StoryDiagnosticCode.presentationEventEmptyText,
  StoryDiagnosticCode.presentationContinuationWithoutMeaningfulPresentation,
  StoryDiagnosticCode.presentationAutomaticEventPresentationNotHostVisible,
};
