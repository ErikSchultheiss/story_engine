// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:story_engine/story_engine.dart';

import '../test/support/synthetic_story_project_generator.dart';

void main(List<String> arguments) {
  final options = _BenchmarkOptions.parse(arguments);
  _warmUp();

  final observations = <_BenchmarkObservation>[
    for (final profile in SyntheticStoryProfile.values)
      _measureStructured(profile, samples: options.samples),
    if (options.stressEvents != null)
      _measureStress(
        eventCount: options.stressEvents!,
        samples: options.stressSamples,
      ),
  ];

  if (options.jsonOutput) {
    const encoder = JsonEncoder.withIndent('  ');
    print(
      encoder.convert({
        'schema': 'story_engine.performance_baseline.v1',
        'samples': options.samples,
        'stressSamples': options.stressSamples,
        'observations': [
          for (final observation in observations) observation.toJson(),
        ],
      }),
    );
    return;
  }

  print('story_engine performance baseline');
  print('Timings are medians in microseconds; compare on the same machine/SDK.');
  for (final observation in observations) {
    print('');
    print(
      '${observation.name}: ${observation.eventCount} events / '
      '${observation.choiceCount} choices / '
      '${observation.variableCount} variables',
    );
    print(
      '  Story Format: ${observation.bundleFileCount} files / '
      '${observation.bundleUtf8Bytes} UTF-8 bytes',
    );
    print('  validate:         ${observation.validationMicros} us');
    print('  format encode:    ${observation.formatEncodeMicros} us');
    print('  format decode:    ${observation.formatDecodeMicros} us');
    print('  runtime traverse: ${observation.runtimeTraversalMicros} us');
    print('  snapshot encode:  ${observation.snapshotEncodeMicros} us');
    print('  snapshot decode:  ${observation.snapshotDecodeMicros} us');
    print('  snapshot restore: ${observation.snapshotRestoreMicros} us');
    print(
      '  completed route:  ${observation.routeEventCount} entered events / '
      '${observation.routeChoiceCount} selected choices',
    );
  }
}

_BenchmarkObservation _measureStructured(
  SyntheticStoryProfile profile, {
  required int samples,
}) {
  final fixture = SyntheticStoryProjectGenerator.structured(profile);
  return _measureProject(
    name: profile.config.name,
    fixture: fixture,
    samples: samples,
    randomSeed: 0x6a17,
  );
}

_BenchmarkObservation _measureStress({
  required int eventCount,
  required int samples,
}) {
  final quarterScaleVariables = eventCount ~/ 4;
  final variableCount = quarterScaleVariables < 80
      ? 80
      : quarterScaleVariables > 1000
      ? 1000
      : quarterScaleVariables;
  final fixture = SyntheticStoryProjectGenerator.randomized(
    seed: 0x6a17,
    eventCount: eventCount,
    variableCount: variableCount,
  );
  return _measureProject(
    name: 'stress_$eventCount',
    fixture: fixture,
    samples: samples,
    randomSeed: 0x51ca1e,
  );
}

_BenchmarkObservation _measureProject({
  required String name,
  required SyntheticStoryProjectFixture fixture,
  required int samples,
  required int randomSeed,
}) {
  const formatCodec = StoryFormatCodec();
  final snapshotCodec = StoryRuntimeSnapshotCodec();

  final validation = _measureMedian(
    samples,
    () => StoryValidator.validate(fixture.project),
  );
  if (validation.value.errors.isNotEmpty) {
    throw StateError(
      '$name benchmark fixture is not valid: ${validation.value.summary}',
    );
  }

  final formatEncode = _measureMedian(
    samples,
    () => formatCodec.encodeProject(fixture.project),
  );
  final bundle = formatEncode.value;

  final formatDecode = _measureMedian(
    samples,
    () => formatCodec.decodeProject(bundle),
  );
  final decodedProject = formatDecode.value;

  final runtime = _measureMedian(
    samples,
    () => _runToTermination(decodedProject, randomSeed: randomSeed),
  );
  final completedEngine = runtime.value;

  final snapshot = completedEngine.createSnapshot();
  final snapshotEncode = _measureMedian(
    samples,
    () => snapshotCodec.encodeJson(snapshot),
  );
  final snapshotJson = snapshotEncode.value;

  final snapshotDecode = _measureMedian(
    samples,
    () => snapshotCodec.decodeJson(snapshotJson, project: decodedProject),
  );
  final decodedSnapshot = snapshotDecode.value;

  final snapshotRestore = _measureMedian(
    samples,
    () => StoryEngine.restore(
      project: decodedProject,
      snapshot: decodedSnapshot,
    ),
  );
  if (snapshotRestore.value.history != completedEngine.history) {
    throw StateError('$name snapshot restore did not preserve runtime history.');
  }

  final bundleUtf8Bytes = bundle.files.values.fold<int>(
    0,
    (total, source) => total + utf8.encode(source).length,
  );

  return _BenchmarkObservation(
    name: name,
    eventCount: fixture.metrics.eventCount,
    choiceCount: fixture.metrics.choiceCount,
    variableCount: fixture.metrics.variableCount,
    bundleFileCount: bundle.files.length,
    bundleUtf8Bytes: bundleUtf8Bytes,
    routeEventCount: completedEngine.history.eventRoute.length,
    routeChoiceCount: completedEngine.history.selectedChoiceIds.length,
    validationMicros: validation.medianMicros,
    formatEncodeMicros: formatEncode.medianMicros,
    formatDecodeMicros: formatDecode.medianMicros,
    runtimeTraversalMicros: runtime.medianMicros,
    snapshotEncodeMicros: snapshotEncode.medianMicros,
    snapshotDecodeMicros: snapshotDecode.medianMicros,
    snapshotRestoreMicros: snapshotRestore.medianMicros,
  );
}

StoryEngine _runToTermination(StoryProject project, {required int randomSeed}) {
  final engine = StoryEngine(project: project, randomSeed: randomSeed)..start();
  final guard = project.events.length * 3;
  var hostActions = 0;

  while (engine.status != StoryEngineStatus.terminated) {
    switch (engine.status) {
      case StoryEngineStatus.awaitingChoice:
        final choices = engine.availableChoices;
        if (choices.isEmpty) {
          throw StateError(
            'Benchmark fixture reached awaitingChoice with no available choice.',
          );
        }
        engine.choose(choices.first.id);
        hostActions++;
        break;

      case StoryEngineStatus.awaitingContinue:
        engine.continueStory();
        hostActions++;
        break;

      case StoryEngineStatus.notStarted:
        throw StateError('Started benchmark engine returned to notStarted.');

      case StoryEngineStatus.terminated:
        break;
    }

    if (hostActions > guard) {
      throw StateError('Benchmark route exceeded its forward-progress guard.');
    }
  }

  return engine;
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

void _warmUp() {
  final fixture = SyntheticStoryProjectGenerator.structured(
    SyntheticStoryProfile.small,
  );
  const formatCodec = StoryFormatCodec();
  final report = StoryValidator.validate(fixture.project);
  if (report.errors.isNotEmpty) {
    throw StateError('Warm-up fixture must be valid.');
  }
  final bundle = formatCodec.encodeProject(fixture.project);
  final project = formatCodec.decodeProject(bundle);
  _runToTermination(project, randomSeed: 0);
}

final class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.samples,
    required this.stressSamples,
    required this.stressEvents,
    required this.jsonOutput,
  });

  final int samples;
  final int stressSamples;
  final int? stressEvents;
  final bool jsonOutput;

  static _BenchmarkOptions parse(List<String> arguments) {
    var samples = 3;
    var stressSamples = 1;
    int? stressEvents;
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
      if (argument.startsWith('--stress-samples=')) {
        stressSamples = _positiveInt(argument, '--stress-samples=');
        continue;
      }
      if (argument.startsWith('--stress-events=')) {
        stressEvents = _positiveInt(argument, '--stress-events=');
        if (stressEvents < 8) {
          throw ArgumentError.value(
            stressEvents,
            '--stress-events',
            'Stress fixture requires at least 8 events.',
          );
        }
        continue;
      }
      throw ArgumentError.value(
        argument,
        'arguments',
        'Supported options: --samples=N, --stress-events=N, '
            '--stress-samples=N, --json.',
      );
    }

    return _BenchmarkOptions(
      samples: samples,
      stressSamples: stressSamples,
      stressEvents: stressEvents,
      jsonOutput: jsonOutput,
    );
  }

  static int _positiveInt(String argument, String prefix) {
    final parsed = int.tryParse(argument.substring(prefix.length));
    if (parsed == null || parsed <= 0) {
      throw ArgumentError.value(
        argument,
        'arguments',
        '$prefix requires a positive integer.',
      );
    }
    return parsed;
  }
}

final class _BenchmarkObservation {
  const _BenchmarkObservation({
    required this.name,
    required this.eventCount,
    required this.choiceCount,
    required this.variableCount,
    required this.bundleFileCount,
    required this.bundleUtf8Bytes,
    required this.routeEventCount,
    required this.routeChoiceCount,
    required this.validationMicros,
    required this.formatEncodeMicros,
    required this.formatDecodeMicros,
    required this.runtimeTraversalMicros,
    required this.snapshotEncodeMicros,
    required this.snapshotDecodeMicros,
    required this.snapshotRestoreMicros,
  });

  final String name;
  final int eventCount;
  final int choiceCount;
  final int variableCount;
  final int bundleFileCount;
  final int bundleUtf8Bytes;
  final int routeEventCount;
  final int routeChoiceCount;
  final int validationMicros;
  final int formatEncodeMicros;
  final int formatDecodeMicros;
  final int runtimeTraversalMicros;
  final int snapshotEncodeMicros;
  final int snapshotDecodeMicros;
  final int snapshotRestoreMicros;

  Map<String, Object> toJson() => <String, Object>{
    'name': name,
    'events': eventCount,
    'choices': choiceCount,
    'variables': variableCount,
    'bundleFiles': bundleFileCount,
    'bundleUtf8Bytes': bundleUtf8Bytes,
    'routeEvents': routeEventCount,
    'routeChoices': routeChoiceCount,
    'medianMicros': <String, int>{
      'validation': validationMicros,
      'formatEncode': formatEncodeMicros,
      'formatDecode': formatDecodeMicros,
      'runtimeTraversal': runtimeTraversalMicros,
      'snapshotEncode': snapshotEncodeMicros,
      'snapshotDecode': snapshotDecodeMicros,
      'snapshotRestore': snapshotRestoreMicros,
    },
  };
}
