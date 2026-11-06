import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9A5 aggregate narrative runtime restore', () {
    test(
      'capture and restore retain completed history, active state, and pending host action',
      () {
        final score = StoryVariableId('var_score');
        final firstEvent = StoryEventId('evt_first');
        final secondEvent = StoryEventId('evt_second');
        final firstChoice = StoryChoiceId('choice_first');
        final firstEntry = StoryEntryPointId('entry_first');
        final secondEntry = StoryEntryPointId('entry_second');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a5_restore'),
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
            StoryEvent(
              id: firstEvent,
              choices: [
                StoryChoice(
                  id: firstChoice,
                  effects: [
                    StoryIncrementVariableEffect(
                      variableId: score,
                      amount: StoryIntegerValue(1),
                    ),
                  ],
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
            StoryEvent(
              id: secondEvent,
              entryEffects: [
                StoryIncrementVariableEffect(
                  variableId: score,
                  amount: StoryIntegerValue(10),
                ),
              ],
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [
          StoryEntryPoint(id: firstEntry, eventId: firstEvent),
          StoryEntryPoint(id: secondEntry, eventId: secondEvent),
        ];
        final runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          randomSeed: 123,
          maxAutomaticTransitions: 77,
        );

        final completed = runtime.startSession(firstEntry);
        completed.choose(firstChoice);
        expect(completed.isTerminated, isTrue);
        expect(completed.state.rawValueOf(score), 1);

        final waiting = runtime.startSession(secondEntry);
        final pending = waiting.requestHostAction(
          schemaNamespace: 'com.example.world',
          actionId: 'load_area',
          arguments: const {'area': 'market'},
        );
        expect(runtime.persistentState.rawValueOf(score), 11);
        expect(runtime.persistentStateRevision, 2);

        final snapshot = runtime.createSnapshot();
        final codec = StoryNarrativeRuntimeSnapshotCodec();
        final decoded = codec.decodeJson(
          codec.encodeJson(snapshot),
          project: project,
          entryPoints: entryPoints,
        );
        final restored = StoryNarrativeRuntime.restore(
          project: project,
          entryPoints: entryPoints,
          snapshot: decoded,
        );

        expect(restored.randomSeed, 123);
        expect(restored.maxAutomaticTransitions, 77);
        expect(restored.persistentState.rawValueOf(score), 11);
        expect(restored.persistentStateRevision, 2);
        expect(restored.history.sessions, hasLength(2));
        expect(restored.activeSessions, hasLength(1));

        final restoredCompleted = restored.sessionByIndex(0);
        expect(restoredCompleted.isTerminated, isTrue);
        expect(restoredCompleted.state.rawValueOf(score), 1);
        expect(restoredCompleted.history.eventRoute, [firstEvent]);

        final restoredWaiting = restored.sessionByIndex(1);
        expect(
          restoredWaiting.sessionStatus,
          StoryNarrativeSessionStatus.awaitingHost,
        );
        expect(restoredWaiting.state.rawValueOf(score), 11);
        expect(restoredWaiting.pendingHostAction?.id, pending.id);
        expect(restoredWaiting.pendingHostAction?.arguments, {
          'area': 'market',
        });

        restoredWaiting.completeHostAction(pending.id);
        expect(
          restoredWaiting.sessionStatus,
          StoryNarrativeSessionStatus.awaitingContinue,
        );
        restoredWaiting.continueStory();
        expect(restoredWaiting.isTerminated, isTrue);
        expect(restored.activeSessions, isEmpty);
      },
    );

    test(
      'restore preserves next session identity and orchestration RNG state',
      () {
        final leftEvent = StoryEventId('evt_left');
        final rightEvent = StoryEventId('evt_right');
        final leftEntry = StoryEntryPointId('entry_left');
        final rightEntry = StoryEntryPointId('entry_right');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a5_rng'),
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
        final uninterrupted = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          randomSeed: 987654,
        );

        final first = uninterrupted.resolveAndStartSession()!;
        first.continueStory();
        final snapshot = uninterrupted.createSnapshot();
        final restored = StoryNarrativeRuntime.restore(
          project: project,
          entryPoints: entryPoints,
          snapshot: snapshot,
        );

        final nextUninterrupted = uninterrupted.resolveAndStartSession()!;
        final nextRestored = restored.resolveAndStartSession()!;

        expect(nextRestored.index, snapshot.nextSessionIndex);
        expect(nextRestored.index, nextUninterrupted.index);
        expect(nextRestored.entryPoint.id, nextUninterrupted.entryPoint.id);
        expect(nextRestored.randomSeed, nextUninterrupted.randomSeed);
        expect(
          restored.createSnapshot().orchestrationRandomState,
          uninterrupted.createSnapshot().orchestrationRandomState,
        );
      },
    );

    test(
      'restore emits no replay observations and continues the sequence cursor',
      () {
        final eventId = StoryEventId('evt_observed');
        final entryId = StoryEntryPointId('entry_observed');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a5_observation'),
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [StoryEntryPoint(id: entryId, eventId: eventId)];
        final beforeObserver = _RecordingObserver();
        final runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          observers: [beforeObserver],
        );
        runtime.startSession(entryId);
        final snapshot = runtime.createSnapshot();
        expect(beforeObserver.observations, isNotEmpty);
        expect(
          snapshot.nextObservationSequence,
          beforeObserver.observations.length,
        );

        final afterObserver = _RecordingObserver();
        final restored = StoryNarrativeRuntime.restore(
          project: project,
          entryPoints: entryPoints,
          snapshot: snapshot,
          observers: [afterObserver],
        );

        expect(afterObserver.observations, isEmpty);
        final session = restored.sessionByIndex(0);
        final request = session.requestHostAction(
          schemaNamespace: 'com.example.world',
          actionId: 'open_overlay',
        );

        expect(afterObserver.observations, hasLength(1));
        expect(
          afterObserver.observations.single.sequence,
          snapshot.nextObservationSequence,
        );
        expect(
          afterObserver.observations.single,
          isA<StoryNarrativeHostActionRequested>(),
        );
        expect(session.pendingHostAction?.id, request.id);
      },
    );

    test('restoring a pending request never redispatches or duplicates it', () {
      final eventId = StoryEventId('evt_pending');
      final entryId = StoryEntryPointId('entry_pending');
      final project = StoryProject(
        id: StoryProjectId('project_stage9a5_pending'),
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final entryPoints = [StoryEntryPoint(id: entryId, eventId: eventId)];
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: entryPoints,
      );
      final session = runtime.startSession(entryId);
      final pending = session.requestHostAction(
        schemaNamespace: 'com.example.world',
        actionId: 'combat',
      );
      final snapshot = runtime.createSnapshot();
      final observer = _RecordingObserver();

      final restored = StoryNarrativeRuntime.restore(
        project: project,
        entryPoints: entryPoints,
        snapshot: snapshot,
        observers: [observer],
      );
      final restoredSession = restored.sessionByIndex(0);

      expect(observer.observations, isEmpty);
      expect(restoredSession.pendingHostAction?.id, pending.id);
      expect(
        () => restoredSession.requestHostAction(
          schemaNamespace: 'com.example.world',
          actionId: 'combat',
        ),
        throwsA(isA<StoryNarrativeOperationException>()),
      );
      expect(restoredSession.pendingHostAction?.id, pending.id);
    });

    test(
      'aggregate capture is rejected during a serialized runtime operation',
      () {
        final eventId = StoryEventId('evt_capture_boundary');
        final entryId = StoryEntryPointId('entry_capture_boundary');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a5_capture_boundary'),
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [StoryEntryPoint(id: entryId, eventId: eventId)];
        late StoryNarrativeRuntime runtime;
        final observer = _SnapshotAttemptObserver(() => runtime);
        runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
          observers: [observer],
        );

        runtime.startSession(entryId);

        expect(
          observer.error,
          isA<StoryNarrativeOperationException>().having(
            (error) => error.operation,
            'operation',
            'createSnapshot',
          ),
        );
        expect(runtime.createSnapshot().sessions, hasLength(1));
      },
    );

    test(
      'restore incompatibility fails before supplied observers are attached',
      () {
        final eventId = StoryEventId('evt_atomic_failure');
        final entryId = StoryEntryPointId('entry_atomic_failure');
        final project = StoryProject(
          id: StoryProjectId('project_stage9a5_atomic_failure'),
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final entryPoints = [StoryEntryPoint(id: entryId, eventId: eventId)];
        final runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
        )..startSession(entryId);
        final snapshot = runtime.createSnapshot();
        final observer = _RecordingObserver();
        final wrongProject = StoryProject(
          id: StoryProjectId('different_project'),
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );

        expect(
          () => StoryNarrativeRuntime.restore(
            project: wrongProject,
            entryPoints: entryPoints,
            snapshot: snapshot,
            observers: [observer],
          ),
          throwsA(isA<StoryNarrativeRuntimeSnapshotCompatibilityException>()),
        );
        expect(observer.observations, isEmpty);
      },
    );
  });
}

final class _RecordingObserver implements StoryNarrativeObserver {
  final List<StoryNarrativeObservation> observations =
      <StoryNarrativeObservation>[];

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    observations.add(observation);
  }
}

final class _SnapshotAttemptObserver implements StoryNarrativeObserver {
  _SnapshotAttemptObserver(this._runtime);

  final StoryNarrativeRuntime Function() _runtime;
  Object? error;

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    if (error != null) {
      return;
    }
    try {
      _runtime().createSnapshot();
    } on Object catch (caught) {
      error = caught;
    }
  }
}
