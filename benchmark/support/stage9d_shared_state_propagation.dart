import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';

/// Authored-project size dimension used by the Stage 9D3 propagation matrix.
///
/// Padding events are unreachable from the measured route but are deliberately
/// valid authored events. They force snapshot restoration to rebuild and check
/// larger project indexes without lengthening the retained session history.
final class Stage9dPropagationProjectProfile {
  const Stage9dPropagationProjectProfile({
    required this.name,
    required this.paddingEventCount,
    required this.stateVariableCount,
  });

  final String name;
  final int paddingEventCount;
  final int stateVariableCount;
}

/// Retained pre-commit history depth used by the Stage 9D3 matrix.
final class Stage9dPropagationHistoryScale {
  const Stage9dPropagationHistoryScale({
    required this.name,
    required this.continuationsPerSession,
  });

  final String name;
  final int continuationsPerSession;
}

const List<int> stage9dPropagationSessionCounts = <int>[1, 10, 50];

const List<Stage9dPropagationProjectProfile> stage9dPropagationProjectProfiles =
    <Stage9dPropagationProjectProfile>[
      Stage9dPropagationProjectProfile(
        name: 'compact',
        paddingEventCount: 0,
        stateVariableCount: 1,
      ),
      Stage9dPropagationProjectProfile(
        name: 'medium',
        paddingEventCount: 512,
        stateVariableCount: 64,
      ),
      Stage9dPropagationProjectProfile(
        name: 'large',
        paddingEventCount: 2048,
        stateVariableCount: 256,
      ),
    ];

const List<Stage9dPropagationHistoryScale>
stage9dPropagationHistoryScales = <Stage9dPropagationHistoryScale>[
  Stage9dPropagationHistoryScale(name: 'short', continuationsPerSession: 8),
  Stage9dPropagationHistoryScale(name: 'medium', continuationsPerSession: 64),
  Stage9dPropagationHistoryScale(name: 'long', continuationsPerSession: 256),
];

/// One end-to-end shared-state propagation matrix point.
final class Stage9dPropagationScenario {
  const Stage9dPropagationScenario({
    required this.sessionCount,
    required this.projectProfile,
    required this.historyScale,
  });

  final int sessionCount;
  final Stage9dPropagationProjectProfile projectProfile;
  final Stage9dPropagationHistoryScale historyScale;

  int get siblingCount => sessionCount - 1;

  String get idStem =>
      'propagation_${projectProfile.name}_${historyScale.name}_s$sessionCount';
}

/// Full 3 × 3 × 3 Stage 9D3 propagation matrix.
List<Stage9dPropagationScenario> stage9dPropagationMatrix() =>
    List<Stage9dPropagationScenario>.unmodifiable(<Stage9dPropagationScenario>[
      for (final projectProfile in stage9dPropagationProjectProfiles)
        for (final historyScale in stage9dPropagationHistoryScales)
          for (final sessionCount in stage9dPropagationSessionCounts)
            Stage9dPropagationScenario(
              sessionCount: sessionCount,
              projectProfile: projectProfile,
              historyScale: historyScale,
            ),
    ]);

/// Deterministic project whose timed transition changes persistent state once.
final class Stage9dPropagationFixture {
  Stage9dPropagationFixture._({
    required this.project,
    required this.entryPoint,
    required this.counterId,
    required this.preCommitEventId,
    required this.commitEventId,
    required this.projectProfile,
    required this.historyScale,
    required this.authoredChoiceCount,
  });

  factory Stage9dPropagationFixture.build({
    required Stage9dPropagationProjectProfile projectProfile,
    required Stage9dPropagationHistoryScale historyScale,
  }) {
    if (projectProfile.stateVariableCount <= 0) {
      throw ArgumentError.value(
        projectProfile.stateVariableCount,
        'projectProfile.stateVariableCount',
        'Propagation fixtures require at least the shared counter variable.',
      );
    }
    if (projectProfile.paddingEventCount < 0) {
      throw ArgumentError.value(
        projectProfile.paddingEventCount,
        'projectProfile.paddingEventCount',
        'Padding event count must not be negative.',
      );
    }
    if (historyScale.continuationsPerSession < 0) {
      throw ArgumentError.value(
        historyScale.continuationsPerSession,
        'historyScale.continuationsPerSession',
        'History continuation count must not be negative.',
      );
    }

    final counterId = StoryVariableId('stage9d_shared_counter');
    final variables = <StoryVariableDefinition>[
      StoryVariableDefinition(
        id: counterId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(0),
      ),
      for (var index = 1; index < projectProfile.stateVariableCount; index++)
        StoryVariableDefinition(
          id: StoryVariableId('stage9d_state_$index'),
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(index),
        ),
    ];

    final routeEvents = <StoryEvent>[];
    final continuationCount = historyScale.continuationsPerSession;
    for (var index = 0; index <= continuationCount; index++) {
      final eventId = StoryEventId('stage9d_route_$index');
      final destination = index == continuationCount
          ? StoryEventId('stage9d_commit')
          : StoryEventId('stage9d_route_${index + 1}');
      routeEvents.add(
        StoryEvent(
          id: eventId,
          continuationTransition: StoryEventTransition(
            destinationEventId: destination,
          ),
        ),
      );
    }

    final commitEventId = StoryEventId('stage9d_commit');
    routeEvents.add(
      StoryEvent(
        id: commitEventId,
        entryEffects: <StoryEffect>[
          StoryIncrementVariableEffect(
            variableId: counterId,
            amount: StoryIntegerValue(1),
          ),
        ],
        continuationTransition: const StoryTerminalTransition(),
      ),
    );

    final paddingEvents = <StoryEvent>[];
    for (var index = 0; index < projectProfile.paddingEventCount; index++) {
      paddingEvents.add(
        StoryEvent(
          id: StoryEventId('stage9d_padding_event_$index'),
          choices: <StoryChoice>[
            StoryChoice(
              id: StoryChoiceId('stage9d_padding_choice_$index'),
              transition: const StoryTerminalTransition(),
            ),
          ],
        ),
      );
    }

    final entryPoint = StoryEntryPoint(
      id: StoryEntryPointId('stage9d_propagation_entry'),
      eventId: routeEvents.first.id,
    );
    final project = StoryProject(
      id: StoryProjectId(
        'stage9d_propagation_${projectProfile.name}_${historyScale.name}',
      ),
      stateSchema: StoryStateSchema(variables: variables),
      events: <StoryEvent>[...routeEvents, ...paddingEvents],
      entryEventId: routeEvents.first.id,
    );

    return Stage9dPropagationFixture._(
      project: project,
      entryPoint: entryPoint,
      counterId: counterId,
      preCommitEventId: StoryEventId('stage9d_route_$continuationCount'),
      commitEventId: commitEventId,
      projectProfile: projectProfile,
      historyScale: historyScale,
      authoredChoiceCount: projectProfile.paddingEventCount,
    );
  }

  final StoryProject project;
  final StoryEntryPoint entryPoint;
  final StoryVariableId counterId;
  final StoryEventId preCommitEventId;
  final StoryEventId commitEventId;
  final Stage9dPropagationProjectProfile projectProfile;
  final Stage9dPropagationHistoryScale historyScale;
  final int authoredChoiceCount;

  int get authoredEventCount => project.events.length;
  int get stateVariableCount => project.stateSchema.variables.length;
}

/// Prepared core-engine unit used to time the mechanism each sibling rebuilds.
final class Stage9dSiblingRebuildPrepared {
  const Stage9dSiblingRebuildPrepared({
    required this.fixture,
    required this.engine,
    required this.changedState,
  });

  final Stage9dPropagationFixture fixture;
  final StoryEngine engine;
  final StoryState changedState;
}

/// Result of one create-snapshot + validated-restore sibling rebuild unit.
final class Stage9dSiblingRebuildResult {
  const Stage9dSiblingRebuildResult({
    required this.fixture,
    required this.engine,
  });

  final Stage9dPropagationFixture fixture;
  final StoryEngine engine;
}

Stage9dSiblingRebuildPrepared prepareStage9dSiblingRebuild(
  Stage9dPropagationFixture fixture,
) {
  final engine = StoryEngine(project: fixture.project, randomSeed: 0x9d30)
    ..startAt(fixture.entryPoint.eventId);

  for (
    var step = 0;
    step < fixture.historyScale.continuationsPerSession;
    step++
  ) {
    engine.continueStory();
  }
  if (engine.currentEvent?.id != fixture.preCommitEventId) {
    throw StateError(
      'Stage 9D3 unit rebuild preparation did not reach the pre-commit event.',
    );
  }

  final state = engine.state;
  if (state == null) {
    throw StateError('Stage 9D3 unit rebuild preparation lost runtime state.');
  }
  final values = Map<StoryVariableId, StoryValue>.of(state.values);
  values[fixture.counterId] = StoryIntegerValue(1);
  final changedState = StoryState.fromValues(
    schema: fixture.project.stateSchema,
    values: values,
  );

  return Stage9dSiblingRebuildPrepared(
    fixture: fixture,
    engine: engine,
    changedState: changedState,
  );
}

/// Executes the exact correctness-first core of a sibling replacement:
/// committed snapshot capture, shared-state substitution, validation, restore.
Stage9dSiblingRebuildResult runStage9dSiblingRebuild(
  Stage9dSiblingRebuildPrepared prepared,
) {
  final snapshot = prepared.engine.createSnapshot();
  final restored = StoryEngine.restore(
    project: prepared.fixture.project,
    snapshot: StoryRuntimeSnapshot(
      metadata: snapshot.metadata,
      projectId: snapshot.projectId,
      status: snapshot.status,
      state: prepared.changedState,
      currentEventId: snapshot.currentEventId,
      history: snapshot.history,
      randomState: snapshot.randomState,
      maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
    ),
  );
  return Stage9dSiblingRebuildResult(
    fixture: prepared.fixture,
    engine: restored,
  );
}

String stage9dSiblingRebuildFingerprint(Stage9dSiblingRebuildResult result) {
  final json = StoryRuntimeSnapshotCodec().encodeJson(
    result.engine.createSnapshot(),
  );
  return sha256.convert(utf8.encode(json)).toString();
}

Map<String, Object?> stage9dSiblingRebuildMetrics(
  Stage9dSiblingRebuildResult result,
) {
  final fixture = result.fixture;
  final state = result.engine.state;
  return <String, Object?>{
    'projectProfile': fixture.projectProfile.name,
    'historyProfile': fixture.historyScale.name,
    'authoredEventCount': fixture.authoredEventCount,
    'authoredChoiceCount': fixture.authoredChoiceCount,
    'stateVariableCount': fixture.stateVariableCount,
    'historySteps': result.engine.history.steps.length,
    'counterValue': state?.rawValueOf(fixture.counterId),
    'status': result.engine.status.name,
  };
}

/// Prepared end-to-end shared-state propagation workload.
final class Stage9dPropagationPrepared {
  const Stage9dPropagationPrepared({
    required this.fixture,
    required this.scenario,
    required this.runtime,
    required this.sessions,
  });

  final Stage9dPropagationFixture fixture;
  final Stage9dPropagationScenario scenario;
  final StoryNarrativeRuntime runtime;
  final List<StoryNarrativeSession> sessions;

  StoryNarrativeSession get source => sessions.first;
}

/// Result after one authoritative source commit propagated to all siblings.
final class Stage9dPropagationResult {
  const Stage9dPropagationResult({required this.prepared});

  final Stage9dPropagationPrepared prepared;

  StoryNarrativeRuntime get runtime => prepared.runtime;
  Stage9dPropagationFixture get fixture => prepared.fixture;
  Stage9dPropagationScenario get scenario => prepared.scenario;
}

Stage9dPropagationPrepared prepareStage9dPropagation(
  Stage9dPropagationFixture fixture,
  Stage9dPropagationScenario scenario,
) {
  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: <StoryEntryPoint>[fixture.entryPoint],
    randomSeed: 0x9d31,
  );
  final sessions = <StoryNarrativeSession>[
    for (var index = 0; index < scenario.sessionCount; index++)
      runtime.startSession(fixture.entryPoint.id),
  ];

  for (
    var step = 0;
    step < scenario.historyScale.continuationsPerSession;
    step++
  ) {
    for (final session in sessions) {
      session.continueStory();
    }
  }

  for (final session in sessions) {
    if (session.currentEvent?.id != fixture.preCommitEventId) {
      throw StateError(
        'Stage 9D3 propagation preparation did not align every active session '
        'at the pre-commit event for ${scenario.idStem}.',
      );
    }
    if (session.state.rawValueOf(fixture.counterId) != 0) {
      throw StateError(
        'Stage 9D3 propagation preparation changed shared state before timing.',
      );
    }
  }
  if (runtime.persistentStateRevision != 0) {
    throw StateError(
      'Stage 9D3 propagation preparation changed persistent state revision.',
    );
  }

  return Stage9dPropagationPrepared(
    fixture: fixture,
    scenario: scenario,
    runtime: runtime,
    sessions: List<StoryNarrativeSession>.unmodifiable(sessions),
  );
}

/// Times one real source continuation whose destination entry effect changes
/// shared persistent state and therefore rebuilds every active sibling engine.
Stage9dPropagationResult runStage9dPropagationCommit(
  Stage9dPropagationPrepared prepared,
) {
  prepared.source.continueStory();

  final runtime = prepared.runtime;
  final fixture = prepared.fixture;
  if (runtime.persistentStateRevision != 1) {
    throw StateError(
      'Stage 9D3 expected exactly one persistent-state revision after commit.',
    );
  }
  if (runtime.persistentState.rawValueOf(fixture.counterId) != 1) {
    throw StateError(
      'Stage 9D3 authoritative persistent state did not commit.',
    );
  }
  if (runtime.activeSessions.length != prepared.scenario.sessionCount) {
    throw StateError(
      'Stage 9D3 propagation unexpectedly changed active count.',
    );
  }
  for (final session in prepared.sessions) {
    if (session.state.rawValueOf(fixture.counterId) != 1) {
      throw StateError(
        'Stage 9D3 sibling session did not receive the committed shared state.',
      );
    }
  }

  return Stage9dPropagationResult(prepared: prepared);
}

String stage9dPropagationFingerprint(Stage9dPropagationResult result) {
  final json = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
    result.runtime.createSnapshot(),
  );
  return sha256.convert(utf8.encode(json)).toString();
}

Map<String, Object?> stage9dPropagationMetrics(
  Stage9dPropagationResult result,
) {
  final fixture = result.fixture;
  final scenario = result.scenario;
  final snapshot = result.runtime.createSnapshot();
  final json = StoryNarrativeRuntimeSnapshotCodec().encodeJson(snapshot);
  final historySteps = result.runtime.history.sessions
      .map((session) => session.history.steps.length)
      .toList(growable: false);

  return <String, Object?>{
    'projectProfile': scenario.projectProfile.name,
    'historyProfile': scenario.historyScale.name,
    'sessionCount': scenario.sessionCount,
    'siblingRebuildCount': scenario.siblingCount,
    'historyContinuationsPerSession':
        scenario.historyScale.continuationsPerSession,
    'authoredEventCount': fixture.authoredEventCount,
    'authoredChoiceCount': fixture.authoredChoiceCount,
    'stateVariableCount': fixture.stateVariableCount,
    'activeSessionCount': result.runtime.activeSessions.length,
    'retainedSessionCount': result.runtime.history.sessions.length,
    'minHistoryStepsPerSession': historySteps.reduce(
      (left, right) => left < right ? left : right,
    ),
    'maxHistoryStepsPerSession': historySteps.reduce(
      (left, right) => left > right ? left : right,
    ),
    'persistentStateRevision': result.runtime.persistentStateRevision,
    'counterValue': result.runtime.persistentState.rawValueOf(
      fixture.counterId,
    ),
    'aggregateSnapshotUtf8Bytes': utf8.encode(json).length,
  };
}
