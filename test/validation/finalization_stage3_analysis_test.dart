import 'dart:math';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

final _projectId = StoryProjectId('analysis_project');
final _variable = StoryVariableId('score');
StoryEventId _id(int n) => StoryEventId('event_$n');
StoryTransition _to(int n) => StoryEventTransition(destinationEventId: _id(n));
StoryProject _project(List<StoryEvent> events) =>
    StoryProject(id: _projectId, events: events, entryEventId: events.first.id);

void main() {
  test(
    'references retain all alternatives, duplicates, missing targets and locations',
    () {
      final project = _project([
        StoryEvent(
          id: _id(0),
          choices: [
            StoryChoice(
              id: StoryChoiceId('choice'),
              transition: StoryConditionalTransition(
                branches: [
                  StoryConditionalTransitionBranch(
                    condition: StoryNotCondition(
                      StoryVariableIsSetCondition(variableId: _variable),
                    ),
                    transition: _to(1),
                  ),
                ],
                fallback: StoryWeightedTransition(
                  options: [
                    StoryWeightedTransitionOption(
                      weight: 1,
                      transition: _to(1),
                    ),
                    StoryWeightedTransitionOption(
                      weight: 3,
                      transition: _to(99),
                    ),
                    StoryWeightedTransitionOption(
                      weight: 1,
                      transition: const StoryTerminalTransition(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        StoryEvent(
          id: _id(1),
          continuationTransition: const StoryTerminalTransition(),
        ),
      ]);
      final analysis = StoryProjectAnalysis.analyze(project);
      expect(analysis.projectId, project.id);
      expect(analysis.eventReferences.map((r) => r.destinationEventId), [
        _id(1),
        _id(1),
        _id(99),
      ]);
      expect(analysis.incomingReferences(_id(1)), hasLength(2));
      expect(analysis.outgoingReferences(_id(0)), analysis.eventReferences);
      expect(analysis.outgoingReferences(_id(99)), isEmpty);
      expect(
        analysis.eventReferences.last.location.pathString,
        'events[0].choices[0].transition.fallback.options[1].transition.destinationEventId',
      );
      expect(
        analysis.eventReferences.first.location.choiceId,
        StoryChoiceId('choice'),
      );
      expect(
        analysis.eventReferences.first.flowKind,
        StoryAnalysisFlowKind.interactive,
      );
      expect(
        analysis.variableUses.single.location.pathString,
        'events[0].choices[0].transition.branches[0].condition.condition.variableId',
      );
      final graph = analysis.graphFrom([_id(0), _id(99)]);
      expect(graph.unknownEntryEventIds, {_id(99)});
      expect(graph.reachableEventIds, {_id(0), _id(1)});
      expect(graph.canReachTerminationEventIds, {_id(0), _id(1)});
      expect(graph.canReachIncompleteBoundaryEventIds, {_id(0)});
    },
  );

  test(
    'variable inventory separates presence, scalar and read-modify-write uses',
    () {
      final analysis = StoryProjectAnalysis.analyze(
        _project([
          StoryEvent(
            id: _id(0),
            availabilityCondition: StoryAllCondition([
              StoryVariableIsSetCondition(variableId: _variable),
              StoryVariableComparisonCondition(
                variableId: _variable,
                operator: StoryComparisonOperator.greaterThan,
                value: StoryIntegerValue(0),
              ),
            ]),
            entryEffects: [
              StorySetVariableEffect(
                variableId: _variable,
                value: StoryIntegerValue(1),
              ),
              StoryUnsetVariableEffect(variableId: _variable),
              StoryIncrementVariableEffect(
                variableId: _variable,
                amount: StoryIntegerValue(1),
              ),
              StoryDecrementVariableEffect(
                variableId: _variable,
                amount: StoryIntegerValue(1),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ]),
      );
      expect(analysis.variableUses.map((u) => u.kind), [
        StoryVariableUseKind.presenceRead,
        StoryVariableUseKind.valueRead,
        StoryVariableUseKind.set,
        StoryVariableUseKind.unset,
        StoryVariableUseKind.increment,
        StoryVariableUseKind.decrement,
      ]);
      // Authored order puts presence before scalar reads.
      expect(analysis.variableUses.first.readsPresence, isTrue);
      expect(analysis.readersOf(_variable), hasLength(4));
      expect(analysis.writersOf(_variable), hasLength(4));
      expect(analysis.usesOf(StoryVariableId('unknown')), isEmpty);
      expect(analysis.variableUses[4].readsValue, isTrue);
      expect(analysis.variableUses[4].writesValue, isTrue);
    },
  );

  test(
    'analysis collections, query results, graph and cycles are immutable',
    () {
      final events = [StoryEvent(id: _id(0), continuationTransition: _to(0))];
      final analysis = StoryProjectAnalysis.analyze(_project(events));
      events.clear();
      final graph = analysis.graphFrom([_id(0)]);
      expect(graph.reachableEventIds, {_id(0)});
      expect(() => analysis.eventReferences.clear(), throwsUnsupportedError);
      expect(
        () => analysis.outgoingReferences(_id(0)).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => analysis.incomingReferences(_id(0)).clear(),
        throwsUnsupportedError,
      );
      expect(() => analysis.variableUses.clear(), throwsUnsupportedError);
      expect(() => analysis.duplicateEventIds.clear(), throwsUnsupportedError);
      expect(() => graph.reachableEventIds.clear(), throwsUnsupportedError);
      expect(() => graph.cycles.clear(), throwsUnsupportedError);
      expect(
        () => graph.cycles.single.eventIds.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => graph.cycles.single.flowKinds.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'duplicate IDs preserve reference locations while suppressing graph claims',
    () {
      final analysis = StoryProjectAnalysis.analyze(
        _project([
          StoryEvent(id: _id(0), continuationTransition: _to(1)),
          StoryEvent(id: _id(0), automaticTransition: _to(99)),
        ]),
      );
      expect(analysis.duplicateEventIds, {_id(0)});
      expect(analysis.eventReferences.map((r) => r.location.pathString), [
        'events[0].continuationTransition.destinationEventId',
        'events[1].automaticTransition.destinationEventId',
      ]);
      final result = analysis.graphFrom([_id(0), _id(2)]);
      expect(result.isUnambiguous, isFalse);
      expect(result.reachableEventIds, isEmpty);
      expect(result.cycles, isEmpty);
      expect(result.unknownEntryEventIds, {_id(2)});
    },
  );

  test('automatic subcycles remain visible inside a mixed-flow cycle', () {
    final analysis = StoryProjectAnalysis.analyze(
      _project([
        StoryEvent(
          id: _id(0),
          automaticTransition: StoryWeightedTransition(
            options: [
              StoryWeightedTransitionOption(weight: 1, transition: _to(0)),
              StoryWeightedTransitionOption(weight: 1, transition: _to(1)),
            ],
          ),
        ),
        StoryEvent(id: _id(1), continuationTransition: _to(0)),
        StoryEvent(id: _id(2), continuationTransition: _to(2)),
      ]),
    );
    final graph = analysis.graphFrom([_id(0)]);
    expect(graph.cycles.single.eventIds, {_id(0), _id(1)});
    expect(graph.cycles.single.flowKinds, {
      StoryAnalysisFlowKind.automatic,
      StoryAnalysisFlowKind.continuation,
    });
    expect(graph.automaticCycles.single.eventIds, {_id(0)});
    expect(graph.continuationCycles, isEmpty);
    expect(graph.canReachTerminationEventIds, isEmpty);
    expect(analysis.graphFrom([_id(2)]).continuationCycles.single.eventIds, {
      _id(2),
    });
    expect(analysis.graphFrom([]).reachableEventIds, isEmpty);
  });

  test(
    'malformed flow retains authored reachability but not unsound cycle claims',
    () {
      final analysis = StoryProjectAnalysis.analyze(
        _project([
          StoryEvent(
            id: _id(0),
            continuationTransition: _to(1),
            automaticTransition: _to(0),
          ),
          StoryEvent(id: _id(1), continuationTransition: _to(0)),
        ]),
      );
      final graph = analysis.graphFrom([_id(0)]);
      expect(graph.reachableEventIds, {_id(0), _id(1)});
      expect(graph.cycles, isEmpty);
      expect(graph.canReachIncompleteBoundaryEventIds, {_id(0), _id(1)});
    },
  );

  test('structural graph does not evaluate contradictory conditions', () {
    final project = _project([
      StoryEvent(
        id: _id(0),
        automaticTransition: StoryConditionalTransition(
          branches: [
            StoryConditionalTransitionBranch(
              condition: StoryAllCondition([
                StoryVariableIsSetCondition(variableId: _variable),
                StoryVariableIsUnsetCondition(variableId: _variable),
              ]),
              transition: _to(1),
            ),
          ],
          fallback: const StoryTerminalTransition(),
        ),
      ),
      StoryEvent(id: _id(1), automaticTransition: _to(1)),
    ]);
    final graph = StoryProjectAnalysis.analyze(project).graphFrom([_id(0)]);
    expect(graph.reachableEventIds, {_id(0), _id(1)});
    expect(graph.canReachTerminationEventIds, {_id(0)});
    expect(graph.automaticCycles.single.eventIds, {_id(1)});
  });

  test(
    'random small graphs agree with an independent transitive-closure oracle',
    () {
      final random = Random(3381);
      for (var sample = 0; sample < 35; sample++) {
        const size = 7;
        final edges = List.generate(size, (_) => <int>{});
        final terminals = <int>{};
        final events = <StoryEvent>[];
        for (var source = 0; source < size; source++) {
          final options = <StoryWeightedTransitionOption>[];
          for (var target = 0; target < size; target++) {
            if (random.nextInt(4) == 0) {
              edges[source].add(target);
              options.add(
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: _to(target),
                ),
              );
            }
          }
          if (options.isEmpty || random.nextBool()) {
            terminals.add(source);
            options.add(
              StoryWeightedTransitionOption(
                weight: 1,
                transition: const StoryTerminalTransition(),
              ),
            );
          }
          events.add(
            StoryEvent(
              id: _id(source),
              continuationTransition: StoryWeightedTransition(options: options),
            ),
          );
        }
        final closure = List.generate(
          size,
          (i) => List.generate(size, (j) => edges[i].contains(j)),
        );
        for (var k = 0; k < size; k++) {
          for (var i = 0; i < size; i++) {
            for (var j = 0; j < size; j++) {
              closure[i][j] = closure[i][j] || (closure[i][k] && closure[k][j]);
            }
          }
        }
        final reachable = {
          0,
          for (var n = 0; n < size; n++)
            if (closure[0][n]) n,
        };
        final canTerminate = {
          for (final n in reachable)
            if (terminals.contains(n) || terminals.any((t) => closure[n][t]))
              _id(n),
        };
        final graph = StoryProjectAnalysis.analyze(
          _project(events),
        ).graphFrom([_id(0)]);
        expect(
          graph.reachableEventIds,
          reachable.map(_id).toSet(),
          reason: 'sample $sample',
        );
        expect(
          graph.canReachTerminationEventIds,
          canTerminate,
          reason: 'sample $sample',
        );
        final cycleMembers = {for (final c in graph.cycles) ...c.eventIds};
        expect(cycleMembers, {
          for (final n in reachable)
            if (closure[n][n]) _id(n),
        }, reason: 'sample $sample');
        for (final c in graph.cycles) {
          for (final a in c.eventIds) {
            final index = int.parse(a.value.substring(6));
            expect(c.eventIds, {
              for (final n in reachable)
                if (closure[index][n] && closure[n][index]) _id(n),
            });
          }
        }
      }
    },
  );

  test(
    'ten-thousand-event cycle completes without recursive graph stack growth',
    () {
      const size = 10000;
      final project = _project(
        List.generate(
          size,
          (n) => StoryEvent(
            id: _id(n),
            continuationTransition: _to((n + 1) % size),
          ),
        ),
      );
      final graph = StoryProjectAnalysis.analyze(project).graphFrom([_id(0)]);
      expect(graph.reachableEventIds, hasLength(size));
      expect(graph.cycles.single.eventIds, hasLength(size));
      expect(graph.continuationCycles.single.eventIds, hasLength(size));
      expect(graph.canReachTerminationEventIds, isEmpty);
    },
  );
}
