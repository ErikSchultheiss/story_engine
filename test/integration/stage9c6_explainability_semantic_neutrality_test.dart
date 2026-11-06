import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9C6 explainability semantic neutrality', () {
    test(
      'diagnostics off/on preserve snapshots, RNG, host-action identity, and observations',
      () {
        final baselineObserver = _RecordingObserver();
        final diagnosticObserver = _RecordingObserver();
        final debugAdapter = _RecordingDebugAdapter();
        final baseline = _successfulFixture(observers: [baselineObserver]);
        final diagnostic = _successfulFixture(
          observers: [diagnosticObserver],
          debugAdapter: debugAdapter,
        );
        final context = StoryHostContext(
          conditionResults: {baseline.hostConditionKey: true},
        );
        final diagnosticContext = StoryHostContext(
          conditionResults: {diagnostic.hostConditionKey: true},
        );

        final baselineSession = baseline.runtime.resolveAndStartSession(
          hostContext: context,
        )!;
        final diagnosticSession = diagnostic.runtime.resolveAndStartSession(
          hostContext: diagnosticContext,
        )!;

        expect(diagnosticSession.entryPoint.id, baselineSession.entryPoint.id);
        expect(diagnosticSession.index, baselineSession.index);
        expect(diagnosticSession.randomSeed, baselineSession.randomSeed);
        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);

        expect(
          diagnosticSession.availableChoices.map((choice) => choice.id),
          baselineSession.availableChoices.map((choice) => choice.id),
        );

        final baselineRequest = baselineSession.requestHostAction(
          schemaNamespace: 'com.example.world',
          actionId: 'inspect_marker',
          arguments: const {'marker': 'north_gate'},
          resultType: const StoryHostActionValueType.boolean(),
        );
        final diagnosticRequest = diagnosticSession.requestHostAction(
          schemaNamespace: 'com.example.world',
          actionId: 'inspect_marker',
          arguments: const {'marker': 'north_gate'},
          resultType: const StoryHostActionValueType.boolean(),
        );

        expect(diagnosticRequest.id, baselineRequest.id);
        expect(
          diagnosticSession.pendingHostAction?.id,
          baselineSession.pendingHostAction?.id,
        );
        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);

        baselineSession.completeHostAction(baselineRequest.id, value: true);
        diagnosticSession.completeHostAction(diagnosticRequest.id, value: true);

        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);

        baselineSession.choose(baseline.goChoiceId);
        diagnosticSession.choose(diagnostic.goChoiceId);

        expect(diagnosticSession.isTerminated, baselineSession.isTerminated);
        expect(diagnosticSession.state, baselineSession.state);
        expect(diagnosticSession.history, baselineSession.history);
        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);

        expect(debugAdapter.entryResolutions, isNotEmpty);
        expect(debugAdapter.choiceBatches, isNotEmpty);
        expect(debugAdapter.effectBatches, isNotEmpty);

        final baselineError = _captureRuntimeException(
          () => baselineSession.choose(baseline.goChoiceId),
        );
        final diagnosticError = _captureRuntimeException(
          () => diagnosticSession.choose(diagnostic.goChoiceId),
        );
        _expectExceptionParity(diagnosticError, baselineError);
        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);
      },
    );

    test(
      'diagnostics preserve missing-host-fact resolution failures exactly',
      () {
        final baselineObserver = _RecordingObserver();
        final diagnosticObserver = _RecordingObserver();
        final debugAdapter = _RecordingDebugAdapter();
        final baseline = _hostFactFailureFixture(observers: [baselineObserver]);
        final diagnostic = _hostFactFailureFixture(
          observers: [diagnosticObserver],
          debugAdapter: debugAdapter,
        );

        final baselineError = _captureRuntimeException(
          () => baseline.runtime.resolveAndStartSession(),
        );
        final diagnosticError = _captureRuntimeException(
          () => diagnostic.runtime.resolveAndStartSession(),
        );

        _expectExceptionParity(diagnosticError, baselineError);
        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);
        expect(diagnostic.runtime.activeSessions, isEmpty);
        expect(debugAdapter.effectBatches, isEmpty);
      },
    );

    test(
      'diagnostics preserve rejected-effect startup failures and RNG state',
      () {
        final baselineObserver = _RecordingObserver();
        final diagnosticObserver = _RecordingObserver();
        final debugAdapter = _RecordingDebugAdapter();
        final baseline = _effectFailureFixture(observers: [baselineObserver]);
        final diagnostic = _effectFailureFixture(
          observers: [diagnosticObserver],
          debugAdapter: debugAdapter,
        );

        final baselineError = _captureRuntimeException(
          () => baseline.runtime.resolveAndStartSession(),
        );
        final diagnosticError = _captureRuntimeException(
          () => diagnostic.runtime.resolveAndStartSession(),
        );

        _expectExceptionParity(diagnosticError, baselineError);
        _expectRuntimeParity(diagnostic.runtime, baseline.runtime);
        _expectObservationParity(diagnosticObserver, baselineObserver);
        expect(diagnostic.runtime.activeSessions, isEmpty);
        expect(debugAdapter.effectBatches, hasLength(1));
        expect(
          debugAdapter.effectBatches.single.single.outcome,
          StoryEffectOutcome.rejected,
        );
      },
    );
  });
}

({
  StoryNarrativeRuntime runtime,
  StoryChoiceId goChoiceId,
  StoryHostConditionKey hostConditionKey,
})
_successfulFixture({
  required List<StoryNarrativeObserver> observers,
  StoryNarrativeDebugAdapter? debugAdapter,
}) {
  final scoreId = StoryVariableId('score');
  final enabledId = StoryVariableId('enabled');
  final startId = StoryEventId('start');
  final endId = StoryEventId('end');
  final goChoiceId = StoryChoiceId('go');
  final blockedChoiceId = StoryChoiceId('blocked');
  final firstEntryId = StoryEntryPointId('entry_first');
  final secondEntryId = StoryEntryPointId('entry_second');
  final fallbackEntryId = StoryEntryPointId('entry_fallback');
  final hostConditionKey = StoryHostConditionKey('near_gate');
  final project = StoryProject(
    id: StoryProjectId('stage9c6_success'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: scoreId,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
        StoryVariableDefinition(
          id: enabledId,
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(true),
        ),
      ],
    ),
    events: [
      StoryEvent(
        id: startId,
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: scoreId,
            amount: StoryIntegerValue(1),
          ),
        ],
        choices: [
          StoryChoice(
            id: goChoiceId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: scoreId,
              operator: StoryComparisonOperator.greaterThanOrEqual,
              value: StoryIntegerValue(1),
            ),
            effects: [
              StoryIncrementVariableEffect(
                variableId: scoreId,
                amount: StoryIntegerValue(2),
              ),
            ],
            transition: StoryEventTransition(destinationEventId: endId),
          ),
          StoryChoice(
            id: blockedChoiceId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: scoreId,
              operator: StoryComparisonOperator.greaterThan,
              value: StoryIntegerValue(100),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
      StoryEvent(
        id: endId,
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: scoreId,
            amount: StoryIntegerValue(3),
          ),
        ],
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  final eligibility = StoryVariableComparisonCondition(
    variableId: enabledId,
    operator: StoryComparisonOperator.equal,
    value: const StoryBooleanValue(true),
  );
  final hostRequirement = StoryHostConditionRequirement(
    key: hostConditionKey,
    schemaNamespace: 'com.example.world',
    conditionId: 'near_gate',
  );
  final entryPoints = <StoryEntryPoint>[
    StoryEntryPoint(
      id: firstEntryId,
      eventId: startId,
      eligibilityCondition: eligibility,
      hostConditions: [hostRequirement],
      weight: 1,
    ),
    StoryEntryPoint(
      id: secondEntryId,
      eventId: startId,
      eligibilityCondition: eligibility,
      hostConditions: [hostRequirement],
      weight: 3,
    ),
    StoryEntryPoint(id: fallbackEntryId, eventId: startId, isFallback: true),
  ];
  return (
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: entryPoints,
      randomSeed: 0x9c6,
      observers: observers,
      debugAdapter: debugAdapter,
    ),
    goChoiceId: goChoiceId,
    hostConditionKey: hostConditionKey,
  );
}

({StoryNarrativeRuntime runtime}) _hostFactFailureFixture({
  required List<StoryNarrativeObserver> observers,
  StoryNarrativeDebugAdapter? debugAdapter,
}) {
  final eventId = StoryEventId('host_fact_event');
  final entryPointId = StoryEntryPointId('host_fact_entry');
  final hostKey = StoryHostConditionKey('required_fact');
  final project = StoryProject(
    id: StoryProjectId('stage9c6_missing_host_fact'),
    events: [
      StoryEvent(
        id: eventId,
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  return (
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: [
        StoryEntryPoint(
          id: entryPointId,
          eventId: eventId,
          hostConditions: [
            StoryHostConditionRequirement(
              key: hostKey,
              schemaNamespace: 'com.example.world',
              conditionId: 'required_fact',
            ),
          ],
        ),
      ],
      randomSeed: 0x9c6,
      observers: observers,
      debugAdapter: debugAdapter,
    ),
  );
}

({StoryNarrativeRuntime runtime}) _effectFailureFixture({
  required List<StoryNarrativeObserver> observers,
  StoryNarrativeDebugAdapter? debugAdapter,
}) {
  final counterId = StoryVariableId('counter');
  final eventId = StoryEventId('effect_failure_event');
  final entryPointId = StoryEntryPointId('effect_failure_entry');
  final project = StoryProject(
    id: StoryProjectId('stage9c6_effect_failure'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(id: counterId, type: StoryValueType.integer),
      ],
    ),
    events: [
      StoryEvent(
        id: eventId,
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: counterId,
            amount: StoryIntegerValue(1),
          ),
        ],
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  return (
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: [StoryEntryPoint(id: entryPointId, eventId: eventId)],
      randomSeed: 0x9c6,
      observers: observers,
      debugAdapter: debugAdapter,
    ),
  );
}

void _expectRuntimeParity(
  StoryNarrativeRuntime actual,
  StoryNarrativeRuntime expected,
) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  expect(
    codec.encodeJson(actual.createSnapshot()),
    codec.encodeJson(expected.createSnapshot()),
  );
}

void _expectObservationParity(
  _RecordingObserver actual,
  _RecordingObserver expected,
) {
  expect(actual.signatures, expected.signatures);
}

StoryNarrativeRuntimeException _captureRuntimeException(
  void Function() action,
) {
  try {
    action();
  } on StoryNarrativeRuntimeException catch (error) {
    return error;
  }
  fail('Expected StoryNarrativeRuntimeException.');
}

void _expectExceptionParity(
  StoryNarrativeRuntimeException actual,
  StoryNarrativeRuntimeException expected,
) {
  expect(actual.runtimeType, expected.runtimeType);
  expect(actual.message, expected.message);
  expect(actual.operation, expected.operation);
  expect(actual.cause?.runtimeType, expected.cause?.runtimeType);
  expect(actual.cause?.toString(), expected.cause?.toString());
}

final class _RecordingObserver implements StoryNarrativeObserver {
  final List<String> signatures = [];

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    signatures.add(_observationSignature(observation));
  }
}

String _observationSignature(StoryNarrativeObservation observation) {
  if (observation is StoryNarrativeSessionStarted) {
    return '${observation.sequence}|started|${observation.sessionIndex}|'
        '${observation.entryPointId.value}|${observation.entryEventId.value}|'
        '${observation.randomSeed}';
  }
  if (observation is StoryNarrativeEventEntered) {
    return '${observation.sequence}|event|${observation.sessionIndex}|'
        '${observation.eventId.value}';
  }
  if (observation is StoryNarrativeChoicePresented) {
    return '${observation.sequence}|presented|${observation.sessionIndex}|'
        '${observation.eventId.value}|${observation.choiceId.value}';
  }
  if (observation is StoryNarrativeChoiceSelected) {
    return '${observation.sequence}|selected|${observation.sessionIndex}|'
        '${observation.eventId.value}|${observation.choiceId.value}';
  }
  if (observation is StoryNarrativeHostActionRequested) {
    return '${observation.sequence}|host_requested|${observation.sessionIndex}|'
        '${observation.requestId.value}|${observation.schemaNamespace}|'
        '${observation.actionId}';
  }
  if (observation is StoryNarrativeHostActionCompleted) {
    return '${observation.sequence}|host_completed|${observation.sessionIndex}|'
        '${observation.requestId.value}|${observation.resolution.name}|'
        '${observation.code}';
  }
  if (observation is StoryNarrativeSessionEnded) {
    return '${observation.sequence}|ended|${observation.sessionIndex}|'
        '${observation.entryPointId.value}';
  }
  if (observation is StoryNarrativeError) {
    return '${observation.sequence}|error|${observation.sessionIndex}|'
        '${observation.category.name}|${observation.operation}|'
        '${observation.message}';
  }
  throw StateError('Unknown narrative observation ${observation.runtimeType}.');
}

final class _RecordingDebugAdapter extends StoryNarrativeDebugAdapter {
  final List<StoryEntryPointExplanation> entryEligibilities = [];
  final List<StoryEntryPointResolutionExplanation> entryResolutions = [];
  final List<List<StoryChoiceExplanation>> choiceBatches = [];
  final List<List<StoryEffectExplanation>> effectBatches = [];

  @override
  void onEntryPointEligibility(StoryEntryPointExplanation explanation) {
    entryEligibilities.add(explanation);
  }

  @override
  void onEntryPointResolution(
    StoryEntryPointResolutionExplanation explanation,
  ) {
    entryResolutions.add(explanation);
  }

  @override
  void onChoiceExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) {
    choiceBatches.add(explanations);
  }

  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) {
    effectBatches.add(explanations);
  }
}
