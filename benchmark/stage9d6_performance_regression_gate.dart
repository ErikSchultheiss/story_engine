import 'dart:convert';
import 'dart:io';

import 'support/stage9d_benchmark_harness.dart';
import 'support/stage9d6_contract.dart';
import 'support/stage9d6_performance_budgets.dart';
import 'support/stage9d6_representative_workloads.dart';

const _semanticBaselinePath =
    'benchmark/reference/stage9d6_semantic_baseline.json';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final report = const Stage9dBenchmarkHarness().run(
    schema: stage9d6BenchmarkReportSchema,
    cases: buildStage9d6RepresentativeCases(),
    config: Stage9dBenchmarkConfig(
      samples: options.samples,
      warmupIterations: options.warmups,
    ),
  );
  final semanticBaseline = _loadSemanticBaseline();
  final evaluation = evaluateStage9d6PerformanceBudgets(
    report: report,
    semanticBaseline: semanticBaseline,
  );
  final payload = <String, Object?>{
    'schema': stage9d6GateReportSchema,
    'timingContract': <String, Object?>{
      'version': stage9d6TimingContractVersion,
      'timerBoundaryContract': stage9d6TimerBoundaryContract,
      'frozenPreparationMode': stage9d6FrozenPreparationMode,
    },
    'provenance': _provenance(report),
    'benchmarkReport': report.toJson(),
    'budgetEvaluation': evaluation.toJson(),
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(payload);

  if (options.outputPath != null) {
    final output = File(options.outputPath!);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync('$encoded\n');
  }
  if (options.json) {
    stdout.writeln(encoded);
  } else {
    _printHumanReport(report, evaluation, options.outputPath);
  }

  exitCode = switch (evaluation.outcome) {
    Stage9d6EvaluationOutcome.pass => 0,
    Stage9d6EvaluationOutcome.fail => 1,
    Stage9d6EvaluationOutcome.inconclusive => 2,
  };
}

Stage9d6SemanticBaseline _loadSemanticBaseline() {
  final file = File(_semanticBaselinePath);
  if (!file.existsSync()) {
    throw StateError(
      'Stage 9D6 semantic baseline not found at $_semanticBaselinePath.',
    );
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<Object?, Object?>) {
    throw FormatException(
      'Stage 9D6 semantic baseline root must be an object.',
    );
  }
  return Stage9d6SemanticBaseline.fromJson(<String, Object?>{
    for (final entry in decoded.entries) '${entry.key}': entry.value,
  });
}

Map<String, Object?> _provenance(Stage9dBenchmarkReport report) {
  final sourceRevision = _gitValue(<String>['rev-parse', 'HEAD']);
  final sourceStatus = _gitValue(<String>['status', '--porcelain']);
  return <String, Object?>{
    'sourceRevision': sourceRevision ?? 'unavailable',
    'sourceRevisionAvailable': sourceRevision != null,
    'workingTreeDirty': sourceStatus == null
        ? 'unknown'
        : sourceStatus.isNotEmpty,
    'executionMode': const bool.fromEnvironment('dart.vm.product')
        ? 'dart_vm_product'
        : 'dart_vm_jit',
    'dartVersion': report.environment['dartVersion'],
    'operatingSystem': report.environment['operatingSystem'],
    'benchmarkReportSchema': report.schema,
    'gateReportSchema': stage9d6GateReportSchema,
    'semanticBaselineSchema': stage9d6SemanticBaselineSchema,
    'timingContractVersion': stage9d6TimingContractVersion,
  };
}

String? _gitValue(List<String> arguments) {
  try {
    final result = Process.runSync(
      'git',
      arguments,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      return null;
    }
    return '${result.stdout}'.trim();
  } on Object {
    return null;
  }
}

void _printHumanReport(
  Stage9dBenchmarkReport report,
  Stage9d6BudgetEvaluation evaluation,
  String? outputPath,
) {
  stdout.writeln('story_engine Stage 9D6 performance regression gate');
  stdout.writeln(
    'Samples: ${report.config.samples}; warm-ups: '
    '${report.config.warmupIterations}',
  );
  stdout.writeln('Dart: ${report.environment['dartVersion']}');
  stdout.writeln(
    'OS: ${report.environment['operatingSystem']} '
    '(${report.environment['numberOfProcessors']} logical processors)',
  );
  stdout.writeln('Timing contract: $stage9d6TimingContractVersion');
  stdout.writeln();

  if (evaluation.semanticFailures.isNotEmpty) {
    stdout.writeln('SEMANTIC / CONTRACT BASELINE: FAIL');
    for (final failure in evaluation.semanticFailures) {
      stdout.writeln('  - $failure');
    }
  } else {
    stdout.writeln('SEMANTIC / CONTRACT BASELINE: PASS');
  }

  if (evaluation.timingEvidenceIssues.isNotEmpty) {
    stdout.writeln();
    stdout.writeln('TIMING EVIDENCE: INCONCLUSIVE');
    for (final issue in evaluation.timingEvidenceIssues) {
      stdout.writeln('  - $issue');
    }
  }

  if (evaluation.checks.isNotEmpty) {
    stdout.writeln();
    stdout.writeln('RELATIVE / GROWTH-SHAPE BUDGETS');
    for (final check in evaluation.checks) {
      stdout.writeln(
        '  ${check.verdict} ${check.id}: '
        '${check.observedRatio.toStringAsFixed(3)} '
        '[${check.lowerEvidenceRatio.toStringAsFixed(3)}, '
        '${check.upperEvidenceRatio.toStringAsFixed(3)}] <= '
        '${check.maximumRatio.toStringAsFixed(3)}',
      );
    }
  }

  if (evaluation.advisories.isNotEmpty) {
    stdout.writeln();
    stdout.writeln('ADVISORIES');
    for (final advisory in evaluation.advisories) {
      stdout.writeln('  - ${advisory.message}');
    }
  }

  stdout.writeln();
  stdout.writeln('STAGE 9D6 GATE: ${evaluation.outcome.label}');
  if (evaluation.outcome == Stage9d6EvaluationOutcome.inconclusive) {
    stdout.writeln('Repeat the run before accepting or rejecting performance.');
  }
  if (outputPath != null) {
    stdout.writeln('UTF-8 JSON report: $outputPath');
  }
  stdout.writeln(
    'Stage 9D6 primarily uses relative/growth-shape budgets. Small explicit '
    'denominator floors remain part of the contract, so absolute timing can '
    'influence a verdict when a denominator falls below its floor.',
  );
}

final class _Options {
  const _Options({
    required this.samples,
    required this.warmups,
    required this.json,
    required this.outputPath,
  });

  factory _Options.parse(List<String> arguments) {
    var samples = 11;
    var warmups = 3;
    var json = false;
    String? outputPath;
    for (final argument in arguments) {
      if (argument == '--json') {
        json = true;
      } else if (argument.startsWith('--samples=')) {
        samples = _positiveInt(argument, '--samples=');
      } else if (argument.startsWith('--warmups=')) {
        warmups = _nonNegativeInt(argument, '--warmups=');
      } else if (argument.startsWith('--output=')) {
        outputPath = argument.substring('--output='.length);
        if (outputPath.isEmpty) {
          throw ArgumentError.value(argument, '--output=', 'Expected a path.');
        }
      } else {
        throw ArgumentError.value(argument, 'arguments', 'Unknown option.');
      }
    }
    return _Options(
      samples: samples,
      warmups: warmups,
      json: json,
      outputPath: outputPath,
    );
  }

  final int samples;
  final int warmups;
  final bool json;
  final String? outputPath;
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
