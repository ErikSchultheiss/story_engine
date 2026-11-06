import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

final _count = StoryVariableId('count');
final _missing = StoryVariableId('undeclared');
final _auto = StoryEventId('auto');
final _pause = StoryEventId('pause');
final _go = StoryChoiceId('go');
final _no = StoryChoiceId('no');

void main() {
  group('Finalization Stage 2 runtime execution explanations', () {
    test(
      'nested first-match/weighted traversal is causal and snapshot-neutral',
      () {
        final project = _nestedProject();
        final plain = StoryEngine(project: project, randomSeed: 37)..start();
        final diagnostic = StoryEngine(project: project, randomSeed: 37);
        final trace = diagnostic.startWithExplanations();
        expect(_snapshot(diagnostic), _snapshot(plain));
        expect(trace.outcome, StoryRuntimeExecutionOutcome.committed);
        expect(trace.operation, 'start');
        expect(trace.steps.map((step) => step.runtimeType), [
          StoryEventAvailabilityExplanation,
          StoryRuntimeEffectExplanation,
          StoryEventTraversalExplanation,
          StoryAutomaticTraversalExplanation,
          StoryTransitionBranchExplanation,
          StoryTransitionBranchExplanation,
          StoryConditionalTransitionExplanation,
          StoryWeightedTransitionExplanation,
          StoryWeightedTransitionExplanation,
          StoryEventTransitionExplanation,
          StoryEventAvailabilityExplanation,
          StoryEventTraversalExplanation,
        ]);
        final availability = trace.steps
            .whereType<StoryEventAvailabilityExplanation>()
            .toList();
        expect(availability.first.eventId, _auto);
        expect(
          (availability.first.condition
                  as StoryVariableComparisonConditionExplanation)
              .currentValue,
          StoryIntegerValue(0),
        );
        expect(availability.last.eventId, _pause);
        expect(availability.every((step) => step.available), isTrue);
        final branches = trace.steps
            .whereType<StoryTransitionBranchExplanation>()
            .toList();
        expect(branches.map((step) => step.condition.result), [false, true]);
        expect(
          (branches[0].condition as StoryAllConditionExplanation)
              .evaluatedChildren,
          hasLength(1),
        );
        expect(
          (branches[1].condition as StoryAnyConditionExplanation)
              .evaluatedChildren,
          hasLength(1),
        );
        expect(
          branches[0].location.pathString,
          'events[0].automaticTransition.branches[0].condition',
        );
        final conditional = trace.steps
            .whereType<StoryConditionalTransitionExplanation>()
            .single;
        expect(conditional.authoredBranchCount, 3);
        expect(conditional.selectedBranchIndex, 1);
        expect(conditional.evaluatedBranchCount, 2);
        expect(conditional.usedFallback, isFalse);
        final draws = trace.steps
            .whereType<StoryWeightedTransitionExplanation>()
            .toList();
        expect(draws, hasLength(2));
        expect(draws[0].weights, [1, 3]);
        expect(draws[1].weights, [1]);
        // Two nextInt calls here consume four specified LCG32 words (no rejection).
        var expectedRandomWord = 37;
        for (var index = 0; index < 4; index++) {
          expectedRandomWord =
              (1664525 * expectedRandomWord + 1013904223) % 4294967296;
        }
        expect(diagnostic.createSnapshot().randomState.stateWords, [
          37,
          expectedRandomWord,
        ]);
        expect(draws[1].sampledOffset, 0);
        expect(draws[1].selectedOptionIndex, 0);
        final destination = trace.steps
            .whereType<StoryEventTransitionExplanation>()
            .single;
        expect(destination.location.eventId, _auto);
        expect(destination.location.choiceId, isNull);
        expect(
          destination.location.pathString,
          'events[0].automaticTransition.branches[1].transition.options[${draws[0].selectedOptionIndex}].transition.options[0].transition',
        );
        expect(trace.effects, diagnostic.lastEffectExplanations);
        plain.continueStory();
        final continued = diagnostic.continueStoryWithExplanations();
        expect(_snapshot(diagnostic), _snapshot(plain));
        expect(continued.operation, 'continueStory');
        expect(
          continued.steps
              .whereType<StoryConditionalTransitionExplanation>()
              .single
              .usedFallback,
          isTrue,
        );
        expect(
          continued.steps
              .whereType<StoryTerminalTransitionExplanation>()
              .single
              .location
              .pathString,
          'events[1].continuationTransition.fallback',
        );
        expect(plain.lastExecutionExplanation, isNull);
      },
    );

    test(
      'automatic transition ownership changes after a choice enters another event',
      () {
        final project = _project([
          StoryEvent(
            id: _pause,
            choices: [
              StoryChoice(
                id: _go,
                availabilityCondition: _equals(0),
                transition: StoryEventTransition(destinationEventId: _auto),
              ),
            ],
          ),
          StoryEvent(
            id: _auto,
            automaticTransition: _weighted(const StoryTerminalTransition()),
          ),
        ]);
        final plain = StoryEngine(project: project, randomSeed: 12)..start();
        final diagnostic = StoryEngine(project: project, randomSeed: 12)
          ..start();
        plain.choose(_go);
        final trace = diagnostic.chooseWithExplanations(_go);
        expect(_snapshot(diagnostic), _snapshot(plain));
        final chosen = trace.steps
            .whereType<StoryEventTransitionExplanation>()
            .single;
        expect(chosen.location.eventId, _pause);
        expect(chosen.location.choiceId, _go);
        final automatic = trace.steps
            .whereType<StoryWeightedTransitionExplanation>()
            .single;
        expect(automatic.location.eventId, _auto);
        expect(automatic.location.choiceId, isNull);
        expect(automatic.location.pathString, 'events[1].automaticTransition');
        expect(
          trace.steps
              .whereType<StoryTerminalTransitionExplanation>()
              .single
              .location
              .pathString,
          'events[1].automaticTransition.options[0].transition',
        );
      },
    );

    test(
      'available event is evaluated before entry effects, not afterwards',
      () {
        final project = _nestedProject();
        final engine = StoryEngine(project: project);
        final trace = engine.startAtWithExplanations(_auto);
        expect(trace.steps.first, isA<StoryEventAvailabilityExplanation>());
        expect(trace.effects.single.beforeValue, StoryIntegerValue(0));
        expect(trace.effects.single.afterValue, StoryIntegerValue(1));
        expect(engine.state!.values[_count], StoryIntegerValue(1));
      },
    );

    test(
      'unavailable destination retains the rolled-back attempted prefix',
      () {
        final project = _choiceProject();
        final plain = StoryEngine(project: project)..start();
        final diagnostic = StoryEngine(project: project)..start();
        final before = _snapshot(diagnostic);
        final expected = _failure(() => plain.choose(_go));
        final actual = _failure(() => diagnostic.chooseWithExplanations(_go));
        _expectErrorParity(actual, expected);
        expect(_snapshot(diagnostic), before);
        expect(_snapshot(diagnostic), _snapshot(plain));
        final trace = diagnostic.lastExecutionExplanation!;
        expect(trace.outcome, StoryRuntimeExecutionOutcome.rolledBack);
        expect(
          trace.steps
              .whereType<StoryRuntimeChoiceExplanation>()
              .single
              .choice
              .available,
          isTrue,
        );
        expect(trace.effects.map((effect) => effect.outcome), [
          StoryEffectOutcome.rolledBack,
        ]);
        expect(trace.effects.single.afterValue, StoryIntegerValue(1));
        final denied = trace.steps
            .whereType<StoryEventAvailabilityExplanation>()
            .single;
        expect(denied.eventId, _auto);
        expect(denied.available, isFalse);
        expect(
          trace.steps.whereType<StoryEventTraversalExplanation>(),
          isEmpty,
        );
        expect(trace.effects, diagnostic.lastEffectExplanations);
        expect(
          trace.steps
              .whereType<StoryEventTransitionExplanation>()
              .single
              .location
              .pathString,
          'events[0].choices[0].transition',
        );
      },
    );

    test(
      'rejected choice reports its real condition with no speculative traversal',
      () {
        final engine = StoryEngine(project: _choiceProject())..start();
        final before = _snapshot(engine);
        expect(
          () => engine.chooseWithExplanations(_no),
          throwsA(isA<StoryEngineOperationException>()),
        );
        final trace = engine.lastExecutionExplanation!;
        expect(trace.steps, hasLength(1));
        expect(
          (trace.steps.single as StoryRuntimeChoiceExplanation)
              .choice
              .available,
          isFalse,
        );
        expect(trace.effects, isEmpty);
        expect(_snapshot(engine), before);
        expect(
          () => engine.choose(StoryChoiceId('absent')),
          throwsA(isA<StoryEngineOperationException>()),
        );
        expect(engine.lastExecutionExplanation, isNull);
      },
    );

    test(
      'condition exception keeps completed branches without inventing false',
      () {
        final transition = StoryConditionalTransition(
          branches: [
            StoryConditionalTransitionBranch(
              condition: _equals(2),
              transition: const StoryTerminalTransition(),
            ),
            StoryConditionalTransitionBranch(
              condition: StoryVariableIsSetCondition(variableId: _missing),
              transition: const StoryTerminalTransition(),
            ),
          ],
          fallback: const StoryTerminalTransition(),
        );
        final project = _project([
          StoryEvent(id: _auto, automaticTransition: transition),
        ]);
        final plain = StoryEngine(project: project);
        final diagnostic = StoryEngine(project: project);
        _expectErrorParity(
          _failure(() => diagnostic.startWithExplanations()),
          _failure(plain.start),
        );
        final trace = diagnostic.lastExecutionExplanation!;
        expect(
          trace.steps.whereType<StoryTransitionBranchExplanation>(),
          hasLength(1),
        );
        expect(
          trace.steps.whereType<StoryConditionalTransitionExplanation>(),
          isEmpty,
        );
        expect(
          trace.steps.whereType<StoryTerminalTransitionExplanation>(),
          isEmpty,
        );
        expect(diagnostic.status, StoryEngineStatus.notStarted);
      },
    );

    test(
      'automatic cycle guard exposes allowed checks and leaves RNG uncommitted',
      () {
        final safe = StoryEventId('safe');
        final project = _project([
          StoryEvent(
            id: _auto,
            entryEffects: [_increment()],
            automaticTransition: _weighted(
              StoryEventTransition(destinationEventId: _auto),
            ),
          ),
          StoryEvent(
            id: safe,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ]);
        final plain = StoryEngine(
          project: project,
          randomSeed: 91,
          maxAutomaticTransitions: 3,
        );
        final diagnostic = StoryEngine(
          project: project,
          randomSeed: 91,
          maxAutomaticTransitions: 3,
        );
        _expectErrorParity(
          _failure(() => diagnostic.startWithExplanations()),
          _failure(plain.start),
        );
        final trace = diagnostic.lastExecutionExplanation!;
        expect(
          trace.steps.whereType<StoryAutomaticTraversalExplanation>().map(
            (step) => step.allowed,
          ),
          [true, true, true, false],
        );
        expect(
          trace.steps.whereType<StoryWeightedTransitionExplanation>(),
          hasLength(3),
        );
        expect(trace.effects, hasLength(4));
        expect(
          trace.effects.map((effect) => effect.outcome),
          everyElement(StoryEffectOutcome.rolledBack),
        );
        expect(diagnostic.state, isNull);
        plain.startAt(safe);
        diagnostic.startAt(safe);
        expect(_snapshot(diagnostic), _snapshot(plain));
        expect(diagnostic.lastExecutionExplanation, isNull);
      },
    );

    test('missing destination is distinct from availability rejection', () {
      final project = _project([
        StoryEvent(
          id: _auto,
          automaticTransition: StoryEventTransition(
            destinationEventId: StoryEventId('absent'),
          ),
        ),
      ]);
      final engine = StoryEngine(project: project);
      expect(
        engine.startWithExplanations,
        throwsA(isA<StoryEngineConfigurationException>()),
      );
      final trace = engine.lastExecutionExplanation!;
      expect(
        trace.steps
            .whereType<StoryEventTransitionExplanation>()
            .single
            .destinationEventId,
        StoryEventId('absent'),
      );
      expect(
        trace.steps.whereType<StoryEventAvailabilityExplanation>(),
        hasLength(1),
      );
      expect(trace.outcome, StoryRuntimeExecutionOutcome.rolledBack);
    });

    test(
      'rejected effect retains preceding causal records and its own outcome',
      () {
        final project = _project([
          StoryEvent(
            id: _auto,
            entryEffects: [
              _increment(),
              StorySetVariableEffect(
                variableId: _missing,
                value: StoryIntegerValue(2),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ]);
        final engine = StoryEngine(project: project);
        expect(
          engine.startWithExplanations,
          throwsA(isA<StoryEngineExecutionException>()),
        );
        final trace = engine.lastExecutionExplanation!;
        expect(trace.effects.map((effect) => effect.outcome), [
          StoryEffectOutcome.rolledBack,
          StoryEffectOutcome.rejected,
        ]);
        expect(
          trace.steps.whereType<StoryEventTraversalExplanation>(),
          isEmpty,
        );
        expect(trace.effects, engine.lastEffectExplanations);
      },
    );

    test('restore has no retained execution trace and never replays input', () {
      final project = _nestedProject();
      final source = StoryEngine(project: project)..startWithExplanations();
      final restored = StoryEngine.restore(
        project: project,
        snapshot: source.createSnapshot(),
      );
      expect(restored.lastExecutionExplanation, isNull);
      expect(restored.lastEffectExplanations, isEmpty);
      source.continueStoryWithExplanations();
      restored.continueStoryWithExplanations();
      expect(_snapshot(restored), _snapshot(source));
      expect(
        restored.lastExecutionExplanation!.steps
            .whereType<StoryEventAvailabilityExplanation>(),
        isEmpty,
      );
    });

    test(
      'effect-only inputs preserve their API and do not retain complete traces',
      () {
        final engine = StoryEngine(project: _nestedProject());
        expect(engine.startWithEffectExplanations(), hasLength(1));
        expect(engine.lastExecutionExplanation, isNull);
        expect(engine.continueStoryWithEffectExplanations(), isEmpty);
        expect(engine.lastExecutionExplanation, isNull);
      },
    );

    test(
      'explanation collections own their input and reject contradictory weights',
      () {
        final location = StoryDiagnosticLocation.transition(
          projectId: StoryProjectId('model'),
          eventId: _auto,
          path: [const StoryDiagnosticPathSegment.field('automaticTransition')],
        );
        final weights = [1, 3];
        final weighted = StoryWeightedTransitionExplanation(
          location: location,
          weights: weights,
          sampledOffset: 2,
          selectedOptionIndex: 1,
        );
        weights[0] = 100;
        expect(weighted.weights, [1, 3]);
        expect(() => weighted.weights.add(1), throwsUnsupportedError);
        expect(
          () => StoryWeightedTransitionExplanation(
            location: location,
            weights: [1, 3],
            sampledOffset: 0,
            selectedOptionIndex: 1,
          ),
          throwsArgumentError,
        );
        final steps = <StoryRuntimeExplanationStep>[weighted];
        final trace = StoryRuntimeExecutionExplanation(
          operation: 'start',
          outcome: StoryRuntimeExecutionOutcome.committed,
          steps: steps,
        );
        steps.clear();
        expect(trace.steps, hasLength(1));
        expect(() => trace.steps.clear(), throwsUnsupportedError);
        expect(() => trace.effects.clear(), throwsUnsupportedError);
        expect(trace.asRolledBack().steps.single, same(weighted));
        expect(
          () => StoryWeightedTransitionExplanation(
            location: location,
            weights: [StoryIntegerValue.maxPortableValue, 1],
            sampledOffset: 0,
            selectedOptionIndex: 0,
          ),
          throwsArgumentError,
        );
        final rejected = StoryEventAvailabilityExplanation(
          eventId: _auto,
          condition: StoryVariableIsSetConditionExplanation(
            result: false,
            variableId: _count,
            currentValue: null,
          ),
        );
        expect(
          () => StoryRuntimeExecutionExplanation(
            operation: 'start',
            outcome: StoryRuntimeExecutionOutcome.committed,
            steps: [rejected],
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

StoryVariableComparisonCondition _equals(int value) =>
    StoryVariableComparisonCondition(
      variableId: _count,
      operator: StoryComparisonOperator.equal,
      value: StoryIntegerValue(value),
    );
StoryIncrementVariableEffect _increment() => StoryIncrementVariableEffect(
  variableId: _count,
  amount: StoryIntegerValue(1),
);
StoryWeightedTransition _weighted(StoryTransition transition) =>
    StoryWeightedTransition(
      options: [
        StoryWeightedTransitionOption(weight: 1, transition: transition),
      ],
    );
StoryProject _project(List<StoryEvent> events) => StoryProject(
  id: StoryProjectId('stage2_core'),
  entryEventId: events.first.id,
  stateSchema: StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: _count,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(0),
      ),
    ],
  ),
  events: events,
);
StoryProject _nestedProject() {
  final selected = _weighted(StoryEventTransition(destinationEventId: _pause));
  return _project([
    StoryEvent(
      id: _auto,
      availabilityCondition: _equals(0),
      entryEffects: [_increment()],
      automaticTransition: StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: StoryAllCondition([
              _equals(0),
              StoryVariableIsSetCondition(variableId: _missing),
            ]),
            transition: const StoryTerminalTransition(),
          ),
          StoryConditionalTransitionBranch(
            condition: StoryAnyCondition([
              _equals(1),
              StoryVariableIsSetCondition(variableId: _missing),
            ]),
            transition: StoryWeightedTransition(
              options: [
                StoryWeightedTransitionOption(weight: 1, transition: selected),
                StoryWeightedTransitionOption(weight: 3, transition: selected),
              ],
            ),
          ),
          StoryConditionalTransitionBranch(
            condition: StoryVariableIsSetCondition(variableId: _missing),
            transition: const StoryTerminalTransition(),
          ),
        ],
        fallback: const StoryTerminalTransition(),
      ),
    ),
    StoryEvent(
      id: _pause,
      availabilityCondition: _equals(1),
      continuationTransition: StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: _equals(99),
            transition: StoryEventTransition(destinationEventId: _auto),
          ),
        ],
        fallback: const StoryTerminalTransition(),
      ),
    ),
  ]);
}

StoryProject _choiceProject() => _project([
  StoryEvent(
    id: _pause,
    choices: [
      StoryChoice(
        id: _go,
        effects: [_increment()],
        transition: StoryEventTransition(destinationEventId: _auto),
      ),
      StoryChoice(
        id: _no,
        availabilityCondition: _equals(99),
        transition: const StoryTerminalTransition(),
      ),
    ],
  ),
  StoryEvent(
    id: _auto,
    availabilityCondition: _equals(0),
    automaticTransition: const StoryTerminalTransition(),
  ),
]);
String _snapshot(StoryEngine engine) =>
    jsonEncode(StoryRuntimeSnapshotCodec().encode(engine.createSnapshot()));
Object _failure(void Function() action) {
  try {
    action();
  } on Object catch (error) {
    return error;
  }
  throw StateError('Expected failure');
}

void _expectErrorParity(Object actual, Object expected) {
  expect(actual.runtimeType, expected.runtimeType);
  expect('$actual', '$expected');
  if (actual is StoryEngineException && expected is StoryEngineException) {
    expect(actual.operation, expected.operation);
    expect(actual.eventId, expected.eventId);
    expect(actual.choiceId, expected.choiceId);
    expect(actual.cause.runtimeType, expected.cause.runtimeType);
    expect('${actual.cause}', '${expected.cause}');
  }
}
