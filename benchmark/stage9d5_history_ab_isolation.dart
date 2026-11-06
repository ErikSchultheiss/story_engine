import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';

import 'support/stage9d_benchmark_harness.dart';
import 'support/stage9d5_history_ab_isolation.dart';
import 'support/stage9d5_optimization_baseline.dart';

const _schema = 'story_engine.stage9d5.history_ab_isolation.v1';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);
  final variant = options.variant;
  final compactProfile = stage9d5ProjectProfiles.firstWhere(
    (profile) => profile.name == 'compact',
  );
  final combinedProfile = stage9d5ProjectProfiles.firstWhere(
    (profile) => profile.name == 'combined_large',
  );
  final compact = Stage9d5Fixture.build(compactProfile);
  final combined = Stage9d5Fixture.build(combinedProfile);
  final canonical = <String, StoryNarrativeRuntimeSnapshot>{};

  StoryNarrativeRuntimeSnapshot canonicalFor(
    Stage9d5Fixture fixture,
    Stage9d5HistoryProfile history,
    int sessionCount,
  ) => canonical.putIfAbsent(
    '${fixture.profile.name}:${history.name}:$sessionCount',
    () => buildStage9d5CanonicalRuntimeSnapshot(
      fixture: fixture,
      historyProfile: history,
      sessionCount: sessionCount,
    ),
  );

  // Build canonical aggregate checkpoints once, before the benchmark harness.
  // Every restored-preparation case in this process resumes the exact same
  // immutable checkpoint for its profile/history/session-count tuple.
  for (final history in stage9d5AbHistoryProfiles) {
    for (final sessionCount in stage9d5AbSessionCounts) {
      canonicalFor(compact, history, sessionCount);
    }
  }
  final longHistory = stage9d5RestoreHistoryProfiles.firstWhere(
    (history) => history.name == 'long',
  );
  for (final fixture in <Stage9d5Fixture>[compact, combined]) {
    canonicalFor(fixture, longHistory, 50);
  }

  final cases = <Stage9dBenchmarkCase>[];

  // Control is intentionally independent of the selected A/B runtime strategy.
  // Large movement here is evidence of process/JIT/GC/system drift.
  cases.add(
    Stage9dBenchmarkCase.typed<Stage9d5RestorePrepared, Stage9d5RestoreResult>(
      id: 'restore_control_combined_large_long',
      description:
          'Standalone validated restore control outside the narrative '
          'history strategy under test.',
      workload: <String, Object?>{
        'kind': 'restore_control',
        'variant': variant.label,
        'projectProfile': combined.profile.name,
        'historyProfile': longHistory.name,
      },
      prepare: () => prepareStage9d5Restore(
        fixture: combined,
        historyProfile: longHistory,
      ),
      run: runStage9d5Restore,
      fingerprint: stage9d5RestoreFingerprint,
      metrics: stage9d5RestoreMetrics,
    ),
  );

  // No-state-change history window: exposes rollback/observation overhead when
  // merely having 2 or 50 active sessions should not require sibling rebuilds.
  for (final preparationMode in Stage9d5AbPreparationMode.values) {
    for (final history in stage9d5AbHistoryProfiles) {
      for (final sessionCount in stage9d5AbSessionCounts) {
        cases.add(
          Stage9dBenchmarkCase.typed<
            Stage9d5AbHistoryPrepared,
            Stage9d5AbHistoryPrepared
          >(
            id: 'history_${preparationMode.name}_${history.name}_s$sessionCount',
            description:
                'Execute 16 unchanged-state loop choices with active '
                'session cardinality held explicit.',
            workload: <String, Object?>{
              'kind': 'history_ab',
              'variant': variant.label,
              'rollbackStrategy': variant.rollbackStrategy,
              'observationStrategy': variant.observationStrategy,
              'preparationMode': preparationMode.name,
              'historyProfile': history.name,
              'preparedLoopChoices': history.loopChoices,
              'sessionCount': sessionCount,
              'sharedStateChanges': false,
            },
            prepare: () => prepareStage9d5AbHistory(
              variant: variant,
              preparationMode: preparationMode,
              fixture: compact,
              historyProfile: history,
              sessionCount: sessionCount,
              canonicalSnapshot:
                  preparationMode == Stage9d5AbPreparationMode.restored
                  ? canonicalFor(compact, history, sessionCount)
                  : null,
            ),
            run: runStage9d5AbHistory,
            fingerprint: stage9d5AbHistoryFingerprint,
            metrics: stage9d5AbHistoryMetrics,
          ),
        );
      }
    }
  }

  // Focus on the two propagation workloads that motivated the hybrid. Each is
  // measured with natural versus identical-checkpoint preparation and with the
  // exact-project restore preparation cold versus explicitly prewarmed.
  for (final fixture in <Stage9d5Fixture>[compact, combined]) {
    for (final preparationMode in Stage9d5AbPreparationMode.values) {
      for (final prewarm in <bool>[false, true]) {
        cases.add(
          Stage9dBenchmarkCase.typed<
            Stage9d5AbPropagationPrepared,
            Stage9d5AbPropagationPrepared
          >(
            id:
                'propagation_${fixture.profile.name}_long_s50_'
                '${preparationMode.name}_${prewarm ? 'warm' : 'first'}',
            description:
                'Commit one shared-state change after long retained '
                'history with preparation and project-index warmth isolated.',
            workload: <String, Object?>{
              'kind': 'propagation_ab',
              'variant': variant.label,
              'rollbackStrategy': variant.rollbackStrategy,
              'observationStrategy': variant.observationStrategy,
              'projectProfile': fixture.profile.name,
              'historyProfile': longHistory.name,
              'sessionCount': 50,
              'preparationMode': preparationMode.name,
              'prewarmedProjectPreparation': prewarm,
            },
            prepare: () => prepareStage9d5AbPropagation(
              variant: variant,
              preparationMode: preparationMode,
              fixture: fixture,
              historyProfile: longHistory,
              sessionCount: 50,
              prewarmProjectPreparation: prewarm,
              canonicalSnapshot:
                  preparationMode == Stage9d5AbPreparationMode.restored
                  ? canonicalFor(fixture, longHistory, 50)
                  : null,
            ),
            run: runStage9d5AbPropagation,
            fingerprint: stage9d5AbPropagationFingerprint,
            metrics: stage9d5AbPropagationMetrics,
          ),
        );
      }
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
    final encoded = report.toJson();
    encoded['abVariant'] = <String, Object?>{
      'label': variant.label,
      'rollbackStrategy': variant.rollbackStrategy,
      'observationStrategy': variant.observationStrategy,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(encoded));
    return;
  }

  stdout.writeln('story_engine Stage 9D5 history A/B isolation');
  stdout.writeln(
    'Variant ${variant.label}: ${variant.rollbackStrategy} rollback + '
    '${variant.observationStrategy}.',
  );
  stdout.writeln(
    'Samples: ${report.config.samples}; warm-ups: '
    '${report.config.warmupIterations}',
  );
  for (final result in report.results) {
    stdout.writeln(
      '${result.id.padRight(58)} ${result.medianMicros.toString().padLeft(8)} us '
      '[${result.p25Micros}-${result.p75Micros}]',
    );
  }
}

final class _Options {
  const _Options({
    required this.variant,
    required this.samples,
    required this.warmups,
    required this.json,
  });

  factory _Options.parse(List<String> arguments) {
    Stage9d5AbVariant? variant;
    var samples = 7;
    var warmups = 2;
    var json = false;
    for (final argument in arguments) {
      if (argument == '--json') {
        json = true;
      } else if (argument.startsWith('--variant=')) {
        final value = argument.substring('--variant='.length).toUpperCase();
        variant = switch (value) {
          'A' => Stage9d5AbVariant.a,
          'B' => Stage9d5AbVariant.b,
          'C' => Stage9d5AbVariant.c,
          'D' => Stage9d5AbVariant.d,
          'E' => Stage9d5AbVariant.e,
          'H' || 'HYBRID' => Stage9d5AbVariant.hybrid,
          _ => throw ArgumentError.value(
            argument,
            'variant',
            'Use A/B/C/D/E/H.',
          ),
        };
      } else if (argument.startsWith('--samples=')) {
        samples = _positiveInt(argument, '--samples=');
      } else if (argument.startsWith('--warmups=')) {
        warmups = _nonNegativeInt(argument, '--warmups=');
      } else {
        throw ArgumentError.value(argument, 'arguments', 'Unknown option.');
      }
    }
    if (variant == null) {
      throw ArgumentError('Missing required --variant=A|B|C|D|E|H.');
    }
    return _Options(
      variant: variant,
      samples: samples,
      warmups: warmups,
      json: json,
    );
  }

  final Stage9d5AbVariant variant;
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
