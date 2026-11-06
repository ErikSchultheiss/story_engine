import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../benchmark/support/stage9d_benchmark_harness.dart';
import '../../benchmark/support/stage9d6_contract.dart';
import '../../benchmark/support/stage9d6_performance_budgets.dart';

void main() {
  group('Stage 9D6 performance regression budgets', () {
    late Stage9d6SemanticBaseline baseline;

    setUpAll(() {
      final decoded =
          jsonDecode(
                File(
                  'benchmark/reference/stage9d6_semantic_baseline.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      baseline = Stage9d6SemanticBaseline.fromJson(decoded);
    });

    test(
      'accepted representative shape passes without absolute primary limits',
      () {
        final evaluation = evaluateStage9d6PerformanceBudgets(
          report: _syntheticReport(baseline),
          semanticBaseline: baseline,
        );

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
        expect(evaluation.semanticFailures, isEmpty);
        expect(evaluation.timingEvidenceIssues, isEmpty);
        expect(evaluation.failedChecks, isEmpty);
        expect(evaluation.inconclusiveChecks, isEmpty);
        expect(evaluation.checks, hasLength(25));
      },
    );

    test(
      'isolated narrative history flatness regression fails only that family',
      () {
        final medians = _acceptedMedians()
          ..['history_narrative_medium'] = 10
          ..['history_narrative_long'] = 10
          ..['history_narrative_very_long'] = 26;
        final evaluation = _evaluate(baseline, medians: medians);

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(_failedIds(evaluation), <String>['history_depth_flatness']);
      },
    );

    test('isolated narrative/core overhead regression fails only overhead', () {
      final medians = _acceptedMedians()
        ..['history_core_medium'] = 1
        ..['history_core_long'] = 1
        ..['history_core_very_long'] = 1
        ..['history_narrative_medium'] = 33
        ..['history_narrative_long'] = 33
        ..['history_narrative_very_long'] = 33;
      final evaluation = _evaluate(baseline, medians: medians);

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(_failedIds(evaluation), <String>['history_narrative_overhead']);
    });

    test(
      'isolated single-session history growth regression fails only its case',
      () {
        final medians = _acceptedMedians()
          ..['propagation_compact_short_s1'] = 10
          ..['propagation_compact_long_s1'] = 21;
        final evaluation = _evaluate(baseline, medians: medians);

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(_failedIds(evaluation), <String>[
          'single_session_history_compact',
        ]);
      },
    );

    test(
      'multi-session unchanged-state history catches rejected-hybrid shape',
      () {
        final medians = _acceptedMedians()
          ..['unchanged_history_medium_s2'] = 10
          ..['unchanged_history_long_s2'] = 10
          ..['unchanged_history_very_long_s2'] = 26;
        final evaluation = _evaluate(baseline, medians: medians);

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(_failedIds(evaluation), <String>[
          'unchanged_multi_session_history_s2',
        ]);
      },
    );

    test(
      'isolated prepared sibling reuse regression fails only reuse budget',
      () {
        final medians = _acceptedMedians()
          ..['restore_event_heavy_short'] = 1000
          ..['propagation_event_heavy_short_s1'] = 20
          ..['propagation_event_heavy_short_s10'] = 5000
          ..['propagation_event_heavy_short_s50'] = 6000;
        final evaluation = _evaluate(baseline, medians: medians);

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(_failedIds(evaluation), <String>[
          'prepared_sibling_reuse_event_heavy_short',
        ]);
      },
    );

    test(
      'isolated prewarmed superlinear sibling growth fails scaling budget',
      () {
        final medians = _acceptedMedians()
          ..['prewarmed_propagation_state_heavy_short_s1'] = 100
          ..['prewarmed_propagation_state_heavy_short_s10'] = 1000
          ..['prewarmed_propagation_state_heavy_short_s50'] = 13000;
        final evaluation = _evaluate(baseline, medians: medians);

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(_failedIds(evaluation), <String>[
          'prewarmed_session_scaling_state_heavy_short',
        ]);
      },
    );

    test('exact threshold passes and just-over threshold fails', () {
      final exact = _acceptedMedians()
        ..['history_core_medium'] = 1
        ..['history_core_long'] = 1
        ..['history_core_very_long'] = 1
        ..['history_narrative_medium'] = 32
        ..['history_narrative_long'] = 32
        ..['history_narrative_very_long'] = 32;
      final exactEvaluation = _evaluate(baseline, medians: exact);
      expect(exactEvaluation.outcome, Stage9d6EvaluationOutcome.pass);
      expect(
        _check(exactEvaluation, 'history_narrative_overhead').observedRatio,
        stage9d6MaxNarrativeCoreOverhead,
      );

      final over = Map<String, int>.of(exact)
        ..['history_narrative_medium'] = 33
        ..['history_narrative_long'] = 33
        ..['history_narrative_very_long'] = 33;
      final overEvaluation = _evaluate(baseline, medians: over);
      expect(overEvaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(_failedIds(overEvaluation), <String>[
        'history_narrative_overhead',
      ]);
    });

    test('prewarmed scaling threshold passes at 2.50 and fails just over', () {
      final exact = _acceptedMedians()
        ..['prewarmed_propagation_state_heavy_short_s1'] = 100
        ..['prewarmed_propagation_state_heavy_short_s10'] = 1000
        ..['prewarmed_propagation_state_heavy_short_s50'] = 11000;
      final exactEvaluation = _evaluate(baseline, medians: exact);
      final exactScaling = _check(
        exactEvaluation,
        'prewarmed_session_scaling_state_heavy_short',
      );

      expect(exactEvaluation.outcome, Stage9d6EvaluationOutcome.pass);
      expect(
        exactScaling.observedRatio,
        stage9d6MaxPrewarmedPerSiblingSlopeGrowth,
      );

      final over = Map<String, int>.of(exact)
        ..['prewarmed_propagation_state_heavy_short_s50'] = 11040;
      final overEvaluation = _evaluate(baseline, medians: over);

      expect(overEvaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(_failedIds(overEvaluation), <String>[
        'prewarmed_session_scaling_state_heavy_short',
      ]);
    });

    test('denominator floor behavior is explicit and deterministic', () {
      final medians = _acceptedMedians()
        ..['history_core_medium'] = 1
        ..['history_core_long'] = 2
        ..['history_core_very_long'] = 3
        ..['history_narrative_medium'] = 32
        ..['history_narrative_long'] = 32
        ..['history_narrative_very_long'] = 32;
      final evaluation = _evaluate(baseline, medians: medians);
      final overhead = _check(evaluation, 'history_narrative_overhead');

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
      expect(overhead.observedRatio, 8.0);
      expect(overhead.lowerEvidenceRatio, 8.0);
      expect(overhead.upperEvidenceRatio, 8.0);
    });

    test(
      'negative timing differences clamp to zero instead of inverting slopes',
      () {
        final medians = _acceptedMedians()
          ..['prewarmed_propagation_compact_short_s1'] = 100
          ..['prewarmed_propagation_compact_short_s10'] = 90
          ..['prewarmed_propagation_compact_short_s50'] = 80;
        final evaluation = _evaluate(baseline, medians: medians);
        final scaling = _check(
          evaluation,
          'prewarmed_session_scaling_compact_short',
        );

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
        expect(scaling.observedRatio, 0.0);
      },
    );

    test('missing result ID fails semantic comparability', () {
      final report = _syntheticReport(baseline);
      final changed = _copyReport(
        report,
        results: report.results.skip(1).toList(),
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(evaluation.checks, isEmpty);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Missing'),
        ),
        isTrue,
      );
    });

    test('unexpected result ID fails semantic comparability', () {
      final report = _syntheticReport(baseline);
      final first = report.results.first;
      final changed = _copyReport(
        report,
        results: <Stage9dBenchmarkResult>[
          ...report.results,
          Stage9dBenchmarkResult(
            id: 'unexpected_case',
            description: 'unexpected',
            workload: first.workload,
            sampleMicros: first.sampleMicros,
            semanticFingerprint: first.semanticFingerprint,
            metrics: first.metrics,
          ),
        ],
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Unexpected benchmark result'),
        ),
        isTrue,
      );
    });

    test('duplicate result ID fails semantic comparability', () {
      final report = _syntheticReport(baseline);
      final changed = _copyReport(
        report,
        results: <Stage9dBenchmarkResult>[
          ...report.results,
          report.results.first,
        ],
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Duplicate benchmark result ID'),
        ),
        isTrue,
      );
    });

    test('workload metadata drift fails before timing budgets', () {
      final report = _syntheticReport(baseline);
      final targetIndex = report.results.indexWhere(
        (result) => result.id == 'unchanged_history_medium_s2',
      );
      final target = report.results[targetIndex];
      final changedTarget = _copyResult(
        target,
        workload: <String, Object?>{...target.workload, 'sessionCount': 3},
      );
      final changed = _replaceResult(report, targetIndex, changedTarget);
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures,
        contains(
          'Workload definition changed for unchanged_history_medium_s2.',
        ),
      );
    });

    test('structural metric drift fails before timing budgets', () {
      final report = _syntheticReport(baseline);
      final targetIndex = report.results.indexWhere(
        (result) => result.id == 'unchanged_history_medium_s2',
      );
      final target = report.results[targetIndex];
      final changedTarget = _copyResult(
        target,
        metrics: <String, Object?>{...target.metrics, 'counterValue': 1},
      );
      final changed = _replaceResult(report, targetIndex, changedTarget);
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures,
        contains('Structural metrics changed for unchanged_history_medium_s2.'),
      );
    });

    test(
      '9D6-owned unchanged-state fingerprint drift fails before timing budgets',
      () {
        final report = _syntheticReport(baseline);
        final targetIndex = report.results.indexWhere(
          (result) => result.id == 'unchanged_history_medium_s2',
        );
        final target = report.results[targetIndex];
        final changed = _replaceResult(
          report,
          targetIndex,
          _copyResult(
            target,
            semanticFingerprint: 'changed-owned-semantic-fingerprint',
          ),
        );
        final evaluation = evaluateStage9d6PerformanceBudgets(
          report: changed,
          semanticBaseline: baseline,
        );

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(
          evaluation.semanticFailures,
          contains(
            'Semantic fingerprint changed for unchanged_history_medium_s2.',
          ),
        );
        expect(evaluation.failedChecks, isEmpty);
      },
    );

    test('frozen semantic fingerprint drift fails before timing budgets', () {
      final report = _syntheticReport(baseline);
      final first = report.results.first;
      final changed = _replaceResult(
        report,
        0,
        _copyResult(first, semanticFingerprint: 'changed-semantic-fingerprint'),
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Semantic fingerprint changed'),
        ),
        isTrue,
      );
    });

    test(
      'prewarmed propagation must remain semantically equal to cold counterpart',
      () {
        final report = _syntheticReport(baseline);
        final index = report.results.indexWhere(
          (result) =>
              result.id == 'prewarmed_propagation_event_heavy_short_s10',
        );
        final target = report.results[index];
        final changed = _replaceResult(
          report,
          index,
          _copyResult(target, semanticFingerprint: 'different-final-runtime'),
        );
        final evaluation = evaluateStage9d6PerformanceBudgets(
          report: changed,
          semanticBaseline: baseline,
        );

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
        expect(
          evaluation.semanticFailures.any(
            (failure) => failure.contains('no longer matches'),
          ),
          isTrue,
        );
      },
    );

    test('semantic-baseline schema mismatch is rejected explicitly', () {
      final changedBaseline = _copyBaseline(
        baseline,
        schema: 'story_engine.stage9d6.semantic_baseline.unknown',
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: _syntheticReport(changedBaseline),
        semanticBaseline: changedBaseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Unsupported semantic-baseline schema'),
        ),
        isTrue,
      );
    });

    test('source benchmark schema mismatch is rejected explicitly', () {
      final changedBaseline = _copyBaseline(
        baseline,
        sourceBenchmarkSchema: 'wrong.source.schema',
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: _syntheticReport(changedBaseline),
        semanticBaseline: changedBaseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Unsupported source benchmark schema'),
        ),
        isTrue,
      );
    });

    test('gate report schema mismatch is rejected explicitly', () {
      final changedBaseline = _copyBaseline(
        baseline,
        gateReportSchema: 'wrong.gate.schema',
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: _syntheticReport(changedBaseline),
        semanticBaseline: changedBaseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('gate-report schema mismatch'),
        ),
        isTrue,
      );
    });

    test('benchmark report schema mismatch is rejected explicitly', () {
      final report = _syntheticReport(baseline);
      final changed = _copyReport(report, schema: 'wrong.report.schema');
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: changed,
        semanticBaseline: baseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Benchmark report schema mismatch'),
        ),
        isTrue,
      );
    });

    test('timing-contract identity mismatch is rejected explicitly', () {
      final changedBaseline = _copyBaseline(
        baseline,
        timingContractVersion: 'wrong.timing.contract',
      );
      final evaluation = evaluateStage9d6PerformanceBudgets(
        report: _syntheticReport(changedBaseline),
        semanticBaseline: changedBaseline,
      );

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.fail);
      expect(
        evaluation.semanticFailures.any(
          (failure) => failure.contains('Timing contract version mismatch'),
        ),
        isTrue,
      );
    });

    test('all-zero timing evidence is INCONCLUSIVE rather than PASS', () {
      final zeros = <String, int>{for (final id in baseline.allCaseIds) id: 0};
      final evaluation = _evaluate(baseline, medians: zeros);

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.inconclusive);
      expect(evaluation.passed, isFalse);
      expect(evaluation.checks, isEmpty);
      expect(evaluation.timingEvidenceIssues, isNotEmpty);
    });

    test('ratio evidence straddling a threshold is INCONCLUSIVE', () {
      final medians = _acceptedMedians()
        ..['history_core_medium'] = 4
        ..['history_narrative_medium'] = 32;
      final evaluation = _evaluate(
        baseline,
        medians: medians,
        sampleCount: 5,
        samples: <String, List<int>>{
          'history_narrative_medium': <int>[28, 28, 32, 36, 36],
        },
      );
      final overhead = _check(evaluation, 'history_narrative_overhead');

      expect(evaluation.outcome, Stage9d6EvaluationOutcome.inconclusive);
      expect(overhead.inconclusive, isTrue);
      expect(overhead.lowerEvidenceRatio, lessThanOrEqualTo(8.0));
      expect(overhead.upperEvidenceRatio, greaterThan(8.0));
    });

    test(
      'high dispersion far from a threshold remains advisory, not failure',
      () {
        final evaluation = _evaluate(
          baseline,
          sampleCount: 5,
          samples: <String, List<int>>{
            'restore_event_heavy_long': <int>[1000, 1000, 1100, 3000, 3000],
          },
        );

        expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
        expect(
          evaluation.advisories.map((advisory) => advisory.id),
          contains('dispersion_restore_event_heavy_long'),
        );
      },
    );

    test(
      '3/8 mixed regime is detected even when quartiles share the slow mode',
      () {
        final evaluation = _evaluate(
          baseline,
          sampleCount: 11,
          samples: <String, List<int>>{
            'prewarmed_propagation_event_heavy_long_s1': <int>[
              12,
              12,
              12,
              11,
              10,
              11,
              10,
              13,
              10,
              10,
              12,
            ],
            'prewarmed_propagation_event_heavy_long_s10': <int>[
              1543,
              1541,
              1461,
              1484,
              1484,
              1519,
              1481,
              1553,
              1505,
              1480,
              1607,
            ],
            'prewarmed_propagation_event_heavy_long_s50': <int>[
              13328,
              13046,
              12827,
              13012,
              8152,
              13057,
              8376,
              12920,
              13247,
              8194,
              13078,
            ],
          },
        );

        final scaling = _check(
          evaluation,
          'prewarmed_session_scaling_event_heavy_long',
        );
        expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
        expect(
          scaling.upperEvidenceRatio,
          lessThan(stage9d6MaxPrewarmedPerSiblingSlopeGrowth),
        );
        expect(
          evaluation.advisories.map((advisory) => advisory.id),
          contains('mixed_regime_prewarmed_propagation_event_heavy_long_s50'),
        );
        expect(
          evaluation.advisories
              .singleWhere(
                (advisory) =>
                    advisory.id ==
                    'mixed_regime_prewarmed_propagation_event_heavy_long_s50',
              )
              .message,
          contains('3/8 samples'),
        );
      },
    );

    test('9/12 mixed regime is detected in the larger repeat sample', () {
      final evaluation = _evaluate(
        baseline,
        sampleCount: 21,
        samples: <String, List<int>>{
          'prewarmed_propagation_event_heavy_long_s1': <int>[
            11,
            9,
            9,
            9,
            8,
            9,
            13,
            9,
            10,
            8,
            8,
            14,
            9,
            10,
            9,
            8,
            8,
            10,
            9,
            9,
            8,
          ],
          'prewarmed_propagation_event_heavy_long_s10': <int>[
            1499,
            1472,
            1477,
            1484,
            1495,
            1457,
            1458,
            1482,
            1524,
            1475,
            1478,
            1505,
            1486,
            1516,
            1504,
            1483,
            1484,
            1465,
            1448,
            1467,
            1471,
          ],
          'prewarmed_propagation_event_heavy_long_s50': <int>[
            8376,
            12824,
            8054,
            13551,
            8148,
            13066,
            13041,
            12761,
            8024,
            12529,
            8246,
            13399,
            7984,
            13198,
            8048,
            8121,
            12026,
            8168,
            12771,
            12925,
            13491,
          ],
        },
      );

      final scaling = _check(
        evaluation,
        'prewarmed_session_scaling_event_heavy_long',
      );
      expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
      expect(
        scaling.upperEvidenceRatio,
        lessThan(stage9d6MaxPrewarmedPerSiblingSlopeGrowth),
      );
      expect(
        evaluation.advisories.map((advisory) => advisory.id),
        contains('mixed_regime_prewarmed_propagation_event_heavy_long_s50'),
      );
      expect(
        evaluation.advisories
            .singleWhere(
              (advisory) =>
                  advisory.id ==
                  'mixed_regime_prewarmed_propagation_event_heavy_long_s50',
            )
            .message,
        contains('9/12 samples'),
      );
    });

    test('10/11 mixed regime from final calibration run remains accepted', () {
      final evaluation = _evaluate(
        baseline,
        sampleCount: 21,
        samples: <String, List<int>>{
          'prewarmed_propagation_event_heavy_long_s1': <int>[
            9,
            14,
            17,
            14,
            11,
            10,
            18,
            12,
            12,
            10,
            11,
            11,
            10,
            23,
            13,
            15,
            10,
            9,
            10,
            9,
            11,
          ],
          'prewarmed_propagation_event_heavy_long_s10': <int>[
            1477,
            1769,
            1576,
            1492,
            1540,
            1446,
            1509,
            1674,
            1531,
            1467,
            1659,
            1725,
            1482,
            1507,
            1627,
            1581,
            1494,
            1473,
            1478,
            1440,
            1441,
          ],
          'prewarmed_propagation_event_heavy_long_s50': <int>[
            8994,
            15947,
            9493,
            14599,
            9330,
            16975,
            8174,
            16672,
            8411,
            15369,
            8589,
            15370,
            9320,
            15842,
            9407,
            8455,
            15442,
            8976,
            15159,
            15274,
            14480,
          ],
        },
      );

      final scaling = _check(
        evaluation,
        'prewarmed_session_scaling_event_heavy_long',
      );
      expect(evaluation.outcome, Stage9d6EvaluationOutcome.pass);
      expect(scaling.observedRatio, closeTo(1.95115307486631, 1e-9));
      expect(scaling.upperEvidenceRatio, closeTo(2.136654135338346, 1e-9));
      expect(
        scaling.upperEvidenceRatio,
        lessThan(stage9d6MaxPrewarmedPerSiblingSlopeGrowth),
      );
      expect(
        evaluation.advisories.map((advisory) => advisory.id),
        contains('mixed_regime_prewarmed_propagation_event_heavy_long_s50'),
      );
      expect(
        evaluation.advisories
            .singleWhere(
              (advisory) =>
                  advisory.id ==
                  'mixed_regime_prewarmed_propagation_event_heavy_long_s50',
            )
            .message,
        contains('10/11 samples'),
      );
    });

    test(
      'two high observations in 21 samples stay outlier evidence, not a regime',
      () {
        final evaluation = _evaluate(
          baseline,
          sampleCount: 21,
          samples: <String, List<int>>{
            'prewarmed_propagation_compact_long_s10': <int>[
              2824,
              1575,
              1489,
              1495,
              1517,
              1475,
              1531,
              1462,
              1445,
              1458,
              1492,
              1460,
              1452,
              1521,
              1482,
              2805,
              1557,
              1459,
              1470,
              1679,
              1478,
            ],
          },
        );

        expect(
          evaluation.advisories.map((advisory) => advisory.id),
          isNot(
            contains('mixed_regime_prewarmed_propagation_compact_long_s10'),
          ),
        );
      },
    );

    test(
      'semantic baseline is timing-free and identifies all contract schemas',
      () {
        final decoded =
            jsonDecode(
                  File(
                    'benchmark/reference/stage9d6_semantic_baseline.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final encoded = jsonEncode(decoded);

        expect(baseline.schema, stage9d6SemanticBaselineSchema);
        expect(baseline.sourceBenchmarkSchema, stage9d6SourceBenchmarkSchema);
        expect(baseline.gateReportSchema, stage9d6GateReportSchema);
        expect(baseline.benchmarkReportSchema, stage9d6BenchmarkReportSchema);
        expect(baseline.timingContractVersion, stage9d6TimingContractVersion);
        expect(baseline.timerBoundaryContract, stage9d6TimerBoundaryContract);
        expect(baseline.cases, hasLength(46));
        expect(baseline.ownedCases, hasLength(36));
        expect(
          baseline.ownedCases.values.where(
            (semanticCase) => semanticCase.semanticFingerprint != null,
          ),
          hasLength(6),
        );
        expect(
          baseline.ownedCases.values.where(
            (semanticCase) =>
                semanticCase.semanticFingerprintMatchesCase != null,
          ),
          hasLength(30),
        );
        expect(baseline.allCaseIds, hasLength(82));
        expect(encoded, isNot(contains('sampleMicros')));
        expect(encoded, isNot(contains('medianMicros')));
        expect(encoded, isNot(contains('p25Micros')));
        expect(encoded, isNot(contains('p75Micros')));
      },
    );
  });
}

Stage9d6BudgetEvaluation _evaluate(
  Stage9d6SemanticBaseline baseline, {
  Map<String, int>? medians,
  Map<String, List<int>> samples = const <String, List<int>>{},
  int sampleCount = 3,
}) => evaluateStage9d6PerformanceBudgets(
  report: _syntheticReport(
    baseline,
    medians: medians,
    samples: samples,
    sampleCount: sampleCount,
  ),
  semanticBaseline: baseline,
);

List<String> _failedIds(Stage9d6BudgetEvaluation evaluation) =>
    evaluation.failedChecks.map((check) => check.id).toList(growable: false);

Stage9d6BudgetCheck _check(Stage9d6BudgetEvaluation evaluation, String id) =>
    evaluation.checks.singleWhere((check) => check.id == id);

Stage9dBenchmarkReport _syntheticReport(
  Stage9d6SemanticBaseline baseline, {
  Map<String, int>? medians,
  Map<String, List<int>> samples = const <String, List<int>>{},
  int sampleCount = 3,
}) {
  final timings = medians ?? _acceptedMedians();
  final results = <Stage9dBenchmarkResult>[];

  void addResult({
    required String id,
    required Map<String, Object?> workload,
    required Map<String, Object?> metrics,
    required String fingerprint,
  }) {
    final median = timings[id] ?? 100;
    final caseSamples = samples[id] ?? List<int>.filled(sampleCount, median);
    results.add(
      Stage9dBenchmarkResult(
        id: id,
        description: id,
        workload: workload,
        sampleMicros: caseSamples,
        semanticFingerprint: fingerprint,
        metrics: metrics,
      ),
    );
  }

  for (final semanticCase in baseline.cases.values) {
    addResult(
      id: semanticCase.id,
      workload: semanticCase.workload,
      metrics: semanticCase.metrics,
      fingerprint: semanticCase.semanticFingerprint,
    );
  }
  for (final semanticCase in baseline.ownedCases.values) {
    final reference = semanticCase.semanticFingerprintMatchesCase;
    addResult(
      id: semanticCase.id,
      workload: semanticCase.workload,
      metrics: semanticCase.metrics,
      fingerprint:
          semanticCase.semanticFingerprint ??
          (reference == null
              ? 'structural:${semanticCase.id}'
              : baseline.cases[reference]!.semanticFingerprint),
    );
  }

  return Stage9dBenchmarkReport(
    schema: stage9d6BenchmarkReportSchema,
    config: Stage9dBenchmarkConfig(samples: sampleCount, warmupIterations: 0),
    environment: const <String, Object?>{},
    allocationMeasurement: const <String, Object?>{},
    results: results,
  );
}

Stage9dBenchmarkResult _copyResult(
  Stage9dBenchmarkResult source, {
  Map<String, Object?>? workload,
  List<int>? sampleMicros,
  String? semanticFingerprint,
  Map<String, Object?>? metrics,
}) => Stage9dBenchmarkResult(
  id: source.id,
  description: source.description,
  workload: workload ?? source.workload,
  sampleMicros: sampleMicros ?? source.sampleMicros,
  semanticFingerprint: semanticFingerprint ?? source.semanticFingerprint,
  metrics: metrics ?? source.metrics,
);

Stage9dBenchmarkReport _replaceResult(
  Stage9dBenchmarkReport report,
  int index,
  Stage9dBenchmarkResult replacement,
) {
  final results = report.results.toList();
  results[index] = replacement;
  return _copyReport(report, results: results);
}

Stage9dBenchmarkReport _copyReport(
  Stage9dBenchmarkReport source, {
  String? schema,
  List<Stage9dBenchmarkResult>? results,
}) => Stage9dBenchmarkReport(
  schema: schema ?? source.schema,
  config: source.config,
  environment: source.environment,
  allocationMeasurement: source.allocationMeasurement,
  results: results ?? source.results,
);

Stage9d6SemanticBaseline _copyBaseline(
  Stage9d6SemanticBaseline source, {
  String? schema,
  String? sourceBenchmarkSchema,
  String? gateReportSchema,
  String? benchmarkReportSchema,
  String? timingContractVersion,
  String? timerBoundaryContract,
  String? frozenPreparationMode,
}) => Stage9d6SemanticBaseline(
  schema: schema ?? source.schema,
  sourceBenchmarkSchema: sourceBenchmarkSchema ?? source.sourceBenchmarkSchema,
  gateReportSchema: gateReportSchema ?? source.gateReportSchema,
  benchmarkReportSchema: benchmarkReportSchema ?? source.benchmarkReportSchema,
  timingContractVersion: timingContractVersion ?? source.timingContractVersion,
  timerBoundaryContract: timerBoundaryContract ?? source.timerBoundaryContract,
  frozenPreparationMode: frozenPreparationMode ?? source.frozenPreparationMode,
  cases: source.cases,
  ownedCases: source.ownedCases,
);

Map<String, int> _acceptedMedians() => <String, int>{
  'restore_compact_short': 100,
  'restore_compact_long': 150,
  'restore_event_heavy_short': 1000,
  'restore_event_heavy_long': 1100,
  'restore_choice_heavy_short': 1000,
  'restore_choice_heavy_long': 1100,
  'restore_state_heavy_short': 100,
  'restore_state_heavy_long': 200,
  'restore_combined_large_short': 2000,
  'restore_combined_large_long': 2200,
  'propagation_compact_short_s1': 20,
  'propagation_compact_short_s10': 110,
  'propagation_compact_short_s50': 510,
  'propagation_compact_long_s1': 20,
  'propagation_compact_long_s10': 1700,
  'propagation_compact_long_s50': 9000,
  'propagation_event_heavy_short_s1': 20,
  'propagation_event_heavy_short_s10': 1100,
  'propagation_event_heavy_short_s50': 1500,
  'propagation_event_heavy_long_s1': 20,
  'propagation_event_heavy_long_s10': 2500,
  'propagation_event_heavy_long_s50': 9000,
  'propagation_choice_heavy_short_s1': 20,
  'propagation_choice_heavy_short_s10': 1150,
  'propagation_choice_heavy_short_s50': 1600,
  'propagation_choice_heavy_long_s1': 20,
  'propagation_choice_heavy_long_s10': 2600,
  'propagation_choice_heavy_long_s50': 9200,
  'propagation_state_heavy_short_s1': 100,
  'propagation_state_heavy_short_s10': 850,
  'propagation_state_heavy_short_s50': 4200,
  'propagation_state_heavy_long_s1': 100,
  'propagation_state_heavy_long_s10': 2300,
  'propagation_state_heavy_long_s50': 12000,
  'propagation_combined_large_short_s1': 100,
  'propagation_combined_large_short_s10': 3000,
  'propagation_combined_large_short_s50': 7000,
  'propagation_combined_large_long_s1': 100,
  'propagation_combined_large_long_s10': 4500,
  'propagation_combined_large_long_s50': 14500,
  'history_core_medium': 6,
  'history_narrative_medium': 12,
  'history_core_long': 3,
  'history_narrative_long': 11,
  'history_core_very_long': 3,
  'history_narrative_very_long': 10,
  'unchanged_history_medium_s2': 80,
  'unchanged_history_long_s2': 82,
  'unchanged_history_very_long_s2': 84,
  'unchanged_history_medium_s50': 82,
  'unchanged_history_long_s50': 84,
  'unchanged_history_very_long_s50': 86,
  'prewarmed_propagation_compact_short_s1': 20,
  'prewarmed_propagation_compact_short_s10': 110,
  'prewarmed_propagation_compact_short_s50': 510,
  'prewarmed_propagation_compact_long_s1': 25,
  'prewarmed_propagation_compact_long_s10': 115,
  'prewarmed_propagation_compact_long_s50': 515,
  'prewarmed_propagation_event_heavy_short_s1': 20,
  'prewarmed_propagation_event_heavy_short_s10': 200,
  'prewarmed_propagation_event_heavy_short_s50': 1000,
  'prewarmed_propagation_event_heavy_long_s1': 50,
  'prewarmed_propagation_event_heavy_long_s10': 320,
  'prewarmed_propagation_event_heavy_long_s50': 1520,
  'prewarmed_propagation_choice_heavy_short_s1': 20,
  'prewarmed_propagation_choice_heavy_short_s10': 200,
  'prewarmed_propagation_choice_heavy_short_s50': 1000,
  'prewarmed_propagation_choice_heavy_long_s1': 50,
  'prewarmed_propagation_choice_heavy_long_s10': 320,
  'prewarmed_propagation_choice_heavy_long_s50': 1520,
  'prewarmed_propagation_state_heavy_short_s1': 100,
  'prewarmed_propagation_state_heavy_short_s10': 1000,
  'prewarmed_propagation_state_heavy_short_s50': 5000,
  'prewarmed_propagation_state_heavy_long_s1': 120,
  'prewarmed_propagation_state_heavy_long_s10': 1200,
  'prewarmed_propagation_state_heavy_long_s50': 6000,
  'prewarmed_propagation_combined_large_short_s1': 100,
  'prewarmed_propagation_combined_large_short_s10': 1000,
  'prewarmed_propagation_combined_large_short_s50': 5000,
  'prewarmed_propagation_combined_large_long_s1': 150,
  'prewarmed_propagation_combined_large_long_s10': 1500,
  'prewarmed_propagation_combined_large_long_s50': 7500,
};
