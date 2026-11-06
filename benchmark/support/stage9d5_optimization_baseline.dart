import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';

/// One authored-project shape used by the Stage 9D5 clean before/after gate.
///
/// The dimensions intentionally vary project event/choice structure and state
/// schema size separately where practical. The executable route itself remains
/// the same two-event loop/commit fixture for every profile.
final class Stage9d5ProjectProfile {
  const Stage9d5ProjectProfile({
    required this.name,
    required this.paddingEventCount,
    required this.choicesPerPaddingEvent,
    required this.stateVariableCount,
  });

  final String name;
  final int paddingEventCount;
  final int choicesPerPaddingEvent;
  final int stateVariableCount;
}

const List<Stage9d5ProjectProfile> stage9d5ProjectProfiles =
    <Stage9d5ProjectProfile>[
      Stage9d5ProjectProfile(
        name: 'compact',
        paddingEventCount: 0,
        choicesPerPaddingEvent: 0,
        stateVariableCount: 1,
      ),
      Stage9d5ProjectProfile(
        name: 'event_heavy',
        paddingEventCount: 2048,
        choicesPerPaddingEvent: 0,
        stateVariableCount: 1,
      ),
      Stage9d5ProjectProfile(
        name: 'choice_heavy',
        paddingEventCount: 256,
        choicesPerPaddingEvent: 8,
        stateVariableCount: 1,
      ),
      Stage9d5ProjectProfile(
        name: 'state_heavy',
        paddingEventCount: 0,
        choicesPerPaddingEvent: 0,
        stateVariableCount: 256,
      ),
      Stage9d5ProjectProfile(
        name: 'combined_large',
        paddingEventCount: 2048,
        choicesPerPaddingEvent: 1,
        stateVariableCount: 256,
      ),
    ];

/// Retained history depth for restore/propagation before/after measurements.
final class Stage9d5HistoryProfile {
  const Stage9d5HistoryProfile({required this.name, required this.loopChoices});

  final String name;
  final int loopChoices;
}

const List<Stage9d5HistoryProfile> stage9d5RestoreHistoryProfiles =
    <Stage9d5HistoryProfile>[
      Stage9d5HistoryProfile(name: 'short', loopChoices: 8),
      Stage9d5HistoryProfile(name: 'long', loopChoices: 256),
    ];

const List<Stage9d5HistoryProfile> stage9d5IncrementalHistoryProfiles =
    <Stage9d5HistoryProfile>[
      Stage9d5HistoryProfile(name: 'medium', loopChoices: 32),
      Stage9d5HistoryProfile(name: 'long', loopChoices: 128),
      Stage9d5HistoryProfile(name: 'very_long', loopChoices: 512),
    ];

const List<int> stage9d5SessionCounts = <int>[1, 10, 50];
const int stage9d5MeasuredAdditionalChoices = 16;

/// Fixed authored fixture whose route length never changes with retained history.
final class Stage9d5Fixture {
  Stage9d5Fixture._({
    required this.project,
    required this.entryPoint,
    required this.counterId,
    required this.loopEventId,
    required this.commitEventId,
    required this.loopChoiceId,
    required this.commitChoiceId,
    required this.profile,
    required this.authoredChoiceCount,
  });

  factory Stage9d5Fixture.build(Stage9d5ProjectProfile profile) {
    final counterId = StoryVariableId('stage9d5_counter');
    final loopEventId = StoryEventId('stage9d5_loop');
    final commitEventId = StoryEventId('stage9d5_commit');
    final loopChoiceId = StoryChoiceId('stage9d5_loop_choice');
    final commitChoiceId = StoryChoiceId('stage9d5_commit_choice');

    final variables = <StoryVariableDefinition>[
      StoryVariableDefinition(
        id: counterId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(0),
      ),
      for (var index = 1; index < profile.stateVariableCount; index++)
        StoryVariableDefinition(
          id: StoryVariableId('stage9d5_state_$index'),
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(index),
        ),
    ];

    final loopEvent = StoryEvent(
      id: loopEventId,
      choices: <StoryChoice>[
        StoryChoice(
          id: loopChoiceId,
          transition: StoryEventTransition(destinationEventId: loopEventId),
        ),
        StoryChoice(
          id: commitChoiceId,
          transition: StoryEventTransition(destinationEventId: commitEventId),
        ),
      ],
    );
    final commitEvent = StoryEvent(
      id: commitEventId,
      entryEffects: <StoryEffect>[
        StoryIncrementVariableEffect(
          variableId: counterId,
          amount: StoryIntegerValue(1),
        ),
      ],
      continuationTransition: const StoryTerminalTransition(),
    );

    final paddingEvents = <StoryEvent>[
      for (
        var eventIndex = 0;
        eventIndex < profile.paddingEventCount;
        eventIndex++
      )
        StoryEvent(
          id: StoryEventId('stage9d5_padding_event_$eventIndex'),
          choices: <StoryChoice>[
            for (
              var choiceIndex = 0;
              choiceIndex < profile.choicesPerPaddingEvent;
              choiceIndex++
            )
              StoryChoice(
                id: StoryChoiceId(
                  'stage9d5_padding_choice_${eventIndex}_$choiceIndex',
                ),
                transition: const StoryTerminalTransition(),
              ),
          ],
        ),
    ];
    final paddingChoiceCount =
        profile.paddingEventCount * profile.choicesPerPaddingEvent;

    final project = StoryProject(
      id: StoryProjectId('stage9d5_${profile.name}'),
      stateSchema: StoryStateSchema(variables: variables),
      events: <StoryEvent>[loopEvent, commitEvent, ...paddingEvents],
      entryEventId: loopEventId,
    );
    return Stage9d5Fixture._(
      project: project,
      entryPoint: StoryEntryPoint(
        id: StoryEntryPointId('stage9d5_entry'),
        eventId: loopEventId,
      ),
      counterId: counterId,
      loopEventId: loopEventId,
      commitEventId: commitEventId,
      loopChoiceId: loopChoiceId,
      commitChoiceId: commitChoiceId,
      profile: profile,
      authoredChoiceCount: 2 + paddingChoiceCount,
    );
  }

  final StoryProject project;
  final StoryEntryPoint entryPoint;
  final StoryVariableId counterId;
  final StoryEventId loopEventId;
  final StoryEventId commitEventId;
  final StoryChoiceId loopChoiceId;
  final StoryChoiceId commitChoiceId;
  final Stage9d5ProjectProfile profile;
  final int authoredChoiceCount;

  int get authoredEventCount => project.events.length;
  int get stateVariableCount => project.stateSchema.variables.length;
}

final class Stage9d5RestorePrepared {
  const Stage9d5RestorePrepared({
    required this.fixture,
    required this.historyProfile,
    required this.sourceEngine,
    required this.snapshot,
  });

  final Stage9d5Fixture fixture;
  final Stage9d5HistoryProfile historyProfile;
  final StoryEngine sourceEngine;
  final StoryRuntimeSnapshot snapshot;
}

final class Stage9d5RestoreResult {
  const Stage9d5RestoreResult({required this.prepared, required this.restored});

  final Stage9d5RestorePrepared prepared;
  final StoryEngine restored;
}

Stage9d5RestorePrepared prepareStage9d5Restore({
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
}) {
  final engine = StoryEngine(project: fixture.project, randomSeed: 0x9d50)
    ..startAt(fixture.loopEventId);
  _advanceCoreLoop(engine, fixture.loopChoiceId, historyProfile.loopChoices);
  final snapshot = engine.createSnapshot();
  _verifyLoopSnapshot(
    snapshot: snapshot,
    fixture: fixture,
    expectedLoopChoices: historyProfile.loopChoices,
  );
  return Stage9d5RestorePrepared(
    fixture: fixture,
    historyProfile: historyProfile,
    sourceEngine: engine,
    snapshot: snapshot,
  );
}

/// Timed Stage 9D5 restore operation. All correctness checks happen afterward.
Stage9d5RestoreResult runStage9d5Restore(Stage9d5RestorePrepared prepared) =>
    Stage9d5RestoreResult(
      prepared: prepared,
      restored: StoryEngine.restore(
        project: prepared.fixture.project,
        snapshot: prepared.snapshot,
      ),
    );

String stage9d5RestoreFingerprint(Stage9d5RestoreResult result) {
  final sourceAfter = result.prepared.sourceEngine.createSnapshot();
  if (sourceAfter != result.prepared.snapshot) {
    throw StateError('Restore mutated the source engine checkpoint.');
  }
  final restored = result.restored.createSnapshot();
  if (restored != result.prepared.snapshot) {
    throw StateError('Restored checkpoint does not exactly match the source.');
  }
  return _snapshotFingerprint(restored);
}

Map<String, Object?> stage9d5RestoreMetrics(Stage9d5RestoreResult result) {
  final snapshot = result.restored.createSnapshot();
  return <String, Object?>{
    'projectProfile': result.prepared.fixture.profile.name,
    'historyProfile': result.prepared.historyProfile.name,
    'authoredEventCount': result.prepared.fixture.authoredEventCount,
    'authoredChoiceCount': result.prepared.fixture.authoredChoiceCount,
    'stateVariableCount': result.prepared.fixture.stateVariableCount,
    'historySteps': snapshot.history.steps.length,
  };
}

final class Stage9d5PropagationPrepared {
  const Stage9d5PropagationPrepared({
    required this.fixture,
    required this.historyProfile,
    required this.runtime,
    required this.sessions,
    required this.beforeSnapshots,
  });

  final Stage9d5Fixture fixture;
  final Stage9d5HistoryProfile historyProfile;
  final StoryNarrativeRuntime runtime;
  final List<StoryNarrativeSession> sessions;
  final List<StoryRuntimeSnapshot> beforeSnapshots;
}

final class Stage9d5PropagationResult {
  const Stage9d5PropagationResult(this.prepared);

  final Stage9d5PropagationPrepared prepared;
}

Stage9d5PropagationPrepared prepareStage9d5Propagation({
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required int sessionCount,
}) {
  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: <StoryEntryPoint>[fixture.entryPoint],
    randomSeed: 0x9d51,
  );
  final sessions = <StoryNarrativeSession>[
    for (var index = 0; index < sessionCount; index++)
      runtime.startSession(fixture.entryPoint.id),
  ];
  for (final session in sessions) {
    for (var step = 0; step < historyProfile.loopChoices; step++) {
      session.choose(fixture.loopChoiceId);
    }
  }
  final beforeSnapshots = <StoryRuntimeSnapshot>[
    for (final session in sessions) session.createSnapshot().runtimeSnapshot,
  ];
  for (final snapshot in beforeSnapshots) {
    _verifyLoopSnapshot(
      snapshot: snapshot,
      fixture: fixture,
      expectedLoopChoices: historyProfile.loopChoices,
    );
  }
  if (runtime.persistentStateRevision != 0 ||
      runtime.persistentState.rawValueOf(fixture.counterId) != 0) {
    throw StateError('Prepared propagation fixture already mutated state.');
  }
  return Stage9d5PropagationPrepared(
    fixture: fixture,
    historyProfile: historyProfile,
    runtime: runtime,
    sessions: List<StoryNarrativeSession>.unmodifiable(sessions),
    beforeSnapshots: List<StoryRuntimeSnapshot>.unmodifiable(beforeSnapshots),
  );
}

/// Timed Stage 9D5 propagation operation: exactly one authoritative commit.
Stage9d5PropagationResult runStage9d5Propagation(
  Stage9d5PropagationPrepared prepared,
) {
  prepared.sessions.first.choose(prepared.fixture.commitChoiceId);
  return Stage9d5PropagationResult(prepared);
}

String stage9d5PropagationFingerprint(Stage9d5PropagationResult result) {
  _verifyPropagationResult(result.prepared);
  final json = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
    result.prepared.runtime.createSnapshot(),
  );
  return sha256.convert(utf8.encode(json)).toString();
}

Map<String, Object?> stage9d5PropagationMetrics(
  Stage9d5PropagationResult result,
) {
  final prepared = result.prepared;
  return <String, Object?>{
    'projectProfile': prepared.fixture.profile.name,
    'historyProfile': prepared.historyProfile.name,
    'sessionCount': prepared.sessions.length,
    'expectedSiblingRebuildCount': prepared.sessions.length - 1,
    'authoredEventCount': prepared.fixture.authoredEventCount,
    'authoredChoiceCount': prepared.fixture.authoredChoiceCount,
    'stateVariableCount': prepared.fixture.stateVariableCount,
    'historyStepsBeforePerSession':
        prepared.beforeSnapshots.first.history.steps.length,
    'persistentStateRevision': prepared.runtime.persistentStateRevision,
  };
}

void _verifyPropagationResult(Stage9d5PropagationPrepared prepared) {
  final runtime = prepared.runtime;
  final fixture = prepared.fixture;
  if (runtime.persistentStateRevision != 1) {
    throw StateError(
      'One shared-state commit must advance revision exactly once.',
    );
  }
  if (runtime.persistentState.rawValueOf(fixture.counterId) != 1) {
    throw StateError('Shared counter must commit 0 -> 1.');
  }
  if (runtime.activeSessions.length != prepared.sessions.length) {
    throw StateError('Commit event must keep every session active.');
  }

  for (var index = 0; index < prepared.sessions.length; index++) {
    final session = prepared.sessions[index];
    if (session.state.rawValueOf(fixture.counterId) != 1) {
      throw StateError(
        'Sibling session did not receive committed shared state.',
      );
    }
    final before = prepared.beforeSnapshots[index];
    final after = session.createSnapshot().runtimeSnapshot;
    if (index == 0) {
      final expected = StoryRuntimeSnapshot(
        metadata: before.metadata,
        projectId: before.projectId,
        status: StoryEngineStatus.awaitingContinue,
        state: runtime.persistentState,
        currentEventId: fixture.commitEventId,
        history: StoryRuntimeHistory(
          steps: <StoryRuntimeStep>[
            ...before.history.steps,
            StoryChoiceSelectedStep(
              eventId: fixture.loopEventId,
              choiceId: fixture.commitChoiceId,
            ),
            StoryEventEnteredStep(eventId: fixture.commitEventId),
          ],
        ),
        randomState: before.randomState,
        maxAutomaticTransitions: before.maxAutomaticTransitions,
      );
      if (after != expected) {
        throw StateError('Source session changed beyond the intended commit.');
      }
    } else {
      final expected = StoryRuntimeSnapshot(
        metadata: before.metadata,
        projectId: before.projectId,
        status: before.status,
        state: runtime.persistentState,
        currentEventId: before.currentEventId,
        history: before.history,
        randomState: before.randomState,
        maxAutomaticTransitions: before.maxAutomaticTransitions,
      );
      if (after != expected) {
        throw StateError(
          'Sibling restore changed runtime facts other than shared state.',
        );
      }
    }
  }
}

enum Stage9d5HistoryExecutionKind { core, narrative }

final class Stage9d5HistoryPrepared {
  const Stage9d5HistoryPrepared._({
    required this.fixture,
    required this.historyProfile,
    required this.kind,
    required this.coreEngine,
    required this.runtime,
    required this.session,
  });

  final Stage9d5Fixture fixture;
  final Stage9d5HistoryProfile historyProfile;
  final Stage9d5HistoryExecutionKind kind;
  final StoryEngine? coreEngine;
  final StoryNarrativeRuntime? runtime;
  final StoryNarrativeSession? session;
}

Stage9d5HistoryPrepared prepareStage9d5HistoryIncrement({
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required Stage9d5HistoryExecutionKind kind,
}) {
  switch (kind) {
    case Stage9d5HistoryExecutionKind.core:
      final engine = StoryEngine(project: fixture.project, randomSeed: 0x9d52)
        ..startAt(fixture.loopEventId);
      _advanceCoreLoop(
        engine,
        fixture.loopChoiceId,
        historyProfile.loopChoices,
      );
      return Stage9d5HistoryPrepared._(
        fixture: fixture,
        historyProfile: historyProfile,
        kind: kind,
        coreEngine: engine,
        runtime: null,
        session: null,
      );
    case Stage9d5HistoryExecutionKind.narrative:
      final runtime = StoryNarrativeRuntime(
        project: fixture.project,
        entryPoints: <StoryEntryPoint>[fixture.entryPoint],
        randomSeed: 0x9d53,
      );
      final session = runtime.startSession(fixture.entryPoint.id);
      for (var step = 0; step < historyProfile.loopChoices; step++) {
        session.choose(fixture.loopChoiceId);
      }
      return Stage9d5HistoryPrepared._(
        fixture: fixture,
        historyProfile: historyProfile,
        kind: kind,
        coreEngine: null,
        runtime: runtime,
        session: session,
      );
  }
}

/// Timed fixed-size continuation window after history has already been built.
Stage9d5HistoryPrepared runStage9d5HistoryIncrement(
  Stage9d5HistoryPrepared prepared,
) {
  switch (prepared.kind) {
    case Stage9d5HistoryExecutionKind.core:
      _advanceCoreLoop(
        prepared.coreEngine!,
        prepared.fixture.loopChoiceId,
        stage9d5MeasuredAdditionalChoices,
      );
      return prepared;
    case Stage9d5HistoryExecutionKind.narrative:
      for (var step = 0; step < stage9d5MeasuredAdditionalChoices; step++) {
        prepared.session!.choose(prepared.fixture.loopChoiceId);
      }
      return prepared;
  }
}

String stage9d5HistoryFingerprint(Stage9d5HistoryPrepared result) {
  final expectedChoices =
      result.historyProfile.loopChoices + stage9d5MeasuredAdditionalChoices;
  final snapshot = switch (result.kind) {
    Stage9d5HistoryExecutionKind.core => result.coreEngine!.createSnapshot(),
    Stage9d5HistoryExecutionKind.narrative =>
      result.session!.createSnapshot().runtimeSnapshot,
  };
  _verifyLoopSnapshot(
    snapshot: snapshot,
    fixture: result.fixture,
    expectedLoopChoices: expectedChoices,
  );
  final runtime = result.runtime;
  if (runtime != null &&
      (runtime.persistentStateRevision != 0 ||
          runtime.persistentState.rawValueOf(result.fixture.counterId) != 0)) {
    throw StateError('History-only operations must not mutate shared state.');
  }
  return _snapshotFingerprint(snapshot);
}

Map<String, Object?> stage9d5HistoryMetrics(Stage9d5HistoryPrepared result) {
  final snapshot = switch (result.kind) {
    Stage9d5HistoryExecutionKind.core => result.coreEngine!.createSnapshot(),
    Stage9d5HistoryExecutionKind.narrative =>
      result.session!.createSnapshot().runtimeSnapshot,
  };
  return <String, Object?>{
    'kind': result.kind.name,
    'historyProfile': result.historyProfile.name,
    'preparedLoopChoices': result.historyProfile.loopChoices,
    'measuredAdditionalChoices': stage9d5MeasuredAdditionalChoices,
    'finalHistorySteps': snapshot.history.steps.length,
    'authoredEventCount': result.fixture.authoredEventCount,
    'authoredChoiceCount': result.fixture.authoredChoiceCount,
    'stateVariableCount': result.fixture.stateVariableCount,
  };
}

void _advanceCoreLoop(
  StoryEngine engine,
  StoryChoiceId loopChoiceId,
  int count,
) {
  for (var step = 0; step < count; step++) {
    engine.choose(loopChoiceId);
  }
}

void _verifyLoopSnapshot({
  required StoryRuntimeSnapshot snapshot,
  required Stage9d5Fixture fixture,
  required int expectedLoopChoices,
}) {
  if (snapshot.status != StoryEngineStatus.awaitingChoice ||
      snapshot.currentEventId != fixture.loopEventId) {
    throw StateError('Loop fixture did not remain on its interactive event.');
  }
  final expectedHistorySteps = 1 + (expectedLoopChoices * 2);
  if (snapshot.history.steps.length != expectedHistorySteps) {
    throw StateError(
      'Unexpected loop history length ${snapshot.history.steps.length}; '
      'expected $expectedHistorySteps.',
    );
  }
  if (snapshot.state?.rawValueOf(fixture.counterId) != 0) {
    throw StateError('Loop-only history unexpectedly changed shared state.');
  }
}

String _snapshotFingerprint(StoryRuntimeSnapshot snapshot) {
  final json = StoryRuntimeSnapshotCodec().encodeJson(snapshot);
  return sha256.convert(utf8.encode(json)).toString();
}
