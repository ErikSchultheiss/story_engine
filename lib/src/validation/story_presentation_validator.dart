import '../model/story_event.dart';
import '../model/story_project.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Stage 3G non-blocking presentation/authoring-quality validation.
///
/// Presentation remains optional at the engine layer. These diagnostics surface
/// likely authoring mistakes without turning prose/UI assumptions into runtime
/// validity requirements.
final class StoryPresentationValidator {
  const StoryPresentationValidator();

  List<StoryDiagnostic> validate(StoryProject project) {
    final diagnostics = <StoryDiagnostic>[];

    for (var eventIndex = 0; eventIndex < project.events.length; eventIndex++) {
      final event = project.events[eventIndex];
      final eventPath = _eventPath(eventIndex);
      final presentation = event.presentation;

      if (presentation != null) {
        final title = presentation.title;
        if (title != null && !_hasMeaningfulText(title.value)) {
          diagnostics.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.presentationEventEmptyText,
              severity: StoryDiagnosticSeverity.information,
              message: 'Event presentation title is empty or whitespace only.',
              location: StoryDiagnosticLocation.event(
                projectId: project.id,
                eventId: event.id,
                path: [
                  ...eventPath,
                  const StoryDiagnosticPathSegment.field('presentation'),
                  const StoryDiagnosticPathSegment.field('title'),
                ],
              ),
              references: [StoryDiagnosticReference.event(event.id)],
            ),
          );
        }

        final body = presentation.body;
        if (body != null && !_hasMeaningfulText(body.value)) {
          diagnostics.add(
            StoryDiagnostic(
              code: StoryDiagnosticCode.presentationEventEmptyText,
              severity: StoryDiagnosticSeverity.information,
              message: 'Event presentation body is empty or whitespace only.',
              location: StoryDiagnosticLocation.event(
                projectId: project.id,
                eventId: event.id,
                path: [
                  ...eventPath,
                  const StoryDiagnosticPathSegment.field('presentation'),
                  const StoryDiagnosticPathSegment.field('body'),
                ],
              ),
              references: [StoryDiagnosticReference.event(event.id)],
            ),
          );
        }
      }

      final hasChoices = event.choices.isNotEmpty;
      final hasContinuation = event.continuationTransition != null;
      final hasAutomatic = event.automaticTransition != null;
      final validContinuation = !hasChoices && hasContinuation && !hasAutomatic;
      final validAutomatic = !hasChoices && !hasContinuation && hasAutomatic;

      if (validContinuation && !_eventHasMeaningfulPresentation(event)) {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode
                .presentationContinuationWithoutMeaningfulPresentation,
            severity: StoryDiagnosticSeverity.warning,
            message:
                'Continuation event pauses for the host but has no '
                'meaningful presentation title or body.',
            location: StoryDiagnosticLocation.event(
              projectId: project.id,
              eventId: event.id,
              path: [
                ...eventPath,
                const StoryDiagnosticPathSegment.field('presentation'),
              ],
            ),
            references: [StoryDiagnosticReference.event(event.id)],
          ),
        );
      }

      if (validAutomatic && presentation != null) {
        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode
                .presentationAutomaticEventPresentationNotHostVisible,
            severity: StoryDiagnosticSeverity.warning,
            message:
                'Automatic event presentation is never host-visible '
                'because automatic flow resolves synchronously.',
            location: StoryDiagnosticLocation.event(
              projectId: project.id,
              eventId: event.id,
              path: [
                ...eventPath,
                const StoryDiagnosticPathSegment.field('presentation'),
              ],
            ),
            references: [StoryDiagnosticReference.event(event.id)],
          ),
        );
      }

      for (
        var choiceIndex = 0;
        choiceIndex < event.choices.length;
        choiceIndex++
      ) {
        final choice = event.choices[choiceIndex];
        final choicePresentation = choice.presentation;
        if (choicePresentation != null &&
            _hasMeaningfulText(choicePresentation.text.value)) {
          continue;
        }

        diagnostics.add(
          StoryDiagnostic(
            code: StoryDiagnosticCode.presentationChoiceMissingText,
            severity: StoryDiagnosticSeverity.information,
            message: choicePresentation == null
                ? 'Interactive choice has no default presentation text.'
                : 'Interactive choice presentation text is empty or '
                      'whitespace only.',
            location: StoryDiagnosticLocation.choice(
              projectId: project.id,
              eventId: event.id,
              choiceId: choice.id,
              path: [
                ..._choicePath(eventIndex, choiceIndex),
                const StoryDiagnosticPathSegment.field('presentation'),
                if (choicePresentation != null)
                  const StoryDiagnosticPathSegment.field('text'),
              ],
            ),
            references: [StoryDiagnosticReference.choice(choice.id)],
          ),
        );
      }
    }

    return diagnostics;
  }
}

bool _eventHasMeaningfulPresentation(StoryEvent event) {
  final presentation = event.presentation;
  if (presentation == null) {
    return false;
  }
  return (presentation.title != null &&
          _hasMeaningfulText(presentation.title!.value)) ||
      (presentation.body != null &&
          _hasMeaningfulText(presentation.body!.value));
}

bool _hasMeaningfulText(String value) => value.trim().isNotEmpty;

List<StoryDiagnosticPathSegment> _eventPath(int eventIndex) =>
    <StoryDiagnosticPathSegment>[
      const StoryDiagnosticPathSegment.field('events'),
      StoryDiagnosticPathSegment.index(eventIndex),
    ];

List<StoryDiagnosticPathSegment> _choicePath(int eventIndex, int choiceIndex) =>
    <StoryDiagnosticPathSegment>[
      const StoryDiagnosticPathSegment.field('events'),
      StoryDiagnosticPathSegment.index(eventIndex),
      const StoryDiagnosticPathSegment.field('choices'),
      StoryDiagnosticPathSegment.index(choiceIndex),
    ];
