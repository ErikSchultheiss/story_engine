import 'dart:convert';
import 'dart:io';

import 'support/stage9d_benchmark_harness.dart';
import 'support/stage9d_shared_state_propagation.dart';

const _schema = 'story_engine.stage9d3.shared_state_propagation';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final scenarios = stage9dPropagationMatrix();
  final fixtures = <String, Stage9dPropagationFixture>{
    for (final projectProfile in stage9dPropagationProjectProfiles)
      for (final historyScale in stage9dPropagationHistoryScales)
        '${projectProfile.name}:${historyScale.name}':
            Stage9dPropagationFixture.build(
              projectProfile: projectProfile,
              historyScale: historyScale,
            ),
  };

  final cases = <Stage9dBenchmarkCase>[];

  // One unit rebuild for each project/history shape. This measures the
  // correctness-first snapshot + validated restore mechanism independently of
  // how many siblings the orchestration layer needs to rebuild.
  for (final projectProfile in stage9dPropagationProjectProfiles) {
    for (final historyScale in stage9dPropagationHistoryScales) {
      final fixture = fixtures['${projectProfile.name}:${historyScale.name}']!;
      cases.add(
        Stage9dBenchmarkCase.typed<
          Stage9dSiblingRebuildPrepared,
          Stage9dSiblingRebuildResult
        >(
          id: 'sibling_rebuild_${projectProfile.name}_${historyScale.name}',
          description:
              'Capture one committed core snapshot, substitute the '
              'new shared state, then run the normal validated StoryEngine '
              'restore used by sibling propagation.',
          workload: <String, Object?>{
            'kind': 'single_sibling_snapshot_restore',
            'projectProfile': projectProfile.name,
            'historyProfile': historyScale.name,
            'historyContinuationsPerSession':
                historyScale.continuationsPerSession,
            'authoredEventCount': fixture.authoredEventCount,
            'authoredChoiceCount': fixture.authoredChoiceCount,
            'stateVariableCount': fixture.stateVariableCount,
          },
          prepare: () => prepareStage9dSiblingRebuild(fixture),
          run: runStage9dSiblingRebuild,
          fingerprint: stage9dSiblingRebuildFingerprint,
          metrics: stage9dSiblingRebuildMetrics,
        ),
      );
    }
  }

  // End-to-end source commit. Session count 1 is the no-sibling baseline;
  // 10/50 expose the cost of rebuilding 9/49 active sibling engines.
  for (final scenario in scenarios) {
    final fixture =
        fixtures['${scenario.projectProfile.name}:${scenario.historyScale.name}']!;
    cases.add(
      Stage9dBenchmarkCase.typed<
        Stage9dPropagationPrepared,
        Stage9dPropagationResult
      >(
        id: scenario.idStem,
        description:
            'Commit one real persistent-state change from the source '
            'session and synchronously rebuild every active sibling session.',
        workload: <String, Object?>{
          'kind': 'shared_persistent_state_commit',
          'projectProfile': scenario.projectProfile.name,
          'historyProfile': scenario.historyScale.name,
          'sessionCount': scenario.sessionCount,
          'siblingRebuildCount': scenario.siblingCount,
          'historyContinuationsPerSession':
              scenario.historyScale.continuationsPerSession,
          'authoredEventCount': fixture.authoredEventCount,
          'authoredChoiceCount': fixture.authoredChoiceCount,
          'stateVariableCount': fixture.stateVariableCount,
        },
        prepare: () => prepareStage9dPropagation(fixture, scenario),
        run: runStage9dPropagationCommit,
        fingerprint: stage9dPropagationFingerprint,
        metrics: stage9dPropagationMetrics,
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
  _printHumanReport(report);
}

void _printHumanReport(Stage9dBenchmarkReport report) {
  stdout.writeln('story_engine Stage 9D3 shared-state propagation');
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

  stdout.writeln('Single sibling rebuild unit');
  stdout.writeln('Project | History | Events | Choices | Vars | Rebuild us');
  stdout.writeln('--------+---------+--------+---------+------+-----------');
  for (final result in report.results.where(
    (result) => result.workload['kind'] == 'single_sibling_snapshot_restore',
  )) {
    stdout.writeln(
      '${_pad(result.workload['projectProfile'], 7)} | '
      '${_pad(result.workload['historyProfile'], 7)} | '
      '${_pad(result.workload['authoredEventCount'], 6, right: true)} | '
      '${_pad(result.workload['authoredChoiceCount'], 7, right: true)} | '
      '${_pad(result.workload['stateVariableCount'], 4, right: true)} | '
      '${_pad(result.medianMicros, 9, right: true)}',
    );
  }

  stdout.writeln();
  stdout.writeln('End-to-end shared persistent-state commit');
  stdout.writeln(
    'Project | History | Sessions | Siblings | Events | Vars | Commit us',
  );
  stdout.writeln(
    '--------+---------+----------+----------+--------+------+----------',
  );
  for (final result in report.results.where(
    (result) => result.workload['kind'] == 'shared_persistent_state_commit',
  )) {
    stdout.writeln(
      '${_pad(result.workload['projectProfile'], 7)} | '
      '${_pad(result.workload['historyProfile'], 7)} | '
      '${_pad(result.workload['sessionCount'], 8, right: true)} | '
      '${_pad(result.workload['siblingRebuildCount'], 8, right: true)} | '
      '${_pad(result.workload['authoredEventCount'], 6, right: true)} | '
      '${_pad(result.workload['stateVariableCount'], 4, right: true)} | '
      '${_pad(result.medianMicros, 8, right: true)}',
    );
  }

  stdout.writeln();
  stdout.writeln(
    'The 1-session commit is the no-sibling baseline. Compare 10/50-session '
    'growth against the matching single-rebuild unit before deciding whether '
    'the correctness-first propagation mechanism needs structural optimization.',
  );
  stdout.writeln(
    'Use --json for raw samples, IQR data, fingerprints, structural metrics, '
    'and environment metadata.',
  );
}

String _pad(Object? value, int width, {bool right = false}) {
  final text = '$value';
  return right ? text.padLeft(width) : text.padRight(width);
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
