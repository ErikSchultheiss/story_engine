import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryNarrativeDebugAdapter', () {
    test(
      'receives entry resolution, choice, and committed effect explanations',
      () {
        final adapter = _CollectingDebugAdapter();
        final fixture = _fixture(debugAdapter: adapter);

        final session = fixture.runtime.resolveAndStartSession();

        expect(session, isNotNull);
        expect(adapter.entryResolutions, hasLength(1));
        expect(
          adapter.entryResolutions.single.selectedEntryPointId,
          fixture.entryPointId,
        );
        expect(adapter.effectBatches, hasLength(1));
        expect(adapter.effectSessionIndexes, [0]);
        expect(adapter.effectBatches.single, hasLength(1));
        expect(
          adapter.effectBatches.single.single.outcome,
          StoryEffectOutcome.committed,
        );
        expect(adapter.choiceBatches, hasLength(1));
        expect(adapter.choiceSessionIndexes, [0]);
        expect(adapter.choiceBatches.single, hasLength(2));
        expect(
          adapter.choiceBatches.single[0].choiceId,
          fixture.availableChoiceId,
        );
        expect(adapter.choiceBatches.single[0].available, isTrue);
        expect(
          adapter.choiceBatches.single[1].choiceId,
          fixture.blockedChoiceId,
        );
        expect(adapter.choiceBatches.single[1].available, isFalse);

        session!.choose(fixture.availableChoiceId);

        expect(adapter.effectBatches, hasLength(2));
        expect(adapter.effectSessionIndexes, [0, 0]);
        expect(adapter.effectBatches.last, hasLength(2));
        expect(
          adapter.effectBatches.last.map((explanation) => explanation.outcome),
          everyElement(StoryEffectOutcome.committed),
        );
        expect(session.isTerminated, isTrue);
      },
    );

    test(
      'explicit start emits the actual entry-point eligibility explanation',
      () {
        final adapter = _CollectingDebugAdapter();
        final fixture = _fixture(debugAdapter: adapter);

        fixture.runtime.startSession(fixture.entryPointId);

        expect(adapter.entryEligibilities, hasLength(1));
        final explanation = adapter.entryEligibilities.single;
        expect(explanation.entryPointId, fixture.entryPointId);
        expect(explanation.status, StoryEntryPointCandidateStatus.eligible);
        expect(explanation.eligibilityCondition?.result, isTrue);
        expect(adapter.entryResolutions, isEmpty);
      },
    );

    test(
      'failed session startup exposes rejected effects without allocating a session',
      () {
        final adapter = _CollectingDebugAdapter();
        final counterId = StoryVariableId('counter');
        final eventId = StoryEventId('invalid_start');
        final entryPointId = StoryEntryPointId('invalid_entry');
        final project = StoryProject(
          id: StoryProjectId('debug_adapter_failed_start'),
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: counterId,
                type: StoryValueType.integer,
              ),
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
        final runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: [StoryEntryPoint(id: entryPointId, eventId: eventId)],
          debugAdapter: adapter,
        );

        expect(
          () => runtime.startSession(entryPointId),
          throwsA(isA<StoryNarrativeExecutionException>()),
        );

        expect(runtime.activeSessions, isEmpty);
        expect(runtime.history.sessions, isEmpty);
        expect(adapter.effectBatches, hasLength(1));
        expect(adapter.effectSessionIndexes, [null]);
        expect(
          adapter.effectBatches.single.single.outcome,
          StoryEffectOutcome.rejected,
        );
      },
    );

    test('adapter failures cannot change narrative semantics', () {
      final baseline = _fixture();
      final instrumented = _fixture(debugAdapter: _ThrowingDebugAdapter());

      final baselineSession = baseline.runtime.resolveAndStartSession()!;
      final instrumentedSession = instrumented.runtime
          .resolveAndStartSession()!;
      baselineSession.choose(baseline.availableChoiceId);
      instrumentedSession.choose(instrumented.availableChoiceId);

      final codec = StoryNarrativeRuntimeSnapshotCodec();
      expect(
        codec.encode(instrumented.runtime.createSnapshot()),
        codec.encode(baseline.runtime.createSnapshot()),
      );
    });

    test(
      'restore attaches the adapter without replaying historical diagnostics',
      () {
        final source = _fixture();
        final sourceSession = source.runtime.resolveAndStartSession()!;
        final snapshot = source.runtime.createSnapshot();
        final adapter = _CollectingDebugAdapter();
        final restored = StoryNarrativeRuntime.restore(
          project: source.project,
          entryPoints: source.entryPoints,
          snapshot: snapshot,
          debugAdapter: adapter,
        );

        expect(adapter.entryEligibilities, isEmpty);
        expect(adapter.entryResolutions, isEmpty);
        expect(adapter.choiceBatches, isEmpty);
        expect(adapter.effectBatches, isEmpty);

        final restoredSession = restored.sessionByIndex(sourceSession.index);
        restoredSession.choose(source.availableChoiceId);

        expect(adapter.effectBatches, hasLength(1));
        expect(adapter.effectSessionIndexes, [sourceSession.index]);
      },
    );
  });
}

({
  StoryProject project,
  List<StoryEntryPoint> entryPoints,
  StoryNarrativeRuntime runtime,
  StoryEntryPointId entryPointId,
  StoryChoiceId availableChoiceId,
  StoryChoiceId blockedChoiceId,
})
_fixture({StoryNarrativeDebugAdapter? debugAdapter}) {
  final scoreId = StoryVariableId('score');
  final enabledId = StoryVariableId('enabled');
  final startId = StoryEventId('start');
  final endId = StoryEventId('end');
  final entryPointId = StoryEntryPointId('entry');
  final availableChoiceId = StoryChoiceId('available');
  final blockedChoiceId = StoryChoiceId('blocked');
  final project = StoryProject(
    id: StoryProjectId('debug_adapter_project'),
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
            id: availableChoiceId,
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
              operator: StoryComparisonOperator.greaterThanOrEqual,
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
  final entryPoints = <StoryEntryPoint>[
    StoryEntryPoint(
      id: entryPointId,
      eventId: startId,
      eligibilityCondition: StoryVariableComparisonCondition(
        variableId: enabledId,
        operator: StoryComparisonOperator.equal,
        value: const StoryBooleanValue(true),
      ),
    ),
  ];
  return (
    project: project,
    entryPoints: entryPoints,
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: entryPoints,
      randomSeed: 73,
      debugAdapter: debugAdapter,
    ),
    entryPointId: entryPointId,
    availableChoiceId: availableChoiceId,
    blockedChoiceId: blockedChoiceId,
  );
}

final class _CollectingDebugAdapter extends StoryNarrativeDebugAdapter {
  final List<StoryEntryPointExplanation> entryEligibilities = [];
  final List<StoryEntryPointResolutionExplanation> entryResolutions = [];
  final List<int> choiceSessionIndexes = [];
  final List<List<StoryChoiceExplanation>> choiceBatches = [];
  final List<int?> effectSessionIndexes = [];
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
    choiceSessionIndexes.add(sessionIndex);
    choiceBatches.add(explanations);
  }

  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) {
    effectSessionIndexes.add(sessionIndex);
    effectBatches.add(explanations);
  }
}

final class _ThrowingDebugAdapter extends StoryNarrativeDebugAdapter {
  Never _fail() => throw StateError('debug adapter failure');

  @override
  void onEntryPointEligibility(StoryEntryPointExplanation explanation) =>
      _fail();

  @override
  void onEntryPointResolution(
    StoryEntryPointResolutionExplanation explanation,
  ) => _fail();

  @override
  void onChoiceExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) => _fail();

  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) => _fail();
}
