import 'dart:convert';
import 'dart:io';

import 'support/stage9d_benchmark_harness.dart';
import 'support/stage9d5_optimization_baseline.dart';

const _schema = 'story_engine.stage9d5.optimization_baseline.v1';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final fixtures = <String, Stage9d5Fixture>{
    for (final profile in stage9d5ProjectProfiles)
      profile.name: Stage9d5Fixture.build(profile),
  };
  final cases = <Stage9dBenchmarkCase>[];

  // Exact checkpoint restore with fixed authored projects. History depth varies
  // independently from project structure because the executable route is a
  // two-event self-loop fixture for every profile.
  for (final profile in stage9d5ProjectProfiles) {
    final fixture = fixtures[profile.name]!;
    for (final history in stage9d5RestoreHistoryProfiles) {
      cases.add(
        Stage9dBenchmarkCase.typed<
          Stage9d5RestorePrepared,
          Stage9d5RestoreResult
        >(
          id: 'restore_${profile.name}_${history.name}',
          description:
              'Restore one exact committed core checkpoint through '
              'the normal validated StoryEngine.restore path.',
          workload: <String, Object?>{
            'kind': 'validated_restore',
            'projectProfile': profile.name,
            'historyProfile': history.name,
            'historyLoopChoices': history.loopChoices,
            'authoredEventCount': fixture.authoredEventCount,
            'authoredChoiceCount': fixture.authoredChoiceCount,
            'stateVariableCount': fixture.stateVariableCount,
          },
          prepare: () =>
              prepareStage9d5Restore(fixture: fixture, historyProfile: history),
          run: runStage9d5Restore,
          fingerprint: stage9d5RestoreFingerprint,
          metrics: stage9d5RestoreMetrics,
        ),
      );
    }
  }

  // End-to-end propagation measures only the one source commit in the timed
  // region. History construction and all semantic verification happen outside.
  for (final profile in stage9d5ProjectProfiles) {
    final fixture = fixtures[profile.name]!;
    for (final history in stage9d5RestoreHistoryProfiles) {
      for (final sessionCount in stage9d5SessionCounts) {
        cases.add(
          Stage9dBenchmarkCase.typed<
            Stage9d5PropagationPrepared,
            Stage9d5PropagationResult
          >(
            id: 'propagation_${profile.name}_${history.name}_s$sessionCount',
            description:
                'Commit one shared-state change with already prepared '
                'sibling histories; verify exact sibling checkpoint parity '
                'after timing.',
            workload: <String, Object?>{
              'kind': 'shared_state_propagation',
              'projectProfile': profile.name,
              'historyProfile': history.name,
              'historyLoopChoices': history.loopChoices,
              'sessionCount': sessionCount,
              'expectedSiblingRebuildCount': sessionCount - 1,
              'authoredEventCount': fixture.authoredEventCount,
              'authoredChoiceCount': fixture.authoredChoiceCount,
              'stateVariableCount': fixture.stateVariableCount,
            },
            prepare: () => prepareStage9d5Propagation(
              fixture: fixture,
              historyProfile: history,
              sessionCount: sessionCount,
            ),
            run: runStage9d5Propagation,
            fingerprint: stage9d5PropagationFingerprint,
            metrics: stage9d5PropagationMetrics,
          ),
        );
      }
    }
  }

  // Independent long-history signal. The project is fixed and history is fully
  // built before timing; every sample measures the same 16 additional choices.
  final compactFixture = fixtures['compact']!;
  for (final history in stage9d5IncrementalHistoryProfiles) {
    for (final kind in Stage9d5HistoryExecutionKind.values) {
      cases.add(
        Stage9dBenchmarkCase.typed<
          Stage9d5HistoryPrepared,
          Stage9d5HistoryPrepared
        >(
          id: 'history_${kind.name}_${history.name}',
          description:
              'Execute a fixed 16-choice window after prebuilding '
              'history on one fixed authored loop project.',
          workload: <String, Object?>{
            'kind': 'fixed_history_increment',
            'runtimeKind': kind.name,
            'historyProfile': history.name,
            'preparedLoopChoices': history.loopChoices,
            'measuredAdditionalChoices': stage9d5MeasuredAdditionalChoices,
            'authoredEventCount': compactFixture.authoredEventCount,
            'authoredChoiceCount': compactFixture.authoredChoiceCount,
            'stateVariableCount': compactFixture.stateVariableCount,
          },
          prepare: () => prepareStage9d5HistoryIncrement(
            fixture: compactFixture,
            historyProfile: history,
            kind: kind,
          ),
          run: runStage9d5HistoryIncrement,
          fingerprint: stage9d5HistoryFingerprint,
          metrics: stage9d5HistoryMetrics,
        ),
      );
    }
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
  stdout.writeln('story_engine Stage 9D5 clean optimization baseline');
  stdout.writeln('Run this exact benchmark before and after each 9D5 change.');
  stdout.writeln(
    'Samples: ${report.config.samples}; warm-ups: '
    '${report.config.warmupIterations}',
  );
  stdout.writeln('Dart: ${report.environment['dartVersion']}');
  stdout.writeln(
    'OS: ${report.environment['operatingSystem']} '
    '(${report.environment['numberOfProcessors']} logical processors)',
  );
  stdout.writeln();

  stdout.writeln('Validated restore');
  stdout.writeln(
    'Project        | History | Events | Choices | Vars | Median us',
  );
  stdout.writeln(
    '---------------+---------+--------+---------+------+----------',
  );
  for (final result in report.results.where(
    (result) => result.workload['kind'] == 'validated_restore',
  )) {
    stdout.writeln(
      '${_pad(result.workload['projectProfile'], 14)} | '
      '${_pad(result.workload['historyProfile'], 7)} | '
      '${_pad(result.workload['authoredEventCount'], 6, right: true)} | '
      '${_pad(result.workload['authoredChoiceCount'], 7, right: true)} | '
      '${_pad(result.workload['stateVariableCount'], 4, right: true)} | '
      '${_pad(result.medianMicros, 9, right: true)}',
    );
  }

  stdout.writeln();
  stdout.writeln('Shared-state propagation');
  stdout.writeln('Project        | History | Sessions | Siblings | Median us');
  stdout.writeln('---------------+---------+----------+----------+----------');
  for (final result in report.results.where(
    (result) => result.workload['kind'] == 'shared_state_propagation',
  )) {
    stdout.writeln(
      '${_pad(result.workload['projectProfile'], 14)} | '
      '${_pad(result.workload['historyProfile'], 7)} | '
      '${_pad(result.workload['sessionCount'], 8, right: true)} | '
      '${_pad(result.workload['expectedSiblingRebuildCount'], 8, right: true)} | '
      '${_pad(result.medianMicros, 9, right: true)}',
    );
  }

  stdout.writeln();
  stdout.writeln('Fixed-project history increment (16 choices)');
  stdout.writeln('Runtime   | Prepared history | Median us');
  stdout.writeln('----------+------------------+----------');
  for (final result in report.results.where(
    (result) => result.workload['kind'] == 'fixed_history_increment',
  )) {
    stdout.writeln(
      '${_pad(result.workload['runtimeKind'], 9)} | '
      '${_pad(result.workload['historyProfile'], 16)} | '
      '${_pad(result.medianMicros, 9, right: true)}',
    );
  }

  stdout.writeln();
  stdout.writeln(
    'All fixture construction, retained-history buildup, fingerprinting, and '
    'semantic parity checks are outside the timed region.',
  );
  stdout.writeln(
    'Save the --json output before applying a 9D5 production optimization; '
    'rerun this unchanged benchmark afterward on the same machine/SDK.',
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
    var samples = 9;
    var warmups = 3;
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
