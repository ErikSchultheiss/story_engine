/// Versioned identities for the Stage 9D6 regression gate.
///
/// These strings are part of benchmark evidence, not public package API. Any
/// change to what is prepared outside the stopwatch, what is measured inside
/// it, or which semantic workload is represented must deliberately bump the
/// applicable contract/schema rather than silently reusing old evidence.
const String stage9d6GateReportSchema =
    'story_engine.stage9d6.performance_regression_gate.v2';
const String stage9d6BenchmarkReportSchema =
    'story_engine.stage9d6.benchmark_report.v2';
const String stage9d6SemanticBaselineSchema =
    'story_engine.stage9d6.semantic_baseline.v2';
const String stage9d6SourceBenchmarkSchema =
    'story_engine.stage9d5.optimization_baseline.v1';
const String stage9d6TimingContractVersion =
    'story_engine.stage9d6.timing_contract.v1';

/// Stable statement of the harness stopwatch boundary.
///
/// `prepare` is outside the stopwatch. Only `run` is timed. Fingerprinting and
/// structural metrics are collected after the stopwatch stops.
const String stage9d6TimerBoundaryContract =
    'prepare_outside_timer__run_only_inside_timer__semantic_checks_after_timer';

const String stage9d6FrozenPreparationMode =
    'frozen_stage9d5_prepare_outside_timer';
const String stage9d6UnchangedStatePreparationMode =
    'multi_session_history_prebuilt_outside_timer';
const String stage9d6PrewarmedPropagationPreparationMode =
    'multi_session_history_and_project_restore_preparation_prebuilt_outside_timer';
