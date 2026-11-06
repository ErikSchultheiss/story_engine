import '../identity/story_event_id.dart';
import '../model/story_project.dart';
import 'story_project_analysis.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Complete static reference validation using the shared authored-tree index.
final class StoryReferenceValidator {
  const StoryReferenceValidator();
  List<StoryDiagnostic> validate(
    StoryProject project, {
    required StoryProjectAnalysis analysis,
    Set<StoryEventId> knownExternalEventIds = const {},
  }) {
    final eventIds = {
      ...project.events.map((event) => event.id),
      ...knownExternalEventIds,
    };
    return [
      for (final reference in analysis.eventReferences)
        if (!eventIds.contains(reference.destinationEventId))
          StoryDiagnostic(
            code: StoryDiagnosticCode.referenceMissingTransitionDestination,
            severity: StoryDiagnosticSeverity.error,
            message:
                'Transition destination does not exist: ${reference.destinationEventId.value}.',
            location: reference.location,
            references: [
              StoryDiagnosticReference.event(reference.destinationEventId),
            ],
          ),
      for (final use in analysis.variableUses)
        if (!project.stateSchema.contains(use.variableId))
          StoryDiagnostic(
            code: use.writesValue
                ? StoryDiagnosticCode.referenceUndeclaredEffectVariable
                : StoryDiagnosticCode.referenceUndeclaredConditionVariable,
            severity: StoryDiagnosticSeverity.error,
            message: use.writesValue
                ? 'Effect references undeclared variable: ${use.variableId.value}.'
                : 'Condition references undeclared variable: ${use.variableId.value}.',
            location: use.location,
            references: [StoryDiagnosticReference.variable(use.variableId)],
          ),
    ];
  }
}
