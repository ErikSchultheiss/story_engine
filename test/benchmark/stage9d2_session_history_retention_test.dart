import 'package:test/test.dart';

import '../../benchmark/support/stage9d_session_history_retention.dart';
import '../../benchmark/support/stage9d_synthetic_narrative.dart';

void main() {
  group('Stage 9D2 session/history retention workloads', () {
    test(
      'matrix freezes 1/10/50 sessions across four history scales and both lifecycles',
      () {
        final matrix = stage9dRetentionMatrix();

        expect(stage9dRetentionSessionCounts, <int>[1, 10, 50]);
        expect(
          stage9dRetentionHistoryScales
              .map((scale) => (scale.name, scale.continuationsPerSession))
              .toList(growable: false),
          <(String, int)>[
            ('short', 8),
            ('medium', 32),
            ('long', 128),
            ('very_long', 512),
          ],
        );
        expect(matrix, hasLength(24));
        expect(
          matrix.map((scenario) => scenario.idStem).toSet(),
          hasLength(24),
        );
      },
    );

    test(
      'completed sessions leave active membership but retain complete history',
      () {
        const scale = Stage9dRetentionHistoryScale(
          name: 'test',
          continuationsPerSession: 6,
        );
        final fixture = Stage9dSyntheticNarrativeFixture.build(
          continuationCount: scale.continuationsPerSession,
        );
        final active = runStage9dRetentionWorkload(
          fixture: fixture,
          scenario: const Stage9dRetentionScenario(
            sessionCount: 3,
            historyScale: scale,
            lifecycle: Stage9dRetentionLifecycle.active,
          ),
        );
        final completed = runStage9dRetentionWorkload(
          fixture: fixture,
          scenario: const Stage9dRetentionScenario(
            sessionCount: 3,
            historyScale: scale,
            lifecycle: Stage9dRetentionLifecycle.completed,
          ),
        );

        expect(active.activeSessionCount, 3);
        expect(active.completedSessionCount, 0);
        expect(active.runtime.history.sessions, hasLength(3));
        expect(active.runtime.createSnapshot().sessions, hasLength(3));

        expect(completed.activeSessionCount, 0);
        expect(completed.completedSessionCount, 3);
        expect(completed.runtime.history.sessions, hasLength(3));
        expect(completed.runtime.createSnapshot().sessions, hasLength(3));
        expect(
          completed.totalHistorySteps,
          greaterThan(active.totalHistorySteps),
        );
      },
    );

    test(
      'retained snapshot size grows with session count and history depth',
      () {
        const short = Stage9dRetentionHistoryScale(
          name: 'short_test',
          continuationsPerSession: 2,
        );
        const long = Stage9dRetentionHistoryScale(
          name: 'long_test',
          continuationsPerSession: 20,
        );
        final shortFixture = Stage9dSyntheticNarrativeFixture.build(
          continuationCount: short.continuationsPerSession,
        );
        final longFixture = Stage9dSyntheticNarrativeFixture.build(
          continuationCount: long.continuationsPerSession,
        );

        final oneShort = runStage9dRetentionWorkload(
          fixture: shortFixture,
          scenario: const Stage9dRetentionScenario(
            sessionCount: 1,
            historyScale: short,
            lifecycle: Stage9dRetentionLifecycle.active,
          ),
        );
        final tenShort = runStage9dRetentionWorkload(
          fixture: shortFixture,
          scenario: const Stage9dRetentionScenario(
            sessionCount: 10,
            historyScale: short,
            lifecycle: Stage9dRetentionLifecycle.active,
          ),
        );
        final oneLong = runStage9dRetentionWorkload(
          fixture: longFixture,
          scenario: const Stage9dRetentionScenario(
            sessionCount: 1,
            historyScale: long,
            lifecycle: Stage9dRetentionLifecycle.active,
          ),
        );

        final oneShortBytes =
            stage9dRetentionMetrics(oneShort)['aggregateSnapshotUtf8Bytes']!
                as int;
        final tenShortBytes =
            stage9dRetentionMetrics(tenShort)['aggregateSnapshotUtf8Bytes']!
                as int;
        final oneLongBytes =
            stage9dRetentionMetrics(oneLong)['aggregateSnapshotUtf8Bytes']!
                as int;

        expect(tenShortBytes, greaterThan(oneShortBytes));
        expect(oneLongBytes, greaterThan(oneShortBytes));
        expect(
          tenShort.totalHistorySteps,
          greaterThan(oneShort.totalHistorySteps),
        );
        expect(
          oneLong.totalHistorySteps,
          greaterThan(oneShort.totalHistorySteps),
        );
      },
    );

    test(
      'same retention scenario produces identical aggregate fingerprints',
      () {
        const scale = Stage9dRetentionHistoryScale(
          name: 'deterministic',
          continuationsPerSession: 9,
        );
        final firstFixture = Stage9dSyntheticNarrativeFixture.build(
          continuationCount: scale.continuationsPerSession,
        );
        final secondFixture = Stage9dSyntheticNarrativeFixture.build(
          continuationCount: scale.continuationsPerSession,
        );
        const scenario = Stage9dRetentionScenario(
          sessionCount: 4,
          historyScale: scale,
          lifecycle: Stage9dRetentionLifecycle.completed,
        );

        final first = runStage9dRetentionWorkload(
          fixture: firstFixture,
          scenario: scenario,
        );
        final second = runStage9dRetentionWorkload(
          fixture: secondFixture,
          scenario: scenario,
        );

        expect(
          stage9dRetentionFingerprint(first),
          stage9dRetentionFingerprint(second),
        );
        expect(stage9dRetentionMetrics(first), stage9dRetentionMetrics(second));
      },
    );
  });
}
