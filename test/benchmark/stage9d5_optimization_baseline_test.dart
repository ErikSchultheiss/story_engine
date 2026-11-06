import 'package:test/test.dart';

import '../../benchmark/support/stage9d5_optimization_baseline.dart';

void main() {
  group('Stage 9D5 clean optimization baseline', () {
    test('project profiles separate the intended authored dimensions', () {
      final fixtures = <String, Stage9d5Fixture>{
        for (final profile in stage9d5ProjectProfiles)
          profile.name: Stage9d5Fixture.build(profile),
      };

      expect(fixtures['compact']!.authoredEventCount, 2);
      expect(fixtures['compact']!.authoredChoiceCount, 2);
      expect(fixtures['compact']!.stateVariableCount, 1);

      expect(fixtures['event_heavy']!.authoredEventCount, 2050);
      expect(fixtures['event_heavy']!.authoredChoiceCount, 2);
      expect(fixtures['event_heavy']!.stateVariableCount, 1);

      expect(fixtures['choice_heavy']!.authoredEventCount, 258);
      expect(fixtures['choice_heavy']!.authoredChoiceCount, 2050);
      expect(fixtures['choice_heavy']!.stateVariableCount, 1);

      expect(fixtures['state_heavy']!.authoredEventCount, 2);
      expect(fixtures['state_heavy']!.authoredChoiceCount, 2);
      expect(fixtures['state_heavy']!.stateVariableCount, 256);

      expect(fixtures['combined_large']!.authoredEventCount, 2050);
      expect(fixtures['combined_large']!.authoredChoiceCount, 2050);
      expect(fixtures['combined_large']!.stateVariableCount, 256);
    });

    test(
      'history depth changes checkpoint history without changing project',
      () {
        final fixture = Stage9d5Fixture.build(stage9d5ProjectProfiles.first);
        final short = prepareStage9d5Restore(
          fixture: fixture,
          historyProfile: stage9d5RestoreHistoryProfiles.first,
        );
        final long = prepareStage9d5Restore(
          fixture: fixture,
          historyProfile: stage9d5RestoreHistoryProfiles.last,
        );

        expect(identical(short.fixture.project, long.fixture.project), isTrue);
        expect(short.snapshot.history.steps, hasLength(17));
        expect(long.snapshot.history.steps, hasLength(513));
        expect(
          short.fixture.authoredEventCount,
          long.fixture.authoredEventCount,
        );
        expect(
          short.fixture.authoredChoiceCount,
          long.fixture.authoredChoiceCount,
        );
      },
    );

    test(
      'validated restore reproduces exact checkpoint and source stays unchanged',
      () {
        final fixture = Stage9d5Fixture.build(stage9d5ProjectProfiles.first);
        final prepared = prepareStage9d5Restore(
          fixture: fixture,
          historyProfile: stage9d5RestoreHistoryProfiles.first,
        );
        final result = runStage9d5Restore(prepared);

        expect(result.restored.createSnapshot(), prepared.snapshot);
        expect(prepared.sourceEngine.createSnapshot(), prepared.snapshot);
        expect(stage9d5RestoreFingerprint(result), isNotEmpty);
      },
    );

    test(
      'propagation changes only source traversal plus sibling shared state',
      () {
        final fixture = Stage9d5Fixture.build(stage9d5ProjectProfiles.first);
        final prepared = prepareStage9d5Propagation(
          fixture: fixture,
          historyProfile: stage9d5RestoreHistoryProfiles.first,
          sessionCount: 4,
        );
        final result = runStage9d5Propagation(prepared);

        expect(stage9d5PropagationFingerprint(result), isNotEmpty);
        expect(prepared.runtime.persistentStateRevision, 1);
        expect(
          prepared.runtime.persistentState.rawValueOf(fixture.counterId),
          1,
        );
        expect(prepared.runtime.activeSessions, hasLength(4));
        expect(
          prepared.sessions.map(
            (session) => session.state.rawValueOf(fixture.counterId),
          ),
          everyElement(1),
        );
      },
    );

    test('fixed history increment measures the same operation window', () {
      final fixture = Stage9d5Fixture.build(stage9d5ProjectProfiles.first);
      for (final history in stage9d5IncrementalHistoryProfiles) {
        for (final kind in Stage9d5HistoryExecutionKind.values) {
          final prepared = prepareStage9d5HistoryIncrement(
            fixture: fixture,
            historyProfile: history,
            kind: kind,
          );
          final result = runStage9d5HistoryIncrement(prepared);
          expect(stage9d5HistoryFingerprint(result), isNotEmpty);
          final metrics = stage9d5HistoryMetrics(result);
          expect(
            metrics['finalHistorySteps'],
            1 + ((history.loopChoices + stage9d5MeasuredAdditionalChoices) * 2),
          );
          expect(metrics['measuredAdditionalChoices'], 16);
        }
      }
    });
  });
}
