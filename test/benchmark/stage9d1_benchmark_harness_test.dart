import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../benchmark/support/stage9d_benchmark_harness.dart';
import '../../benchmark/support/stage9d_synthetic_narrative.dart';

void main() {
  group('Stage 9D1 benchmark harness', () {
    test('rotates case order deterministically across samples', () {
      final invocationOrder = <String>[];
      final cases = <Stage9dBenchmarkCase>[
        Stage9dBenchmarkCase.typed<int, int>(
          id: 'a',
          description: 'case a',
          workload: const <String, Object?>{'kind': 'unit'},
          prepare: () => 1,
          run: (value) {
            invocationOrder.add('a');
            return value;
          },
          fingerprint: (value) => '$value',
        ),
        Stage9dBenchmarkCase.typed<int, int>(
          id: 'b',
          description: 'case b',
          workload: const <String, Object?>{'kind': 'unit'},
          prepare: () => 2,
          run: (value) {
            invocationOrder.add('b');
            return value;
          },
          fingerprint: (value) => '$value',
        ),
      ];

      final report = const Stage9dBenchmarkHarness().run(
        schema: 'stage9d1.test',
        cases: cases,
        config: const Stage9dBenchmarkConfig(samples: 3, warmupIterations: 0),
      );

      expect(invocationOrder, <String>['a', 'b', 'b', 'a', 'a', 'b']);
      expect(report.results, hasLength(2));
      expect(report.results[0].sampleMicros, hasLength(3));
      expect(report.results[1].sampleMicros, hasLength(3));
      expect(report.results[0].semanticFingerprint, '1');
      expect(report.results[1].semanticFingerprint, '2');
    });

    test('rejects semantic drift between repeated samples', () {
      var generation = 0;
      final benchmarkCase = Stage9dBenchmarkCase.typed<int, int>(
        id: 'drift',
        description: 'intentionally unstable test case',
        workload: const <String, Object?>{'kind': 'unit'},
        prepare: () => 0,
        run: (_) => generation++,
        fingerprint: (value) => '$value',
      );

      expect(
        () => const Stage9dBenchmarkHarness().run(
          schema: 'stage9d1.test',
          cases: <Stage9dBenchmarkCase>[benchmarkCase],
          config: const Stage9dBenchmarkConfig(samples: 2, warmupIterations: 0),
        ),
        throwsStateError,
      );
    });

    test('synthetic narrative workload is structurally reproducible', () {
      final firstFixture = Stage9dSyntheticNarrativeFixture.build(
        continuationCount: 7,
      );
      final secondFixture = Stage9dSyntheticNarrativeFixture.build(
        continuationCount: 7,
      );
      const formatCodec = StoryFormatCodec();

      expect(
        formatCodec.encodeProject(firstFixture.project),
        formatCodec.encodeProject(secondFixture.project),
      );
      expect(firstFixture.entryPointId, secondFixture.entryPointId);

      final first = runStage9dActiveSessionWorkload(
        fixture: firstFixture,
        sessionCount: 4,
        continuationsPerSession: 6,
      );
      final second = runStage9dActiveSessionWorkload(
        fixture: secondFixture,
        sessionCount: 4,
        continuationsPerSession: 6,
      );

      expect(
        stage9dNarrativeFingerprint(first),
        stage9dNarrativeFingerprint(second),
      );
      expect(stage9dNarrativeMetrics(first), stage9dNarrativeMetrics(second));
      expect(first.activeSessionCount, 4);
      expect(first.sessionCount, 4);
    });

    test('reports allocation limitation instead of mislabeling RSS', () {
      final benchmarkCase = Stage9dBenchmarkCase.typed<int, int>(
        id: 'allocation_contract',
        description: 'allocation reporting contract',
        workload: const <String, Object?>{'kind': 'unit'},
        prepare: () => 1,
        run: (value) => value,
        fingerprint: (value) => '$value',
      );

      final report = const Stage9dBenchmarkHarness().run(
        schema: 'stage9d1.test',
        cases: <Stage9dBenchmarkCase>[benchmarkCase],
        config: const Stage9dBenchmarkConfig(samples: 1, warmupIterations: 0),
      );

      expect(report.allocationMeasurement['status'], 'unavailable_portably');
      expect(
        report.allocationMeasurement['metric'],
        'per_workload_allocated_bytes',
      );
    });
  });
}
