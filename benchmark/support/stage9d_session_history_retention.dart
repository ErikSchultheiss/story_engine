import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';

import 'stage9d_synthetic_narrative.dart';

/// Lifecycle shape retained by one Stage 9D2 benchmark scenario.
enum Stage9dRetentionLifecycle {
  /// Sessions stop on their last host-visible continuation event.
  active,

  /// Sessions perform one final continuation and terminate, but remain retained
  /// in the narrative runtime's historical session list.
  completed,
}

/// Named retained-history depth used by the Stage 9D2 measurement matrix.
final class Stage9dRetentionHistoryScale {
  const Stage9dRetentionHistoryScale({
    required this.name,
    required this.continuationsPerSession,
  });

  final String name;
  final int continuationsPerSession;
}

/// Required session-count dimension from the approved Stage 9D2 roadmap.
const List<int> stage9dRetentionSessionCounts = <int>[1, 10, 50];

/// Fixed short-to-very-long retained-history depths for Stage 9D2.
///
/// The progression is deliberately geometric so growth shape is visible while
/// keeping the full 24-scenario matrix practical on a developer workstation.
const List<Stage9dRetentionHistoryScale> stage9dRetentionHistoryScales =
    <Stage9dRetentionHistoryScale>[
      Stage9dRetentionHistoryScale(name: 'short', continuationsPerSession: 8),
      Stage9dRetentionHistoryScale(name: 'medium', continuationsPerSession: 32),
      Stage9dRetentionHistoryScale(name: 'long', continuationsPerSession: 128),
      Stage9dRetentionHistoryScale(
        name: 'very_long',
        continuationsPerSession: 512,
      ),
    ];

/// One point in the Stage 9D2 retention matrix.
final class Stage9dRetentionScenario {
  const Stage9dRetentionScenario({
    required this.sessionCount,
    required this.historyScale,
    required this.lifecycle,
  });

  final int sessionCount;
  final Stage9dRetentionHistoryScale historyScale;
  final Stage9dRetentionLifecycle lifecycle;

  String get idStem =>
      'retention_${lifecycle.name}_s${sessionCount}_${historyScale.name}';
}

/// Deterministic full Stage 9D2 session/history-retention matrix.
List<Stage9dRetentionScenario> stage9dRetentionMatrix() =>
    List<Stage9dRetentionScenario>.unmodifiable(<Stage9dRetentionScenario>[
      for (final lifecycle in Stage9dRetentionLifecycle.values)
        for (final sessionCount in stage9dRetentionSessionCounts)
          for (final historyScale in stage9dRetentionHistoryScales)
            Stage9dRetentionScenario(
              sessionCount: sessionCount,
              historyScale: historyScale,
              lifecycle: lifecycle,
            ),
    ]);

/// Completed deterministic retained-session workload for one matrix point.
final class Stage9dRetentionWorkloadResult {
  const Stage9dRetentionWorkloadResult({
    required this.runtime,
    required this.scenario,
  });

  final StoryNarrativeRuntime runtime;
  final Stage9dRetentionScenario scenario;

  int get activeSessionCount => runtime.activeSessions.length;
  int get completedSessionCount => scenario.sessionCount - activeSessionCount;

  int get terminalCompletionOperationsPerSession =>
      scenario.lifecycle == Stage9dRetentionLifecycle.completed ? 1 : 0;

  int get totalContinueOperations =>
      scenario.sessionCount *
      (scenario.historyScale.continuationsPerSession +
          terminalCompletionOperationsPerSession);

  List<int> get historyStepsPerSession => List<int>.unmodifiable(
    runtime.history.sessions
        .map((session) => session.history.steps.length)
        .toList(growable: false),
  );

  int get totalHistorySteps =>
      historyStepsPerSession.fold<int>(0, (sum, count) => sum + count);

  int get minHistoryStepsPerSession => historyStepsPerSession.reduce(
    (left, right) => left < right ? left : right,
  );

  int get maxHistoryStepsPerSession => historyStepsPerSession.reduce(
    (left, right) => left > right ? left : right,
  );
}

/// Executes one deterministic Stage 9D2 retained-session workload.
///
/// Every session starts before any session advances. The requested continuation
/// depth is then applied round-robin. Completed scenarios perform exactly one
/// additional continuation from the final host-visible event to the terminal
/// transition. Completed sessions remain retained by [StoryNarrativeRuntime]
/// even though they are no longer members of `activeSessions`.
Stage9dRetentionWorkloadResult runStage9dRetentionWorkload({
  required Stage9dSyntheticNarrativeFixture fixture,
  required Stage9dRetentionScenario scenario,
  int randomSeed = 0x9d20,
}) {
  if (scenario.sessionCount <= 0) {
    throw ArgumentError.value(
      scenario.sessionCount,
      'scenario.sessionCount',
      'Session count must be greater than zero.',
    );
  }
  final historyContinuations = scenario.historyScale.continuationsPerSession;
  if (historyContinuations < 0) {
    throw ArgumentError.value(
      historyContinuations,
      'scenario.historyScale.continuationsPerSession',
      'History continuation count must not be negative.',
    );
  }
  if (fixture.eventCount != historyContinuations + 1) {
    throw ArgumentError.value(
      fixture.eventCount,
      'fixture.eventCount',
      'The retention fixture must contain exactly one event more than the '
          'requested retained continuation depth.',
    );
  }

  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: fixture.entryPoints,
    randomSeed: randomSeed,
  );
  final sessions = <StoryNarrativeSession>[
    for (var index = 0; index < scenario.sessionCount; index++)
      runtime.startSession(fixture.entryPointId),
  ];

  for (var step = 0; step < historyContinuations; step++) {
    for (final session in sessions) {
      session.continueStory();
    }
  }

  if (scenario.lifecycle == Stage9dRetentionLifecycle.completed) {
    for (final session in sessions) {
      session.continueStory();
    }
  }

  final expectedActive = scenario.lifecycle == Stage9dRetentionLifecycle.active
      ? scenario.sessionCount
      : 0;
  if (runtime.activeSessions.length != expectedActive) {
    throw StateError(
      'Stage 9D2 retention workload produced ${runtime.activeSessions.length} '
      'active sessions; expected $expectedActive for ${scenario.idStem}.',
    );
  }
  if (runtime.history.sessions.length != scenario.sessionCount) {
    throw StateError(
      'Stage 9D2 retention workload lost retained session history for '
      '${scenario.idStem}.',
    );
  }

  return Stage9dRetentionWorkloadResult(runtime: runtime, scenario: scenario);
}

/// Stable aggregate-checkpoint fingerprint for one retained-session workload.
String stage9dRetentionFingerprint(Stage9dRetentionWorkloadResult result) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final json = codec.encodeJson(result.runtime.createSnapshot());
  return sha256.convert(utf8.encode(json)).toString();
}

/// Structural evidence recorded outside the Stage 9D timed region.
Map<String, Object?> stage9dRetentionMetrics(
  Stage9dRetentionWorkloadResult result,
) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final snapshot = result.runtime.createSnapshot();
  final json = codec.encodeJson(snapshot);
  return <String, Object?>{
    'lifecycle': result.scenario.lifecycle.name,
    'sessionCount': result.scenario.sessionCount,
    'activeSessionCount': result.activeSessionCount,
    'completedSessionCount': result.completedSessionCount,
    'historyProfile': result.scenario.historyScale.name,
    'historyContinuationsPerSession':
        result.scenario.historyScale.continuationsPerSession,
    'terminalCompletionOperationsPerSession':
        result.terminalCompletionOperationsPerSession,
    'totalContinueOperations': result.totalContinueOperations,
    'totalHistorySteps': result.totalHistorySteps,
    'minHistoryStepsPerSession': result.minHistoryStepsPerSession,
    'maxHistoryStepsPerSession': result.maxHistoryStepsPerSession,
    'retainedSnapshotSessionCount': snapshot.sessions.length,
    'aggregateSnapshotUtf8Bytes': utf8.encode(json).length,
    'persistentStateRevision': result.runtime.persistentStateRevision,
  };
}

/// Stable fingerprint for a captured aggregate snapshot.
String stage9dRetentionSnapshotFingerprint(
  StoryNarrativeRuntimeSnapshot snapshot,
) {
  final json = StoryNarrativeRuntimeSnapshotCodec().encodeJson(snapshot);
  return sha256.convert(utf8.encode(json)).toString();
}

/// Stable fingerprint for encoded aggregate snapshot JSON.
String stage9dRetentionEncodedFingerprint(String json) =>
    sha256.convert(utf8.encode(json)).toString();
