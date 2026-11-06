import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';
import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 4E end-to-end runtime snapshot parity', () {
    test(
      'Lantern Mystery matches uninterrupted execution at every committed checkpoint',
      () {
        final project = LanternMysteryFixture.buildProject();
        final scenarios = <_ParityScenario>[
          _ParityScenario(
            name: 'good archive route with repeated foyer visits',
            randomSeed: LanternMysteryFixture.safeSeed,
            actions: [
              _choose(LanternMysteryFixture.inspectAlarmId),
              _choose(LanternMysteryFixture.openServiceDrawerId),
              _choose(LanternMysteryFixture.visitCaretakerId),
              _choose(LanternMysteryFixture.correctCodenameId),
              _choose(LanternMysteryFixture.readMaintenanceNoteId),
              _choose(LanternMysteryFixture.openArchiveId),
              _choose(LanternMysteryFixture.followMarkedSafeRouteId),
              const _ContinueAction(),
            ],
          ),
          _ParityScenario(
            name: 'cold route with continuation, self-loop, and automatic RNG',
            randomSeed: LanternMysteryFixture.safeSeed,
            actions: [
              _choose(LanternMysteryFixture.inspectAlarmId),
              _choose(LanternMysteryFixture.openServiceDrawerId),
              _choose(LanternMysteryFixture.visitCaretakerId),
              _choose(LanternMysteryFixture.correctCodenameId),
              _choose(LanternMysteryFixture.takeColdStairwayId),
              const _ContinueAction(),
              _choose(LanternMysteryFixture.studyFrostId),
              _choose(LanternMysteryFixture.enterUnstablePassageId),
              _choose(LanternMysteryFixture.followChalkMarksId),
              const _ContinueAction(),
            ],
          ),
          _ParityScenario(
            name: 'collapse route preserves alternate weighted result',
            randomSeed: LanternMysteryFixture.collapseSeed,
            actions: [
              _choose(LanternMysteryFixture.inspectAlarmId),
              _choose(LanternMysteryFixture.openServiceDrawerId),
              _choose(LanternMysteryFixture.enterCorridorId),
              _choose(LanternMysteryFixture.enterCellarId),
              _choose(LanternMysteryFixture.enterUnstablePassageId),
              const _ContinueAction(),
            ],
          ),
        ];

        for (final scenario in scenarios) {
          for (
            var checkpoint = 0;
            checkpoint <= scenario.actions.length;
            checkpoint++
          ) {
            _expectParityFromCheckpoint(
              project: project,
              randomSeed: scenario.randomSeed,
              actions: scenario.actions,
              checkpoint: checkpoint,
              reason: '${scenario.name}, checkpoint $checkpoint',
            );
          }
        }
      },
    );

    test(
      'notStarted round-trip preserves the complete future Lantern route',
      () {
        final project = LanternMysteryFixture.buildProject();
        final uninterrupted = StoryEngine(
          project: project,
          randomSeed: LanternMysteryFixture.safeSeed,
          maxAutomaticTransitions: 43,
        );
        final restored = _roundTrip(project, uninterrupted);

        _expectSameCommittedRuntime(
          restored,
          uninterrupted,
          reason: 'before start',
        );

        uninterrupted.start();
        restored.start();
        _expectSameCommittedRuntime(
          restored,
          uninterrupted,
          reason: 'after start',
        );

        final actions = <_HostAction>[
          _choose(LanternMysteryFixture.inspectAlarmId),
          _choose(LanternMysteryFixture.openServiceDrawerId),
          _choose(LanternMysteryFixture.enterCorridorId),
          _choose(LanternMysteryFixture.enterCellarId),
          _choose(LanternMysteryFixture.enterUnstablePassageId),
          _choose(LanternMysteryFixture.takeNearestExitId),
          const _ContinueAction(),
        ];

        for (var index = 0; index < actions.length; index++) {
          _apply(uninterrupted, actions[index]);
          _apply(restored, actions[index]);
          _expectSameCommittedRuntime(
            restored,
            uninterrupted,
            reason: 'future action $index after notStarted restore',
          );
        }

        expect(uninterrupted.status, StoryEngineStatus.terminated);
        expect(restored.status, StoryEngineStatus.terminated);
      },
    );

    test(
      'awaitingContinue immediately before termination remains paused after restore',
      () {
        final project = LanternMysteryFixture.buildProject();
        final source = StoryEngine(
          project: project,
          randomSeed: LanternMysteryFixture.safeSeed,
        )..start();

        source.choose(LanternMysteryFixture.leaveFoyerId);
        expect(source.status, StoryEngineStatus.awaitingContinue);
        expect(source.currentEvent?.id, LanternMysteryFixture.neutralOutcomeId);

        final restored = _roundTrip(project, source);
        _expectSameCommittedRuntime(
          restored,
          source,
          reason: 'immediately before terminal continue',
        );
        expect(restored.status, StoryEngineStatus.awaitingContinue);

        source.continueStory();
        restored.continueStory();
        _expectSameCommittedRuntime(
          restored,
          source,
          reason: 'after terminal continue',
        );
        expect(restored.status, StoryEngineStatus.terminated);
      },
    );

    test(
      'generated randomized projects preserve route, state, status, and future RNG after restore',
      () {
        for (var generatorSeed = 0; generatorSeed < 12; generatorSeed++) {
          final fixture = SyntheticStoryProjectGenerator.randomized(
            seed: generatorSeed,
          );
          final runtimeSeed = (generatorSeed * 7919 + 17) & 0xffffffff;
          final actions = _recordPrimaryRoute(
            fixture.project,
            randomSeed: runtimeSeed,
          );

          expect(
            actions,
            isNotEmpty,
            reason: 'generator seed $generatorSeed should be runnable',
          );

          for (final checkpoint in _representativeCheckpoints(actions.length)) {
            _expectParityFromCheckpoint(
              project: fixture.project,
              randomSeed: runtimeSeed,
              actions: actions,
              checkpoint: checkpoint,
              reason: 'generator seed $generatorSeed, checkpoint $checkpoint',
            );
          }
        }
      },
    );

    test(
      'structured synthetic project survives checkpoints around automatic traversal and termination',
      () {
        final fixture = SyntheticStoryProjectGenerator.structured(
          SyntheticStoryProfile.small,
        );
        const runtimeSeed = 0x5a17;
        final actions = _recordPrimaryRoute(
          fixture.project,
          randomSeed: runtimeSeed,
        );

        expect(actions.length, greaterThan(80));

        for (final checkpoint in <int>{
          0,
          1,
          38,
          39,
          40,
          actions.length ~/ 2,
          actions.length - 1,
          actions.length,
        }) {
          _expectParityFromCheckpoint(
            project: fixture.project,
            randomSeed: runtimeSeed,
            actions: actions,
            checkpoint: checkpoint,
            reason: 'structured small checkpoint $checkpoint',
          );
        }
      },
    );
  });
}

void _expectParityFromCheckpoint({
  required StoryProject project,
  required int randomSeed,
  required List<_HostAction> actions,
  required int checkpoint,
  required String reason,
}) {
  if (checkpoint < 0 || checkpoint > actions.length) {
    throw ArgumentError.value(checkpoint, 'checkpoint');
  }

  final uninterrupted = StoryEngine(
    project: project,
    randomSeed: randomSeed,
    maxAutomaticTransitions: 257,
  )..start();

  for (var index = 0; index < checkpoint; index++) {
    _apply(uninterrupted, actions[index]);
  }

  final restored = _roundTrip(project, uninterrupted);
  _expectSameCommittedRuntime(restored, uninterrupted, reason: '$reason save');

  for (var index = checkpoint; index < actions.length; index++) {
    _apply(uninterrupted, actions[index]);
    _apply(restored, actions[index]);
    _expectSameCommittedRuntime(
      restored,
      uninterrupted,
      reason: '$reason future action $index',
    );
  }

  expect(
    uninterrupted.status,
    StoryEngineStatus.terminated,
    reason: '$reason uninterrupted route must terminate',
  );
  expect(
    restored.status,
    StoryEngineStatus.terminated,
    reason: '$reason restored route must terminate',
  );
}

StoryEngine _roundTrip(StoryProject project, StoryEngine engine) {
  final codec = StoryRuntimeSnapshotCodec();
  final encoded = codec.encodeJson(engine.createSnapshot());
  final decoded = codec.decodeJson(encoded, project: project);
  return StoryEngine.restore(project: project, snapshot: decoded);
}

void _expectSameCommittedRuntime(
  StoryEngine actual,
  StoryEngine expected, {
  required String reason,
}) {
  expect(actual.status, expected.status, reason: '$reason: status');
  expect(
    actual.currentEvent?.id,
    expected.currentEvent?.id,
    reason: '$reason: current event',
  );
  expect(actual.state, expected.state, reason: '$reason: state');
  expect(actual.history, expected.history, reason: '$reason: history');
  expect(
    actual.randomSeed,
    expected.randomSeed,
    reason: '$reason: original random seed',
  );
  expect(
    actual.maxAutomaticTransitions,
    expected.maxAutomaticTransitions,
    reason: '$reason: automatic traversal guard',
  );
  expect(
    [for (final choice in actual.availableChoices) choice.id],
    [for (final choice in expected.availableChoices) choice.id],
    reason: '$reason: available choices',
  );

  final actualSnapshot = actual.createSnapshot();
  final expectedSnapshot = expected.createSnapshot();
  expect(
    actualSnapshot,
    expectedSnapshot,
    reason: '$reason: complete runtime snapshot',
  );

  final codec = StoryRuntimeSnapshotCodec();
  expect(
    codec.encodeJson(actualSnapshot),
    codec.encodeJson(expectedSnapshot),
    reason: '$reason: deterministic encoded snapshot',
  );
}

List<_HostAction> _recordPrimaryRoute(
  StoryProject project, {
  required int randomSeed,
}) {
  final engine = StoryEngine(
    project: project,
    randomSeed: randomSeed,
    maxAutomaticTransitions: 257,
  )..start();
  final actions = <_HostAction>[];
  final guard = project.events.length * 3;

  while (engine.status != StoryEngineStatus.terminated) {
    if (engine.status == StoryEngineStatus.awaitingChoice) {
      final choices = engine.availableChoices;
      if (choices.isEmpty) {
        fail('Generated route reached an interactive event with no choice.');
      }
      final action = _choose(choices.first.id);
      actions.add(action);
      engine.choose(action.choiceId);
    } else if (engine.status == StoryEngineStatus.awaitingContinue) {
      actions.add(const _ContinueAction());
      engine.continueStory();
    } else {
      fail('Generated route reached unexpected status ${engine.status}.');
    }

    if (actions.length > guard) {
      fail('Generated primary route exceeded its forward-progress guard.');
    }
  }

  return List<_HostAction>.unmodifiable(actions);
}

Iterable<int> _representativeCheckpoints(int actionCount) {
  final candidates = <int>{
    0,
    1,
    2,
    actionCount ~/ 4,
    actionCount ~/ 2,
    (actionCount * 3) ~/ 4,
    actionCount - 1,
    actionCount,
  };
  final sorted =
      candidates.where((value) => value >= 0 && value <= actionCount).toList()
        ..sort();
  return sorted;
}

void _apply(StoryEngine engine, _HostAction action) {
  switch (action) {
    case _ChooseAction(:final choiceId):
      engine.choose(choiceId);
    case _ContinueAction():
      engine.continueStory();
  }
}

_ChooseAction _choose(StoryChoiceId choiceId) => _ChooseAction(choiceId);

sealed class _HostAction {
  const _HostAction();
}

final class _ChooseAction extends _HostAction {
  const _ChooseAction(this.choiceId);

  final StoryChoiceId choiceId;
}

final class _ContinueAction extends _HostAction {
  const _ContinueAction();
}

final class _ParityScenario {
  const _ParityScenario({
    required this.name,
    required this.randomSeed,
    required this.actions,
  });

  final String name;
  final int randomSeed;
  final List<_HostAction> actions;
}
