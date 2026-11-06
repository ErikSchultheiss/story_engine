import 'package:story_engine/story_engine.dart';

/// Inspect one independently activated module using the global state schema.
void main() {
  final local = StoryEventId('local');
  final external = StoryEventId('external');
  final project = StoryProject(
    id: StoryProjectId('analysis_example'),
    events: [
      StoryEvent(
        id: local,
        continuationTransition: StoryEventTransition(
          destinationEventId: external,
        ),
      ),
    ],
  );
  final analysis = StoryProjectAnalysis.analyze(project);
  final reference = analysis.outgoingReferences(local).single;
  print(
    '${reference.sourceEventId.value} -> '
    '${reference.destinationEventId.value} @ ${reference.location.pathString}',
  );

  final report = StoryValidator.validate(
    project,
    context: StoryValidationContext.moduleSlice(
      entryEventIds: [local],
      knownExternalEventIds: [external],
    ),
  );
  print('Module validation errors: ${report.errors.length}');

  final graph = analysis.graphFrom([local]);
  print('Reachable local events: ${graph.reachableEventIds.length}');
  print(
    'Incomplete boundary: '
    '${graph.canReachIncompleteBoundaryEventIds.contains(local)}',
  );
}
