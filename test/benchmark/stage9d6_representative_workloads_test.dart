import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../benchmark/support/stage9d6_contract.dart';
import '../../benchmark/support/stage9d6_performance_budgets.dart';
import '../../benchmark/support/stage9d6_representative_workloads.dart';

void main() {
  group('Stage 9D6 representative workloads', () {
    test(
      'preserve frozen 9D5 cases and add explicit 9D6-owned protections',
      () {
        final cases = buildStage9d6RepresentativeCases();
        final decoded =
            jsonDecode(
                  File(
                    'benchmark/reference/stage9d6_semantic_baseline.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final baseline = Stage9d6SemanticBaseline.fromJson(decoded);

        expect(cases, hasLength(82));
        expect(
          cases.map((benchmarkCase) => benchmarkCase.id).toSet(),
          baseline.allCaseIds,
        );
        expect(
          cases.where(
            (benchmarkCase) =>
                benchmarkCase.workload['kind'] == 'validated_restore',
          ),
          hasLength(10),
        );
        expect(
          cases.where(
            (benchmarkCase) =>
                benchmarkCase.workload['kind'] == 'shared_state_propagation',
          ),
          hasLength(30),
        );
        expect(
          cases.where(
            (benchmarkCase) =>
                benchmarkCase.workload['kind'] == 'fixed_history_increment',
          ),
          hasLength(6),
        );
        expect(
          cases.where(
            (benchmarkCase) =>
                benchmarkCase.workload['kind'] ==
                'multi_session_unchanged_state_history',
          ),
          hasLength(6),
        );
        expect(
          cases.where(
            (benchmarkCase) =>
                benchmarkCase.workload['kind'] ==
                'prewarmed_shared_state_propagation',
          ),
          hasLength(30),
        );
      },
    );

    test(
      '9D6-owned cases make timer boundary and preparation mode explicit',
      () {
        final ownedCases = buildStage9d6RepresentativeCases().where(
          (benchmarkCase) =>
              benchmarkCase.workload['kind'] ==
                  'multi_session_unchanged_state_history' ||
              benchmarkCase.workload['kind'] ==
                  'prewarmed_shared_state_propagation',
        );

        expect(ownedCases, hasLength(36));
        for (final benchmarkCase in ownedCases) {
          expect(
            benchmarkCase.workload['timingContractVersion'],
            stage9d6TimingContractVersion,
          );
          expect(
            benchmarkCase.workload['timerBoundaryContract'],
            stage9d6TimerBoundaryContract,
          );
          expect(benchmarkCase.workload['preparationMode'], isA<String>());
        }
      },
    );

    test(
      'unchanged-state cases cover 2/50 sessions and three history depths',
      () {
        final cases = buildStage9d6RepresentativeCases()
            .where(
              (benchmarkCase) =>
                  benchmarkCase.workload['kind'] ==
                  'multi_session_unchanged_state_history',
            )
            .toList();

        expect(
          cases
              .map((benchmarkCase) => benchmarkCase.workload['sessionCount'])
              .toSet(),
          <Object?>{2, 50},
        );
        expect(
          cases
              .map((benchmarkCase) => benchmarkCase.workload['historyProfile'])
              .toSet(),
          <Object?>{'medium', 'long', 'very_long'},
        );
        expect(
          cases.every(
            (benchmarkCase) =>
                benchmarkCase.workload['persistentStateMutationExpected'] ==
                false,
          ),
          isTrue,
        );
      },
    );

    test('prewarmed propagation uses comparable s1/s10/s50 conditions', () {
      final cases = buildStage9d6RepresentativeCases()
          .where(
            (benchmarkCase) =>
                benchmarkCase.workload['kind'] ==
                'prewarmed_shared_state_propagation',
          )
          .toList();

      expect(
        cases
            .map((benchmarkCase) => benchmarkCase.workload['sessionCount'])
            .toSet(),
        <Object?>{1, 10, 50},
      );
      expect(
        cases.every(
          (benchmarkCase) =>
              benchmarkCase.workload['projectPreparationPrewarmed'] == true &&
              benchmarkCase.workload['preparationMode'] ==
                  stage9d6PrewarmedPropagationPreparationMode,
        ),
        isTrue,
      );
    });
  });
}
