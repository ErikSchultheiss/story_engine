import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryNarrativeRuntimeSnapshotCodec', () {
    final codec = StoryNarrativeRuntimeSnapshotCodec();

    test('emits the canonical deterministic aggregate format-v1 fixture', () {
      final fixture = _fixture();
      final golden = File(
        'test/fixtures/narrative_runtime_snapshot_v1.json',
      ).readAsStringSync().trim();

      expect(codec.encodeJson(fixture.snapshot), golden);
      expect(codec.encodeJson(fixture.snapshot), golden);
    });

    test(
      'round-trips aggregate state, sessions, core snapshot, and host action',
      () {
        final fixture = _fixture();
        final decoded = codec.decode(
          codec.encode(fixture.snapshot),
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        );

        expect(decoded.metadata, fixture.snapshot.metadata);
        expect(decoded.projectId, fixture.snapshot.projectId);
        expect(decoded.persistentState, fixture.snapshot.persistentState);
        expect(
          decoded.persistentStateRevision,
          fixture.snapshot.persistentStateRevision,
        );
        expect(
          decoded.orchestrationRandomState,
          fixture.snapshot.orchestrationRandomState,
        );
        expect(
          decoded.maxAutomaticTransitions,
          fixture.snapshot.maxAutomaticTransitions,
        );
        expect(decoded.nextSessionIndex, fixture.snapshot.nextSessionIndex);
        expect(
          decoded.nextObservationSequence,
          fixture.snapshot.nextObservationSequence,
        );
        expect(decoded.sessions, hasLength(1));

        final actualSession = decoded.sessions.single;
        final expectedSession = fixture.snapshot.sessions.single;
        expect(actualSession.sessionIndex, expectedSession.sessionIndex);
        expect(actualSession.entryPointId, expectedSession.entryPointId);
        expect(actualSession.runtimeSnapshot, expectedSession.runtimeSnapshot);
        expect(
          actualSession.hostActionSnapshot.scope,
          expectedSession.hostActionSnapshot.scope,
        );
        expect(
          actualSession.hostActionSnapshot.nextRequestOrdinal,
          expectedSession.hostActionSnapshot.nextRequestOrdinal,
        );
        expect(
          actualSession.hostActionSnapshot.pendingRequest,
          expectedSession.hostActionSnapshot.pendingRequest,
        );
      },
    );

    test(
      'round-trips an empty runtime without losing future-session config',
      () {
        final fixture = _fixture();
        final empty = StoryNarrativeRuntimeSnapshot(
          projectId: fixture.snapshot.projectId,
          persistentState: fixture.snapshot.persistentState,
          persistentStateRevision: fixture.snapshot.persistentStateRevision,
          orchestrationRandomState: fixture.snapshot.orchestrationRandomState,
          maxAutomaticTransitions: 91,
          nextSessionIndex: 0,
          nextObservationSequence: 17,
        );

        final decoded = codec.decode(
          codec.encode(empty),
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        );

        expect(decoded.sessions, isEmpty);
        expect(decoded.maxAutomaticTransitions, 91);
        expect(decoded.nextSessionIndex, 0);
        expect(decoded.nextObservationSequence, 17);
        expect(
          decoded.orchestrationRandomState,
          empty.orchestrationRandomState,
        );
      },
    );

    test('decodes the checked-in format-v1 golden fixture', () {
      final fixture = _fixture();
      final source = File(
        'test/fixtures/narrative_runtime_snapshot_v1.json',
      ).readAsStringSync();

      final decoded = codec.decodeJson(
        source,
        project: fixture.project,
        entryPoints: fixture.entryPoints,
      );

      expect(decoded.projectId, fixture.snapshot.projectId);
      expect(
        decoded.sessions.single.runtimeSnapshot,
        fixture.snapshot.sessions.single.runtimeSnapshot,
      );
      expect(
        decoded.sessions.single.hostActionSnapshot.pendingRequest,
        fixture.snapshot.sessions.single.hostActionSnapshot.pendingRequest,
      );
    });

    test(
      'stores shared state once without duplicating the authored schema',
      () {
        final encoded = codec.encode(_fixture().snapshot);
        final state = encoded['persistentState']! as Map<String, Object?>;

        expect(state.keys, ['values']);
        expect(state, isNot(contains('schema')));
        expect(state, isNot(contains('variables')));
      },
    );

    test('embeds existing core and host-action versioned documents intact', () {
      final encoded = codec.encode(_fixture().snapshot);
      final sessions = encoded['sessions']! as List<Object?>;
      final session = sessions.single! as Map<String, Object?>;
      final runtime = session['runtimeSnapshot']! as Map<String, Object?>;
      final host = session['hostActionSnapshot']! as Map<String, dynamic>;

      expect(runtime['documentType'], StoryRuntimeSnapshotCodec.documentType);
      expect(
        runtime['formatVersion'],
        StoryRuntimeSnapshotMetadata.currentFormatVersion,
      );
      expect(host['contract'], StoryHostActionProtocolSnapshotCodec.contract);
      expect(
        host['contractVersion'],
        StoryHostActionProtocolSnapshotCodec.contractVersion,
      );
    });

    test('rejects invalid JSON as malformed aggregate data', () {
      final fixture = _fixture();

      expect(
        () => codec.decodeJson(
          '{broken',
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotFormatException>()
              .having((error) => error.path, 'path', r'$')
              .having(
                (error) => error.message,
                'message',
                contains('not valid JSON'),
              ),
        ),
      );
    });

    test('rejects unknown fields rather than silently discarding them', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['futureField'] = true;

      expect(
        () => codec.decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotFormatException>().having(
            (error) => error.path,
            'path',
            r'$.futureField',
          ),
        ),
      );
    });

    test('rejects malformed nested core snapshot with aggregate path', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final sessions = encoded['sessions']! as List<Object?>;
      final session = sessions.single! as Map<String, Object?>;
      final runtime = session['runtimeSnapshot']! as Map<String, Object?>;
      runtime['status'] = 'sleeping';

      expect(
        () => codec.decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotFormatException>()
              .having(
                (error) => error.path,
                'path',
                r'$.sessions[0].runtimeSnapshot.status',
              )
              .having(
                (error) => error.cause,
                'cause',
                isA<StoryRuntimeSnapshotFormatException>(),
              ),
        ),
      );
    });

    test('wraps nested core compatibility failure with aggregate identity', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final sessions = encoded['sessions']! as List<Object?>;
      final session = sessions.single! as Map<String, Object?>;
      final runtime = session['runtimeSnapshot']! as Map<String, Object?>;
      runtime['projectId'] = 'project_other';

      expect(
        () => codec.decode(
          encoded,
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
    });

    test(
      'rejects malformed nested host-action snapshot with aggregate path',
      () {
        final fixture = _fixture();
        final encoded = codec.encode(fixture.snapshot);
        final sessions = encoded['sessions']! as List<Object?>;
        final session = sessions.single! as Map<String, Object?>;
        final host = session['hostActionSnapshot']! as Map<String, dynamic>;
        host['futureField'] = true;

        expect(
          () => codec.decode(
            encoded,
            project: fixture.project,
            entryPoints: fixture.entryPoints,
          ),
          throwsA(
            isA<StoryNarrativeRuntimeSnapshotFormatException>()
                .having(
                  (error) => error.path,
                  'path',
                  r'$.sessions[0].hostActionSnapshot',
                )
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<StoryHostActionProtocolSnapshotFormatException>(),
                ),
          ),
        );
      },
    );

    test('rejects duplicate aggregate persistent-state variables', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final state = encoded['persistentState']! as Map<String, Object?>;
      final values = state['values']! as List<Object?>;
      values.add(
        Map<String, Object?>.of(values.single! as Map<String, Object?>),
      );

      expect(
        () => codec.decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotFormatException>().having(
            (error) => error.message,
            'message',
            contains('duplicate variable ID'),
          ),
        ),
      );
    });

    test('rejects a newer aggregate format as incompatible', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['formatVersion'] =
          StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion + 1;

      expect(
        () => codec.decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .unsupportedFormatVersion,
          ),
        ),
      );
    });

    test('rejects an unsupported aggregate runtime contract', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['runtimeContractVersion'] =
          StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion +
          1;

      expect(
        () => codec.decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .unsupportedRuntimeContractVersion,
          ),
        ),
      );
    });

    test('rejects a cross-project aggregate document before state decode', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final other = StoryProject(
        id: StoryProjectId('project_other'),
        stateSchema: fixture.project.stateSchema,
        events: fixture.project.events,
      );

      expect(
        () => codec.decode(
          encoded,
          project: other,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryNarrativeRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
          ),
        ),
      );
    });

    test('decode finishes aggregate semantic validation before returning', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['nextSessionIndex'] = 4;

      expect(
        () => codec.decode(
          encoded,
          project: fixture.project,
          entryPoints: fixture.entryPoints,
        ),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .invalidNextSessionIndex,
          ),
        ),
      );
    });

    test('encode refuses non-current in-memory aggregate metadata', () {
      final fixture = _fixture();
      final changed = StoryNarrativeRuntimeSnapshot(
        metadata: StoryNarrativeRuntimeSnapshotMetadata(
          formatVersion:
              StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion + 1,
        ),
        projectId: fixture.snapshot.projectId,
        persistentState: fixture.snapshot.persistentState,
        persistentStateRevision: fixture.snapshot.persistentStateRevision,
        orchestrationRandomState: fixture.snapshot.orchestrationRandomState,
        maxAutomaticTransitions: fixture.snapshot.maxAutomaticTransitions,
        nextSessionIndex: fixture.snapshot.nextSessionIndex,
        nextObservationSequence: fixture.snapshot.nextObservationSequence,
        sessions: fixture.snapshot.sessions,
      );

      expect(
        () => codec.encode(changed),
        throwsA(
          isA<StoryNarrativeRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryNarrativeRuntimeSnapshotCompatibilityIssue
                .unsupportedFormatVersion,
          ),
        ),
      );
    });

    test(
      'JSON representation carries stable aggregate compatibility metadata',
      () {
        final encoded =
            jsonDecode(codec.encodeJson(_fixture().snapshot))
                as Map<String, Object?>;

        expect(
          encoded['documentType'],
          StoryNarrativeRuntimeSnapshotCodec.documentType,
        );
        expect(
          encoded['formatVersion'],
          StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion,
        );
        expect(
          encoded['runtimeContractVersion'],
          StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion,
        );
      },
    );
  });
}

({
  StoryProject project,
  List<StoryEntryPoint> entryPoints,
  StoryNarrativeRuntimeSnapshot snapshot,
})
_fixture() {
  final projectId = StoryProjectId('project_stage9a4');
  final variableId = StoryVariableId('var_score');
  final eventId = StoryEventId('event_primary');
  final entryPointId = StoryEntryPointId('entry_primary');
  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: variableId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(5),
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
    ],
  );
  final state = StoryState.initial(schema);
  final core = StoryRuntimeSnapshot(
    projectId: projectId,
    status: StoryEngineStatus.awaitingContinue,
    state: state,
    currentEventId: eventId,
    history: StoryRuntimeHistory(
      steps: [StoryEventEnteredStep(eventId: eventId)],
    ),
    randomState: _randomState(7, 9),
    maxAutomaticTransitions: 64,
  );
  final pendingRequest = StoryHostActionRequest(
    id: StoryHostActionRequestId('host_action_session_0_0'),
    schemaNamespace: 'test.actions',
    actionId: 'show_dialog',
    arguments: const {'priority': 2, 'message': 'Continue?'},
    resultType: const StoryHostActionValueType.string(),
  );
  final session = StoryNarrativeSessionSnapshot(
    sessionIndex: 0,
    entryPointId: entryPointId,
    runtimeSnapshot: core,
    hostActionSnapshot: StoryHostActionProtocolSnapshot(
      scope: 'session_0',
      nextRequestOrdinal: 1,
      pendingRequest: pendingRequest,
    ),
  );

  return (
    project: project,
    entryPoints: [StoryEntryPoint(id: entryPointId, eventId: eventId)],
    snapshot: StoryNarrativeRuntimeSnapshot(
      projectId: projectId,
      persistentState: state,
      persistentStateRevision: 3,
      orchestrationRandomState: _randomState(11, 19),
      maxAutomaticTransitions: 64,
      nextSessionIndex: 1,
      nextObservationSequence: 9,
      sessions: [session],
    ),
  );
}

StoryRuntimeRandomState _randomState(int initialSeed, int currentState) =>
    StoryRuntimeRandomState(
      algorithmId: 'story_engine.lcg32',
      algorithmVersion: 1,
      stateWords: [initialSeed, currentState],
    );
