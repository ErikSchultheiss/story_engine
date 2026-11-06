import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeSnapshotMetadata', () {
    test('defaults to the current independent compatibility versions', () {
      const metadata = StoryRuntimeSnapshotMetadata();

      expect(
        metadata.formatVersion,
        StoryRuntimeSnapshotMetadata.currentFormatVersion,
      );
      expect(
        metadata.runtimeContractVersion,
        StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion,
      );
      expect(metadata, const StoryRuntimeSnapshotMetadata());
    });
  });

  group('StoryRuntimeRandomState', () {
    test('owns an immutable algorithm-versioned state payload', () {
      final source = <int>[1, 2, 3];
      final state = StoryRuntimeRandomState(
        algorithmId: 'story_engine.test_rng',
        algorithmVersion: 2,
        stateWords: source,
      );

      source[0] = 999;

      expect(state.algorithmId, 'story_engine.test_rng');
      expect(state.algorithmVersion, 2);
      expect(state.stateWords, [1, 2, 3]);
      expect(() => state.stateWords.add(4), throwsA(isA<UnsupportedError>()));
      expect(
        state,
        StoryRuntimeRandomState(
          algorithmId: 'story_engine.test_rng',
          algorithmVersion: 2,
          stateWords: const [1, 2, 3],
        ),
      );
    });

    test('rejects malformed algorithm metadata and state words', () {
      expect(
        () => StoryRuntimeRandomState(
          algorithmId: 'Bad RNG',
          algorithmVersion: 1,
          stateWords: const [1],
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryRuntimeRandomState(
          algorithmId: 'story_engine.test_rng',
          algorithmVersion: 0,
          stateWords: const [1],
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryRuntimeRandomState(
          algorithmId: 'story_engine.test_rng',
          algorithmVersion: 1,
          stateWords: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryRuntimeRandomState(
          algorithmId: 'story_engine.test_rng',
          algorithmVersion: 1,
          stateWords: const [-1],
        ),
        throwsArgumentError,
      );
    });
  });

  group('StoryRuntimeSnapshot committed shape', () {
    test('supports a committed before-start snapshot', () {
      final snapshot = StoryRuntimeSnapshot(
        projectId: StoryProjectId('project_snapshot_before_start'),
        status: StoryEngineStatus.notStarted,
        state: null,
        currentEventId: null,
        history: StoryRuntimeHistory(),
        randomState: _randomState(),
        maxAutomaticTransitions: StoryEngine.defaultMaxAutomaticTransitions,
      );

      expect(snapshot.status, StoryEngineStatus.notStarted);
      expect(snapshot.state, isNull);
      expect(snapshot.currentEventId, isNull);
      expect(snapshot.history.isEmpty, isTrue);
      expect(snapshot.randomState, _randomState());
    });

    for (final status in [
      StoryEngineStatus.awaitingChoice,
      StoryEngineStatus.awaitingContinue,
      StoryEngineStatus.terminated,
    ]) {
      test('supports committed ${status.name} runtime shape', () {
        final fixture = _startedFixture(status);
        final snapshot = fixture.snapshot;

        expect(snapshot.status, status);
        expect(snapshot.state, fixture.state);
        expect(snapshot.currentEventId, fixture.currentEventId);
        expect(snapshot.history.eventRoute, [fixture.currentEventId]);
        expect(snapshot.maxAutomaticTransitions, 77);
      });
    }

    test('rejects not-started snapshots carrying committed runtime data', () {
      final fixture = _startedFixture(StoryEngineStatus.awaitingChoice);

      expect(
        () => StoryRuntimeSnapshot(
          projectId: StoryProjectId('project_invalid_not_started'),
          status: StoryEngineStatus.notStarted,
          state: fixture.state,
          currentEventId: fixture.currentEventId,
          history: fixture.snapshot.history,
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects started snapshots without state/current event/history', () {
      expect(
        () => StoryRuntimeSnapshot(
          projectId: StoryProjectId('project_invalid_started'),
          status: StoryEngineStatus.awaitingChoice,
          state: null,
          currentEventId: null,
          history: StoryRuntimeHistory(),
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a history whose latest entered event is not current', () {
      final schema = StoryStateSchema.empty();
      final state = StoryState.initial(schema);
      final currentEventId = StoryEventId('event_current');
      final otherEventId = StoryEventId('event_other');

      expect(
        () => StoryRuntimeSnapshot(
          projectId: StoryProjectId('project_wrong_history_tail'),
          status: StoryEngineStatus.awaitingContinue,
          state: state,
          currentEventId: currentEventId,
          history: StoryRuntimeHistory(
            steps: [StoryEventEnteredStep(eventId: otherEventId)],
          ),
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-positive execution-affecting runtime configuration', () {
      expect(
        () => StoryRuntimeSnapshot(
          projectId: StoryProjectId('project_invalid_limit'),
          status: StoryEngineStatus.notStarted,
          state: null,
          currentEventId: null,
          history: StoryRuntimeHistory(),
          randomState: _randomState(),
          maxAutomaticTransitions: 0,
        ),
        throwsArgumentError,
      );
    });

    test('history remains the only persisted structural route source', () {
      final eventId = StoryEventId('event_loop');
      final choiceId = StoryChoiceId('choice_loop');
      final snapshot = StoryRuntimeSnapshot(
        projectId: StoryProjectId('project_history_source'),
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.initial(StoryStateSchema.empty()),
        currentEventId: eventId,
        history: StoryRuntimeHistory(
          steps: [
            StoryEventEnteredStep(eventId: eventId),
            StoryChoiceSelectedStep(eventId: eventId, choiceId: choiceId),
            StoryEventEnteredStep(eventId: eventId),
          ],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(snapshot.history.eventRoute, [eventId, eventId]);
      expect(snapshot.history.selectedChoiceIds, [choiceId]);
      expect(snapshot.history.eventOccurrenceCount(eventId), 2);
    });
  });
}

StoryRuntimeRandomState _randomState() => StoryRuntimeRandomState(
  algorithmId: 'story_engine.test_rng',
  algorithmVersion: 1,
  stateWords: const [123456789],
);

({StoryRuntimeSnapshot snapshot, StoryState state, StoryEventId currentEventId})
_startedFixture(StoryEngineStatus status) {
  final variableId = StoryVariableId('var_snapshot_value');
  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: variableId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(3),
      ),
    ],
  );
  final state = StoryState.initial(schema);
  final currentEventId = StoryEventId('event_snapshot_current');
  return (
    snapshot: StoryRuntimeSnapshot(
      projectId: StoryProjectId('project_snapshot_started'),
      status: status,
      state: state,
      currentEventId: currentEventId,
      history: StoryRuntimeHistory(
        steps: [StoryEventEnteredStep(eventId: currentEventId)],
      ),
      randomState: _randomState(),
      maxAutomaticTransitions: 77,
    ),
    state: state,
    currentEventId: currentEventId,
  );
}
