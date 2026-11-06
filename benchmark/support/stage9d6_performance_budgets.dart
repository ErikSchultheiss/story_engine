import 'stage9d_benchmark_harness.dart';
import 'stage9d6_contract.dart';

const double stage9d6MaxNarrativeHistoryDepthGrowth = 2.5;
const double stage9d6MaxNarrativeCoreOverhead = 8.0;
const double stage9d6MaxSingleSessionHistoryGrowth = 2.0;
const double stage9d6MaxMultiSessionUnchangedHistoryGrowth = 2.5;
const double stage9d6MaxPreparedSiblingCostVsRestore = 0.40;

/// Calibrated against repeated accepted-runtime evidence after switching the
/// session-scaling formula from confounded cold points to comparable prewarmed
/// points. See the Stage 9D6 budget document for the evidence and rationale.
const double stage9d6MaxPrewarmedPerSiblingSlopeGrowth = 2.50;

const double stage9d6DispersionAdvisoryRatio = 1.75;

/// Mixed-regime candidates need a substantive population on both sides plus
/// visible boundary and center separation. This keeps small outlier tails from
/// being promoted to a second timing regime.
const double stage9d6MixedRegimeMinBoundaryGapRatio = 1.30;
const double stage9d6MixedRegimeMinMedianSeparationRatio = 1.45;
const double stage9d6MixedRegimeMinClusterFraction = 0.20;
const int stage9d6DispersionMedianFloorMicros = 100;
const double stage9d6CoreTimingFloorMicros = 4.0;
const double stage9d6SingleSessionTimingFloorMicros = 10.0;
const double stage9d6SiblingSlopeTimingFloorMicros = 1.0;

/// Machine-independent semantic/timing identity for the accepted Stage 9D6
/// workload. The frozen source cases retain exact semantic fingerprints. New
/// 9D6-owned cases additionally carry exact workload/metric contracts and may
/// either pin their own accepted fingerprint or declare semantic equivalence to
/// one frozen case.
final class Stage9d6SemanticBaseline {
  Stage9d6SemanticBaseline({
    required this.schema,
    required this.sourceBenchmarkSchema,
    required this.gateReportSchema,
    required this.benchmarkReportSchema,
    required this.timingContractVersion,
    required this.timerBoundaryContract,
    required this.frozenPreparationMode,
    required this.cases,
    required this.ownedCases,
  });

  factory Stage9d6SemanticBaseline.fromJson(Map<String, Object?> json) {
    final rawCases = json['cases'];
    final rawOwnedCases = json['ownedCases'];
    if (rawCases is! List<Object?> || rawOwnedCases is! List<Object?>) {
      throw FormatException(
        'Stage 9D6 semantic baseline requires cases and ownedCases lists.',
      );
    }
    final cases = <String, Stage9d6SemanticCase>{};
    for (final rawCase in rawCases) {
      if (rawCase is! Map<Object?, Object?>) {
        throw FormatException('Stage 9D6 semantic case must be an object.');
      }
      final mapped = _stringObjectMap(rawCase);
      final id = mapped['id'];
      final fingerprint = mapped['semanticFingerprint'];
      final workload = mapped['workload'];
      final metrics = mapped['metrics'];
      if (id is! String ||
          fingerprint is! String ||
          workload is! Map<Object?, Object?> ||
          metrics is! Map<Object?, Object?>) {
        throw FormatException('Invalid Stage 9D6 semantic case: $mapped');
      }
      if (cases.containsKey(id)) {
        throw FormatException('Duplicate Stage 9D6 semantic case ID: $id');
      }
      cases[id] = Stage9d6SemanticCase(
        id: id,
        semanticFingerprint: fingerprint,
        workload: _stringObjectMap(workload),
        metrics: _stringObjectMap(metrics),
      );
    }

    final ownedCases = <String, Stage9d6OwnedSemanticCase>{};
    for (final rawCase in rawOwnedCases) {
      if (rawCase is! Map<Object?, Object?>) {
        throw FormatException(
          'Stage 9D6 owned semantic case must be an object.',
        );
      }
      final mapped = _stringObjectMap(rawCase);
      final id = mapped['id'];
      final workload = mapped['workload'];
      final metrics = mapped['metrics'];
      final semanticFingerprint = mapped['semanticFingerprint'];
      final fingerprintMatchesCase = mapped['semanticFingerprintMatchesCase'];
      if (id is! String ||
          workload is! Map<Object?, Object?> ||
          metrics is! Map<Object?, Object?> ||
          (semanticFingerprint != null && semanticFingerprint is! String) ||
          (fingerprintMatchesCase != null &&
              fingerprintMatchesCase is! String) ||
          (semanticFingerprint != null && fingerprintMatchesCase != null)) {
        throw FormatException('Invalid Stage 9D6 owned semantic case: $mapped');
      }
      if (ownedCases.containsKey(id) || cases.containsKey(id)) {
        throw FormatException('Duplicate Stage 9D6 semantic case ID: $id');
      }
      ownedCases[id] = Stage9d6OwnedSemanticCase(
        id: id,
        workload: _stringObjectMap(workload),
        metrics: _stringObjectMap(metrics),
        semanticFingerprint: semanticFingerprint as String?,
        semanticFingerprintMatchesCase: fingerprintMatchesCase as String?,
      );
    }

    return Stage9d6SemanticBaseline(
      schema: _requiredString(json, 'schema'),
      sourceBenchmarkSchema: _requiredString(json, 'sourceBenchmarkSchema'),
      gateReportSchema: _requiredString(json, 'gateReportSchema'),
      benchmarkReportSchema: _requiredString(json, 'benchmarkReportSchema'),
      timingContractVersion: _requiredString(json, 'timingContractVersion'),
      timerBoundaryContract: _requiredString(json, 'timerBoundaryContract'),
      frozenPreparationMode: _requiredString(json, 'frozenPreparationMode'),
      cases: Map<String, Stage9d6SemanticCase>.unmodifiable(cases),
      ownedCases: Map<String, Stage9d6OwnedSemanticCase>.unmodifiable(
        ownedCases,
      ),
    );
  }

  final String schema;
  final String sourceBenchmarkSchema;
  final String gateReportSchema;
  final String benchmarkReportSchema;
  final String timingContractVersion;
  final String timerBoundaryContract;
  final String frozenPreparationMode;
  final Map<String, Stage9d6SemanticCase> cases;
  final Map<String, Stage9d6OwnedSemanticCase> ownedCases;

  Set<String> get allCaseIds => <String>{...cases.keys, ...ownedCases.keys};
}

final class Stage9d6SemanticCase {
  const Stage9d6SemanticCase({
    required this.id,
    required this.semanticFingerprint,
    required this.workload,
    required this.metrics,
  });

  final String id;
  final String semanticFingerprint;
  final Map<String, Object?> workload;
  final Map<String, Object?> metrics;
}

final class Stage9d6OwnedSemanticCase {
  const Stage9d6OwnedSemanticCase({
    required this.id,
    required this.workload,
    required this.metrics,
    required this.semanticFingerprint,
    required this.semanticFingerprintMatchesCase,
  });

  final String id;
  final Map<String, Object?> workload;
  final Map<String, Object?> metrics;
  final String? semanticFingerprint;
  final String? semanticFingerprintMatchesCase;
}

enum Stage9d6EvaluationOutcome { pass, fail, inconclusive }

extension Stage9d6EvaluationOutcomeLabel on Stage9d6EvaluationOutcome {
  String get label => switch (this) {
    Stage9d6EvaluationOutcome.pass => 'PASS',
    Stage9d6EvaluationOutcome.fail => 'FAIL',
    Stage9d6EvaluationOutcome.inconclusive => 'INCONCLUSIVE',
  };
}

final class Stage9d6BudgetCheck {
  const Stage9d6BudgetCheck({
    required this.id,
    required this.description,
    required this.observedRatio,
    required this.lowerEvidenceRatio,
    required this.upperEvidenceRatio,
    required this.maximumRatio,
    required this.details,
  });

  final String id;
  final String description;
  final double observedRatio;
  final double lowerEvidenceRatio;
  final double upperEvidenceRatio;
  final double maximumRatio;
  final String details;

  bool get robustlyPassed => upperEvidenceRatio <= maximumRatio;
  bool get robustlyFailed => lowerEvidenceRatio > maximumRatio;
  bool get inconclusive => !robustlyPassed && !robustlyFailed;
  bool get passed => robustlyPassed;

  String get verdict => robustlyPassed
      ? 'PASS'
      : robustlyFailed
      ? 'FAIL'
      : 'INCONCLUSIVE';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'description': description,
    'observedRatio': observedRatio,
    'lowerEvidenceRatio': lowerEvidenceRatio,
    'upperEvidenceRatio': upperEvidenceRatio,
    'maximumRatio': maximumRatio,
    'verdict': verdict,
    'passed': robustlyPassed,
    'details': details,
  };
}

final class Stage9d6BudgetAdvisory {
  const Stage9d6BudgetAdvisory({required this.id, required this.message});

  final String id;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'message': message,
  };
}

final class Stage9d6BudgetEvaluation {
  Stage9d6BudgetEvaluation({
    required this.semanticFailures,
    required this.timingEvidenceIssues,
    required this.checks,
    required this.advisories,
  });

  final List<String> semanticFailures;
  final List<String> timingEvidenceIssues;
  final List<Stage9d6BudgetCheck> checks;
  final List<Stage9d6BudgetAdvisory> advisories;

  Stage9d6EvaluationOutcome get outcome {
    if (semanticFailures.isNotEmpty || failedChecks.isNotEmpty) {
      return Stage9d6EvaluationOutcome.fail;
    }
    if (timingEvidenceIssues.isNotEmpty || inconclusiveChecks.isNotEmpty) {
      return Stage9d6EvaluationOutcome.inconclusive;
    }
    return Stage9d6EvaluationOutcome.pass;
  }

  bool get passed => outcome == Stage9d6EvaluationOutcome.pass;

  List<Stage9d6BudgetCheck> get failedChecks =>
      checks.where((check) => check.robustlyFailed).toList(growable: false);

  List<Stage9d6BudgetCheck> get inconclusiveChecks =>
      checks.where((check) => check.inconclusive).toList(growable: false);

  Map<String, Object?> toJson() => <String, Object?>{
    'outcome': outcome.label,
    'passed': passed,
    'semanticFailures': semanticFailures,
    'timingEvidenceIssues': timingEvidenceIssues,
    'checks': checks.map((check) => check.toJson()).toList(growable: false),
    'advisories': advisories
        .map((advisory) => advisory.toJson())
        .toList(growable: false),
  };
}

Stage9d6BudgetEvaluation evaluateStage9d6PerformanceBudgets({
  required Stage9dBenchmarkReport report,
  required Stage9d6SemanticBaseline semanticBaseline,
}) {
  final semanticFailures = _semanticFailures(
    report: report,
    baseline: semanticBaseline,
  );
  final advisories = _timingAdvisories(report.results);
  if (semanticFailures.isNotEmpty) {
    return Stage9d6BudgetEvaluation(
      semanticFailures: List<String>.unmodifiable(semanticFailures),
      timingEvidenceIssues: const <String>[],
      checks: const <Stage9d6BudgetCheck>[],
      advisories: List<Stage9d6BudgetAdvisory>.unmodifiable(advisories),
    );
  }

  final timingEvidenceIssues = _timingEvidenceIssues(report);
  if (timingEvidenceIssues.isNotEmpty) {
    return Stage9d6BudgetEvaluation(
      semanticFailures: const <String>[],
      timingEvidenceIssues: List<String>.unmodifiable(timingEvidenceIssues),
      checks: const <Stage9d6BudgetCheck>[],
      advisories: List<Stage9d6BudgetAdvisory>.unmodifiable(advisories),
    );
  }

  final byId = <String, Stage9dBenchmarkResult>{
    for (final result in report.results) result.id: result,
  };
  final timings = <String, _TimingRange>{
    for (final entry in byId.entries) entry.key: _timingRange(entry.value),
  };
  final checks = <Stage9d6BudgetCheck>[];

  _addHistoryDepthChecks(checks, timings);
  _addSingleSessionHistoryChecks(checks, timings);
  _addMultiSessionUnchangedHistoryChecks(checks, timings);
  _addPreparedSiblingReuseChecks(checks, timings);
  _addPrewarmedSessionScalingChecks(checks, timings);

  return Stage9d6BudgetEvaluation(
    semanticFailures: const <String>[],
    timingEvidenceIssues: const <String>[],
    checks: List<Stage9d6BudgetCheck>.unmodifiable(checks),
    advisories: List<Stage9d6BudgetAdvisory>.unmodifiable(advisories),
  );
}

void _addHistoryDepthChecks(
  List<Stage9d6BudgetCheck> checks,
  Map<String, _TimingRange> timings,
) {
  final narrativeMedium = _timing(timings, 'history_narrative_medium');
  final narrativeLong = _timing(timings, 'history_narrative_long');
  final narrativeVeryLong = _timing(timings, 'history_narrative_very_long');
  final coreMedium = _timing(timings, 'history_core_medium');
  final coreLong = _timing(timings, 'history_core_long');
  final coreVeryLong = _timing(timings, 'history_core_very_long');

  final depthGrowth = _maxRanges(<_ScalarRange>[
    _divideRanges(narrativeLong, narrativeMedium, denominatorFloor: 1.0),
    _divideRanges(narrativeVeryLong, narrativeMedium, denominatorFloor: 1.0),
  ]);
  checks.add(
    _check(
      id: 'history_depth_flatness',
      description:
          'Narrative fixed-window cost must stay approximately flat '
          'as retained history grows.',
      ratio: depthGrowth,
      maximumRatio: stage9d6MaxNarrativeHistoryDepthGrowth,
      details:
          'max(long/medium, very_long/medium) for the frozen narrative '
          '16-choice window.',
    ),
  );

  final overhead = _maxRanges(<_ScalarRange>[
    _divideRanges(
      narrativeMedium,
      coreMedium,
      denominatorFloor: stage9d6CoreTimingFloorMicros,
    ),
    _divideRanges(
      narrativeLong,
      coreLong,
      denominatorFloor: stage9d6CoreTimingFloorMicros,
    ),
    _divideRanges(
      narrativeVeryLong,
      coreVeryLong,
      denominatorFloor: stage9d6CoreTimingFloorMicros,
    ),
  ]);
  checks.add(
    _check(
      id: 'history_narrative_overhead',
      description:
          'Narrative orchestration must remain within a bounded '
          'multiple of direct core execution.',
      ratio: overhead,
      maximumRatio: stage9d6MaxNarrativeCoreOverhead,
      details:
          'max(narrative/core) across medium/long/very-long history. '
          'When core timing is below 4 us, the denominator floor means this '
          'also acts as a conditional absolute ceiling for the narrative '
          'window; it is not fully machine-speed invariant.',
    ),
  );
}

void _addSingleSessionHistoryChecks(
  List<Stage9d6BudgetCheck> checks,
  Map<String, _TimingRange> timings,
) {
  for (final profile in <String>[
    'compact',
    'event_heavy',
    'choice_heavy',
    'state_heavy',
    'combined_large',
  ]) {
    final short = _timing(timings, 'propagation_${profile}_short_s1');
    final long = _timing(timings, 'propagation_${profile}_long_s1');
    final ratio = _divideRanges(
      long,
      short,
      denominatorFloor: stage9d6SingleSessionTimingFloorMicros,
    );
    checks.add(
      _check(
        id: 'single_session_history_$profile',
        description:
            'Single-session shared-state commit cost must not regain '
            'retained-history scaling for $profile.',
        ratio: ratio,
        maximumRatio: stage9d6MaxSingleSessionHistoryGrowth,
        details:
            'long-history s1 / short-history s1. If short timing is below '
            '10 us, the floor imposes a conditional absolute ceiling on the '
            'long case rather than a purely scale-free ratio.',
      ),
    );
  }
}

void _addMultiSessionUnchangedHistoryChecks(
  List<Stage9d6BudgetCheck> checks,
  Map<String, _TimingRange> timings,
) {
  for (final sessionCount in <int>[2, 50]) {
    final medium = _timing(timings, 'unchanged_history_medium_s$sessionCount');
    final long = _timing(timings, 'unchanged_history_long_s$sessionCount');
    final veryLong = _timing(
      timings,
      'unchanged_history_very_long_s$sessionCount',
    );
    final ratio = _maxRanges(<_ScalarRange>[
      _divideRanges(long, medium, denominatorFloor: 1.0),
      _divideRanges(veryLong, medium, denominatorFloor: 1.0),
    ]);
    checks.add(
      _check(
        id: 'unchanged_multi_session_history_s$sessionCount',
        description:
            'Unchanged-state source operations must not regain '
            'history-depth cost merely because $sessionCount sessions are '
            'active.',
        ratio: ratio,
        maximumRatio: stage9d6MaxMultiSessionUnchangedHistoryGrowth,
        details:
            'max(long/medium, very_long/medium) for the 9D6-owned '
            'multi-session unchanged-state fixed choice window.',
      ),
    );
  }
}

void _addPreparedSiblingReuseChecks(
  List<Stage9d6BudgetCheck> checks,
  Map<String, _TimingRange> timings,
) {
  for (final profile in <String>[
    'event_heavy',
    'choice_heavy',
    'combined_large',
  ]) {
    for (final history in <String>['short', 'long']) {
      final restore = _timing(timings, 'restore_${profile}_$history');
      final s1 = _timing(timings, 'propagation_${profile}_${history}_s1');
      final s10 = _timing(timings, 'propagation_${profile}_${history}_s10');
      final s50 = _timing(timings, 'propagation_${profile}_${history}_s50');
      final firstSlope = _differenceRange(s10, s1, divisor: 9.0);
      final fullSlope = _differenceRange(s50, s1, divisor: 49.0);
      final ratio = _divideRanges(
        _maxRanges(<_ScalarRange>[firstSlope, fullSlope]),
        restore,
        denominatorFloor: 1.0,
      );
      checks.add(
        _check(
          id: 'prepared_sibling_reuse_${profile}_$history',
          description:
              'Prepared sibling reconstruction must stay much '
              'cheaper than a fresh validated restore for $profile/$history.',
          ratio: ratio,
          maximumRatio: stage9d6MaxPreparedSiblingCostVsRestore,
          details:
              'Frozen cold propagation still protects project-derived '
              'preparation reuse: max((s10-s1)/9, (s50-s1)/49) / validated '
              'restore median.',
        ),
      );
    }
  }
}

void _addPrewarmedSessionScalingChecks(
  List<Stage9d6BudgetCheck> checks,
  Map<String, _TimingRange> timings,
) {
  for (final profile in <String>[
    'compact',
    'event_heavy',
    'choice_heavy',
    'state_heavy',
    'combined_large',
  ]) {
    for (final history in <String>['short', 'long']) {
      final s1 = _timing(
        timings,
        'prewarmed_propagation_${profile}_${history}_s1',
      );
      final s10 = _timing(
        timings,
        'prewarmed_propagation_${profile}_${history}_s10',
      );
      final s50 = _timing(
        timings,
        'prewarmed_propagation_${profile}_${history}_s50',
      );
      final earlySlope = _differenceRange(s10, s1, divisor: 9.0);
      final lateSlope = _differenceRange(s50, s10, divisor: 40.0);
      final ratio = _divideRanges(
        lateSlope,
        earlySlope,
        denominatorFloor: stage9d6SiblingSlopeTimingFloorMicros,
      );
      checks.add(
        _check(
          id: 'prewarmed_session_scaling_${profile}_$history',
          description:
              'Per-sibling propagation cost must not become '
              'materially superlinear from 10 to 50 sessions for '
              '$profile/$history when fixed project preparation is already '
              'warm at every measurement point.',
          ratio: ratio,
          maximumRatio: stage9d6MaxPrewarmedPerSiblingSlopeGrowth,
          details:
              '(s50-s10)/40 / max((s10-s1)/9, 1 us), using only '
              'prewarmed s1/s10/s50 cases. The 1 us slope floor is retained '
              'for timer quantization and is explicitly part of this contract.',
        ),
      );
    }
  }
}

Stage9d6BudgetCheck _check({
  required String id,
  required String description,
  required _ScalarRange ratio,
  required double maximumRatio,
  required String details,
}) => Stage9d6BudgetCheck(
  id: id,
  description: description,
  observedRatio: ratio.observed,
  lowerEvidenceRatio: ratio.lower,
  upperEvidenceRatio: ratio.upper,
  maximumRatio: maximumRatio,
  details: details,
);

List<String> _semanticFailures({
  required Stage9dBenchmarkReport report,
  required Stage9d6SemanticBaseline baseline,
}) {
  final failures = <String>[];
  if (baseline.schema != stage9d6SemanticBaselineSchema) {
    failures.add(
      'Unsupported semantic-baseline schema: ${baseline.schema}; expected '
      '$stage9d6SemanticBaselineSchema.',
    );
  }
  if (baseline.sourceBenchmarkSchema != stage9d6SourceBenchmarkSchema) {
    failures.add(
      'Unsupported source benchmark schema: ${baseline.sourceBenchmarkSchema}; '
      'expected $stage9d6SourceBenchmarkSchema.',
    );
  }
  if (baseline.gateReportSchema != stage9d6GateReportSchema) {
    failures.add(
      'Semantic baseline gate-report schema mismatch: '
      '${baseline.gateReportSchema}; expected $stage9d6GateReportSchema.',
    );
  }
  if (baseline.benchmarkReportSchema != stage9d6BenchmarkReportSchema) {
    failures.add(
      'Semantic baseline benchmark-report schema mismatch: '
      '${baseline.benchmarkReportSchema}; expected '
      '$stage9d6BenchmarkReportSchema.',
    );
  }
  if (report.schema != stage9d6BenchmarkReportSchema) {
    failures.add(
      'Benchmark report schema mismatch: ${report.schema}; expected '
      '$stage9d6BenchmarkReportSchema.',
    );
  }
  if (baseline.timingContractVersion != stage9d6TimingContractVersion) {
    failures.add(
      'Timing contract version mismatch: ${baseline.timingContractVersion}; '
      'expected $stage9d6TimingContractVersion.',
    );
  }
  if (baseline.timerBoundaryContract != stage9d6TimerBoundaryContract) {
    failures.add(
      'Timer-boundary contract mismatch: ${baseline.timerBoundaryContract}; '
      'expected $stage9d6TimerBoundaryContract.',
    );
  }
  if (baseline.frozenPreparationMode != stage9d6FrozenPreparationMode) {
    failures.add(
      'Frozen preparation-mode identity mismatch: '
      '${baseline.frozenPreparationMode}; expected '
      '$stage9d6FrozenPreparationMode.',
    );
  }

  final current = <String, Stage9dBenchmarkResult>{};
  for (final result in report.results) {
    if (current.containsKey(result.id)) {
      failures.add('Duplicate benchmark result ID: ${result.id}.');
    }
    current[result.id] = result;
  }

  for (final expected in baseline.cases.values) {
    final result = current[expected.id];
    if (result == null) {
      failures.add('Missing accepted semantic case: ${expected.id}.');
      continue;
    }
    if (result.semanticFingerprint != expected.semanticFingerprint) {
      failures.add('Semantic fingerprint changed for ${expected.id}.');
    }
    if (!_deepJsonLikeEquals(result.workload, expected.workload)) {
      failures.add('Workload definition changed for ${expected.id}.');
    }
    if (!_deepJsonLikeEquals(result.metrics, expected.metrics)) {
      failures.add('Structural metrics changed for ${expected.id}.');
    }
  }

  for (final expected in baseline.ownedCases.values) {
    final result = current[expected.id];
    if (result == null) {
      failures.add('Missing Stage 9D6-owned semantic case: ${expected.id}.');
      continue;
    }
    if (!_deepJsonLikeEquals(result.workload, expected.workload)) {
      failures.add('Workload definition changed for ${expected.id}.');
    }
    if (!_deepJsonLikeEquals(result.metrics, expected.metrics)) {
      failures.add('Structural metrics changed for ${expected.id}.');
    }
    final acceptedFingerprint = expected.semanticFingerprint;
    if (acceptedFingerprint != null &&
        result.semanticFingerprint != acceptedFingerprint) {
      failures.add('Semantic fingerprint changed for ${expected.id}.');
    }
    final fingerprintReference = expected.semanticFingerprintMatchesCase;
    if (fingerprintReference != null) {
      final reference = current[fingerprintReference];
      if (reference == null) {
        failures.add(
          'Semantic fingerprint reference $fingerprintReference for '
          '${expected.id} is missing.',
        );
      } else if (result.semanticFingerprint != reference.semanticFingerprint) {
        failures.add(
          'Semantic fingerprint for ${expected.id} no longer matches '
          '$fingerprintReference.',
        );
      }
    }
  }

  for (final id in current.keys) {
    if (!baseline.allCaseIds.contains(id)) {
      failures.add('Unexpected benchmark result outside accepted set: $id.');
    }
  }
  return failures;
}

List<String> _timingEvidenceIssues(Stage9dBenchmarkReport report) {
  final issues = <String>[];
  for (final result in report.results) {
    if (result.sampleMicros.isEmpty) {
      issues.add('${result.id} has no timing samples.');
      continue;
    }
    if (result.sampleMicros.length != report.config.samples) {
      issues.add(
        '${result.id} has ${result.sampleMicros.length} timing samples; '
        'expected ${report.config.samples}.',
      );
    }
    if (result.sampleMicros.any((sample) => sample < 0)) {
      issues.add('${result.id} contains a negative timing sample.');
      continue;
    }
    if (result.medianMicros <= 0) {
      issues.add(
        '${result.id} has a non-positive median timing and cannot support '
        'a meaningful relative-performance verdict.',
      );
    }
  }
  return issues;
}

List<Stage9d6BudgetAdvisory> _timingAdvisories(
  List<Stage9dBenchmarkResult> results,
) {
  final advisories = <Stage9d6BudgetAdvisory>[];
  for (final result in results) {
    if (result.sampleMicros.isEmpty || result.medianMicros <= 0) {
      continue;
    }
    if (result.medianMicros >= stage9d6DispersionMedianFloorMicros &&
        result.p25Micros > 0) {
      final ratio = result.p75Micros / result.p25Micros;
      if (ratio > stage9d6DispersionAdvisoryRatio) {
        advisories.add(
          Stage9d6BudgetAdvisory(
            id: 'dispersion_${result.id}',
            message:
                '${result.id} has p75/p25=${ratio.toStringAsFixed(2)}. '
                'The evaluator uses an evidence range rather than treating '
                'the median as unquestionably representative.',
          ),
        );
      }
    }
    final mixed = _mixedRegime(result);
    if (mixed != null) {
      advisories.add(
        Stage9d6BudgetAdvisory(
          id: 'mixed_regime_${result.id}',
          message:
              '${result.id} has a possible mixed timing regime: '
              '${mixed.lowerClusterSize}/${mixed.upperClusterSize} samples form '
              'clusters with a ${mixed.gapRatio.toStringAsFixed(2)}x boundary '
              'gap and ${mixed.medianSeparationRatio.toStringAsFixed(2)}x median '
              'separation (${mixed.lowerClusterMedian.toStringAsFixed(0)} us vs '
              '${mixed.upperClusterMedian.toStringAsFixed(0)} us). Those cluster '
              'medians expand the ratio evidence range.',
        ),
      );
    }
  }
  return advisories;
}

_TimingRange _timingRange(Stage9dBenchmarkResult result) {
  var lower = result.p25Micros.toDouble();
  var upper = result.p75Micros.toDouble();
  final mixed = _mixedRegime(result);
  if (mixed != null) {
    lower = _minDouble(lower, mixed.lowerClusterMedian);
    upper = _maxDouble(upper, mixed.upperClusterMedian);
  }
  return _TimingRange(
    observed: result.medianMicros.toDouble(),
    lower: lower,
    upper: upper,
  );
}

_MixedRegime? _mixedRegime(Stage9dBenchmarkResult result) {
  if (result.sampleMicros.length < 5 ||
      result.medianMicros < stage9d6DispersionMedianFloorMicros) {
    return null;
  }
  final sorted = result.sampleMicros.where((sample) => sample > 0).toList()
    ..sort();
  if (sorted.length < 5) {
    return null;
  }

  final minimumClusterSize = _maxInt(
    2,
    (sorted.length * stage9d6MixedRegimeMinClusterFraction).ceil(),
  );
  if (minimumClusterSize * 2 > sorted.length) {
    return null;
  }

  _MixedRegime? best;
  var bestMedianSeparation = 0.0;
  for (
    var split = minimumClusterSize;
    split <= sorted.length - minimumClusterSize;
    split++
  ) {
    final lowerBoundary = sorted[split - 1].toDouble();
    final upperBoundary = sorted[split].toDouble();
    final boundaryGap = upperBoundary / lowerBoundary;
    if (boundaryGap < stage9d6MixedRegimeMinBoundaryGapRatio) {
      continue;
    }

    final lowerCluster = sorted.sublist(0, split);
    final upperCluster = sorted.sublist(split);
    final lowerMedian = _medianIntList(lowerCluster).toDouble();
    final upperMedian = _medianIntList(upperCluster).toDouble();
    final medianSeparation = upperMedian / lowerMedian;
    if (medianSeparation < stage9d6MixedRegimeMinMedianSeparationRatio ||
        medianSeparation <= bestMedianSeparation) {
      continue;
    }

    bestMedianSeparation = medianSeparation;
    best = _MixedRegime(
      gapRatio: boundaryGap,
      medianSeparationRatio: medianSeparation,
      lowerClusterMedian: lowerMedian,
      upperClusterMedian: upperMedian,
      lowerClusterSize: lowerCluster.length,
      upperClusterSize: upperCluster.length,
    );
  }
  return best;
}

int _medianIntList(List<int> values) {
  final sorted = values.toList()..sort();
  return sorted[((sorted.length - 1) * 0.5).round()];
}

_TimingRange _timing(Map<String, _TimingRange> timings, String id) {
  final timing = timings[id];
  if (timing == null) {
    throw StateError('Stage 9D6 budget case missing after semantic gate: $id');
  }
  return timing;
}

_ScalarRange _differenceRange(
  _ScalarRange minuend,
  _ScalarRange subtrahend, {
  required double divisor,
}) => _ScalarRange(
  observed: _nonNegative(minuend.observed - subtrahend.observed) / divisor,
  lower: _nonNegative(minuend.lower - subtrahend.upper) / divisor,
  upper: _nonNegative(minuend.upper - subtrahend.lower) / divisor,
);

_ScalarRange _divideRanges(
  _ScalarRange numerator,
  _ScalarRange denominator, {
  required double denominatorFloor,
}) => _ScalarRange(
  observed:
      numerator.observed / _maxDouble(denominator.observed, denominatorFloor),
  lower: numerator.lower / _maxDouble(denominator.upper, denominatorFloor),
  upper: numerator.upper / _maxDouble(denominator.lower, denominatorFloor),
);

_ScalarRange _maxRanges(List<_ScalarRange> ranges) => _ScalarRange(
  observed: ranges.map((range) => range.observed).reduce(_maxDouble),
  lower: ranges.map((range) => range.lower).reduce(_maxDouble),
  upper: ranges.map((range) => range.upper).reduce(_maxDouble),
);

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Stage 9D6 semantic baseline requires $key string.');
  }
  return value;
}

Map<String, Object?> _stringObjectMap(Map<Object?, Object?> source) =>
    <String, Object?>{
      for (final entry in source.entries) '${entry.key}': entry.value,
    };

bool _deepJsonLikeEquals(Object? left, Object? right) {
  if (identical(left, right) || left == right) {
    return true;
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_deepJsonLikeEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map<Object?, Object?> && right is Map<Object?, Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonLikeEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

double _maxDouble(num left, num right) =>
    left.toDouble() > right.toDouble() ? left.toDouble() : right.toDouble();

int _maxInt(int left, int right) => left > right ? left : right;

double _minDouble(num left, num right) =>
    left.toDouble() < right.toDouble() ? left.toDouble() : right.toDouble();

double _nonNegative(num value) => value.toDouble() < 0 ? 0 : value.toDouble();

class _ScalarRange {
  const _ScalarRange({
    required this.observed,
    required this.lower,
    required this.upper,
  });

  final double observed;
  final double lower;
  final double upper;
}

final class _TimingRange extends _ScalarRange {
  const _TimingRange({
    required super.observed,
    required super.lower,
    required super.upper,
  });
}

final class _MixedRegime {
  const _MixedRegime({
    required this.gapRatio,
    required this.medianSeparationRatio,
    required this.lowerClusterMedian,
    required this.upperClusterMedian,
    required this.lowerClusterSize,
    required this.upperClusterSize,
  });

  final double gapRatio;
  final double medianSeparationRatio;
  final double lowerClusterMedian;
  final double upperClusterMedian;
  final int lowerClusterSize;
  final int upperClusterSize;
}
