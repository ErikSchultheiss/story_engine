import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';

/// Read-only benchmark configuration; no timing gates are imposed.
final class AggregateLoadScenario {
  const AggregateLoadScenario(
    this.id,
    this.sessions,
    this.repeats,
    this.paddingEvents,
    this.variables,
  );
  final String id;
  final int sessions;
  final int repeats;
  final int paddingEvents;
  final int variables;
}

const aggregateLoadScenarios = [
  AggregateLoadScenario('compact', 10, 8, 0, 8),
  AggregateLoadScenario('retained_history', 50, 128, 512, 32),
  AggregateLoadScenario('large_retained_history', 200, 256, 2048, 128),
];

/// Deterministic aggregate with active, terminated and host-suspended sessions.
final class AggregateLoadFixture {
  AggregateLoadFixture._(
    this.project,
    this.entryPoints,
    this.snapshot,
    this.json,
  );
  factory AggregateLoadFixture.build(AggregateLoadScenario scenario) {
    final eventId = StoryEventId('route');
    final score = StoryVariableId('score');
    final repeat = StoryChoiceId('repeat');
    final finish = StoryChoiceId('finish');
    final project = StoryProject(
      id: StoryProjectId('aggregate_load_${scenario.id}'),
      entryEventId: eventId,
      stateSchema: StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: score,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(0),
          ),
          for (var n = 1; n < scenario.variables; n++)
            StoryVariableDefinition(
              id: StoryVariableId('value_$n'),
              type: StoryValueType.string,
              initialValue: StoryStringValue(
                'Retained value $n: deterministic load-path verification.',
              ),
            ),
        ],
      ),
      events: [
        StoryEvent(
          id: eventId,
          choices: [
            StoryChoice(
              id: repeat,
              transition: StoryConditionalTransition(
                branches: [
                  StoryConditionalTransitionBranch(
                    condition: StoryVariableComparisonCondition(
                      variableId: score,
                      operator: StoryComparisonOperator.greaterThanOrEqual,
                      value: StoryIntegerValue(0),
                    ),
                    transition: StoryWeightedTransition(
                      options: [
                        StoryWeightedTransitionOption(
                          weight: 1,
                          transition: StoryEventTransition(
                            destinationEventId: eventId,
                          ),
                        ),
                        StoryWeightedTransitionOption(
                          weight: 3,
                          transition: StoryEventTransition(
                            destinationEventId: eventId,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                fallback: const StoryTerminalTransition(),
              ),
            ),
            StoryChoice(
              id: StoryChoiceId('bump'),
              effects: [
                StoryIncrementVariableEffect(
                  variableId: score,
                  amount: StoryIntegerValue(1),
                ),
              ],
              transition: StoryEventTransition(destinationEventId: eventId),
            ),
            StoryChoice(
              id: finish,
              transition: const StoryTerminalTransition(),
            ),
          ],
        ),
        for (var n = 0; n < scenario.paddingEvents; n++)
          StoryEvent(
            id: StoryEventId('padding_$n'),
            continuationTransition: const StoryTerminalTransition(),
          ),
      ],
    );
    final entries = [
      StoryEntryPoint(id: StoryEntryPointId('entry'), eventId: eventId),
    ];
    final runtime = StoryNarrativeRuntime(
      project: project,
      entryPoints: entries,
      randomSeed: 119,
    );
    for (var n = 0; n < scenario.sessions; n++) {
      final session = runtime.startSession(entries.single.id);
      for (var step = 0; step < scenario.repeats; step++) {
        session.choose(repeat);
      }
      if (n % 4 == 0) {
        session.choose(finish);
      } else if (n % 4 == 1) {
        session.requestHostAction(
          schemaNamespace: 'org.example.load',
          actionId: 'verify',
          arguments: {'session': n},
          resultType: const StoryHostActionValueType.boolean(),
        );
      }
    }
    // Terminated sessions retain their historical state while unfinished
    // sessions, including host-suspended ones, receive the shared commit.
    runtime.activeSessions
        .lastWhere(
          (s) => s.sessionStatus == StoryNarrativeSessionStatus.awaitingChoice,
        )
        .choose(StoryChoiceId('bump'));
    final snapshot = runtime.createSnapshot();
    final encoded = StoryNarrativeRuntimeSnapshotCodec().encodeJson(snapshot);
    return AggregateLoadFixture._(project, entries, snapshot, encoded);
  }
  final StoryProject project;
  final List<StoryEntryPoint> entryPoints;
  final StoryNarrativeRuntimeSnapshot snapshot;
  final String json;
  int get jsonBytes => utf8.encode(json).length;
  int get retainedHistorySteps => snapshot.sessions.fold(
    0,
    (sum, s) => sum + s.runtimeSnapshot.history.steps.length,
  );

  StoryNarrativeRuntime loadJson() {
    final decoded = StoryNarrativeRuntimeSnapshotCodec().decodeJson(
      json,
      project: project,
      entryPoints: entryPoints,
    );
    return StoryNarrativeRuntime.restore(
      project: project,
      entryPoints: entryPoints,
      snapshot: decoded,
    );
  }

  /// Verification stays outside timed regions. It compares the entire durable
  /// aggregate, then a future weighted input against direct typed restoration.
  String verify(StoryNarrativeRuntime restored) {
    final codec = StoryNarrativeRuntimeSnapshotCodec();
    final encoded = codec.encodeJson(restored.createSnapshot());
    if (encoded != json) {
      throw StateError('Aggregate load changed durable checkpoint bytes.');
    }
    final direct = StoryNarrativeRuntime.restore(
      project: project,
      entryPoints: entryPoints,
      snapshot: snapshot,
    );
    final index = restored.activeSessions
        .lastWhere(
          (s) => s.sessionStatus == StoryNarrativeSessionStatus.awaitingChoice,
        )
        .index;
    restored.sessionByIndex(index).choose(StoryChoiceId('repeat'));
    direct.sessionByIndex(index).choose(StoryChoiceId('repeat'));
    final next = codec.encodeJson(restored.createSnapshot());
    if (next != codec.encodeJson(direct.createSnapshot())) {
      throw StateError('Restored future input diverged from typed checkpoint.');
    }
    return sha256.convert(utf8.encode(next)).toString();
  }
}

/// Captures raw measurements with reproducible semantic fingerprints.
Map<String, Object?> measureAggregateLoad(
  AggregateLoadScenario scenario, {
  required int samples,
  required int warmups,
}) {
  final fixture = AggregateLoadFixture.build(scenario);
  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final parsed = jsonDecode(fixture.json);
  final decoded = codec.decode(
    parsed,
    project: fixture.project,
    entryPoints: fixture.entryPoints,
  );
  final phases = <String, Object? Function()>{
    'jsonParse': () => jsonDecode(fixture.json),
    'typedDecodeAndValidation': () => codec.decode(
      parsed,
      project: fixture.project,
      entryPoints: fixture.entryPoints,
    ),
    'restoreDecoded': () => StoryNarrativeRuntime.restore(
      project: fixture.project,
      entryPoints: fixture.entryPoints,
      snapshot: decoded,
    ),
    'jsonDecodeToAggregateRestore': fixture.loadJson,
  };
  final timings = <String, Object?>{};
  String? fingerprint;
  for (final entry in phases.entries) {
    for (var n = 0; n < warmups; n++) {
      entry.value();
    }
    final measurements = <int>[];
    for (var n = 0; n < samples; n++) {
      final clock = Stopwatch()..start();
      final result = entry.value();
      clock.stop();
      measurements.add(clock.elapsedMicroseconds);
      if (result is StoryNarrativeRuntime) {
        final current = fixture.verify(result);
        if (fingerprint != null && fingerprint != current) {
          throw StateError('Semantic fingerprint changed between samples.');
        }
        fingerprint = current;
      }
    }
    final sorted = measurements.toList()..sort();
    timings[entry.key] = {
      'samplesMicros': measurements,
      'medianMicros': sorted[sorted.length ~/ 2],
      'p25Micros': sorted[(sorted.length - 1) ~/ 4],
      'p75Micros': sorted[((sorted.length - 1) * 3) ~/ 4],
    };
  }
  return {
    'id': scenario.id,
    'retainedSessions': scenario.sessions,
    'repeatsPerSession': scenario.repeats,
    'authoredEvents': fixture.project.events.length,
    'stateVariables': scenario.variables,
    'retainedHistorySteps': fixture.retainedHistorySteps,
    'jsonUtf8Bytes': fixture.jsonBytes,
    'semanticFingerprint': fingerprint,
    'timings': timings,
  };
}
