import '../condition/story_condition.dart';
import '../effect/story_effect.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../transition/story_transition.dart';
import 'story_diagnostic_location.dart';

/// Authored flow mode of a transition reference.
enum StoryAnalysisFlowKind { interactive, continuation, automatic }

/// One authored reference, including repeated references to the same target.
final class StoryEventReference {
  const StoryEventReference._(
    this.destinationEventId,
    this.flowKind,
    this.location,
  );
  final StoryEventId destinationEventId;
  final StoryAnalysisFlowKind flowKind;

  /// Includes the `destinationEventId` field and enclosing event/choice IDs.
  final StoryDiagnosticLocation location;
  StoryEventId get sourceEventId => location.eventId!;
}

/// Static variable use; numeric adjustments both read and write a value.
enum StoryVariableUseKind {
  valueRead,
  presenceRead,
  set,
  unset,
  increment,
  decrement,
}

/// One variable use at a precise authored field location.
final class StoryVariableUse {
  const StoryVariableUse._(this.variableId, this.kind, this.location);
  final StoryVariableId variableId;
  final StoryVariableUseKind kind;
  final StoryDiagnosticLocation location;
  bool get readsValue =>
      kind == StoryVariableUseKind.valueRead ||
      kind == StoryVariableUseKind.increment ||
      kind == StoryVariableUseKind.decrement;
  bool get readsPresence => kind == StoryVariableUseKind.presenceRead;
  bool get writesValue =>
      kind == StoryVariableUseKind.set ||
      kind == StoryVariableUseKind.unset ||
      kind == StoryVariableUseKind.increment ||
      kind == StoryVariableUseKind.decrement;
}

/// Immutable authored-tree index. No predicates are evaluated and no RNG is used.
///
/// Every branch, fallback and weighted option is visited, including impossible
/// runtime alternatives. Lists preserve authored order and duplicates. Missing
/// destinations and undeclared variables are retained for authoring tools.
final class StoryProjectAnalysis {
  factory StoryProjectAnalysis.analyze(StoryProject project) {
    final collector = _AnalysisCollector(project);
    collector.collect();
    return StoryProjectAnalysis._(project, collector);
  }
  StoryProjectAnalysis._(this._project, _AnalysisCollector collector)
    : eventReferences = List.unmodifiable(collector.references),
      variableUses = List.unmodifiable(collector.uses),
      _terminals = Set.unmodifiable(collector.terminals),
      _incomplete = Set.unmodifiable(collector.incomplete),
      _outgoing = _index(collector.references, (r) => r.sourceEventId),
      _incoming = _index(collector.references, (r) => r.destinationEventId),
      _uses = _index(collector.uses, (u) => u.variableId),
      duplicateEventIds = Set.unmodifiable(_duplicates(_project));
  final StoryProject _project;
  late final _GraphData? _graph = _GraphData.build(this);
  StoryProjectId get projectId => _project.id;
  final List<StoryEventReference> eventReferences;
  final List<StoryVariableUse> variableUses;

  /// Graph queries are suppressed when event identity is ambiguous.
  final Set<StoryEventId> duplicateEventIds;
  bool get isGraphUnambiguous => duplicateEventIds.isEmpty;
  final Set<int> _terminals;
  final Set<int> _incomplete;
  final Map<StoryEventId, List<StoryEventReference>> _outgoing;
  final Map<StoryEventId, List<StoryEventReference>> _incoming;
  final Map<StoryVariableId, List<StoryVariableUse>> _uses;
  List<StoryEventReference> outgoingReferences(StoryEventId id) =>
      _outgoing[id] ?? const [];
  List<StoryEventReference> incomingReferences(StoryEventId id) =>
      _incoming[id] ?? const [];
  List<StoryVariableUse> usesOf(StoryVariableId id) => _uses[id] ?? const [];
  List<StoryVariableUse> readersOf(StoryVariableId id) => List.unmodifiable(
    usesOf(id).where((u) => u.readsValue || u.readsPresence),
  );
  List<StoryVariableUse> writersOf(StoryVariableId id) =>
      List.unmodifiable(usesOf(id).where((u) => u.writesValue));

  /// Structural possibility from explicit roots, independent of runtime state.
  /// Unknown roots are reported; they are never silently treated as events.
  StoryGraphAnalysis graphFrom(Iterable<StoryEventId> entryEventIds) {
    final roots = Set<StoryEventId>.of(entryEventIds);
    final graph = _graph;
    final known = _project.events.map((e) => e.id).toSet();
    final unknown = roots.difference(known);
    if (graph == null) {
      return StoryGraphAnalysis._(
        false,
        unknown,
        const {},
        const {},
        const {},
        const [],
        const [],
        const [],
      );
    }
    final reachable = graph.reachableFromMany(
      roots.where(known.contains).map((id) => graph.indexById[id]!),
    );
    Set<StoryEventId> ids(Iterable<int> indices) {
      final ordered = indices.toList()..sort();
      return {for (final index in ordered) graph.nodes[index].event.id};
    }

    List<StoryGraphCycle> cycles(List<_CycleComponent> values) => [
      for (final c in values)
        StoryGraphCycle._(ids(c.nodeIndices), c.flowKinds),
    ];
    return StoryGraphAnalysis._(
      true,
      unknown,
      ids(reachable),
      ids(
        graph.reverseReachableFrom({
          for (final n in graph.nodes)
            if (n.hasTerminal) n.index,
        }, allowed: reachable),
      ),
      ids(
        graph.reverseReachableFrom({
          for (final n in graph.nodes)
            if (n.hasIncompleteBoundary) n.index,
        }, allowed: reachable),
      ),
      cycles(graph.reachableCycles(reachable)),
      cycles(
        graph.reachableCycles(
          reachable,
          onlyFlowKind: StoryAnalysisFlowKind.automatic,
        ),
      ),
      cycles(
        graph.reachableCycles(
          reachable,
          onlyFlowKind: StoryAnalysisFlowKind.continuation,
        ),
      ),
    );
  }
}

/// Strongly connected cyclic region, in project event order.
final class StoryGraphCycle {
  StoryGraphCycle._(
    Iterable<StoryEventId> events,
    Iterable<StoryAnalysisFlowKind> kinds,
  ) : eventIds = Set.unmodifiable(events),
      flowKinds = Set.unmodifiable(
        StoryAnalysisFlowKind.values.where(kinds.contains),
      );
  final Set<StoryEventId> eventIds;
  final Set<StoryAnalysisFlowKind> flowKinds;
}

/// Immutable structural graph result for the requested roots.
///
/// `canReachTerminationEventIds` means some authored route may terminate, not
/// that every execution will terminate. Incomplete boundaries include missing
/// destinations and malformed/incomplete flow, so absence of a terminal path
/// there does not prove non-termination. Automatic/continuation subcycles are
/// exposed separately from full strongly connected regions. No results are
/// inferred for duplicate event IDs; reference indexes remain usable.
final class StoryGraphAnalysis {
  StoryGraphAnalysis._(
    this.isUnambiguous,
    Iterable<StoryEventId> unknown,
    Iterable<StoryEventId> reachable,
    Iterable<StoryEventId> terminal,
    Iterable<StoryEventId> incomplete,
    Iterable<StoryGraphCycle> all,
    Iterable<StoryGraphCycle> automatic,
    Iterable<StoryGraphCycle> continuation,
  ) : unknownEntryEventIds = Set.unmodifiable(unknown),
      reachableEventIds = Set.unmodifiable(reachable),
      canReachTerminationEventIds = Set.unmodifiable(terminal),
      canReachIncompleteBoundaryEventIds = Set.unmodifiable(incomplete),
      cycles = List.unmodifiable(all),
      automaticCycles = List.unmodifiable(automatic),
      continuationCycles = List.unmodifiable(continuation);
  final bool isUnambiguous;
  final Set<StoryEventId> unknownEntryEventIds;
  final Set<StoryEventId> reachableEventIds;
  final Set<StoryEventId> canReachTerminationEventIds;
  final Set<StoryEventId> canReachIncompleteBoundaryEventIds;
  final List<StoryGraphCycle> cycles;
  final List<StoryGraphCycle> automaticCycles;
  final List<StoryGraphCycle> continuationCycles;
}

Map<K, List<V>> _index<K, V>(Iterable<V> values, K Function(V) key) {
  final result = <K, List<V>>{};
  for (final value in values) {
    result.putIfAbsent(key(value), () => []).add(value);
  }
  return Map.unmodifiable(
    result.map((k, v) => MapEntry(k, List<V>.unmodifiable(v))),
  );
}

Set<StoryEventId> _duplicates(StoryProject project) {
  final seen = <StoryEventId>{};
  return {
    for (final e in project.events)
      if (!seen.add(e.id)) e.id,
  };
}

final class _AnalysisCollector {
  _AnalysisCollector(this.project);
  final StoryProject project;
  final references = <StoryEventReference>[];
  final uses = <StoryVariableUse>[];
  final terminals = <int>{};
  final incomplete = <int>{};
  void collect() {
    for (var i = 0; i < project.events.length; i++) {
      final e = project.events[i];
      final path = <StoryDiagnosticPathSegment>[
        const StoryDiagnosticPathSegment.field('events'),
        StoryDiagnosticPathSegment.index(i),
      ];
      if (_flowKind(e) == null) incomplete.add(i);
      _collectCondition(e, e.availabilityCondition, [
        ...path,
        const StoryDiagnosticPathSegment.field('availabilityCondition'),
      ]);
      _collectEffects(e, e.entryEffects, [
        ...path,
        const StoryDiagnosticPathSegment.field('entryEffects'),
      ]);
      for (var n = 0; n < e.choices.length; n++) {
        final c = e.choices[n];
        final cp = [
          ...path,
          const StoryDiagnosticPathSegment.field('choices'),
          StoryDiagnosticPathSegment.index(n),
        ];
        _collectCondition(e, c.availabilityCondition, [
          ...cp,
          const StoryDiagnosticPathSegment.field('availabilityCondition'),
        ], n);
        _collectEffects(e, c.effects, [
          ...cp,
          const StoryDiagnosticPathSegment.field('effects'),
        ], n);
        _collectTransition(
          i,
          e,
          c.transition,
          StoryAnalysisFlowKind.interactive,
          [...cp, const StoryDiagnosticPathSegment.field('transition')],
          n,
        );
      }
      if (e.continuationTransition != null) {
        _collectTransition(
          i,
          e,
          e.continuationTransition,
          StoryAnalysisFlowKind.continuation,
          [
            ...path,
            const StoryDiagnosticPathSegment.field('continuationTransition'),
          ],
        );
      }
      if (e.automaticTransition != null) {
        _collectTransition(
          i,
          e,
          e.automaticTransition,
          StoryAnalysisFlowKind.automatic,
          [
            ...path,
            const StoryDiagnosticPathSegment.field('automaticTransition'),
          ],
        );
      }
    }
  }

  StoryDiagnosticLocation _location(
    StoryEvent e,
    String kind,
    List<StoryDiagnosticPathSegment> p, [
    int? choice,
  ]) => switch (kind) {
    'condition' => StoryDiagnosticLocation.condition(
      projectId: project.id,
      eventId: e.id,
      choiceId: choice == null ? null : e.choices[choice].id,
      path: p,
    ),
    'effect' => StoryDiagnosticLocation.effect(
      projectId: project.id,
      eventId: e.id,
      choiceId: choice == null ? null : e.choices[choice].id,
      path: p,
    ),
    _ => StoryDiagnosticLocation.transition(
      projectId: project.id,
      eventId: e.id,
      choiceId: choice == null ? null : e.choices[choice].id,
      path: p,
    ),
  };

  void _collectCondition(
    StoryEvent e,
    StoryCondition? c,
    List<StoryDiagnosticPathSegment> p, [
    int? choice,
  ]) {
    if (c == null) return;
    final pending = <(StoryCondition, List<StoryDiagnosticPathSegment>)>[
      (c, p),
    ];
    while (pending.isNotEmpty) {
      final (node, nodePath) = pending.removeLast();
      switch (node) {
        case StoryAllCondition(:final conditions) ||
            StoryAnyCondition(:final conditions):
          for (var n = conditions.length - 1; n >= 0; n--) {
            pending.add((
              conditions[n],
              [
                ...nodePath,
                const StoryDiagnosticPathSegment.field('conditions'),
                StoryDiagnosticPathSegment.index(n),
              ],
            ));
          }
        case StoryNotCondition(:final condition):
          pending.add((
            condition,
            [...nodePath, const StoryDiagnosticPathSegment.field('condition')],
          ));
        case StoryVariableIsSetCondition(:final variableId) ||
            StoryVariableIsUnsetCondition(:final variableId):
          uses.add(
            StoryVariableUse._(
              variableId,
              StoryVariableUseKind.presenceRead,
              _location(e, 'condition', [
                ...nodePath,
                const StoryDiagnosticPathSegment.field('variableId'),
              ], choice),
            ),
          );
        case StoryVariableComparisonCondition(:final variableId):
          uses.add(
            StoryVariableUse._(
              variableId,
              StoryVariableUseKind.valueRead,
              _location(e, 'condition', [
                ...nodePath,
                const StoryDiagnosticPathSegment.field('variableId'),
              ], choice),
            ),
          );
      }
    }
  }

  void _collectEffects(
    StoryEvent e,
    List<StoryEffect> values,
    List<StoryDiagnosticPathSegment> p, [
    int? choice,
  ]) {
    for (var n = 0; n < values.length; n++) {
      final (id, kind) = switch (values[n]) {
        StorySetVariableEffect(:final variableId) => (
          variableId,
          StoryVariableUseKind.set,
        ),
        StoryUnsetVariableEffect(:final variableId) => (
          variableId,
          StoryVariableUseKind.unset,
        ),
        StoryIncrementVariableEffect(:final variableId) => (
          variableId,
          StoryVariableUseKind.increment,
        ),
        StoryDecrementVariableEffect(:final variableId) => (
          variableId,
          StoryVariableUseKind.decrement,
        ),
      };
      uses.add(
        StoryVariableUse._(
          id,
          kind,
          _location(e, 'effect', [
            ...p,
            StoryDiagnosticPathSegment.index(n),
            const StoryDiagnosticPathSegment.field('variableId'),
          ], choice),
        ),
      );
    }
  }

  void _collectTransition(
    int i,
    StoryEvent e,
    StoryTransition? t,
    StoryAnalysisFlowKind kind,
    List<StoryDiagnosticPathSegment> p, [
    int? choice,
  ]) {
    if (t == null) {
      incomplete.add(i);
      return;
    }
    // Explicit stack avoids recursion for deeply nested authored transitions.
    // Conditions are queued too so variable uses retain full authored order.
    final pending = <(Object, List<StoryDiagnosticPathSegment>)>[(t, p)];
    while (pending.isNotEmpty) {
      final (node, nodePath) = pending.removeLast();
      switch (node) {
        case StoryCondition():
          _collectCondition(e, node, nodePath, choice);
        case StoryEventTransition(:final destinationEventId):
          references.add(
            StoryEventReference._(
              destinationEventId,
              kind,
              _location(e, 'transition', [
                ...nodePath,
                const StoryDiagnosticPathSegment.field('destinationEventId'),
              ], choice),
            ),
          );
        case StoryTerminalTransition():
          terminals.add(i);
        case StoryConditionalTransition(:final branches, :final fallback):
          pending.add((
            fallback,
            [...nodePath, const StoryDiagnosticPathSegment.field('fallback')],
          ));
          for (var n = branches.length - 1; n >= 0; n--) {
            final branchPath = [
              ...nodePath,
              const StoryDiagnosticPathSegment.field('branches'),
              StoryDiagnosticPathSegment.index(n),
            ];
            pending.add((
              branches[n].transition,
              [
                ...branchPath,
                const StoryDiagnosticPathSegment.field('transition'),
              ],
            ));
            pending.add((
              branches[n].condition,
              [
                ...branchPath,
                const StoryDiagnosticPathSegment.field('condition'),
              ],
            ));
          }
        case StoryWeightedTransition(:final options):
          for (var n = options.length - 1; n >= 0; n--) {
            pending.add((
              options[n].transition,
              [
                ...nodePath,
                const StoryDiagnosticPathSegment.field('options'),
                StoryDiagnosticPathSegment.index(n),
                const StoryDiagnosticPathSegment.field('transition'),
              ],
            ));
          }
      }
    }
  }
}

final class _GraphEdge {
  const _GraphEdge({required this.destinationEventId, required this.flowKind});

  final StoryEventId destinationEventId;
  final StoryAnalysisFlowKind flowKind;
}

final class _GraphNode {
  _GraphNode({
    required this.index,
    required this.event,
    required this.flowKind,
  });

  final int index;
  final StoryEvent event;
  final StoryAnalysisFlowKind? flowKind;
  final List<_GraphEdge> edges = [];
  bool hasTerminal = false;
  bool hasIncompleteBoundary = false;
}

final class _CycleComponent {
  const _CycleComponent({required this.nodeIndices, required this.flowKinds});

  final Set<int> nodeIndices;
  final Set<StoryAnalysisFlowKind> flowKinds;
}

final class _GraphData {
  _GraphData._({required this.nodes, required this.indexById});

  static _GraphData? build(StoryProjectAnalysis analysis) {
    if (!analysis.isGraphUnambiguous) return null;
    final project = analysis._project;
    final indexById = <StoryEventId, int>{
      for (var i = 0; i < project.events.length; i++) project.events[i].id: i,
    };
    final nodes = <_GraphNode>[];
    for (var i = 0; i < project.events.length; i++) {
      final event = project.events[i];
      final node = _GraphNode(
        index: i,
        event: event,
        flowKind: _flowKind(event),
      );
      node.hasTerminal = analysis._terminals.contains(i);
      node.hasIncompleteBoundary = analysis._incomplete.contains(i);
      for (final reference in analysis.outgoingReferences(event.id)) {
        node.edges.add(
          _GraphEdge(
            destinationEventId: reference.destinationEventId,
            flowKind: reference.flowKind,
          ),
        );
        if (!indexById.containsKey(reference.destinationEventId)) {
          node.hasIncompleteBoundary = true;
        }
      }
      nodes.add(node);
    }
    return _GraphData._(nodes: nodes, indexById: indexById);
  }

  final List<_GraphNode> nodes;
  final Map<StoryEventId, int> indexById;

  Set<int> reachableFromMany(Iterable<int> entryIndices) {
    final reachable = <int>{...entryIndices};
    final queue = reachable.toList()..sort();
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

  Set<int> reverseReachableFrom(Set<int> seeds, {required Set<int> allowed}) {
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
    StoryAnalysisFlowKind? onlyFlowKind,
  }) {
    final adjacency = <int, List<int>>{};
    final reverse = <int, List<int>>{};
    _collectCycleEdges(
      reachable,
      adjacency,
      reverse,
      onlyFlowKind: onlyFlowKind,
    );
    final finished = _cycleFinishOrder(reachable, adjacency);
    final components = _cycleComponents(finished, reverse);

    final cycles = <_CycleComponent>[];
    for (final component in components) {
      final flowKinds = <StoryAnalysisFlowKind>{};
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

  void _collectCycleEdges(
    Set<int> reachable,
    Map<int, List<int>> adjacency,
    Map<int, List<int>> reverse, {
    StoryAnalysisFlowKind? onlyFlowKind,
  }) {
    for (final source in reachable) {
      adjacency[source] = [];
      if (nodes[source].flowKind == null) continue;
      for (final edge in nodes[source].edges) {
        if (onlyFlowKind != null && edge.flowKind != onlyFlowKind) continue;
        final target = indexById[edge.destinationEventId];
        if (target == null || !reachable.contains(target)) continue;
        adjacency[source]!.add(target);
        reverse.putIfAbsent(target, () => []).add(source);
      }
    }
  }

  List<int> _cycleFinishOrder(
    Set<int> reachable,
    Map<int, List<int>> adjacency,
  ) {
    final visited = <int>{};
    final finished = <int>[];
    final ordered = reachable.toList()..sort();
    for (final seed in ordered) {
      if (!visited.add(seed)) continue;
      final stack = <(int, int)>[(seed, 0)];
      while (stack.isNotEmpty) {
        final (node, cursor) = stack.last;
        final targets = adjacency[node]!;
        if (cursor == targets.length) {
          stack.removeLast();
          finished.add(node);
          continue;
        }
        stack[stack.length - 1] = (node, cursor + 1);
        final target = targets[cursor];
        if (visited.add(target)) stack.add((target, 0));
      }
    }
    return finished;
  }

  List<Set<int>> _cycleComponents(
    List<int> finished,
    Map<int, List<int>> reverse,
  ) {
    final assigned = <int>{};
    final components = <Set<int>>[];
    for (final seed in finished.reversed) {
      if (!assigned.add(seed)) continue;
      final component = <int>{};
      final stack = <int>[seed];
      while (stack.isNotEmpty) {
        final node = stack.removeLast();
        component.add(node);
        for (final target in reverse[node] ?? const <int>[]) {
          if (assigned.add(target)) stack.add(target);
        }
      }
      components.add(component);
    }
    return components;
  }
}

StoryAnalysisFlowKind? _flowKind(StoryEvent event) {
  final hasChoices = event.choices.isNotEmpty;
  final hasContinuation = event.continuationTransition != null;
  final hasAutomatic = event.automaticTransition != null;
  final count =
      (hasChoices ? 1 : 0) + (hasContinuation ? 1 : 0) + (hasAutomatic ? 1 : 0);
  if (count != 1) {
    return null;
  }
  if (hasChoices) {
    return StoryAnalysisFlowKind.interactive;
  }
  if (hasContinuation) {
    return StoryAnalysisFlowKind.continuation;
  }
  return StoryAnalysisFlowKind.automatic;
}
