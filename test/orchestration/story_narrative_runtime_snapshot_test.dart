import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryNarrativeRuntimeSnapshotMetadata', () {
    test('owns independent aggregate compatibility versions', () {
      const metadata = StoryNarrativeRuntimeSnapshotMetadata();

      expect(
        metadata.formatVersion,
        StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion,
      );
      expect(
        metadata.runtimeContractVersion,
        StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion,
      );
      expect(metadata, const StoryNarrativeRuntimeSnapshotMetadata());
    });
  });

  group('StoryNarrativeRuntimeSnapshot', () {
    test('carries the complete Stage 9A2 aggregate value surface', () {
      final fixture = _fixture();
      final snapshot = fixture.snapshot;

      expect(snapshot.projectId, fixture.projectId);
      expect(snapshot.persistentState, fixture.state);
      expect(snapshot.persistentStateRevision, 7);
      expect(snapshot.orchestrationRandomState, fixture.randomState);
      expect(snapshot.maxAutomaticTransitions, 91);
      expect(snapshot.nextSessionIndex, 1);
      expect(snapshot.nextObservationSequence, 14);
      expect(snapshot.sessions, hasLength(1));
      expect(snapshot.sessions.single.sessionIndex, 0);
      expect(
        snapshot.sessions.single.entryPointId,
        StoryEntryPointId('entry_snapshot'),
      );
    });

    test('defensively owns an immutable retained-session list', () {
      final fixture = _fixture();
      final source = <StoryNarrativeSessionSnapshot>[
        fixture.snapshot.sessions.single,
      ];
      final snapshot = StoryNarrativeRuntimeSnapshot(
        projectId: fixture.projectId,
        persistentState: fixture.state,
        persistentStateRevision: 0,
        orchestrationRandomState: fixture.randomState,
        maxAutomaticTransitions: 10,
        nextSessionIndex: 1,
        nextObservationSequence: 0,
        sessions: source,
      );

      source.clear();

      expect(snapshot.sessions, hasLength(1));
      expect(
        () => snapshot.sessions.add(snapshot.sessions.single),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('supports an empty runtime while preserving future configuration', () {
      final projectId = StoryProjectId('project_empty_aggregate');
      final state = StoryState.initial(StoryStateSchema.empty());
      final randomState = _randomState(17, 17);
      final snapshot = StoryNarrativeRuntimeSnapshot(
        projectId: projectId,
        persistentState: state,
        persistentStateRevision: 0,
        orchestrationRandomState: randomState,
        maxAutomaticTransitions: 33,
        nextSessionIndex: 0,
        nextObservationSequence: 0,
      );

      expect(snapshot.sessions, isEmpty);
      expect(snapshot.maxAutomaticTransitions, 33);
      expect(snapshot.orchestrationRandomState, randomState);
    });

    test(
      'rejects invalid local numeric shape without doing 9A3 validation',
      () {
        final projectId = StoryProjectId('project_invalid_aggregate_shape');
        final state = StoryState.initial(StoryStateSchema.empty());
        final randomState = _randomState(1, 1);

        StoryNarrativeRuntimeSnapshot build({
          int persistentStateRevision = 0,
          int maxAutomaticTransitions = 10,
          int nextSessionIndex = 0,
          int nextObservationSequence = 0,
        }) => StoryNarrativeRuntimeSnapshot(
          projectId: projectId,
          persistentState: state,
          persistentStateRevision: persistentStateRevision,
          orchestrationRandomState: randomState,
          maxAutomaticTransitions: maxAutomaticTransitions,
          nextSessionIndex: nextSessionIndex,
          nextObservationSequence: nextObservationSequence,
        );

        expect(() => build(persistentStateRevision: -1), throwsArgumentError);
        expect(() => build(maxAutomaticTransitions: 0), throwsArgumentError);
        expect(() => build(nextSessionIndex: -1), throwsArgumentError);
        expect(() => build(nextObservationSequence: -1), throwsArgumentError);
        expect(
          () => build(nextSessionIndex: StoryIntegerValue.maxPortableValue + 1),
          throwsArgumentError,
        );
      },
    );

    test('leaves cross-session consistency to the Stage 9A3 validator', () {
      final fixture = _fixture();
      final session = fixture.snapshot.sessions.single;
      final dataOnly = StoryNarrativeRuntimeSnapshot(
        projectId: fixture.projectId,
        persistentState: fixture.state,
        persistentStateRevision: 0,
        orchestrationRandomState: fixture.randomState,
        maxAutomaticTransitions: 91,
        nextSessionIndex: 1,
        nextObservationSequence: 0,
        sessions: [session, session],
      );

      // Duplicate session indexes are invalid aggregate semantics, but 9A2 is
      // deliberately only the immutable data model. Stage 9A3 owns diagnosis.
      expect(dataOnly.sessions, hasLength(2));
      expect(
        dataOnly.sessions[0].sessionIndex,
        dataOnly.sessions[1].sessionIndex,
      );
    });
  });
}

({
  StoryNarrativeRuntimeSnapshot snapshot,
  StoryProjectId projectId,
  StoryState state,
  StoryRuntimeRandomState randomState,
})
_fixture() {
  final projectId = StoryProjectId('project_aggregate_snapshot');
  final state = StoryState.initial(StoryStateSchema.empty());
  final randomState = _randomState(123, 456);
  final eventId = StoryEventId('event_snapshot');
  final runtimeSnapshot = StoryRuntimeSnapshot(
    projectId: projectId,
    status: StoryEngineStatus.awaitingContinue,
    state: state,
    currentEventId: eventId,
    history: StoryRuntimeHistory(
      steps: [StoryEventEnteredStep(eventId: eventId)],
    ),
    randomState: _randomState(999, 999),
    maxAutomaticTransitions: 91,
  );
  final session = StoryNarrativeSessionSnapshot(
    sessionIndex: 0,
    entryPointId: StoryEntryPointId('entry_snapshot'),
    runtimeSnapshot: runtimeSnapshot,
    hostActionSnapshot: StoryHostActionProtocolSnapshot(
      scope: 'session_0',
      nextRequestOrdinal: 0,
      pendingRequest: null,
    ),
  );

  return (
    snapshot: StoryNarrativeRuntimeSnapshot(
      projectId: projectId,
      persistentState: state,
      persistentStateRevision: 7,
      orchestrationRandomState: randomState,
      maxAutomaticTransitions: 91,
      nextSessionIndex: 1,
      nextObservationSequence: 14,
      sessions: [session],
    ),
    projectId: projectId,
    state: state,
    randomState: randomState,
  );
}

StoryRuntimeRandomState _randomState(int initialSeed, int currentState) =>
    StoryRuntimeRandomState(
      algorithmId: 'story_engine.lcg32',
      algorithmVersion: 1,
      stateWords: [initialSeed, currentState],
    );
