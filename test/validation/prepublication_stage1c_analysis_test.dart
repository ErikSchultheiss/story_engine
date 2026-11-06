import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('1C collector preserves interleaved uses and every authored reference', () {
    final x = StoryVariableId('x');
    final y = StoryVariableId('y');
    final z = StoryVariableId('z');
    final project = StoryProject(
      id: StoryProjectId('collector_order'),
      events: [
        // Ambiguous flow is intentional: authored indexes retain all fields.
        StoryEvent(
          id: _id('root'),
          availabilityCondition: StoryAllCondition([
            StoryVariableIsSetCondition(variableId: x),
            StoryNotCondition(StoryVariableIsUnsetCondition(variableId: y)),
            StoryAnyCondition([
              _comparison(x),
              StoryVariableIsSetCondition(variableId: z),
            ]),
          ]),
          entryEffects: [
            StorySetVariableEffect(variableId: x, value: StoryIntegerValue(1)),
            StoryUnsetVariableEffect(variableId: y),
            StoryIncrementVariableEffect(
              variableId: x,
              amount: StoryIntegerValue(1),
            ),
            StoryDecrementVariableEffect(
              variableId: x,
              amount: StoryIntegerValue(1),
            ),
          ],
          choices: [
            StoryChoice(
              id: StoryChoiceId('route'),
              availabilityCondition: _comparison(y),
              effects: [
                StorySetVariableEffect(
                  variableId: z,
                  value: StoryIntegerValue(1),
                ),
              ],
              transition: StoryConditionalTransition(
                branches: [
                  StoryConditionalTransitionBranch(
                    condition: StoryAllCondition([
                      StoryVariableIsUnsetCondition(variableId: x),
                      _comparison(y),
                    ]),
                    transition: StoryWeightedTransition(
                      options: [
                        StoryWeightedTransitionOption(
                          weight: 1,
                          transition: _to('b'),
                        ),
                        StoryWeightedTransitionOption(
                          weight: 2,
                          transition: _to('b'),
                        ),
                      ],
                    ),
                  ),
                  StoryConditionalTransitionBranch(
                    condition: StoryVariableIsSetCondition(variableId: z),
                    transition: _to('missing'),
                  ),
                ],
                fallback: _to('c'),
              ),
            ),
            StoryChoice(id: StoryChoiceId('unfinished')),
          ],
          continuationTransition: _to('b'),
          automaticTransition: const StoryTerminalTransition(),
        ),
        StoryEvent(
          id: _id('b'),
          continuationTransition: const StoryTerminalTransition(),
        ),
        StoryEvent(id: _id('c'), automaticTransition: _to('b')),
      ],
    );
    final analysis = StoryProjectAnalysis.analyze(project);

    expect(
      analysis.variableUses.map(
        (use) => (
          use.variableId.value,
          use.kind,
          use.location.choiceId?.value,
          use.location.pathString,
        ),
      ),
      [
        (
          'x',
          StoryVariableUseKind.presenceRead,
          null,
          'events[0].availabilityCondition.conditions[0].variableId',
        ),
        (
          'y',
          StoryVariableUseKind.presenceRead,
          null,
          'events[0].availabilityCondition.conditions[1].condition.variableId',
        ),
        (
          'x',
          StoryVariableUseKind.valueRead,
          null,
          'events[0].availabilityCondition.conditions[2].conditions[0].variableId',
        ),
        (
          'z',
          StoryVariableUseKind.presenceRead,
          null,
          'events[0].availabilityCondition.conditions[2].conditions[1].variableId',
        ),
        (
          'x',
          StoryVariableUseKind.set,
          null,
          'events[0].entryEffects[0].variableId',
        ),
        (
          'y',
          StoryVariableUseKind.unset,
          null,
          'events[0].entryEffects[1].variableId',
        ),
        (
          'x',
          StoryVariableUseKind.increment,
          null,
          'events[0].entryEffects[2].variableId',
        ),
        (
          'x',
          StoryVariableUseKind.decrement,
          null,
          'events[0].entryEffects[3].variableId',
        ),
        (
          'y',
          StoryVariableUseKind.valueRead,
          'route',
          'events[0].choices[0].availabilityCondition.variableId',
        ),
        (
          'z',
          StoryVariableUseKind.set,
          'route',
          'events[0].choices[0].effects[0].variableId',
        ),
        (
          'x',
          StoryVariableUseKind.presenceRead,
          'route',
          'events[0].choices[0].transition.branches[0].condition.conditions[0].variableId',
        ),
        (
          'y',
          StoryVariableUseKind.valueRead,
          'route',
          'events[0].choices[0].transition.branches[0].condition.conditions[1].variableId',
        ),
        (
          'z',
          StoryVariableUseKind.presenceRead,
          'route',
          'events[0].choices[0].transition.branches[1].condition.variableId',
        ),
      ],
    );
    expect(
      analysis.eventReferences.map(
        (reference) => (
          reference.destinationEventId.value,
          reference.flowKind,
          reference.location.choiceId?.value,
          reference.location.pathString,
        ),
      ),
      [
        (
          'b',
          StoryAnalysisFlowKind.interactive,
          'route',
          'events[0].choices[0].transition.branches[0].transition.options[0].transition.destinationEventId',
        ),
        (
          'b',
          StoryAnalysisFlowKind.interactive,
          'route',
          'events[0].choices[0].transition.branches[0].transition.options[1].transition.destinationEventId',
        ),
        (
          'missing',
          StoryAnalysisFlowKind.interactive,
          'route',
          'events[0].choices[0].transition.branches[1].transition.destinationEventId',
        ),
        (
          'c',
          StoryAnalysisFlowKind.interactive,
          'route',
          'events[0].choices[0].transition.fallback.destinationEventId',
        ),
        (
          'b',
          StoryAnalysisFlowKind.continuation,
          null,
          'events[0].continuationTransition.destinationEventId',
        ),
        (
          'b',
          StoryAnalysisFlowKind.automatic,
          null,
          'events[2].automaticTransition.destinationEventId',
        ),
      ],
    );
    expect(analysis.outgoingReferences(_id('root')), hasLength(5));
    expect(analysis.incomingReferences(_id('b')), hasLength(4));
    expect(analysis.incomingReferences(_id('missing')), hasLength(1));
    expect(analysis.variableUses.map((u) => u.location.eventId).toSet(), {
      _id('root'),
    });
  });

  test(
    '1C cycle families retain project order, root scope and incomplete paths',
    () {
      final project = StoryProject(
        id: StoryProjectId('cycle_order'),
        events: [
          StoryEvent(
            id: _id('root'),
            choices: [
              for (final target in [
                'auto_a',
                'cont_a',
                'mixed_a',
                'self',
                'boundary',
                'broken',
              ])
                StoryChoice(
                  id: StoryChoiceId('to_$target'),
                  transition: _to(target),
                ),
            ],
          ),
          StoryEvent(id: _id('auto_b'), automaticTransition: _to('auto_a')),
          StoryEvent(id: _id('auto_a'), automaticTransition: _to('auto_b')),
          StoryEvent(id: _id('cont_b'), continuationTransition: _to('cont_a')),
          StoryEvent(id: _id('cont_a'), continuationTransition: _to('cont_b')),
          StoryEvent(
            id: _id('mixed_b'),
            continuationTransition: _to('mixed_a'),
          ),
          StoryEvent(
            id: _id('mixed_a'),
            choices: [
              StoryChoice(
                id: StoryChoiceId('repeat'),
                transition: _to('mixed_b'),
              ),
              StoryChoice(
                id: StoryChoiceId('finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
          StoryEvent(id: _id('self'), automaticTransition: _to('self')),
          StoryEvent(
            id: _id('boundary'),
            continuationTransition: _to('external'),
          ),
          StoryEvent(
            id: _id('unreachable'),
            automaticTransition: _to('unreachable'),
          ),
          StoryEvent(id: _id('broken')),
        ],
      );
      final analysis = StoryProjectAnalysis.analyze(project);
      final graph = analysis.graphFrom([
        _id('root'),
        _id('unknown'),
        _id('root'),
      ]);
      expect(graph.unknownEntryEventIds, {_id('unknown')});
      expect(graph.reachableEventIds.map((id) => id.value), [
        'root',
        'auto_b',
        'auto_a',
        'cont_b',
        'cont_a',
        'mixed_b',
        'mixed_a',
        'self',
        'boundary',
        'broken',
      ]);
      expect(_cycleIds(graph.cycles), [
        ['auto_b', 'auto_a'],
        ['cont_b', 'cont_a'],
        ['mixed_b', 'mixed_a'],
        ['self'],
      ]);
      expect(graph.cycles.map((c) => c.flowKinds.toList()), [
        [StoryAnalysisFlowKind.automatic],
        [StoryAnalysisFlowKind.continuation],
        [StoryAnalysisFlowKind.interactive, StoryAnalysisFlowKind.continuation],
        [StoryAnalysisFlowKind.automatic],
      ]);
      expect(_cycleIds(graph.automaticCycles), [
        ['auto_b', 'auto_a'],
        ['self'],
      ]);
      expect(_cycleIds(graph.continuationCycles), [
        ['cont_b', 'cont_a'],
      ]);
      expect(graph.canReachTerminationEventIds.map((id) => id.value), [
        'root',
        'mixed_b',
        'mixed_a',
      ]);
      expect(graph.canReachIncompleteBoundaryEventIds.map((id) => id.value), [
        'root',
        'boundary',
        'broken',
      ]);

      final isolated = analysis.graphFrom([_id('auto_a')]);
      expect(_cycleIds(isolated.cycles), [
        ['auto_b', 'auto_a'],
      ]);
      expect(isolated.canReachIncompleteBoundaryEventIds, isEmpty);
      expect(analysis.graphFrom(const []).cycles, isEmpty);
      expect(
        _cycleIds(analysis.graphFrom([_id('root')]).cycles),
        _cycleIds(graph.cycles),
      );
    },
  );

  test('1C collector retains deep condition and weighted-transition paths', () {
    final variable = StoryVariableId('deep');
    StoryCondition condition = StoryVariableIsSetCondition(
      variableId: variable,
    );
    StoryTransition transition = _to('target');
    const depth = 512;
    for (var n = 0; n < depth; n++) {
      condition = StoryNotCondition(condition);
      transition = StoryWeightedTransition(
        options: [
          StoryWeightedTransitionOption(weight: 1, transition: transition),
        ],
      );
    }
    final analysis = StoryProjectAnalysis.analyze(
      StoryProject(
        id: StoryProjectId('deep_collector'),
        events: [
          StoryEvent(
            id: _id('root'),
            availabilityCondition: condition,
            automaticTransition: transition,
          ),
          StoryEvent(
            id: _id('target'),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      ),
    );
    expect(
      analysis.variableUses.single.location.pathString,
      'events[0].availabilityCondition.${List.filled(depth, 'condition.').join()}variableId',
    );
    expect(
      analysis.eventReferences.single.location.pathString,
      'events[0].automaticTransition.${List.filled(depth, 'options[0].transition.').join()}destinationEventId',
    );
    expect(analysis.graphFrom([_id('root')]).canReachTerminationEventIds, {
      _id('root'),
      _id('target'),
    });
  });
}

StoryEventId _id(String value) => StoryEventId(value);
StoryEventTransition _to(String value) =>
    StoryEventTransition(destinationEventId: _id(value));
StoryVariableComparisonCondition _comparison(StoryVariableId id) =>
    StoryVariableComparisonCondition(
      variableId: id,
      operator: StoryComparisonOperator.equal,
      value: StoryIntegerValue(1),
    );
List<List<String>> _cycleIds(List<StoryGraphCycle> cycles) => [
  for (final cycle in cycles) cycle.eventIds.map((id) => id.value).toList(),
];
