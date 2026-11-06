// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:story_engine/story_engine.dart';

void main(List<String> arguments) {
  final options = _BenchmarkOptions.parse(arguments);
  final fixture = _fixture();

  _runWorkload(fixture, sessions: 20);
  _runWorkload(fixture, sessions: 20, debugAdapter: _CountingDebugAdapter());

  final diagnosticsOff = _measureMedian(
    options.samples,
    () => _runWorkload(fixture, sessions: options.sessions),
  );
  final diagnosticsOn = _measureMedian(
    options.samples,
    () => _runWorkload(
      fixture,
      sessions: options.sessions,
      debugAdapter: _CountingDebugAdapter(),
    ),
  );

  final codec = StoryNarrativeRuntimeSnapshotCodec();
  final offSnapshot = codec.encodeJson(diagnosticsOff.value.createSnapshot());
  final onSnapshot = codec.encodeJson(diagnosticsOn.value.createSnapshot());
  if (offSnapshot != onSnapshot) {
    throw StateError(
      'Diagnostics-on benchmark execution diverged from diagnostics-off state.',
    );
  }

  final ratio = diagnosticsOn.medianMicros / diagnosticsOff.medianMicros;
  if (options.jsonOutput) {
    const encoder = JsonEncoder.withIndent('  ');
    print(
      encoder.convert({
        'schema': 'story_engine.stage9c6.explainability_overhead',
        'samples': options.samples,
        'sessionsPerSample': options.sessions,
        'diagnosticsOffMedianMicros': diagnosticsOff.medianMicros,
        'diagnosticsOnMedianMicros': diagnosticsOn.medianMicros,
        'overheadRatio': ratio,
      }),
    );
    return;
  }

  print('story_engine Stage 9C6 explainability overhead');
  print('Compare medians on the same machine and Dart SDK.');
  print('Samples: ${options.samples}');
  print('Sessions per sample: ${options.sessions}');
  print('Diagnostics off: ${diagnosticsOff.medianMicros} us');
  print('Diagnostics on:  ${diagnosticsOn.medianMicros} us');
  print('Overhead ratio:  ${ratio.toStringAsFixed(3)}x');
}

StoryNarrativeRuntime _runWorkload(
  _BenchmarkFixture fixture, {
  required int sessions,
  StoryNarrativeDebugAdapter? debugAdapter,
}) {
  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: fixture.entryPoints,
    randomSeed: 0x9c6,
    debugAdapter: debugAdapter,
  );

  for (var index = 0; index < sessions; index++) {
    final session = runtime.resolveAndStartSession();
    if (session == null) {
      throw StateError('Benchmark fixture unexpectedly had no eligible entry.');
    }
    session.choose(fixture.goChoiceId);
    if (!session.isTerminated) {
      throw StateError('Benchmark session did not terminate as expected.');
    }
  }

  return runtime;
}

_BenchmarkFixture _fixture() {
  final scoreId = StoryVariableId('score');
  final startId = StoryEventId('start');
  final endId = StoryEventId('end');
  final goChoiceId = StoryChoiceId('go');
  final project = StoryProject(
    id: StoryProjectId('stage9c6_benchmark'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: scoreId,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
      ],
    ),
    events: [
      StoryEvent(
        id: startId,
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: scoreId,
            amount: StoryIntegerValue(1),
          ),
        ],
        choices: [
          StoryChoice(
            id: goChoiceId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: scoreId,
              operator: StoryComparisonOperator.greaterThanOrEqual,
              value: StoryIntegerValue(0),
            ),
            effects: [
              StoryIncrementVariableEffect(
                variableId: scoreId,
                amount: StoryIntegerValue(1),
              ),
            ],
            transition: StoryEventTransition(destinationEventId: endId),
          ),
          StoryChoice(
            id: StoryChoiceId('blocked'),
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: scoreId,
              operator: StoryComparisonOperator.lessThan,
              value: StoryIntegerValue(0),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
      StoryEvent(
        id: endId,
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: scoreId,
            amount: StoryIntegerValue(1),
          ),
        ],
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  final eligibility = StoryVariableComparisonCondition(
    variableId: scoreId,
    operator: StoryComparisonOperator.greaterThanOrEqual,
    value: StoryIntegerValue(0),
  );
  return _BenchmarkFixture(
    project: project,
    entryPoints: [
      StoryEntryPoint(
        id: StoryEntryPointId('entry_a'),
        eventId: startId,
        eligibilityCondition: eligibility,
        weight: 1,
      ),
      StoryEntryPoint(
        id: StoryEntryPointId('entry_b'),
        eventId: startId,
        eligibilityCondition: eligibility,
        weight: 3,
      ),
    ],
    goChoiceId: goChoiceId,
  );
}

({T value, int medianMicros}) _measureMedian<T>(
  int samples,
  T Function() action,
) {
  final timings = <int>[];
  late T value;
  for (var sample = 0; sample < samples; sample++) {
    final stopwatch = Stopwatch()..start();
    value = action();
    stopwatch.stop();
    timings.add(stopwatch.elapsedMicroseconds);
  }
  timings.sort();
  return (value: value, medianMicros: timings[timings.length ~/ 2]);
}

final class _BenchmarkFixture {
  const _BenchmarkFixture({
    required this.project,
    required this.entryPoints,
    required this.goChoiceId,
  });

  final StoryProject project;
  final List<StoryEntryPoint> entryPoints;
  final StoryChoiceId goChoiceId;
}

final class _CountingDebugAdapter extends StoryNarrativeDebugAdapter {
  int entryResolutionCount = 0;
  int choiceBatchCount = 0;
  int effectBatchCount = 0;

  @override
  void onEntryPointResolution(
    StoryEntryPointResolutionExplanation explanation,
  ) {
    entryResolutionCount++;
  }

  @override
  void onChoiceExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) {
    choiceBatchCount++;
  }

  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) {
    effectBatchCount++;
  }
}

final class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.samples,
    required this.sessions,
    required this.jsonOutput,
  });

  final int samples;
  final int sessions;
  final bool jsonOutput;

  static _BenchmarkOptions parse(List<String> arguments) {
    var samples = 11;
    var sessions = 200;
    var jsonOutput = false;

    for (final argument in arguments) {
      if (argument == '--json') {
        jsonOutput = true;
        continue;
      }
      if (argument.startsWith('--samples=')) {
        samples = _positiveInt(argument, '--samples=');
        continue;
      }
      if (argument.startsWith('--sessions=')) {
        sessions = _positiveInt(argument, '--sessions=');
        continue;
      }
      throw ArgumentError.value(
        argument,
        'arguments',
        'Supported options: --samples=N, --sessions=N, --json.',
      );
    }

    return _BenchmarkOptions(
      samples: samples,
      sessions: sessions,
      jsonOutput: jsonOutput,
    );
  }

  static int _positiveInt(String argument, String prefix) {
    final value = int.tryParse(argument.substring(prefix.length));
    if (value == null || value <= 0) {
      throw ArgumentError.value(
        argument,
        'arguments',
        '$prefix requires a positive integer.',
      );
    }
    return value;
  }
}
