import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../model/story_project.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';
import 'story_validation_context.dart';

/// Stage 3B structural/identity validation over representable authored data.
///
/// This rule collector deliberately does not duplicate constructor invariants
/// such as machine-ID syntax, alias syntax, or state-schema uniqueness.
final class StoryStructuralValidator {
  const StoryStructuralValidator();

  List<StoryDiagnostic> validate(
    StoryProject project, {
    required StoryValidationContext context,
  }) {
    final diagnostics = <StoryDiagnostic>[];

    _validateEntryEvent(project, diagnostics, context);
    final eventIds = project.events.map((event) => event.id).toSet();
    for (final root in context.entryEventIds) {
      if (root == project.entryEventId ||
          eventIds.contains(root) ||
          context.knownExternalEventIds.contains(root)) {
        continue;
      }
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.structureValidationEntryNotFound,
          severity: StoryDiagnosticSeverity.error,
          message: 'Validation entry event does not exist: ${root.value}.',
          location: StoryDiagnosticLocation.project(projectId: project.id),
          references: [StoryDiagnosticReference.event(root)],
        ),
      );
    }
    _validateEventIdentityAndFlow(project, diagnostics);
    _validateChoiceIdentityAndCompleteness(project, diagnostics);

    return diagnostics;
  }

  void _validateEntryEvent(
    StoryProject project,
    List<StoryDiagnostic> diagnostics,
    StoryValidationContext context,
  ) {
    final entryEventId = project.entryEventId;
    final location = StoryDiagnosticLocation.project(
      projectId: project.id,
      path: const [StoryDiagnosticPathSegment.field('entryEventId')],
    );

    if (entryEventId == null) {
      if (!context.requiresDefaultEntry) return;
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.structureMissingEntryEvent,
          severity: StoryDiagnosticSeverity.error,
          message: 'Project has no entry event.',
          location: location,
        ),
      );
      return;
    }

    final hasMatchingEvent = project.events.any(
      (event) => event.id == entryEventId,
    );
    if (!hasMatchingEvent &&
        !context.knownExternalEventIds.contains(entryEventId)) {
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.structureEntryEventNotFound,
          severity: StoryDiagnosticSeverity.error,
          message: 'Project entry event does not exist: ${entryEventId.value}.',
          location: location,
          references: [StoryDiagnosticReference.event(entryEventId)],
        ),
      );
    }
  }

  void _validateEventIdentityAndFlow(
    StoryProject project,
    List<StoryDiagnostic> diagnostics,
  ) {
    final firstById = <StoryEventId, StoryDiagnosticLocation>{};

    for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
      final event = project.events[eventIndex];
      final eventLocation = StoryDiagnosticLocation.event(
        projectId: project.id,
        eventId: event.id,
        path: _eventPath(eventIndex),
      );

      final firstLocation = firstById[event.id];
      if (firstLocation == null) {
        firstById[event.id] = eventLocation;
      } else {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.identityDuplicateEventId,
            severity: StoryDiagnosticSeverity.error,
            message: 'Event ID is duplicated: ${event.id.value}.',
            location: eventLocation,
            references: [StoryDiagnosticReference.event(event.id)],
            relatedLocations: [firstLocation],
          ),
        );
      }

      final hasChoices = event.choices.isNotEmpty;
      final hasContinuation = event.continuationTransition != null;
      final hasAutomatic = event.automaticTransition != null;
      final flowModeCount =
          (hasChoices ? 1 : 0) +
          (hasContinuation ? 1 : 0) +
          (hasAutomatic ? 1 : 0);

      if (flowModeCount == 0) {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.structureEventMissingFlow,
            severity: StoryDiagnosticSeverity.error,
            message:
                'Event has no flow. Add choices, a continuation '
                'transition, or an automatic transition.',
            location: eventLocation,
            references: [StoryDiagnosticReference.event(event.id)],
          ),
        );
      } else if (flowModeCount > 1) {
        final activeModes = <String>[
          if (hasChoices) 'choices',
          if (hasContinuation) 'continuation transition',
          if (hasAutomatic) 'automatic transition',
        ];
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.structureEventAmbiguousFlow,
            severity: StoryDiagnosticSeverity.error,
            message:
                'Event defines multiple flow modes: '
                '${activeModes.join(', ')}. Exactly one is allowed.',
            location: eventLocation,
            references: [StoryDiagnosticReference.event(event.id)],
          ),
        );
      }
    }
  }

  void _validateChoiceIdentityAndCompleteness(
    StoryProject project,
    List<StoryDiagnostic> diagnostics,
  ) {
    final firstById = <StoryChoiceId, StoryDiagnosticLocation>{};

    for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
      final event = project.events[eventIndex];
      for (
        var choiceIndex = 0;
        choiceIndex < event.choices.length;
        choiceIndex++
      ) {
        final choice = event.choices[choiceIndex];
        final choiceLocation = StoryDiagnosticLocation.choice(
          projectId: project.id,
          eventId: event.id,
          choiceId: choice.id,
          path: _choicePath(eventIndex, choiceIndex),
        );

        final firstLocation = firstById[choice.id];
        if (firstLocation == null) {
          firstById[choice.id] = choiceLocation;
        } else {
          diagnostics.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.identityDuplicateChoiceId,
              severity: StoryDiagnosticSeverity.error,
              message: 'Choice ID is duplicated: ${choice.id.value}.',
              location: choiceLocation,
              references: [StoryDiagnosticReference.choice(choice.id)],
              relatedLocations: [firstLocation],
            ),
          );
        }

        if (choice.transition == null) {
          diagnostics.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.structureChoiceMissingTransition,
              severity: StoryDiagnosticSeverity.error,
              message: 'Choice has no transition.',
              location: StoryDiagnosticLocation.choice(
                projectId: project.id,
                eventId: event.id,
                choiceId: choice.id,
                path: _choicePath(eventIndex, choiceIndex, field: 'transition'),
              ),
              references: [StoryDiagnosticReference.choice(choice.id)],
            ),
          );
        }
      }
    }
  }
}

List<StoryDiagnosticPathSegment> _eventPath(int eventIndex, {String? field}) =>
    <StoryDiagnosticPathSegment>[
      const StoryDiagnosticPathSegment.field('events'),
      StoryDiagnosticPathSegment.index(eventIndex),
      if (field != null) StoryDiagnosticPathSegment.field(field),
    ];

List<StoryDiagnosticPathSegment> _choicePath(
  int eventIndex,
  int choiceIndex, {
  String? field,
}) => <StoryDiagnosticPathSegment>[
  const StoryDiagnosticPathSegment.field('events'),
  StoryDiagnosticPathSegment.index(eventIndex),
  const StoryDiagnosticPathSegment.field('choices'),
  StoryDiagnosticPathSegment.index(choiceIndex),
  if (field != null) StoryDiagnosticPathSegment.field(field),
];
