import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/orchestration/story_narrative_runtime.dart'
    as internal;

import 'stage9d5_optimization_baseline.dart';

const int stage9d6UnchangedMeasuredAdditionalChoices = 64;
const List<int> stage9d6UnchangedSessionCounts = <int>[2, 50];
const List<int> stage9d6PrewarmedPropagationSessionCounts = <int>[1, 10, 50];

const List<Stage9d5HistoryProfile> stage9d6UnchangedHistoryProfiles =
    <Stage9d5HistoryProfile>[
      Stage9d5HistoryProfile(name: 'medium', loopChoices: 32),
      Stage9d5HistoryProfile(name: 'long', loopChoices: 128),
      Stage9d5HistoryProfile(name: 'very_long', loopChoices: 512),
    ];

final class Stage9d6UnchangedHistoryPrepared {
  const Stage9d6UnchangedHistoryPrepared({
    required this.fixture,
    required this.historyProfile,
    required this.runtime,
    required this.sessions,
  });

  final Stage9d5Fixture fixture;
  final Stage9d5HistoryProfile historyProfile;
  final StoryNarrativeRuntime runtime;
  final List<StoryNarrativeSession> sessions;
}

Stage9d6UnchangedHistoryPrepared prepareStage9d6UnchangedHistory({
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required int sessionCount,
}) {
  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: <StoryEntryPoint>[fixture.entryPoint],
    randomSeed: 0x9d56,
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
  _verifyUnchangedHistoryRuntime(
    fixture: fixture,
    historyProfile: historyProfile,
    runtime: runtime,
    sessions: sessions,
    measuredChoices: 0,
  );
  return Stage9d6UnchangedHistoryPrepared(
    fixture: fixture,
    historyProfile: historyProfile,
    runtime: runtime,
    sessions: List<StoryNarrativeSession>.unmodifiable(sessions),
  );
}

/// Timed Stage 9D6-only workload: ordinary source choices while siblings exist.
///
/// The selected loop choice never changes persistent state. The accepted
/// selective strategy therefore must not materialize a history-sized rollback
/// snapshot merely because more than one session is active.
Stage9d6UnchangedHistoryPrepared runStage9d6UnchangedHistory(
  Stage9d6UnchangedHistoryPrepared prepared,
) {
  final source = prepared.sessions.first;
  for (
    var step = 0;
    step < stage9d6UnchangedMeasuredAdditionalChoices;
    step++
  ) {
    source.choose(prepared.fixture.loopChoiceId);
  }
  return prepared;
}

String stage9d6UnchangedHistoryFingerprint(
  Stage9d6UnchangedHistoryPrepared result,
) {
  _verifyUnchangedHistoryRuntime(
    fixture: result.fixture,
    historyProfile: result.historyProfile,
    runtime: result.runtime,
    sessions: result.sessions,
    measuredChoices: stage9d6UnchangedMeasuredAdditionalChoices,
  );
  return _runtimeFingerprint(result.runtime.createSnapshot());
}

Map<String, Object?> stage9d6UnchangedHistoryMetrics(
  Stage9d6UnchangedHistoryPrepared result,
) {
  final preparedSteps = 1 + 2 * result.historyProfile.loopChoices;
  final sourceFinalSteps =
      preparedSteps + 2 * stage9d6UnchangedMeasuredAdditionalChoices;
  return <String, Object?>{
    'projectProfile': result.fixture.profile.name,
    'historyProfile': result.historyProfile.name,
    'sessionCount': result.sessions.length,
    'preparedLoopChoices': result.historyProfile.loopChoices,
    'measuredAdditionalChoices': stage9d6UnchangedMeasuredAdditionalChoices,
    'sourceHistoryStepsBefore': preparedSteps,
    'sourceHistoryStepsAfter': sourceFinalSteps,
    'siblingHistorySteps': preparedSteps,
    'activeSessionCount': result.runtime.activeSessions.length,
    'persistentStateRevision': result.runtime.persistentStateRevision,
    'counterValue': result.runtime.persistentState.rawValueOf(
      result.fixture.counterId,
    ),
  };
}

void _verifyUnchangedHistoryRuntime({
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required StoryNarrativeRuntime runtime,
  required List<StoryNarrativeSession> sessions,
  required int measuredChoices,
}) {
  if (runtime.persistentStateRevision != 0 ||
      runtime.persistentState.rawValueOf(fixture.counterId) != 0 ||
      runtime.activeSessions.length != sessions.length) {
    throw StateError(
      'Stage 9D6 unchanged-state history workload changed shared authority.',
    );
  }
  for (var index = 0; index < sessions.length; index++) {
    final snapshot = sessions[index].createSnapshot().runtimeSnapshot;
    final expectedChoices =
        historyProfile.loopChoices + (index == 0 ? measuredChoices : 0);
    final expectedHistorySteps = 1 + 2 * expectedChoices;
    if (snapshot.status != StoryEngineStatus.awaitingChoice ||
        snapshot.currentEventId != fixture.loopEventId ||
        snapshot.history.steps.length != expectedHistorySteps ||
        snapshot.state?.rawValueOf(fixture.counterId) != 0) {
      throw StateError(
        'Stage 9D6 unchanged-state history workload changed unexpected '
        'session facts.',
      );
    }
  }
}

final class Stage9d6PrewarmedPropagationPrepared {
  const Stage9d6PrewarmedPropagationPrepared({
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

Stage9d6PrewarmedPropagationPrepared prepareStage9d6PrewarmedPropagation({
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

  // This benchmark-only hook constructs the exact immutable project-derived
  // restore indexes before the stopwatch. Every s1/s10/s50 point therefore
  // has the same preparation state and the scaling ratio cannot hide sibling
  // growth behind the one-time cold preparation cost.
  internal.warmStoryNarrativeRuntimeProjectPreparationForStage9d5Benchmark(
    runtime,
  );

  final beforeSnapshots = <StoryRuntimeSnapshot>[
    for (final session in sessions) session.createSnapshot().runtimeSnapshot,
  ];
  if (runtime.persistentStateRevision != 0 ||
      runtime.persistentState.rawValueOf(fixture.counterId) != 0) {
    throw StateError(
      'Stage 9D6 prewarmed propagation preparation changed shared state.',
    );
  }
  return Stage9d6PrewarmedPropagationPrepared(
    fixture: fixture,
    historyProfile: historyProfile,
    runtime: runtime,
    sessions: List<StoryNarrativeSession>.unmodifiable(sessions),
    beforeSnapshots: List<StoryRuntimeSnapshot>.unmodifiable(beforeSnapshots),
  );
}

Stage9d6PrewarmedPropagationPrepared runStage9d6PrewarmedPropagation(
  Stage9d6PrewarmedPropagationPrepared prepared,
) {
  prepared.sessions.first.choose(prepared.fixture.commitChoiceId);
  return prepared;
}

String stage9d6PrewarmedPropagationFingerprint(
  Stage9d6PrewarmedPropagationPrepared result,
) {
  _verifyPrewarmedPropagationResult(result);
  return _runtimeFingerprint(result.runtime.createSnapshot());
}

Map<String, Object?> stage9d6PrewarmedPropagationMetrics(
  Stage9d6PrewarmedPropagationPrepared result,
) => <String, Object?>{
  'projectProfile': result.fixture.profile.name,
  'historyProfile': result.historyProfile.name,
  'sessionCount': result.sessions.length,
  'expectedSiblingRebuildCount': result.sessions.length - 1,
  'authoredEventCount': result.fixture.authoredEventCount,
  'authoredChoiceCount': result.fixture.authoredChoiceCount,
  'stateVariableCount': result.fixture.stateVariableCount,
  'historyStepsBeforePerSession':
      result.beforeSnapshots.first.history.steps.length,
  'projectPreparationPrewarmed': true,
  'persistentStateRevision': result.runtime.persistentStateRevision,
};

void _verifyPrewarmedPropagationResult(
  Stage9d6PrewarmedPropagationPrepared prepared,
) {
  final runtime = prepared.runtime;
  final fixture = prepared.fixture;
  if (runtime.persistentStateRevision != 1 ||
      runtime.persistentState.rawValueOf(fixture.counterId) != 1 ||
      runtime.activeSessions.length != prepared.sessions.length) {
    throw StateError(
      'Stage 9D6 prewarmed propagation did not commit shared state exactly '
      'once.',
    );
  }

  for (var index = 0; index < prepared.sessions.length; index++) {
    final session = prepared.sessions[index];
    final before = prepared.beforeSnapshots[index];
    final after = session.createSnapshot().runtimeSnapshot;
    if (session.state.rawValueOf(fixture.counterId) != 1) {
      throw StateError(
        'Stage 9D6 prewarmed sibling did not receive committed shared state.',
      );
    }
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
        throw StateError(
          'Stage 9D6 prewarmed source changed beyond the intended commit.',
        );
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
          'Stage 9D6 prewarmed sibling changed facts other than shared state.',
        );
      }
    }
  }
}

String _runtimeFingerprint(StoryNarrativeRuntimeSnapshot snapshot) {
  final json = StoryNarrativeRuntimeSnapshotCodec().encodeJson(snapshot);
  return sha256.convert(utf8.encode(json)).toString();
}
