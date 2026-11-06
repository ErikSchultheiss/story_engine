import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';

/// Deterministic synthetic narrative fixture used by Stage 9D benchmarks.
///
/// The fixture intentionally uses continuation-only events. That makes session
/// count and retained history depth independently controllable without adding
/// choice-condition or random-route cost to a retention benchmark.
final class Stage9dSyntheticNarrativeFixture {
  Stage9dSyntheticNarrativeFixture._({
    required this.project,
    required this.entryPoints,
    required this.entryPointId,
    required this.eventCount,
  });

  factory Stage9dSyntheticNarrativeFixture.build({
    required int continuationCount,
  }) {
    if (continuationCount < 0) {
      throw ArgumentError.value(
        continuationCount,
        'continuationCount',
        'Continuation count must not be negative.',
      );
    }

    final eventCount = continuationCount + 1;
    final events = <StoryEvent>[];
    for (var index = 0; index < eventCount; index++) {
      final eventId = StoryEventId('stage9d_event_$index');
      final isLast = index == eventCount - 1;
      events.add(
        StoryEvent(
          id: eventId,
          continuationTransition: isLast
              ? const StoryTerminalTransition()
              : StoryEventTransition(
                  destinationEventId: StoryEventId(
                    'stage9d_event_${index + 1}',
                  ),
                ),
        ),
      );
    }

    final entryPointId = StoryEntryPointId('stage9d_entry');
    final project = StoryProject(
      id: StoryProjectId('stage9d_synthetic_narrative'),
      stateSchema: StoryStateSchema.empty(),
      events: events,
      entryEventId: events.first.id,
    );
    final entryPoints = <StoryEntryPoint>[
      StoryEntryPoint(id: entryPointId, eventId: events.first.id),
    ];

    return Stage9dSyntheticNarrativeFixture._(
      project: project,
      entryPoints: List<StoryEntryPoint>.unmodifiable(entryPoints),
      entryPointId: entryPointId,
      eventCount: eventCount,
    );
  }

  final StoryProject project;
  final List<StoryEntryPoint> entryPoints;
  final StoryEntryPointId entryPointId;
  final int eventCount;
}

/// Result of one deterministic simultaneous-session workload.
final class Stage9dNarrativeWorkloadResult {
  const Stage9dNarrativeWorkloadResult({
    required this.runtime,
    required this.sessionCount,
    required this.continuationsPerSession,
  });

  final StoryNarrativeRuntime runtime;
  final int sessionCount;
  final int continuationsPerSession;

  int get activeSessionCount => runtime.activeSessions.length;
  int get totalHistorySteps => runtime.history.sessions.fold<int>(
    0,
    (sum, session) => sum + session.history.steps.length,
  );
}

/// Executes a deterministic active-session workload in round-robin order.
///
/// Every session is started before any session advances. Each session then
/// performs [continuationsPerSession] continuation operations, one round at a
/// time. The generated project contains one additional host-visible event so
/// all sessions remain active at the end. Stage 9D2 can build completed-session
/// variants separately without changing this 9D1 harness contract.
Stage9dNarrativeWorkloadResult runStage9dActiveSessionWorkload({
  required Stage9dSyntheticNarrativeFixture fixture,
  required int sessionCount,
  required int continuationsPerSession,
  int randomSeed = 0x9d10,
}) {
  if (sessionCount <= 0) {
    throw ArgumentError.value(
      sessionCount,
      'sessionCount',
      'Session count must be greater than zero.',
    );
  }
  if (continuationsPerSession < 0 ||
      continuationsPerSession >= fixture.eventCount) {
    throw ArgumentError.value(
      continuationsPerSession,
      'continuationsPerSession',
      'Continuation count must keep sessions on a committed event.',
    );
  }

  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: fixture.entryPoints,
    randomSeed: randomSeed,
  );
  final sessions = <StoryNarrativeSession>[
    for (var index = 0; index < sessionCount; index++)
      runtime.startSession(fixture.entryPointId),
  ];

  for (var step = 0; step < continuationsPerSession; step++) {
    for (final session in sessions) {
      session.continueStory();
    }
  }

  return Stage9dNarrativeWorkloadResult(
    runtime: runtime,
    sessionCount: sessionCount,
    continuationsPerSession: continuationsPerSession,
  );
}

String stage9dNarrativeFingerprint(Stage9dNarrativeWorkloadResult result) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final json = codec.encodeJson(result.runtime.createSnapshot());
  return sha256.convert(utf8.encode(json)).toString();
}

Map<String, Object?> stage9dNarrativeMetrics(
  Stage9dNarrativeWorkloadResult result,
) {
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final json = codec.encodeJson(result.runtime.createSnapshot());
  return <String, Object?>{
    'sessionCount': result.sessionCount,
    'activeSessionCount': result.activeSessionCount,
    'continuationsPerSession': result.continuationsPerSession,
    'totalHistorySteps': result.totalHistorySteps,
    'aggregateSnapshotUtf8Bytes': utf8.encode(json).length,
    'persistentStateRevision': result.runtime.persistentStateRevision,
  };
}
