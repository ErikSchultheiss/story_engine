import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../benchmark/support/finalization_stage4_load_path.dart';

void main() {
  late AggregateLoadFixture fixture;
  setUp(() {
    fixture = AggregateLoadFixture.build(
      const AggregateLoadScenario('test', 6, 12, 32, 8),
    );
  });
  test(
    'JSON load preserves all retained checkpoints and future random state',
    () {
      final loaded = fixture.loadJson();
      expect(fixture.verify(loaded), hasLength(64));
      final sessions = fixture.snapshot.sessions;
      expect(sessions[0].runtimeSnapshot.status, StoryEngineStatus.terminated);
      expect(
        sessions[0].runtimeSnapshot.state,
        isNot(fixture.snapshot.persistentState),
      );
      expect(sessions[1].hostActionSnapshot.pendingRequest, isNotNull);
      expect(
        sessions[1].runtimeSnapshot.state,
        fixture.snapshot.persistentState,
      );
    },
  );
  test(
    'restore with subscribed observer emits no replay then continues normally',
    () {
      final observer = _Observer();
      final decoded = StoryNarrativeRuntimeSnapshotCodec().decodeJson(
        fixture.json,
        project: fixture.project,
        entryPoints: fixture.entryPoints,
      );
      final restored = StoryNarrativeRuntime.restore(
        project: fixture.project,
        entryPoints: fixture.entryPoints,
        snapshot: decoded,
        observers: [observer],
      );
      expect(observer.count, 0);
      expect(
        StoryNarrativeRuntimeSnapshotCodec().encodeJson(
          restored.createSnapshot(),
        ),
        fixture.json,
      );
      restored.sessionByIndex(3).choose(StoryChoiceId('repeat'));
      expect(observer.count, greaterThan(0));
    },
  );
  final corruptions =
      <String, StoryRuntimeSnapshot Function(StoryRuntimeSnapshot)>{
        'metadata': (s) => _core(
          s,
          metadata: const StoryRuntimeSnapshotMetadata(
            runtimeContractVersion: 99,
          ),
        ),
        'project identity': (s) =>
            _core(s, projectId: StoryProjectId('wrong_project')),
        'RNG': (s) => _core(
          s,
          randomState: StoryRuntimeRandomState(
            algorithmId: 'story_engine.unknown',
            algorithmVersion: 1,
            stateWords: [1, 1],
          ),
        ),
        'schema': (s) {
          final schema = StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: StoryVariableId('score'),
                type: StoryValueType.boolean,
              ),
            ],
          );
          return _core(
            s,
            state: StoryState.fromValues(
              schema: schema,
              values: {StoryVariableId('score'): StoryBooleanValue(true)},
            ),
          );
        },
        'history choice': (s) => _core(
          s,
          history: StoryRuntimeHistory(
            steps: [
              StoryEventEnteredStep(eventId: StoryEventId('route')),
              StoryChoiceSelectedStep(
                eventId: StoryEventId('route'),
                choiceId: StoryChoiceId('missing'),
              ),
              StoryEventEnteredStep(eventId: StoryEventId('route')),
            ],
          ),
        ),
        'guard': (s) =>
            _core(s, maxAutomaticTransitions: s.maxAutomaticTransitions + 1),
      };
  for (final corruption in corruptions.entries) {
    test('later retained session still validates ${corruption.key}', () {
      final sessions = fixture.snapshot.sessions.toList();
      final last = sessions.last;
      sessions[sessions.length - 1] = StoryNarrativeSessionSnapshot(
        sessionIndex: last.sessionIndex,
        entryPointId: last.entryPointId,
        runtimeSnapshot: corruption.value(last.runtimeSnapshot),
        hostActionSnapshot: last.hostActionSnapshot,
      );
      final snapshot = _aggregate(fixture.snapshot, sessions);
      final expected =
          isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
            (e) => e.path,
            'later-session path',
            startsWith(r'$.sessions[5].runtimeSnapshot'),
          );
      expect(
        () => const StoryNarrativeRuntimeSnapshotValidator().validate(
          snapshot: snapshot,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(expected),
      );
      final observer = _Observer();
      expect(
        () => StoryNarrativeRuntime.restore(
          project: fixture.project,
          entryPoints: fixture.entryPoints,
          snapshot: snapshot,
          observers: [observer],
        ),
        throwsA(expected),
      );
      expect(observer.count, 0);
      final encoded = StoryNarrativeRuntimeSnapshotCodec().encode(
        fixture.snapshot,
      );
      final rawSessions = encoded['sessions']! as List<Object?>;
      final rawLast = rawSessions.last! as Map<String, Object?>;
      if (corruption.key == 'metadata') {
        (rawLast['runtimeSnapshot']!
                as Map<String, Object?>)['runtimeContractVersion'] =
            99;
      } else {
        rawLast['runtimeSnapshot'] = StoryRuntimeSnapshotCodec().encode(
          sessions.last.runtimeSnapshot,
        );
      }
      expect(
        () => StoryNarrativeRuntimeSnapshotCodec().decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(expected),
      );
    });
  }
  test(
    'a distinct same-ID project is validated against its own authored nodes',
    () {
      final changed = StoryProject(
        id: fixture.project.id,
        stateSchema: fixture.project.stateSchema,
        entryEventId: StoryEventId('route'),
        events: [
          StoryEvent(
            id: StoryEventId('route'),
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      expect(
        () => StoryNarrativeRuntime.restore(
          project: changed,
          entryPoints: fixture.entryPoints,
          snapshot: fixture.snapshot,
        ),
        throwsA(isA<StoryNarrativeRuntimeSnapshotCompatibilityException>()),
      );
      expect(fixture.verify(fixture.loadJson()), hasLength(64));
    },
  );
}

StoryRuntimeSnapshot _core(
  StoryRuntimeSnapshot s, {
  StoryRuntimeSnapshotMetadata? metadata,
  StoryProjectId? projectId,
  StoryState? state,
  StoryRuntimeHistory? history,
  StoryRuntimeRandomState? randomState,
  int? maxAutomaticTransitions,
}) => StoryRuntimeSnapshot(
  metadata: metadata ?? s.metadata,
  projectId: projectId ?? s.projectId,
  status: s.status,
  state: state ?? s.state,
  currentEventId: s.currentEventId,
  history: history ?? s.history,
  randomState: randomState ?? s.randomState,
  maxAutomaticTransitions: maxAutomaticTransitions ?? s.maxAutomaticTransitions,
);
StoryNarrativeRuntimeSnapshot _aggregate(
  StoryNarrativeRuntimeSnapshot s,
  List<StoryNarrativeSessionSnapshot> sessions,
) => StoryNarrativeRuntimeSnapshot(
  metadata: s.metadata,
  projectId: s.projectId,
  persistentState: s.persistentState,
  persistentStateRevision: s.persistentStateRevision,
  orchestrationRandomState: s.orchestrationRandomState,
  maxAutomaticTransitions: s.maxAutomaticTransitions,
  nextSessionIndex: s.nextSessionIndex,
  nextObservationSequence: s.nextObservationSequence,
  sessions: sessions,
);

final class _Observer implements StoryNarrativeObserver {
  int count = 0;
  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    count++;
  }
}
