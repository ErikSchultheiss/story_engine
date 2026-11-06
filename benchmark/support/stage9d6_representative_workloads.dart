import 'stage9d_benchmark_harness.dart';
import 'stage9d5_optimization_baseline.dart';
import 'stage9d6_contract.dart';
import 'stage9d6_owned_workloads.dart';

/// Builds the representative Stage 9D6 workload set.
///
/// The case IDs and fixture dimensions intentionally mirror the frozen Stage
/// 9D5 acceptance benchmark. Stage 9D6 adds regression budgets around that
/// workload without modifying the Stage 9D5 before/after definition.
List<Stage9dBenchmarkCase> buildStage9d6RepresentativeCases() {
  final fixtures = <String, Stage9d5Fixture>{
    for (final profile in stage9d5ProjectProfiles)
      profile.name: Stage9d5Fixture.build(profile),
  };
  final cases = <Stage9dBenchmarkCase>[];

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

  // Stage 9D6-owned protection for the selective-history policy. These cases
  // deliberately have multiple active sessions but perform only choices that
  // leave persistent state unchanged. A rejected hybrid strategy that eagerly
  // snapshots retained source history merely because siblings exist regains a
  // clear medium -> long -> very-long cost slope here.
  for (final history in stage9d6UnchangedHistoryProfiles) {
    for (final sessionCount in stage9d6UnchangedSessionCounts) {
      cases.add(
        Stage9dBenchmarkCase.typed<
          Stage9d6UnchangedHistoryPrepared,
          Stage9d6UnchangedHistoryPrepared
        >(
          id: 'unchanged_history_${history.name}_s$sessionCount',
          description:
              'Execute an unchanged-persistent-state fixed choice '
              'window while multiple narrative sessions are active.',
          workload: <String, Object?>{
            'kind': 'multi_session_unchanged_state_history',
            'projectProfile': compactFixture.profile.name,
            'historyProfile': history.name,
            'preparedLoopChoices': history.loopChoices,
            'measuredAdditionalChoices':
                stage9d6UnchangedMeasuredAdditionalChoices,
            'sessionCount': sessionCount,
            'persistentStateMutationExpected': false,
            'authoredEventCount': compactFixture.authoredEventCount,
            'authoredChoiceCount': compactFixture.authoredChoiceCount,
            'stateVariableCount': compactFixture.stateVariableCount,
            'timingContractVersion': stage9d6TimingContractVersion,
            'timerBoundaryContract': stage9d6TimerBoundaryContract,
            'preparationMode': stage9d6UnchangedStatePreparationMode,
          },
          prepare: () => prepareStage9d6UnchangedHistory(
            fixture: compactFixture,
            historyProfile: history,
            sessionCount: sessionCount,
          ),
          run: runStage9d6UnchangedHistory,
          fingerprint: stage9d6UnchangedHistoryFingerprint,
          metrics: stage9d6UnchangedHistoryMetrics,
        ),
      );
    }
  }

  // The frozen 9D5 propagation cases intentionally stay cold because they
  // preserve historical evidence for project-preparation reuse. Stage 9D6 adds
  // a separate equivalent set with project-derived restore preparation warmed
  // before timing. Session-growth budgets use only these comparable points.
  for (final profile in stage9d5ProjectProfiles) {
    final fixture = fixtures[profile.name]!;
    for (final history in stage9d5RestoreHistoryProfiles) {
      for (final sessionCount in stage9d6PrewarmedPropagationSessionCounts) {
        cases.add(
          Stage9dBenchmarkCase.typed<
            Stage9d6PrewarmedPropagationPrepared,
            Stage9d6PrewarmedPropagationPrepared
          >(
            id: 'prewarmed_propagation_${profile.name}_${history.name}_s$sessionCount',
            description:
                'Commit one shared-state change after exact project '
                'restore preparation has already been constructed outside the '
                'timed region.',
            workload: <String, Object?>{
              'kind': 'prewarmed_shared_state_propagation',
              'projectProfile': profile.name,
              'historyProfile': history.name,
              'historyLoopChoices': history.loopChoices,
              'sessionCount': sessionCount,
              'expectedSiblingRebuildCount': sessionCount - 1,
              'authoredEventCount': fixture.authoredEventCount,
              'authoredChoiceCount': fixture.authoredChoiceCount,
              'stateVariableCount': fixture.stateVariableCount,
              'projectPreparationPrewarmed': true,
              'timingContractVersion': stage9d6TimingContractVersion,
              'timerBoundaryContract': stage9d6TimerBoundaryContract,
              'preparationMode': stage9d6PrewarmedPropagationPreparationMode,
            },
            prepare: () => prepareStage9d6PrewarmedPropagation(
              fixture: fixture,
              historyProfile: history,
              sessionCount: sessionCount,
            ),
            run: runStage9d6PrewarmedPropagation,
            fingerprint: stage9d6PrewarmedPropagationFingerprint,
            metrics: stage9d6PrewarmedPropagationMetrics,
          ),
        );
      }
    }
  }

  return List<Stage9dBenchmarkCase>.unmodifiable(cases);
}
