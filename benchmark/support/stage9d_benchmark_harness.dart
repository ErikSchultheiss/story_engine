import 'dart:io';

/// Repository-only benchmark case used by the Stage 9D profiling harness.
///
/// [prepare] runs outside the timed region. [run] contains only the operation
/// being measured. [fingerprint] and [metrics] also run after the stopwatch has
/// stopped, so semantic verification and reporting do not contaminate the
/// measured wall time.
final class Stage9dBenchmarkCase {
  Stage9dBenchmarkCase._({
    required this.id,
    required this.description,
    required this.workload,
    required Object? Function() prepare,
    required Object? Function(Object? prepared) run,
    required String Function(Object? result) fingerprint,
    required Map<String, Object?> Function(Object? result) metrics,
  }) : _prepare = prepare,
       _run = run,
       _fingerprint = fingerprint,
       _metrics = metrics;

  static Stage9dBenchmarkCase typed<Prepared, Result>({
    required String id,
    required String description,
    required Map<String, Object?> workload,
    required Prepared Function() prepare,
    required Result Function(Prepared prepared) run,
    required String Function(Result result) fingerprint,
    Map<String, Object?> Function(Result result)? metrics,
  }) {
    return Stage9dBenchmarkCase._(
      id: id,
      description: description,
      workload: Map<String, Object?>.unmodifiable(workload),
      prepare: () => prepare(),
      run: (prepared) => run(prepared as Prepared),
      fingerprint: (result) => fingerprint(result as Result),
      metrics: (result) =>
          metrics?.call(result as Result) ?? const <String, Object?>{},
    );
  }

  final String id;
  final String description;
  final Map<String, Object?> workload;
  final Object? Function() _prepare;
  final Object? Function(Object? prepared) _run;
  final String Function(Object? result) _fingerprint;
  final Map<String, Object?> Function(Object? result) _metrics;

  _Stage9dMeasuredInvocation _invoke() {
    final prepared = _prepare();
    final stopwatch = Stopwatch()..start();
    final result = _run(prepared);
    stopwatch.stop();
    return _Stage9dMeasuredInvocation(
      elapsedMicros: stopwatch.elapsedMicroseconds,
      fingerprint: _fingerprint(result),
      metrics: Map<String, Object?>.unmodifiable(_metrics(result)),
    );
  }

  void warmUp() {
    final prepared = _prepare();
    final result = _run(prepared);
    _fingerprint(result);
    _metrics(result);
  }
}

/// Configuration shared by every Stage 9D benchmark runner.
final class Stage9dBenchmarkConfig {
  const Stage9dBenchmarkConfig({this.samples = 9, this.warmupIterations = 3})
    : assert(samples > 0),
      assert(warmupIterations >= 0);

  final int samples;
  final int warmupIterations;
}

/// One completed multi-case benchmark run.
final class Stage9dBenchmarkReport {
  Stage9dBenchmarkReport({
    required this.schema,
    required this.config,
    required this.environment,
    required this.allocationMeasurement,
    required this.results,
  });

  final String schema;
  final Stage9dBenchmarkConfig config;
  final Map<String, Object?> environment;
  final Map<String, Object?> allocationMeasurement;
  final List<Stage9dBenchmarkResult> results;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'samples': config.samples,
    'warmupIterations': config.warmupIterations,
    'environment': environment,
    'allocationMeasurement': allocationMeasurement,
    'results': results.map((result) => result.toJson()).toList(growable: false),
  };
}

/// Stable summary for one measured benchmark case.
final class Stage9dBenchmarkResult {
  Stage9dBenchmarkResult({
    required this.id,
    required this.description,
    required this.workload,
    required this.sampleMicros,
    required this.semanticFingerprint,
    required this.metrics,
  });

  final String id;
  final String description;
  final Map<String, Object?> workload;
  final List<int> sampleMicros;
  final String semanticFingerprint;
  final Map<String, Object?> metrics;

  int get medianMicros => _percentile(sampleMicros, 0.50);
  int get p25Micros => _percentile(sampleMicros, 0.25);
  int get p75Micros => _percentile(sampleMicros, 0.75);
  int get minMicros =>
      sampleMicros.reduce((left, right) => left < right ? left : right);
  int get maxMicros =>
      sampleMicros.reduce((left, right) => left > right ? left : right);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'description': description,
    'workload': workload,
    'sampleMicros': sampleMicros,
    'medianMicros': medianMicros,
    'p25Micros': p25Micros,
    'p75Micros': p75Micros,
    'minMicros': minMicros,
    'maxMicros': maxMicros,
    'semanticFingerprint': semanticFingerprint,
    'metrics': metrics,
  };
}

/// Runs deterministic cases with warm-up and rotating per-sample case order.
///
/// Rotating the order prevents the first case from always paying the same
/// process-level effects (JIT activity, cache state, scheduler wake-up) while
/// keeping the measurement sequence fully reproducible.
final class Stage9dBenchmarkHarness {
  const Stage9dBenchmarkHarness();

  Stage9dBenchmarkReport run({
    required String schema,
    required List<Stage9dBenchmarkCase> cases,
    Stage9dBenchmarkConfig config = const Stage9dBenchmarkConfig(),
  }) {
    if (cases.isEmpty) {
      throw ArgumentError.value(
        cases,
        'cases',
        'At least one case is required.',
      );
    }
    final ids = <String>{};
    for (final benchmarkCase in cases) {
      if (!ids.add(benchmarkCase.id)) {
        throw ArgumentError.value(
          cases,
          'cases',
          'Benchmark case IDs must be unique: ${benchmarkCase.id}.',
        );
      }
    }

    for (var warmup = 0; warmup < config.warmupIterations; warmup++) {
      final order = _rotatedOrder(cases.length, warmup);
      for (final index in order) {
        cases[index].warmUp();
      }
    }

    final samplesById = <String, List<int>>{
      for (final benchmarkCase in cases) benchmarkCase.id: <int>[],
    };
    final fingerprintById = <String, String>{};
    final metricsById = <String, Map<String, Object?>>{};

    for (var sample = 0; sample < config.samples; sample++) {
      final order = _rotatedOrder(cases.length, sample);
      for (final index in order) {
        final benchmarkCase = cases[index];
        final invocation = benchmarkCase._invoke();
        samplesById[benchmarkCase.id]!.add(invocation.elapsedMicros);

        final previousFingerprint = fingerprintById[benchmarkCase.id];
        if (previousFingerprint != null &&
            previousFingerprint != invocation.fingerprint) {
          throw StateError(
            'Benchmark case ${benchmarkCase.id} produced semantic fingerprint '
            '${invocation.fingerprint}, expected $previousFingerprint. '
            'The measured workload is not deterministic.',
          );
        }
        fingerprintById[benchmarkCase.id] = invocation.fingerprint;

        final previousMetrics = metricsById[benchmarkCase.id];
        if (previousMetrics != null &&
            !_deepJsonLikeEquals(previousMetrics, invocation.metrics)) {
          throw StateError(
            'Benchmark case ${benchmarkCase.id} produced changing structural '
            'metrics across samples. The measured workload is not stable.',
          );
        }
        metricsById[benchmarkCase.id] = invocation.metrics;
      }
    }

    final results = <Stage9dBenchmarkResult>[
      for (final benchmarkCase in cases)
        Stage9dBenchmarkResult(
          id: benchmarkCase.id,
          description: benchmarkCase.description,
          workload: benchmarkCase.workload,
          sampleMicros: List<int>.unmodifiable(samplesById[benchmarkCase.id]!),
          semanticFingerprint: fingerprintById[benchmarkCase.id]!,
          metrics: metricsById[benchmarkCase.id]!,
        ),
    ];

    return Stage9dBenchmarkReport(
      schema: schema,
      config: config,
      environment: _environmentMetadata(),
      allocationMeasurement: const <String, Object?>{
        'status': 'unavailable_portably',
        'metric': 'per_workload_allocated_bytes',
        'reason':
            'Stable Dart CLI APIs do not expose a reliable per-workload '
            'allocation counter. RSS is not reported as allocation because it '
            'mixes heap capacity, code, runtime, and allocator behavior.',
      },
      results: List<Stage9dBenchmarkResult>.unmodifiable(results),
    );
  }
}

final class _Stage9dMeasuredInvocation {
  const _Stage9dMeasuredInvocation({
    required this.elapsedMicros,
    required this.fingerprint,
    required this.metrics,
  });

  final int elapsedMicros;
  final String fingerprint;
  final Map<String, Object?> metrics;
}

List<int> _rotatedOrder(int length, int iteration) => <int>[
  for (var offset = 0; offset < length; offset++) (offset + iteration) % length,
];

int _percentile(List<int> values, double fraction) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'Cannot summarize no samples.');
  }
  final sorted = values.toList()..sort();
  if (sorted.length == 1) {
    return sorted.single;
  }
  final index = ((sorted.length - 1) * fraction).round();
  return sorted[index];
}

Map<String, Object?> _environmentMetadata() => <String, Object?>{
  'dartVersion': Platform.version,
  'operatingSystem': Platform.operatingSystem,
  'operatingSystemVersion': Platform.operatingSystemVersion,
  'numberOfProcessors': Platform.numberOfProcessors,
  'executable': Platform.executable,
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
