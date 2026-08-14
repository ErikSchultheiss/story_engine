import '../identity/story_event_id.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../transition/story_transition.dart';
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

  List<StoryDiagnostic> validate(StoryProject project) {
    final graph = _GraphData.build(project);
    if (graph == null) {
      // Duplicate event IDs make graph destinations ambiguous. Stage 3B owns
      // that structural error, so Stage 3F avoids unsound graph claims.
      return const [];
    }

    final entryEventId = project.entryEventId;
    if (entryEventId == null) {
      return const [];
    }
    final entryIndex = graph.indexById[entryEventId];
    if (entryIndex == null) {
      return const [];
    }

    final reachable = graph.reachableFrom(entryIndex);
    final diagnostics = <StoryDiagnostic>[];

    _addUnreachableDiagnostics(
      project: project,
      graph: graph,
      reachable: reachable,
      diagnostics: diagnostics,
    );

    final cycles = graph.reachableCycles(reachable);
    final automaticCycles = graph.reachableCycles(
      reachable,
      onlyFlowKind: _FlowKind.automatic,
    );
    final continuationCycles = graph.reachableCycles(
      reachable,
      onlyFlowKind: _FlowKind.continuation,
    );
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
          message: 'Event ${node.event.id.value} is unreachable from the '
              'project entry event through authored transitions.',
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
      } else if (cycle.flowKinds.single == _FlowKind.interactive) {
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
    final canReachTerminal = graph.reverseReachableFrom(
      {
        for (final node in graph.nodes)
          if (reachable.contains(node.index) && node.hasTerminal)
            node.index,
      },
      allowed: reachable,
    );

    // Incomplete flow or unresolved destinations already have precise Stage
    // 3B/3C diagnostics. Do not infer permanent non-termination through those
    // boundaries because the authored project is explicitly unfinished there.
    final canReachIncompleteBoundary = graph.reverseReachableFrom(
      {
        for (final node in graph.nodes)
          if (reachable.contains(node.index) && node.hasIncompleteBoundary)
            node.index,
      },
      allowed: reachable,
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
              cycle.flowKinds.single == _FlowKind.automatic)) {
        continue;
      }

      final primary = graph.nodes[primaryIndex];
      diagnostics.add(
        StoryDiagnostic(
          code: StoryDiagnosticCode.graphEventCannotReachTermination,
          severity: StoryDiagnosticSeverity.warning,
          message: 'Cycle containing ${primary.event.id.value} has no authored '
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
          message: 'Event ${node.event.id.value} has no authored path to an '
              'explicit terminal transition.',
          location: _eventLocation(project, node),
          references: [StoryDiagnosticReference.event(node.event.id)],
        ),
      );
    }
  }
}

StoryDiagnosticLocation _eventLocation(
  StoryProject project,
  _GraphNode node,
) => StoryDiagnosticLocation.event(
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
  message: (String events) => 'Reachable automatic cycle contains: $events. '
      'Automatic flow can repeat synchronously until the runtime cycle guard '
      'is reached.',
);

final _CycleClassification _continuationCycleClassification = (
  code: StoryDiagnosticCode.graphContinuationCycle,
  severity: StoryDiagnosticSeverity.warning,
  message: (String events) => 'Reachable continuation cycle contains: $events. '
      'Host continuation prevents a synchronous hang, but the loop may still '
      'be unintended.',
);

final _CycleClassification _interactiveCycleClassification = (
  code: StoryDiagnosticCode.graphInteractiveCycle,
  severity: StoryDiagnosticSeverity.information,
  message: (String events) => 'Reachable interactive cycle contains: $events. '
      'Interactive loops can be intentional; this is a non-blocking authoring '
      'observation.',
);

final _CycleClassification _mixedCycleClassification = (
  code: StoryDiagnosticCode.graphMixedCycle,
  severity: StoryDiagnosticSeverity.information,
  message: (String events) => 'Reachable mixed-flow cycle contains: $events. '
      'Because the cycle includes more than one host-flow mode it is not '
      'classified as a synchronous automatic-cycle error.',
);

enum _FlowKind { interactive, continuation, automatic }

final class _GraphEdge {
  const _GraphEdge({required this.destinationEventId, required this.flowKind});

  final StoryEventId destinationEventId;
  final _FlowKind flowKind;
}

final class _GraphNode {
  _GraphNode({
    required this.index,
    required this.event,
    required this.flowKind,
  });

  final int index;
  final StoryEvent event;
  final _FlowKind? flowKind;
  final List<_GraphEdge> edges = [];
  bool hasTerminal = false;
  bool hasIncompleteBoundary = false;
}

final class _CycleComponent {
  const _CycleComponent({required this.nodeIndices, required this.flowKinds});

  final Set<int> nodeIndices;
  final Set<_FlowKind> flowKinds;
}

final class _GraphData {
  _GraphData._({required this.nodes, required this.indexById});

  static _GraphData? build(StoryProject project) {
    final indexById = <StoryEventId, int>{};
    for (var index = 0; index < project.events.length; index++) {
      final eventId = project.events[index].id;
      if (indexById.containsKey(eventId)) {
        return null;
      }
      indexById[eventId] = index;
    }

    final nodes = <_GraphNode>[];
    for (var index = 0; index < project.events.length; index++) {
      final event = project.events[index];
      final flowKind = _flowKind(event);
      final node = _GraphNode(index: index, event: event, flowKind: flowKind);
      nodes.add(node);

      if (flowKind == null) {
        node.hasIncompleteBoundary = true;
      }

      // Reachability uses every authored transition even when an event is
      // temporarily ambiguous. That prevents an already-authored destination
      // from being mislabeled unreachable merely because Stage 3B also needs
      // the author to choose one exclusive flow mode. Cycle/termination claims
      // still exclude such malformed source events below.
      for (final choice in event.choices) {
        final transition = choice.transition;
        if (transition == null) {
          node.hasIncompleteBoundary = true;
          continue;
        }
        _collectTransition(
          transition: transition,
          flowKind: _FlowKind.interactive,
          node: node,
          indexById: indexById,
        );
      }

      final continuationTransition = event.continuationTransition;
      if (continuationTransition != null) {
        _collectTransition(
          transition: continuationTransition,
          flowKind: _FlowKind.continuation,
          node: node,
          indexById: indexById,
        );
      }

      final automaticTransition = event.automaticTransition;
      if (automaticTransition != null) {
        _collectTransition(
          transition: automaticTransition,
          flowKind: _FlowKind.automatic,
          node: node,
          indexById: indexById,
        );
      }
    }

    return _GraphData._(nodes: nodes, indexById: indexById);
  }

  final List<_GraphNode> nodes;
  final Map<StoryEventId, int> indexById;

  Set<int> reachableFrom(int entryIndex) {
    final reachable = <int>{entryIndex};
    final queue = <int>[entryIndex];
    var cursor = 0;

    while (cursor < queue.length) {
      final sourceIndex = queue[cursor++];
      for (final edge in nodes[sourceIndex].edges) {
        final destinationIndex = indexById[edge.destinationEventId];
        if (destinationIndex != null && reachable.add(destinationIndex)) {
          queue.add(destinationIndex);
        }
      }
    }

    return reachable;
  }

  Set<int> reverseReachableFrom(
    Set<int> seeds, {
    required Set<int> allowed,
  }) {
    final reverse = <int, List<int>>{};
    for (final source in allowed) {
      for (final edge in nodes[source].edges) {
        final destination = indexById[edge.destinationEventId];
        if (destination == null || !allowed.contains(destination)) {
          continue;
        }
        reverse.putIfAbsent(destination, () => []).add(source);
      }
    }

    final reached = <int>{...seeds.where(allowed.contains)};
    final queue = reached.toList()..sort();
    var cursor = 0;
    while (cursor < queue.length) {
      final current = queue[cursor++];
      for (final predecessor in reverse[current] ?? const <int>[]) {
        if (reached.add(predecessor)) {
          queue.add(predecessor);
        }
      }
    }
    return reached;
  }

  List<_CycleComponent> reachableCycles(
    Set<int> reachable, {
    _FlowKind? onlyFlowKind,
  }) {
    final index = <int, int>{};
    final lowLink = <int, int>{};
    final stack = <int>[];
    final onStack = <int>{};
    final components = <Set<int>>[];
    var nextIndex = 0;

    void strongConnect(int nodeIndex) {
      index[nodeIndex] = nextIndex;
      lowLink[nodeIndex] = nextIndex;
      nextIndex++;
      stack.add(nodeIndex);
      onStack.add(nodeIndex);

      for (final edge in nodes[nodeIndex].edges) {
        if (nodes[nodeIndex].flowKind == null ||
            (onlyFlowKind != null && edge.flowKind != onlyFlowKind)) {
          continue;
        }
        final destination = indexById[edge.destinationEventId];
        if (destination == null || !reachable.contains(destination)) {
          continue;
        }
        if (!index.containsKey(destination)) {
          strongConnect(destination);
          final childLow = lowLink[destination]!;
          if (childLow < lowLink[nodeIndex]!) {
            lowLink[nodeIndex] = childLow;
          }
        } else if (onStack.contains(destination)) {
          final destinationIndex = index[destination]!;
          if (destinationIndex < lowLink[nodeIndex]!) {
            lowLink[nodeIndex] = destinationIndex;
          }
        }
      }

      if (lowLink[nodeIndex] != index[nodeIndex]) {
        return;
      }

      final component = <int>{};
      while (true) {
        final popped = stack.removeLast();
        onStack.remove(popped);
        component.add(popped);
        if (popped == nodeIndex) {
          break;
        }
      }
      components.add(component);
    }

    final orderedReachable = reachable.toList()..sort();
    for (final nodeIndex in orderedReachable) {
      if (!index.containsKey(nodeIndex)) {
        strongConnect(nodeIndex);
      }
    }

    final cycles = <_CycleComponent>[];
    for (final component in components) {
      final flowKinds = <_FlowKind>{};
      var hasCycle = component.length > 1;
      for (final source in component) {
        for (final edge in nodes[source].edges) {
          if (nodes[source].flowKind == null ||
              (onlyFlowKind != null && edge.flowKind != onlyFlowKind)) {
            continue;
          }
          final destination = indexById[edge.destinationEventId];
          if (destination == null || !component.contains(destination)) {
            continue;
          }
          hasCycle = true;
          flowKinds.add(edge.flowKind);
        }
      }
      if (hasCycle && flowKinds.isNotEmpty) {
        cycles.add(
          _CycleComponent(nodeIndices: component, flowKinds: flowKinds),
        );
      }
    }

    cycles.sort((left, right) {
      final leftMin = left.nodeIndices.reduce((a, b) => a < b ? a : b);
      final rightMin = right.nodeIndices.reduce((a, b) => a < b ? a : b);
      return leftMin.compareTo(rightMin);
    });
    return cycles;
  }
}

_FlowKind? _flowKind(StoryEvent event) {
  final hasChoices = event.choices.isNotEmpty;
  final hasContinuation = event.continuationTransition != null;
  final hasAutomatic = event.automaticTransition != null;
  final count =
      (hasChoices ? 1 : 0) + (hasContinuation ? 1 : 0) + (hasAutomatic ? 1 : 0);
  if (count != 1) {
    return null;
  }
  if (hasChoices) {
    return _FlowKind.interactive;
  }
  if (hasContinuation) {
    return _FlowKind.continuation;
  }
  return _FlowKind.automatic;
}

void _collectTransition({
  required StoryTransition transition,
  required _FlowKind flowKind,
  required _GraphNode node,
  required Map<StoryEventId, int> indexById,
}) {
  switch (transition) {
    case StoryEventTransition(:final destinationEventId):
      node.edges.add(
        _GraphEdge(
          destinationEventId: destinationEventId,
          flowKind: flowKind,
        ),
      );
      if (!indexById.containsKey(destinationEventId)) {
        node.hasIncompleteBoundary = true;
      }
    case StoryTerminalTransition():
      node.hasTerminal = true;
    case StoryConditionalTransition(:final branches, :final fallback):
      for (final branch in branches) {
        _collectTransition(
          transition: branch.transition,
          flowKind: flowKind,
          node: node,
          indexById: indexById,
        );
      }
      _collectTransition(
        transition: fallback,
        flowKind: flowKind,
        node: node,
        indexById: indexById,
      );
    case StoryWeightedTransition(:final options):
      for (final option in options) {
        _collectTransition(
          transition: option.transition,
          flowKind: flowKind,
          node: node,
          indexById: indexById,
        );
      }
  }
}
