import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryNarrativeRuntimeSnapshotValidator', () {
    const validator = StoryNarrativeRuntimeSnapshotValidator();

    test('accepts a compatible aggregate checkpoint', () {
      final fixture = _fixture();

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        returnsNormally,
      );
    });

    test('accepts an empty aggregate runtime', () {
      final fixture = _fixture(includeSession: false);

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        returnsNormally,
      );
    });

    test('rejects unsupported aggregate metadata', () {
      final fixture = _fixture();
      final changed = _copyAggregate(
        fixture.snapshot,
        metadata: StoryNarrativeRuntimeSnapshotMetadata(
          formatVersion:
              StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion + 1,
        ),
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .unsupportedFormatVersion,
          ),
        ),
      );
    });

    test('rejects a cross-project aggregate checkpoint', () {
      final fixture = _fixture();
      final changedProject = StoryProject(
        id: StoryProjectId('project_other'),
        stateSchema: fixture.project.stateSchema,
        events: fixture.project.events,
      );

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: changedProject,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
          ),
        ),
      );
    });

    test(
      'persistent-state compatibility follows the existing scalar contract',
      () {
        final fixture = _fixture();
        final changedProject = StoryProject(
          id: fixture.project.id,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: fixture.variableId,
                type: StoryValueType.string,
              ),
            ],
          ),
          events: fixture.project.events,
        );

        expect(
          () => validator.validate(
            snapshot: fixture.snapshot,
            project: changedProject,
            entryPoints: fixture.entryPoints,
          ),
          throwsA(
            _issue(
              StoryNarrativeRuntimeSnapshotCompatibilityIssue
                  .persistentStateSchemaMismatch,
            ),
          ),
        );
      },
    );

    test('allows compatible scalar schema metadata changes', () {
      final fixture = _fixture();
      final compatibleProject = StoryProject(
        id: fixture.project.id,
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: fixture.variableId,
              alias: StoryAlias('renamed_score'),
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(99),
            ),
          ],
        ),
        events: fixture.project.events,
      );

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: compatibleProject,
          entryPoints: fixture.entryPoints,
        ),
        returnsNormally,
      );
    });

    test('rejects incompatible orchestration random state', () {
      final fixture = _fixture();
      final changed = _copyAggregate(
        fixture.snapshot,
        orchestrationRandomState: StoryRuntimeRandomState(
          algorithmId: 'story_engine.unknown_rng',
          algorithmVersion: 1,
          stateWords: const [1, 1],
        ),
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .unsupportedOrchestrationRandomAlgorithm,
          ),
        ),
      );
    });

    test('rejects malformed orchestration random-state payload', () {
      final fixture = _fixture();
      final changed = _copyAggregate(
        fixture.snapshot,
        orchestrationRandomState: StoryRuntimeRandomState(
          algorithmId: 'story_engine.lcg32',
          algorithmVersion: 1,
          stateWords: const [1],
        ),
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .invalidOrchestrationRandomState,
          ),
        ),
      );
    });

    test('rejects duplicate restore entry-point identity', () {
      final fixture = _fixture();

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
          entryPoints: [fixture.entryPoints.single, fixture.entryPoints.single],
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .duplicateEntryPointId,
          ),
        ),
      );
    });

    test('rejects a restore entry point targeting a missing event', () {
      final fixture = _fixture();
      final invalidEntry = StoryEntryPoint(
        id: fixture.entryPointId,
        eventId: StoryEventId('event_missing'),
      );

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
          entryPoints: [invalidEntry],
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .missingEntryPointEvent,
          ),
        ),
      );
    });

    test('requires contiguous retained session activation indexes', () {
      final fixture = _fixture();
      final session = fixture.snapshot.sessions.single;
      final changedSession = StoryNarrativeSessionSnapshot(
        sessionIndex: 1,
        entryPointId: session.entryPointId,
        runtimeSnapshot: session.runtimeSnapshot,
        hostActionSnapshot: StoryHostActionProtocolSnapshot(
          scope: 'session_1',
          nextRequestOrdinal: 0,
          pendingRequest: null,
        ),
      );
      final changed = _copyAggregate(
        fixture.snapshot,
        sessions: [changedSession],
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .invalidSessionIndexSequence,
          ),
        ),
      );
    });

    test('requires next session identity to follow retained sessions', () {
      final fixture = _fixture();
      final changed = _copyAggregate(fixture.snapshot, nextSessionIndex: 2);

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .invalidNextSessionIndex,
          ),
        ),
      );
    });

    test('requires every retained entry point in restore configuration', () {
      final fixture = _fixture();

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
          entryPoints: const <StoryEntryPoint>[],
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .missingSessionEntryPoint,
          ),
        ),
      );
    });

    test(
      'wraps core snapshot incompatibility with its nested path and cause',
      () {
        final fixture = _fixture();
        final session = fixture.snapshot.sessions.single;
        final incompatibleCore = StoryRuntimeSnapshot(
          projectId: StoryProjectId('project_nested_other'),
          status: session.runtimeSnapshot.status,
          state: session.runtimeSnapshot.state,
          currentEventId: session.runtimeSnapshot.currentEventId,
          history: session.runtimeSnapshot.history,
          randomState: session.runtimeSnapshot.randomState,
          maxAutomaticTransitions:
              session.runtimeSnapshot.maxAutomaticTransitions,
        );
        final changed = _copyAggregate(
          fixture.snapshot,
          sessions: [_copySession(session, runtimeSnapshot: incompatibleCore)],
        );

        expect(
          () => validator.validate(
            snapshot: changed,
            project: fixture.project,
            entryPoints: fixture.entryPoints,
          ),
          throwsA(
            isA<StoryNarrativeRuntimeSnapshotCompatibilityException>()
                .having(
                  (error) => error.issue,
                  'issue',
                  StoryNarrativeRuntimeSnapshotCompatibilityIssue
                      .sessionRuntimeSnapshotIncompatible,
                )
                .having(
                  (error) => error.path,
                  'path',
                  r'$.sessions[0].runtimeSnapshot.projectId',
                )
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<StoryRuntimeSnapshotCompatibilityException>(),
                ),
          ),
        );
      },
    );

    test(
      'requires one automatic-transition guard for the aggregate runtime',
      () {
        final fixture = _fixture();
        final session = fixture.snapshot.sessions.single;
        final changedCore = _copyCore(
          session.runtimeSnapshot,
          maxAutomaticTransitions: fixture.snapshot.maxAutomaticTransitions + 1,
        );
        final changed = _copyAggregate(
          fixture.snapshot,
          sessions: [_copySession(session, runtimeSnapshot: changedCore)],
        );

        expect(
          () => validator.validate(
            snapshot: changed,
            project: fixture.project,
            entryPoints: fixture.entryPoints,
          ),
          throwsA(
            _issue(
              StoryNarrativeRuntimeSnapshotCompatibilityIssue
                  .sessionMaxAutomaticTransitionsMismatch,
            ),
          ),
        );
      },
    );

    test('rejects an unstarted retained narrative session', () {
      final fixture = _fixture();
      final session = fixture.snapshot.sessions.single;
      final unstarted = StoryRuntimeSnapshot(
        projectId: fixture.project.id,
        status: StoryEngineStatus.notStarted,
        state: null,
        currentEventId: null,
        history: StoryRuntimeHistory(),
        randomState: session.runtimeSnapshot.randomState,
        maxAutomaticTransitions: fixture.snapshot.maxAutomaticTransitions,
      );
      final changed = _copyAggregate(
        fixture.snapshot,
        sessions: [_copySession(session, runtimeSnapshot: unstarted)],
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue.unstartedSession,
          ),
        ),
      );
    });

    test('requires deterministic session host-action scope', () {
      final fixture = _fixture();
      final session = fixture.snapshot.sessions.single;
      final changed = _copyAggregate(
        fixture.snapshot,
        sessions: [
          _copySession(
            session,
            hostActionSnapshot: StoryHostActionProtocolSnapshot(
              scope: 'session_other',
              nextRequestOrdinal: 0,
              pendingRequest: null,
            ),
          ),
        ],
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .hostActionScopeMismatch,
          ),
        ),
      );
    });

    test('accepts a pending host action over a committed pause', () {
      final fixture = _fixture();
      final session = fixture.snapshot.sessions.single;
      final request = StoryHostActionRequest(
        id: StoryHostActionRequestId('host_action_session_0_0'),
        schemaNamespace: 'test.actions',
        actionId: 'show_dialog',
      );
      final changed = _copyAggregate(
        fixture.snapshot,
        sessions: [
          _copySession(
            session,
            hostActionSnapshot: StoryHostActionProtocolSnapshot(
              scope: 'session_0',
              nextRequestOrdinal: 1,
              pendingRequest: request,
            ),
          ),
        ],
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        returnsNormally,
      );
    });

    test(
      'pending host action requires a committed host-visible core pause',
      () {
        final fixture = _fixture(status: StoryEngineStatus.terminated);
        final session = fixture.snapshot.sessions.single;
        final request = StoryHostActionRequest(
          id: StoryHostActionRequestId('host_action_session_0_0'),
          schemaNamespace: 'test.actions',
          actionId: 'show_dialog',
        );
        final changed = _copyAggregate(
          fixture.snapshot,
          sessions: [
            _copySession(
              session,
              hostActionSnapshot: StoryHostActionProtocolSnapshot(
                scope: 'session_0',
                nextRequestOrdinal: 1,
                pendingRequest: request,
              ),
            ),
          ],
        );

        expect(
          () => validator.validate(
            snapshot: changed,
            project: fixture.project,
            entryPoints: fixture.entryPoints,
          ),
          throwsA(
            _issue(
              StoryNarrativeRuntimeSnapshotCompatibilityIssue
                  .invalidPendingHostActionState,
            ),
          ),
        );
      },
    );

    test(
      'unfinished sessions must carry current aggregate persistent state',
      () {
        final fixture = _fixture();
        final session = fixture.snapshot.sessions.single;
        final staleState = StoryState.fromValues(
          schema: fixture.project.stateSchema,
          values: {fixture.variableId: StoryIntegerValue(2)},
        );
        final changedCore = _copyCore(
          session.runtimeSnapshot,
          state: staleState,
        );
        final changed = _copyAggregate(
          fixture.snapshot,
          sessions: [_copySession(session, runtimeSnapshot: changedCore)],
        );

        expect(
          () => validator.validate(
            snapshot: changed,
            project: fixture.project,
            entryPoints: fixture.entryPoints,
          ),
          throwsA(
            _issue(
              StoryNarrativeRuntimeSnapshotCompatibilityIssue
                  .unfinishedSessionStateMismatch,
            ),
          ),
        );
      },
    );

    test('completed sessions may retain their historical committed state', () {
      final fixture = _fixture(status: StoryEngineStatus.terminated);
      final session = fixture.snapshot.sessions.single;
      final historicalState = StoryState.fromValues(
        schema: fixture.project.stateSchema,
        values: {fixture.variableId: StoryIntegerValue(2)},
      );
      final changedCore = _copyCore(
        session.runtimeSnapshot,
        state: historicalState,
      );
      final changed = _copyAggregate(
        fixture.snapshot,
        sessions: [_copySession(session, runtimeSnapshot: changedCore)],
      );

      expect(
        () => validator.validate(
          snapshot: changed,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        returnsNormally,
      );
    });

    test('session history must originate at its stored entry point', () {
      final fixture = _fixture();
      final mismatchedEntry = StoryEntryPoint(
        id: fixture.entryPointId,
        eventId: fixture.otherEventId,
      );

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
          entryPoints: [mismatchedEntry],
        ),
        throwsA(
          _issue(
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .sessionEntryPointOriginMismatch,
          ),
        ),
      );
    });
  });
}

Matcher _issue(StoryNarrativeRuntimeSnapshotCompatibilityIssue issue) =>
    isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
      (error) => error.issue,
      'issue',
      issue,
    );

({
  StoryProject project,
  List<StoryEntryPoint> entryPoints,
  StoryEntryPointId entryPointId,
  StoryEventId otherEventId,
  StoryVariableId variableId,
  StoryNarrativeRuntimeSnapshot snapshot,
})
_fixture({
  bool includeSession = true,
  StoryEngineStatus status = StoryEngineStatus.awaitingContinue,
}) {
  final projectId = StoryProjectId('project_stage9a3');
  final variableId = StoryVariableId('var_score');
  final eventId = StoryEventId('event_primary');
  final otherEventId = StoryEventId('event_other');
  final entryPointId = StoryEntryPointId('entry_primary');
  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: variableId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(1),
      ),
    ],
  );
  final project = StoryProject(
    id: projectId,
    stateSchema: schema,
    events: [
      StoryEvent(
        id: eventId,
        continuationTransition: const StoryTerminalTransition(),
      ),
      StoryEvent(
        id: otherEventId,
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  final state = StoryState.initial(schema);
  final history = StoryRuntimeHistory(
    steps: [
      StoryEventEnteredStep(eventId: eventId),
      if (status == StoryEngineStatus.terminated)
        StoryEventContinuedStep(eventId: eventId),
    ],
  );
  final core = StoryRuntimeSnapshot(
    projectId: projectId,
    status: status,
    state: state,
    currentEventId: eventId,
    history: history,
    randomState: _randomState(7, 7),
    maxAutomaticTransitions: 64,
  );
  final session = StoryNarrativeSessionSnapshot(
    sessionIndex: 0,
    entryPointId: entryPointId,
    runtimeSnapshot: core,
    hostActionSnapshot: StoryHostActionProtocolSnapshot(
      scope: 'session_0',
      nextRequestOrdinal: 0,
      pendingRequest: null,
    ),
  );

  return (
    project: project,
    entryPoints: [StoryEntryPoint(id: entryPointId, eventId: eventId)],
    entryPointId: entryPointId,
    otherEventId: otherEventId,
    variableId: variableId,
    snapshot: StoryNarrativeRuntimeSnapshot(
      projectId: projectId,
      persistentState: state,
      persistentStateRevision: 3,
      orchestrationRandomState: _randomState(11, 19),
      maxAutomaticTransitions: 64,
      nextSessionIndex: includeSession ? 1 : 0,
      nextObservationSequence: 9,
      sessions: includeSession ? [session] : const [],
    ),
  );
}

StoryNarrativeRuntimeSnapshot _copyAggregate(
  StoryNarrativeRuntimeSnapshot source, {
  StoryNarrativeRuntimeSnapshotMetadata? metadata,
  StoryRuntimeRandomState? orchestrationRandomState,
  int? nextSessionIndex,
  Iterable<StoryNarrativeSessionSnapshot>? sessions,
}) => StoryNarrativeRuntimeSnapshot(
  metadata: metadata ?? source.metadata,
  projectId: source.projectId,
  persistentState: source.persistentState,
  persistentStateRevision: source.persistentStateRevision,
  orchestrationRandomState:
      orchestrationRandomState ?? source.orchestrationRandomState,
  maxAutomaticTransitions: source.maxAutomaticTransitions,
  nextSessionIndex: nextSessionIndex ?? source.nextSessionIndex,
  nextObservationSequence: source.nextObservationSequence,
  sessions: sessions ?? source.sessions,
);

StoryNarrativeSessionSnapshot _copySession(
  StoryNarrativeSessionSnapshot source, {
  StoryRuntimeSnapshot? runtimeSnapshot,
  StoryHostActionProtocolSnapshot? hostActionSnapshot,
}) => StoryNarrativeSessionSnapshot(
  sessionIndex: source.sessionIndex,
  entryPointId: source.entryPointId,
  runtimeSnapshot: runtimeSnapshot ?? source.runtimeSnapshot,
  hostActionSnapshot: hostActionSnapshot ?? source.hostActionSnapshot,
);

StoryRuntimeSnapshot _copyCore(
  StoryRuntimeSnapshot source, {
  StoryState? state,
  int? maxAutomaticTransitions,
}) => StoryRuntimeSnapshot(
  metadata: source.metadata,
  projectId: source.projectId,
  status: source.status,
  state: state ?? source.state,
  currentEventId: source.currentEventId,
  history: source.history,
  randomState: source.randomState,
  maxAutomaticTransitions:
      maxAutomaticTransitions ?? source.maxAutomaticTransitions,
);

StoryRuntimeRandomState _randomState(int initialSeed, int currentState) =>
    StoryRuntimeRandomState(
      algorithmId: 'story_engine.lcg32',
      algorithmVersion: 1,
      stateWords: [initialSeed, currentState],
    );
