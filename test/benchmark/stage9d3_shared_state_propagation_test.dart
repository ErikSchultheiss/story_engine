import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../benchmark/support/stage9d_shared_state_propagation.dart';

void main() {
  group('Stage 9D3 shared-state propagation workloads', () {
    test('matrix freezes project/history/session growth dimensions', () {
      final matrix = stage9dPropagationMatrix();

      expect(stage9dPropagationSessionCounts, <int>[1, 10, 50]);
      expect(
        stage9dPropagationProjectProfiles
            .map(
              (profile) => (
                profile.name,
                profile.paddingEventCount,
                profile.stateVariableCount,
              ),
            )
            .toList(growable: false),
        <(String, int, int)>[
          ('compact', 0, 1),
          ('medium', 512, 64),
          ('large', 2048, 256),
        ],
      );
      expect(
        stage9dPropagationHistoryScales
            .map((scale) => (scale.name, scale.continuationsPerSession))
            .toList(growable: false),
        <(String, int)>[('short', 8), ('medium', 64), ('long', 256)],
      );
      expect(matrix, hasLength(27));
      expect(matrix.map((scenario) => scenario.idStem).toSet(), hasLength(27));
    });

    test('one source commit updates every active sibling exactly once', () {
      const projectProfile = Stage9dPropagationProjectProfile(
        name: 'test',
        paddingEventCount: 3,
        stateVariableCount: 4,
      );
      const historyScale = Stage9dPropagationHistoryScale(
        name: 'test',
        continuationsPerSession: 3,
      );
      const scenario = Stage9dPropagationScenario(
        sessionCount: 3,
        projectProfile: projectProfile,
        historyScale: historyScale,
      );
      final fixture = Stage9dPropagationFixture.build(
        projectProfile: projectProfile,
        historyScale: historyScale,
      );
      final prepared = prepareStage9dPropagation(fixture, scenario);

      expect(prepared.runtime.persistentStateRevision, 0);
      expect(prepared.runtime.persistentState.rawValueOf(fixture.counterId), 0);
      expect(prepared.runtime.activeSessions, hasLength(3));
      for (final session in prepared.sessions) {
        expect(session.currentEvent?.id, fixture.preCommitEventId);
        expect(session.state.rawValueOf(fixture.counterId), 0);
      }

      final result = runStage9dPropagationCommit(prepared);

      expect(result.runtime.persistentStateRevision, 1);
      expect(result.runtime.persistentState.rawValueOf(fixture.counterId), 1);
      expect(result.runtime.activeSessions, hasLength(3));
      expect(result.prepared.source.currentEvent?.id, fixture.commitEventId);
      for (final session in prepared.sessions.skip(1)) {
        expect(session.currentEvent?.id, fixture.preCommitEventId);
        expect(session.state.rawValueOf(fixture.counterId), 1);
      }
      expect(stage9dPropagationMetrics(result)['siblingRebuildCount'], 2);
    });

    test(
      'single rebuild preserves checkpoint semantics with substituted state',
      () {
        const projectProfile = Stage9dPropagationProjectProfile(
          name: 'unit',
          paddingEventCount: 5,
          stateVariableCount: 6,
        );
        const historyScale = Stage9dPropagationHistoryScale(
          name: 'unit',
          continuationsPerSession: 4,
        );
        final fixture = Stage9dPropagationFixture.build(
          projectProfile: projectProfile,
          historyScale: historyScale,
        );
        final first = runStage9dSiblingRebuild(
          prepareStage9dSiblingRebuild(fixture),
        );
        final second = runStage9dSiblingRebuild(
          prepareStage9dSiblingRebuild(fixture),
        );

        expect(first.engine.currentEvent?.id, fixture.preCommitEventId);
        expect(first.engine.state?.rawValueOf(fixture.counterId), 1);
        expect(first.engine.status, StoryEngineStatus.awaitingContinue);
        expect(
          stage9dSiblingRebuildFingerprint(first),
          stage9dSiblingRebuildFingerprint(second),
        );
        expect(
          stage9dSiblingRebuildMetrics(first),
          stage9dSiblingRebuildMetrics(second),
        );
      },
    );

    test(
      'project profiles independently add unreachable authored structure',
      () {
        const historyScale = Stage9dPropagationHistoryScale(
          name: 'shape',
          continuationsPerSession: 2,
        );
        final compact = Stage9dPropagationFixture.build(
          projectProfile: stage9dPropagationProjectProfiles.first,
          historyScale: historyScale,
        );
        final large = Stage9dPropagationFixture.build(
          projectProfile: stage9dPropagationProjectProfiles.last,
          historyScale: historyScale,
        );

        expect(
          large.authoredEventCount,
          greaterThan(compact.authoredEventCount),
        );
        expect(
          large.authoredChoiceCount,
          greaterThan(compact.authoredChoiceCount),
        );
        expect(
          large.stateVariableCount,
          greaterThan(compact.stateVariableCount),
        );
        expect(compact.preCommitEventId, large.preCommitEventId);
      },
    );
  });
}
