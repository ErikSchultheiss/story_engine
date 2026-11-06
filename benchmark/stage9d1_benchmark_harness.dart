import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';

import '../test/support/synthetic_story_project_generator.dart';
import 'support/stage9d_benchmark_harness.dart';
import 'support/stage9d_synthetic_narrative.dart';

const _schema = 'story_engine.stage9d1.benchmark_harness';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final coreProfile = _parseProfile(options.coreProfile);
  final coreFixture = SyntheticStoryProjectGenerator.structured(coreProfile);
  final narrativeFixture = Stage9dSyntheticNarrativeFixture.build(
    continuationCount: options.narrativeContinuations + 1,
  );

  final cases = <Stage9dBenchmarkCase>[
    Stage9dBenchmarkCase.typed<SyntheticStoryProjectFixture, StoryEngine>(
      id: 'core_runtime_${options.coreProfile}_primary_route',
      description:
          'Traverse one deterministic structured project through the '
          'public StoryEngine runtime to termination.',
      workload: <String, Object?>{
        'kind': 'core_runtime_primary_route',
        'profile': options.coreProfile,
        'eventCount': coreFixture.metrics.eventCount,
        'choiceCount': coreFixture.metrics.choiceCount,
        'variableCount': coreFixture.metrics.variableCount,
      },
      prepare: () => coreFixture,
      run: _runCoreRoute,
      fingerprint: _coreFingerprint,
      metrics: (engine) => <String, Object?>{
        'status': engine.status.name,
        'historySteps': engine.history.steps.length,
        'eventRouteLength': engine.history.eventRoute.length,
      },
    ),
    Stage9dBenchmarkCase.typed<
      Stage9dSyntheticNarrativeFixture,
      Stage9dNarrativeWorkloadResult
    >(
      id: 'narrative_active_sessions',
      description:
          'Start all synthetic narrative sessions, then advance them '
          'round-robin through continuation history while retaining every '
          'session as active.',
      workload: <String, Object?>{
        'kind': 'narrative_active_sessions',
        'sessionCount': options.narrativeSessions,
        'continuationsPerSession': options.narrativeContinuations,
        'sharedStateMutation': false,
        'eventCount': narrativeFixture.eventCount,
      },
      prepare: () => narrativeFixture,
      run: (fixture) => runStage9dActiveSessionWorkload(
        fixture: fixture,
        sessionCount: options.narrativeSessions,
        continuationsPerSession: options.narrativeContinuations,
      ),
      fingerprint: stage9dNarrativeFingerprint,
      metrics: stage9dNarrativeMetrics,
    ),
  ];

  final report = const Stage9dBenchmarkHarness().run(
    schema: _schema,
    cases: cases,
    config: Stage9dBenchmarkConfig(
      samples: options.samples,
      warmupIterations: options.warmups,
    ),
  );

  if (options.json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
    return;
  }
  _printHumanReport(report);
}

StoryEngine _runCoreRoute(SyntheticStoryProjectFixture fixture) {
  final engine = StoryEngine(project: fixture.project, randomSeed: 0x9d11)
    ..start();

  var guard = fixture.metrics.eventCount * 4;
  while (engine.status != StoryEngineStatus.terminated) {
    if (guard-- <= 0) {
      throw StateError('Stage 9D1 core route exceeded its progress guard.');
    }
    switch (engine.status) {
      case StoryEngineStatus.awaitingChoice:
        final choices = engine.availableChoices;
        if (choices.isEmpty) {
          throw StateError('Stage 9D1 core route exposed no available choice.');
        }
        engine.choose(choices.first.id);
        break;
      case StoryEngineStatus.awaitingContinue:
        engine.continueStory();
        break;
      case StoryEngineStatus.notStarted:
        throw StateError(
          'Stage 9D1 core route unexpectedly became notStarted.',
        );
      case StoryEngineStatus.terminated:
        break;
    }
  }
  return engine;
}

String _coreFingerprint(StoryEngine engine) {
  final json = StoryRuntimeSnapshotCodec().encodeJson(engine.createSnapshot());
  return sha256.convert(utf8.encode(json)).toString();
}

SyntheticStoryProfile _parseProfile(String value) => switch (value) {
  'small' => SyntheticStoryProfile.small,
  'medium' => SyntheticStoryProfile.medium,
  'large' => SyntheticStoryProfile.large,
  _ => throw ArgumentError.value(
    value,
    '--core-profile',
    'Expected small, medium, or large.',
  ),
};

void _printHumanReport(Stage9dBenchmarkReport report) {
  stdout.writeln('story_engine Stage 9D1 reproducible benchmark harness');
  stdout.writeln('Compare measurements on the same machine and Dart SDK.');
  stdout.writeln(
    'Samples: ${report.config.samples}; warm-ups: '
    '${report.config.warmupIterations}',
  );
  stdout.writeln('Dart: ${report.environment['dartVersion']}');
  stdout.writeln(
    'OS: ${report.environment['operatingSystem']} '
    '(${report.environment['numberOfProcessors']} logical processors)',
  );
  stdout.writeln(
    'Allocation metric: ${report.allocationMeasurement['status']}',
  );
  stdout.writeln();

  for (final result in report.results) {
    stdout.writeln(result.id);
    stdout.writeln('  ${result.description}');
    stdout.writeln('  raw: ${result.sampleMicros} us');
    stdout.writeln(
      '  median: ${result.medianMicros} us '
      '(p25 ${result.p25Micros}, p75 ${result.p75Micros}, '
      'min ${result.minMicros}, max ${result.maxMicros})',
    );
    stdout.writeln('  fingerprint: ${result.semanticFingerprint}');
    stdout.writeln('  metrics: ${jsonEncode(result.metrics)}');
  }
}

final class _Options {
  const _Options({
    required this.samples,
    required this.warmups,
    required this.coreProfile,
    required this.narrativeSessions,
    required this.narrativeContinuations,
    required this.json,
  });

  factory _Options.parse(List<String> arguments) {
    var samples = 9;
    var warmups = 3;
    var coreProfile = 'medium';
    var narrativeSessions = 10;
    var narrativeContinuations = 24;
    var json = false;

    for (final argument in arguments) {
      if (argument == '--json') {
        json = true;
      } else if (argument.startsWith('--samples=')) {
        samples = _positiveInt(argument, '--samples=');
      } else if (argument.startsWith('--warmups=')) {
        warmups = _nonNegativeInt(argument, '--warmups=');
      } else if (argument.startsWith('--core-profile=')) {
        coreProfile = argument.substring('--core-profile='.length);
      } else if (argument.startsWith('--narrative-sessions=')) {
        narrativeSessions = _positiveInt(argument, '--narrative-sessions=');
      } else if (argument.startsWith('--narrative-continuations=')) {
        narrativeContinuations = _nonNegativeInt(
          argument,
          '--narrative-continuations=',
        );
      } else {
        throw ArgumentError.value(argument, 'arguments', 'Unknown option.');
      }
    }

    _parseProfile(coreProfile);
    return _Options(
      samples: samples,
      warmups: warmups,
      coreProfile: coreProfile,
      narrativeSessions: narrativeSessions,
      narrativeContinuations: narrativeContinuations,
      json: json,
    );
  }

  final int samples;
  final int warmups;
  final String coreProfile;
  final int narrativeSessions;
  final int narrativeContinuations;
  final bool json;
}

int _positiveInt(String argument, String prefix) {
  final value = int.tryParse(argument.substring(prefix.length));
  if (value == null || value <= 0) {
    throw ArgumentError.value(argument, prefix, 'Expected a positive integer.');
  }
  return value;
}

int _nonNegativeInt(String argument, String prefix) {
  final value = int.tryParse(argument.substring(prefix.length));
  if (value == null || value < 0) {
    throw ArgumentError.value(
      argument,
      prefix,
      'Expected a non-negative integer.',
    );
  }
  return value;
}
