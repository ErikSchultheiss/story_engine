import '../identity/story_event_id.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import 'story_project_analysis.dart';
import 'story_diagnostic.dart';
import 'story_diagnostic_code.dart';
import 'story_diagnostic_location.dart';
import 'story_diagnostic_reference.dart';
import 'story_diagnostic_severity.dart';

/// Stage 3F conservative authored control-flow graph validation.
///
/// The graph deliberately over-approximates executable flow: every authored
/// conditional branch, fallback, and weighted option is considered possible.
/// This keeps unreachable-event findings structurally provable without asking
/// runtime evaluators or resolvers to decide which path would execute.
final class StoryGraphValidator {
  const StoryGraphValidator();

  List<StoryDiagnostic> validate(
    StoryProject project, {
    required Iterable<StoryEventId> entryEventIds,
    required StoryProjectAnalysis analysis,
  }) {
    final result = analysis.graphFrom(entryEventIds);
    if (!result.isUnambiguous || result.reachableEventIds.isEmpty) {
      return const [];
    }
    final graph = _GraphData(project, result);
    final reachable = graph.indices(result.reachableEventIds);
    final diagnostics = <StoryDiagnostic>[];

    _addUnreachableDiagnostics(
      project: project,
      graph: graph,
      reachable: reachable,
      diagnostics: diagnostics,
    );

    final cycles = graph.cycles(result.cycles);
    final automaticCycles = graph.cycles(result.automaticCycles);
    final continuationCycles = graph.cycles(result.continuationCycles);
    _addCycleDiagnostics(
      project: project,
      graph: graph,
      cycles: cycles,
      automaticCycles: automaticCycles,
      continuationCycles: continuationCycles,
      diagnostics: diagnostics,
    );

    _addTerminationDiagnostics(
      project: project,
      graph: graph,
      reachable: reachable,
      cycles: cycles,
      diagnostics: diagnostics,
    );

    return diagnostics;
  }

  void _addUnreachableDiagnostics({
    required StoryProject project,
    required _GraphData graph,
    required Set<int> reachable,
    required List<StoryDiagnostic> diagnostics,
  }) {
    for (final node in graph.nodes) {
      if (reachable.contains(node.index)) {
        continue;
      }
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.graphUnreachableEvent,
          severity: StoryDiagnosticSeverity.warning,
          message:
              'Event ${node.event.id.value} is unreachable from the '
              'declared validation entry points through authored transitions.',
          location: _eventLocation(project, node),
          references: [StoryDiagnosticReference.event(node.event.id)],
        ),
      );
    }
  }

  void _addCycleDiagnostics({
    required StoryProject project,
    required _GraphData graph,
    required List<_CycleComponent> cycles,
    required List<_CycleComponent> automaticCycles,
    required List<_CycleComponent> continuationCycles,
    required List<StoryDiagnostic> diagnostics,
  }) {
    for (final cycle in automaticCycles) {
      _addCycleDiagnostic(
        project: project,
        graph: graph,
        cycle: cycle,
        classification: _automaticCycleClassification,
        diagnostics: diagnostics,
      );
    }

    for (final cycle in continuationCycles) {
      _addCycleDiagnostic(
        project: project,
        graph: graph,
        cycle: cycle,
        classification: _continuationCycleClassification,
        diagnostics: diagnostics,
      );
    }

    for (final cycle in cycles) {
      if (cycle.flowKinds.length > 1) {
        _addCycleDiagnostic(
          project: project,
          graph: graph,
          cycle: cycle,
          classification: _mixedCycleClassification,
          diagnostics: diagnostics,
        );
      } else if (cycle.flowKinds.single == StoryAnalysisFlowKind.interactive) {
        _addCycleDiagnostic(
          project: project,
          graph: graph,
          cycle: cycle,
          classification: _interactiveCycleClassification,
          diagnostics: diagnostics,
        );
      }
    }
  }

  void _addCycleDiagnostic({
    required StoryProject project,
    required _GraphData graph,
    required _CycleComponent cycle,
    required _CycleClassification classification,
    required List<StoryDiagnostic> diagnostics,
  }) {
    final orderedIndices = cycle.nodeIndices.toList()..sort();
    final primary = graph.nodes[orderedIndices.first];
    final relatedLocations = <StoryDiagnosticLocation>[
      for (final index in orderedIndices.skip(1))
        _eventLocation(project, graph.nodes[index]),
    ];
    final references = <StoryDiagnosticReference>[
      for (final index in orderedIndices)
        StoryDiagnosticReference.event(graph.nodes[index].event.id),
    ];
    final eventList = orderedIndices
        .map((index) => graph.nodes[index].event.id.value)
        .join(', ');

    diagnostics.add(
      StoryDiagnostic(
        code: classification.code,
        severity: classification.severity,
        message: classification.message(eventList),
        location: _eventLocation(project, primary),
        references: references,
        relatedLocations: relatedLocations,
      ),
    );
  }

  void _addTerminationDiagnostics({
    required StoryProject project,
    required _GraphData graph,
    required Set<int> reachable,
    required List<_CycleComponent> cycles,
    required List<StoryDiagnostic> diagnostics,
  }) {
    final canReachTerminal = graph.indices(
      graph.result.canReachTerminationEventIds,
    );
    final canReachIncompleteBoundary = graph.indices(
      graph.result.canReachIncompleteBoundaryEventIds,
    );

    final cycleMembers = <int>{
      for (final cycle in cycles) ...cycle.nodeIndices,
    };

    for (final cycle in cycles) {
      final orderedIndices = cycle.nodeIndices.toList()..sort();
      final primaryIndex = orderedIndices.first;
      if (canReachTerminal.contains(primaryIndex) ||
          canReachIncompleteBoundary.contains(primaryIndex) ||
          (cycle.flowKinds.length == 1 &&
              cycle.flowKinds.single == StoryAnalysisFlowKind.automatic)) {
        continue;
      }

      final primary = graph.nodes[primaryIndex];
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.graphEventCannotReachTermination,
          severity: StoryDiagnosticSeverity.warning,
          message:
              'Cycle containing ${primary.event.id.value} has no authored '
              'path to an explicit terminal transition.',
          location: _eventLocation(project, primary),
          references: [
            for (final index in orderedIndices)
              StoryDiagnosticReference.event(graph.nodes[index].event.id),
          ],
          relatedLocations: [
            for (final index in orderedIndices.skip(1))
              _eventLocation(project, graph.nodes[index]),
          ],
        ),
      );
    }

    for (final node in graph.nodes) {
      if (!reachable.contains(node.index) ||
          canReachTerminal.contains(node.index) ||
          canReachIncompleteBoundary.contains(node.index) ||
          cycleMembers.contains(node.index) ||
          node.flowKind == null) {
        continue;
      }

      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.graphEventCannotReachTermination,
          severity: StoryDiagnosticSeverity.warning,
          message:
              'Event ${node.event.id.value} has no authored path to an '
              'explicit terminal transition.',
          location: _eventLocation(project, node),
          references: [StoryDiagnosticReference.event(node.event.id)],
        ),
      );
    }
  }
}

StoryDiagnosticLocation _eventLocation(StoryProject project, _GraphNode node) =>
    StoryDiagnosticLocation.event(
      projectId: project.id,
      eventId: node.event.id,
      path: [
        const StoryDiagnosticPathSegment.field('events'),
        StoryDiagnosticPathSegment.index(node.index),
      ],
    );

typedef _CycleClassification = ({
  StoryDiagnosticCode code,
  StoryDiagnosticSeverity severity,
  String Function(String events) message,
});

final _CycleClassification _automaticCycleClassification = (
  code: StoryDiagnosticCode.graphAutomaticCycle,
  severity: StoryDiagnosticSeverity.error,
  message: (String events) =>
      'Reachable automatic cycle contains: $events. '
      'Automatic flow can repeat synchronously until the runtime cycle guard '
      'is reached.',
);

final _CycleClassification _continuationCycleClassification = (
  code: StoryDiagnosticCode.graphContinuationCycle,
  severity: StoryDiagnosticSeverity.warning,
  message: (String events) =>
      'Reachable continuation cycle contains: $events. '
      'Host continuation prevents a synchronous hang, but the loop may still '
      'be unintended.',
);

final _CycleClassification _interactiveCycleClassification = (
  code: StoryDiagnosticCode.graphInteractiveCycle,
  severity: StoryDiagnosticSeverity.information,
  message: (String events) =>
      'Reachable interactive cycle contains: $events. '
      'Interactive loops can be intentional; this is a non-blocking authoring '
      'observation.',
);

final _CycleClassification _mixedCycleClassification = (
  code: StoryDiagnosticCode.graphMixedCycle,
  severity: StoryDiagnosticSeverity.information,
  message: (String events) =>
      'Reachable mixed-flow cycle contains: $events. '
      'Because the cycle includes more than one host-flow mode it is not '
      'classified as a synchronous automatic-cycle error.',
);

final class _GraphNode {
  _GraphNode(this.index, this.event);
  final int index;
  final StoryEvent event;
  StoryAnalysisFlowKind? get flowKind {
    final count =
        (event.choices.isNotEmpty ? 1 : 0) +
        (event.continuationTransition != null ? 1 : 0) +
        (event.automaticTransition != null ? 1 : 0);
    if (count != 1) return null;
    return event.choices.isNotEmpty
        ? StoryAnalysisFlowKind.interactive
        : event.continuationTransition != null
        ? StoryAnalysisFlowKind.continuation
        : StoryAnalysisFlowKind.automatic;
  }
}

final class _CycleComponent {
  _CycleComponent(this.nodeIndices, this.flowKinds);
  final Set<int> nodeIndices;
  final Set<StoryAnalysisFlowKind> flowKinds;
}

final class _GraphData {
  _GraphData(StoryProject project, this.result)
    : nodes = [
        for (var i = 0; i < project.events.length; i++)
          _GraphNode(i, project.events[i]),
      ],
      indexById = {
        for (var i = 0; i < project.events.length; i++) project.events[i].id: i,
      };
  final StoryGraphAnalysis result;
  final List<_GraphNode> nodes;
  final Map<StoryEventId, int> indexById;
  Set<int> indices(Iterable<StoryEventId> ids) => {
    for (final id in ids) indexById[id]!,
  };
  List<_CycleComponent> cycles(Iterable<StoryGraphCycle> values) => [
    for (final c in values) _CycleComponent(indices(c.eventIds), c.flowKinds),
  ];
}
