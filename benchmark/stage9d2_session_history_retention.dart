import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';

import 'support/stage9d_benchmark_harness.dart';
import 'support/stage9d_session_history_retention.dart';
import 'support/stage9d_synthetic_narrative.dart';

const _schema = 'story_engine.stage9d2.session_history_retention';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final scenarios = stage9dRetentionMatrix();
  final fixtures = <String, Stage9dSyntheticNarrativeFixture>{
    for (final scale in stage9dRetentionHistoryScales)
      scale.name: Stage9dSyntheticNarrativeFixture.build(
        continuationCount: scale.continuationsPerSession,
      ),
  };

  final cases = <Stage9dBenchmarkCase>[];
  for (final scenario in scenarios) {
    final fixture = fixtures[scenario.historyScale.name]!;
    final baseWorkload = <String, Object?>{
      'kind': 'session_history_retention',
      'lifecycle': scenario.lifecycle.name,
      'sessionCount': scenario.sessionCount,
      'historyProfile': scenario.historyScale.name,
      'historyContinuationsPerSession':
          scenario.historyScale.continuationsPerSession,
    };

    cases.add(
      Stage9dBenchmarkCase.typed<
        Stage9dSyntheticNarrativeFixture,
        Stage9dRetentionWorkloadResult
      >(
        id: '${scenario.idStem}_execute',
        description:
            'Construct and advance the retained narrative sessions '
            'for this matrix point.',
        workload: <String, Object?>{...baseWorkload, 'phase': 'execute_retain'},
        prepare: () => fixture,
        run: (preparedFixture) => runStage9dRetentionWorkload(
          fixture: preparedFixture,
          scenario: scenario,
        ),
        fingerprint: stage9dRetentionFingerprint,
        metrics: stage9dRetentionMetrics,
      ),
    );

    cases.add(
      Stage9dBenchmarkCase.typed<
        Stage9dRetentionWorkloadResult,
        StoryNarrativeRuntimeSnapshot
      >(
        id: '${scenario.idStem}_snapshot_capture',
        description:
            'Capture the aggregate runtime snapshot for the already '
            'retained sessions/history.',
        workload: <String, Object?>{
          ...baseWorkload,
          'phase': 'snapshot_capture',
        },
        prepare: () =>
            runStage9dRetentionWorkload(fixture: fixture, scenario: scenario),
        run: (prepared) => prepared.runtime.createSnapshot(),
        fingerprint: stage9dRetentionSnapshotFingerprint,
        metrics: (captured) => <String, Object?>{
          'lifecycle': scenario.lifecycle.name,
          'sessionCount': scenario.sessionCount,
          'historyProfile': scenario.historyScale.name,
          'historyContinuationsPerSession':
              scenario.historyScale.continuationsPerSession,
          'phase': 'snapshot_capture',
          'retainedSnapshotSessionCount': captured.sessions.length,
          'aggregateSnapshotUtf8Bytes': utf8
              .encode(StoryNarrativeRuntimeSnapshotCodec().encodeJson(captured))
              .length,
        },
      ),
    );

    cases.add(
      Stage9dBenchmarkCase.typed<_SnapshotEncodingInput, String>(
        id: '${scenario.idStem}_snapshot_encode',
        description:
            'Encode the already captured aggregate snapshot as '
            'deterministic compact JSON.',
        workload: <String, Object?>{
          ...baseWorkload,
          'phase': 'snapshot_encode',
        },
        prepare: () {
          final prepared = runStage9dRetentionWorkload(
            fixture: fixture,
            scenario: scenario,
          );
          return _SnapshotEncodingInput(
            codec: StoryNarrativeRuntimeSnapshotCodec(),
            snapshot: prepared.runtime.createSnapshot(),
          );
        },
        run: (prepared) => prepared.codec.encodeJson(prepared.snapshot),
        fingerprint: stage9dRetentionEncodedFingerprint,
        metrics: (json) => <String, Object?>{
          'lifecycle': scenario.lifecycle.name,
          'sessionCount': scenario.sessionCount,
          'historyProfile': scenario.historyScale.name,
          'historyContinuationsPerSession':
              scenario.historyScale.continuationsPerSession,
          'phase': 'snapshot_encode',
          'aggregateSnapshotUtf8Bytes': utf8.encode(json).length,
        },
      ),
    );
  }

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
  _printHumanReport(report, scenarios);
}

void _printHumanReport(
  Stage9dBenchmarkReport report,
  List<Stage9dRetentionScenario> scenarios,
) {
  stdout.writeln('story_engine Stage 9D2 session/history retention matrix');
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
  stdout.writeln(
    'Lifecycle | Sessions | History    | Steps | Snapshot bytes | '
    'Execute us | Capture us | Encode us',
  );
  stdout.writeln(
    '----------+----------+------------+-------+----------------+------------+'
    '------------+----------',
  );

  final byId = <String, Stage9dBenchmarkResult>{
    for (final result in report.results) result.id: result,
  };
  for (final scenario in scenarios) {
    final execute = byId['${scenario.idStem}_execute']!;
    final capture = byId['${scenario.idStem}_snapshot_capture']!;
    final encode = byId['${scenario.idStem}_snapshot_encode']!;
    final metrics = execute.metrics;
    stdout.writeln(
      '${scenario.lifecycle.name.padRight(9)} | '
      '${scenario.sessionCount.toString().padLeft(8)} | '
      '${scenario.historyScale.name.padRight(10)} | '
      '${metrics['totalHistorySteps'].toString().padLeft(5)} | '
      '${metrics['aggregateSnapshotUtf8Bytes'].toString().padLeft(14)} | '
      '${execute.medianMicros.toString().padLeft(10)} | '
      '${capture.medianMicros.toString().padLeft(10)} | '
      '${encode.medianMicros.toString().padLeft(8)}',
    );
  }
  stdout.writeln();
  stdout.writeln(
    'Medians summarize the reported raw samples. Use --json for all samples, '
    'IQR data, fingerprints, workload metadata, and environment metadata.',
  );
}

final class _SnapshotEncodingInput {
  const _SnapshotEncodingInput({required this.codec, required this.snapshot});

  final StoryNarrativeRuntimeSnapshotCodec codec;
  final StoryNarrativeRuntimeSnapshot snapshot;
}

final class _Options {
  const _Options({
    required this.samples,
    required this.warmups,
    required this.json,
  });

  factory _Options.parse(List<String> arguments) {
    var samples = 5;
    var warmups = 2;
    var json = false;

    for (final argument in arguments) {
      if (argument == '--json') {
        json = true;
      } else if (argument.startsWith('--samples=')) {
        samples = _positiveInt(argument, '--samples=');
      } else if (argument.startsWith('--warmups=')) {
        warmups = _nonNegativeInt(argument, '--warmups=');
      } else {
        throw ArgumentError.value(argument, 'arguments', 'Unknown option.');
      }
    }

    return _Options(samples: samples, warmups: warmups, json: json);
  }

  final int samples;
  final int warmups;
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
