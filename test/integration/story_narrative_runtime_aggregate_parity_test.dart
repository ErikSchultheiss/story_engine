import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9A7 aggregate narrative restoration parity', () {
    test(
      'multiple active sessions, completed history, and shared-state commits '
      'match uninterrupted execution',
      () {
        final score = StoryVariableId('var_score');
        final eventA = StoryEventId('evt_shared_a');
        final eventB = StoryEventId('evt_shared_b');
        final eventC = StoryEventId('evt_shared_c');
        final choiceA = StoryChoiceId('choice_shared_a');
        final choiceB = StoryChoiceId('choice_shared_b');
        final entryA = StoryEntryPointId('entry_shared_a');
        final entryB = StoryEntryPointId('entry_shared_b');
        final entryC = StoryEntryPointId('entry_shared_c');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a7_shared_state'),
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: score,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(0),
              ),
            ],
          ),
          events: [
            _singleChoiceEvent(
              eventA,
              choiceA,
              effects: [
                StoryIncrementVariableEffect(
                  variableId: score,
                  amount: StoryIntegerValue(1),
                ),
              ],
            ),
            _singleChoiceEvent(
              eventB,
              choiceB,
              effects: [
                StoryIncrementVariableEffect(
                  variableId: score,
                  amount: StoryIntegerValue(10),
                ),
              ],
            ),
            StoryEvent(
              id: eventC,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [
          StoryEntryPoint(id: entryA, eventId: eventA),
          StoryEntryPoint(id: entryB, eventId: eventB),
          StoryEntryPoint(id: entryC, eventId: eventC),
        ];
        final uninterruptedObserver = _RecordingObserver();
        final uninterrupted = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          randomSeed: 0x9a7001,
          observers: [uninterruptedObserver],
        );

        final first = uninterrupted.startSession(entryA);
        uninterrupted.startSession(entryB);
        uninterrupted.startSession(entryC);
        first.choose(choiceA);

        expect(first.isTerminated, isTrue);
        expect(
          uninterrupted.activeSessions.map((session) => session.index).toList(),
          [1, 2],
        );
        expect(uninterrupted.persistentState.rawValueOf(score), 1);

        final checkpointObservationCount =
            uninterruptedObserver.observations.length;
        final restoredRun = _roundTripRuntime(
          project: project,
          entryPoints: entryPoints,
          runtime: uninterrupted,
        );
        final restored = restoredRun.runtime;
        _expectRuntimeParity(
          restored,
          uninterrupted,
          reason: 'shared-state checkpoint',
        );

        _applyBoth(
          uninterrupted,
          restored,
          StoryNarrativeChoiceInput(sessionIndex: 1, choiceId: choiceB),
          reason: 'session 1 commits shared state',
        );
        expect(uninterrupted.persistentState.rawValueOf(score), 11);
        expect(restored.persistentState.rawValueOf(score), 11);
        expect(uninterrupted.sessionByIndex(0).state.rawValueOf(score), 1);
        expect(restored.sessionByIndex(0).state.rawValueOf(score), 1);
        expect(uninterrupted.sessionByIndex(2).state.rawValueOf(score), 11);
        expect(restored.sessionByIndex(2).state.rawValueOf(score), 11);

        _applyBoth(
          uninterrupted,
          restored,
          const StoryNarrativeContinueInput(sessionIndex: 2),
          reason: 'restore-then-continue final active session',
        );
        expect(uninterrupted.activeSessions, isEmpty);
        expect(restored.activeSessions, isEmpty);

        _expectObservationSuffixParity(
          uninterruptedObserver: uninterruptedObserver,
          uninterruptedStart: checkpointObservationCount,
          restoredObserver: restoredRun.observer,
          reason: 'shared-state future observations',
        );
      },
    );

    test(
      'weighted entry selection and next-session seed allocation remain exact '
      'after restore',
      () {
        final leftEvent = StoryEventId('evt_weighted_left');
        final rightEvent = StoryEventId('evt_weighted_right');
        final leftEntry = StoryEntryPointId('entry_weighted_left');
        final rightEntry = StoryEntryPointId('entry_weighted_right');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a7_weighted_resolution'),
          events: [
            StoryEvent(
              id: leftEvent,
              continuationTransition: const StoryTerminalTransition(),
            ),
            StoryEvent(
              id: rightEvent,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [
          StoryEntryPoint(id: leftEntry, eventId: leftEvent, weight: 1),
          StoryEntryPoint(id: rightEntry, eventId: rightEvent, weight: 3),
        ];
        final uninterruptedObserver = _RecordingObserver();
        final uninterrupted = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          randomSeed: 0x9a7002,
          observers: [uninterruptedObserver],
        );

        for (var index = 0; index < 2; index++) {
          final session = uninterrupted.resolveAndStartSession()!;
          session.continueStory();
        }

        final checkpointObservationCount =
            uninterruptedObserver.observations.length;
        final restoredRun = _roundTripRuntime(
          project: project,
          entryPoints: entryPoints,
          runtime: uninterrupted,
        );
        final restored = restoredRun.runtime;
        _expectRuntimeParity(
          restored,
          uninterrupted,
          reason: 'weighted-resolution checkpoint',
        );

        for (var index = 0; index < 8; index++) {
          final expectedSession = uninterrupted.resolveAndStartSession()!;
          final actualSession = restored.resolveAndStartSession()!;

          expect(
            actualSession.index,
            expectedSession.index,
            reason: 'weighted future session $index: index',
          );
          expect(
            actualSession.entryPoint.id,
            expectedSession.entryPoint.id,
            reason: 'weighted future session $index: entry point',
          );
          expect(
            actualSession.randomSeed,
            expectedSession.randomSeed,
            reason: 'weighted future session $index: allocated seed',
          );
          _expectRuntimeParity(
            restored,
            uninterrupted,
            reason: 'weighted future session $index after activation',
          );

          expectedSession.continueStory();
          actualSession.continueStory();
          _expectRuntimeParity(
            restored,
            uninterrupted,
            reason: 'weighted future session $index after continuation',
          );
        }

        _expectObservationSuffixParity(
          uninterruptedObserver: uninterruptedObserver,
          uninterruptedStart: checkpointObservationCount,
          restoredObserver: restoredRun.observer,
          reason: 'weighted-resolution future observations',
        );
      },
    );

    test('local session RNG continues identically after aggregate restore', () {
      final pauseEvent = StoryEventId('evt_local_rng_pause');
      final randomEvent = StoryEventId('evt_local_rng_random');
      final leftEvent = StoryEventId('evt_local_rng_left');
      final rightEvent = StoryEventId('evt_local_rng_right');
      final entryId = StoryEntryPointId('entry_local_rng');
      final project = StoryProject(
        id: StoryProjectId('project_stage9a7_local_rng'),
        events: [
          StoryEvent(
            id: pauseEvent,
            continuationTransition: StoryEventTransition(
              destinationEventId: randomEvent,
            ),
          ),
          StoryEvent(
            id: randomEvent,
            automaticTransition: StoryWeightedTransition(
              options: [
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: StoryEventTransition(
                    destinationEventId: leftEvent,
                  ),
                ),
                StoryWeightedTransitionOption(
                  weight: 3,
                  transition: StoryEventTransition(
                    destinationEventId: rightEvent,
                  ),
                ),
              ],
            ),
          ),
          StoryEvent(
            id: leftEvent,
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: rightEvent,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final entryPoints = [StoryEntryPoint(id: entryId, eventId: pauseEvent)];
      final uninterruptedObserver = _RecordingObserver();
      final uninterrupted = StoryNarrativeRuntime(
        project: project,
        entryPoints: entryPoints,
        randomSeed: 0x9a7003,
        observers: [uninterruptedObserver],
      );
      uninterrupted.startSession(entryId);

      final checkpointObservationCount =
          uninterruptedObserver.observations.length;
      final restoredRun = _roundTripRuntime(
        project: project,
        entryPoints: entryPoints,
        runtime: uninterrupted,
      );
      final restored = restoredRun.runtime;
      _expectRuntimeParity(
        restored,
        uninterrupted,
        reason: 'local RNG checkpoint',
      );

      _applyBoth(
        uninterrupted,
        restored,
        const StoryNarrativeContinueInput(sessionIndex: 0),
        reason: 'local RNG weighted automatic traversal',
      );
      expect(
        restored.sessionByIndex(0).currentEvent?.id,
        uninterrupted.sessionByIndex(0).currentEvent?.id,
      );

      _applyBoth(
        uninterrupted,
        restored,
        const StoryNarrativeContinueInput(sessionIndex: 0),
        reason: 'local RNG selected branch termination',
      );
      expect(restored.sessionByIndex(0).isTerminated, isTrue);

      _expectObservationSuffixParity(
        uninterruptedObserver: uninterruptedObserver,
        uninterruptedStart: checkpointObservationCount,
        restoredObserver: restoredRun.observer,
        reason: 'local RNG future observations',
      );
    });

    for (final resolution in _HostResolution.values) {
      test('pending host action ${resolution.name} path preserves identity, '
          'ordinal, and future continuation', () {
        final eventId = StoryEventId('evt_host_${resolution.name}');
        final entryId = StoryEntryPointId('entry_host_${resolution.name}');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a7_host_${resolution.name}'),
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [StoryEntryPoint(id: entryId, eventId: eventId)];
        final uninterruptedObserver = _RecordingObserver();
        final uninterrupted = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          randomSeed: 0x9a7004,
          observers: [uninterruptedObserver],
        );
        final uninterruptedSession = uninterrupted.startSession(entryId);
        final pending = uninterruptedSession.requestHostAction(
          schemaNamespace: 'com.example.stage9a7',
          actionId: 'first_request',
          arguments: const {'attempt': 1},
          resultType: const StoryHostActionValueType.string(),
        );

        final checkpointObservationCount =
            uninterruptedObserver.observations.length;
        final restoredRun = _roundTripRuntime(
          project: project,
          entryPoints: entryPoints,
          runtime: uninterrupted,
        );
        final restored = restoredRun.runtime;
        final restoredSession = restored.sessionByIndex(0);

        expect(restoredSession.pendingHostAction, pending);
        expect(
          restoredSession.sessionStatus,
          StoryNarrativeSessionStatus.awaitingHost,
        );
        _expectRuntimeParity(
          restored,
          uninterrupted,
          reason: 'host ${resolution.name} checkpoint',
        );
        _resolveHostAction(
          resolution: resolution,
          runtime: uninterrupted,
          requestId: pending.id,
        );
        _resolveHostAction(
          resolution: resolution,
          runtime: restored,
          requestId: pending.id,
        );
        _expectRuntimeParity(
          restored,
          uninterrupted,
          reason: 'host ${resolution.name} resolution',
        );

        final nextExpected = uninterrupted
            .sessionByIndex(0)
            .requestHostAction(
              schemaNamespace: 'com.example.stage9a7',
              actionId: 'second_request',
              arguments: const {'attempt': 2},
              resultType: const StoryHostActionValueType.boolean(),
            );
        final nextActual = restored
            .sessionByIndex(0)
            .requestHostAction(
              schemaNamespace: 'com.example.stage9a7',
              actionId: 'second_request',
              arguments: const {'attempt': 2},
              resultType: const StoryHostActionValueType.boolean(),
            );
        expect(nextActual.id, nextExpected.id);
        expect(nextActual.id, isNot(equals(pending.id)));
        _expectRuntimeParity(
          restored,
          uninterrupted,
          reason: 'host ${resolution.name} next ordinal',
        );

        uninterrupted
            .sessionByIndex(0)
            .completeHostAction(nextExpected.id, value: true);
        restored
            .sessionByIndex(0)
            .completeHostAction(nextActual.id, value: true);
        _expectRuntimeParity(
          restored,
          uninterrupted,
          reason: 'host ${resolution.name} second completion',
        );

        _applyBoth(
          uninterrupted,
          restored,
          const StoryNarrativeContinueInput(sessionIndex: 0),
          reason: 'host ${resolution.name} restore-then-continue',
        );
        expect(restored.sessionByIndex(0).isTerminated, isTrue);

        _expectObservationSuffixParity(
          uninterruptedObserver: uninterruptedObserver,
          uninterruptedStart: checkpointObservationCount,
          restoredObserver: restoredRun.observer,
          reason: 'host ${resolution.name} future observations',
        );
      });
    }

    test(
      'repeated codec checkpoint/restore cycles do not accumulate drift',
      () {
        final eventId = StoryEventId('evt_repeated_round_trip');
        final entryId = StoryEntryPointId('entry_repeated_round_trip');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a7_repeated_round_trip'),
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [StoryEntryPoint(id: entryId, eventId: eventId)];
        var runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          randomSeed: 0x9a7005,
        );

        for (var index = 0; index < 6; index++) {
          final before = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
            runtime.createSnapshot(),
          );
          runtime = _roundTripRuntime(
            project: project,
            entryPoints: entryPoints,
            runtime: runtime,
            attachObserver: false,
          ).runtime;
          final after = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
            runtime.createSnapshot(),
          );
          expect(after, before, reason: 'round trip $index must be canonical');
        }

        final session = runtime.startSession(entryId);
        session.continueStory();
        expect(session.isTerminated, isTrue);
      },
    );
  });
}

enum _HostResolution { completed, failed, cancelled }

StoryEvent _singleChoiceEvent(
  StoryEventId eventId,
  StoryChoiceId choiceId, {
  List<StoryEffect> effects = const [],
}) => StoryEvent(
  id: eventId,
  choices: [
    StoryChoice(
      id: choiceId,
      effects: effects,
      transition: const StoryTerminalTransition(),
    ),
  ],
);

_RestoredRun _roundTripRuntime({
  required StoryProject project,
  required List<StoryEntryPoint> entryPoints,
  required StoryNarrativeRuntime runtime,
  bool attachObserver = true,
}) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final encoded = codec.encodeJson(runtime.createSnapshot());
  final decoded = codec.decodeJson(
    encoded,
    project: project,
    entryPoints: entryPoints,
  );
  final observer = _RecordingObserver();
  final restored = StoryNarrativeRuntime.restore(
    project: project,
    entryPoints: entryPoints,
    snapshot: decoded,
    observers: attachObserver
        ? <StoryNarrativeObserver>[observer]
        : const <StoryNarrativeObserver>[],
  );
  return _RestoredRun(runtime: restored, observer: observer);
}

void _applyBoth(
  StoryNarrativeRuntime expected,
  StoryNarrativeRuntime actual,
  StoryNarrativeInput input, {
  required String reason,
}) {
  expected.applyInput(input);
  actual.applyInput(input);
  _expectRuntimeParity(actual, expected, reason: reason);
}

void _resolveHostAction({
  required _HostResolution resolution,
  required StoryNarrativeRuntime runtime,
  required StoryHostActionRequestId requestId,
}) {
  switch (resolution) {
    case _HostResolution.completed:
      runtime.applyInput(
        StoryNarrativeHostActionCompletedInput(
          sessionIndex: 0,
          requestId: requestId,
          value: 'accepted',
        ),
      );
      return;
    case _HostResolution.failed:
      runtime.applyInput(
        StoryNarrativeHostActionFailedInput(
          sessionIndex: 0,
          requestId: requestId,
          code: 'host_failed',
          message: 'Host reported failure.',
        ),
      );
      return;
    case _HostResolution.cancelled:
      runtime.applyInput(
        StoryNarrativeHostActionCancelledInput(
          sessionIndex: 0,
          requestId: requestId,
          code: 'host_cancelled',
          message: 'Host cancelled request.',
        ),
      );
      return;
  }
}

void _expectRuntimeParity(
  StoryNarrativeRuntime actual,
  StoryNarrativeRuntime expected, {
  required String reason,
}) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final actualSnapshot = actual.createSnapshot();
  final expectedSnapshot = expected.createSnapshot();

  expect(
    codec.encodeJson(actualSnapshot),
    codec.encodeJson(expectedSnapshot),
    reason: '$reason: canonical aggregate checkpoint',
  );
  expect(
    actual.activeSessions.map((session) => session.index).toList(),
    expected.activeSessions.map((session) => session.index).toList(),
    reason: '$reason: active-session membership',
  );
  expect(
    actual.history.eventRoute,
    expected.history.eventRoute,
    reason: '$reason: aggregate event route',
  );

  for (var index = 0; index < expectedSnapshot.sessions.length; index++) {
    final actualSession = actual.sessionByIndex(index);
    final expectedSession = expected.sessionByIndex(index);
    expect(
      actualSession.sessionStatus,
      expectedSession.sessionStatus,
      reason: '$reason: session $index status',
    );
    expect(
      actualSession.currentEvent?.id,
      expectedSession.currentEvent?.id,
      reason: '$reason: session $index current event',
    );
    expect(
      actualSession.availableChoices.map((choice) => choice.id).toList(),
      expectedSession.availableChoices.map((choice) => choice.id).toList(),
      reason: '$reason: session $index available choices',
    );
    expect(
      actualSession.pendingHostAction,
      expectedSession.pendingHostAction,
      reason: '$reason: session $index pending host action',
    );
  }
}

void _expectObservationSuffixParity({
  required _RecordingObserver uninterruptedObserver,
  required int uninterruptedStart,
  required _RecordingObserver restoredObserver,
  required String reason,
}) {
  final expected = uninterruptedObserver.observations
      .skip(uninterruptedStart)
      .map(_observationFingerprint)
      .toList();
  final actual = restoredObserver.observations
      .map(_observationFingerprint)
      .toList();
  expect(actual, expected, reason: reason);
}

String _observationFingerprint(StoryNarrativeObservation observation) {
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
  throw StateError('Unknown narrative observation $observation.');
}

final class _RestoredRun {
  const _RestoredRun({required this.runtime, required this.observer});

  final StoryNarrativeRuntime runtime;
  final _RecordingObserver observer;
}

final class _RecordingObserver implements StoryNarrativeObserver {
  final List<StoryNarrativeObservation> observations =
      <StoryNarrativeObservation>[];

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    observations.add(observation);
  }
}
