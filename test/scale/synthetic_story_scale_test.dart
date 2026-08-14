import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 2F structured scale traversal', () {
    test('medium project traverses deterministically to termination', () {
      final fixture = SyntheticStoryProjectGenerator.structured(
        SyntheticStoryProfile.medium,
      );

      final first = _runPrimaryRoute(fixture.project, randomSeed: 42);
      final second = _runPrimaryRoute(fixture.project, randomSeed: 42);

      expect(first.status, StoryEngineStatus.terminated);
      expect(first.state, second.state);
      expect(first.history, second.history);
      expect(first.currentEvent?.id, second.currentEvent?.id);
      expect(first.history.eventRoute.length, lessThanOrEqualTo(500));
      expect(first.history.selectedChoiceIds.length, lessThanOrEqualTo(500));
    });

    test('large project traverses without architecture-scale failure', () {
      final fixture = SyntheticStoryProjectGenerator.structured(
        SyntheticStoryProfile.large,
      );

      final engine = _runPrimaryRoute(fixture.project, randomSeed: 314159);

      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.history.eventRoute, isNotEmpty);
      expect(engine.history.eventRoute.length, lessThanOrEqualTo(1000));
      expect(engine.history.selectedChoiceIds.length, lessThanOrEqualTo(1000));
    });

    test('different runtime seeds remain valid on the medium project', () {
      final fixture = SyntheticStoryProjectGenerator.structured(
        SyntheticStoryProfile.medium,
      );

      for (final seed in [0, 1, 7, 42, 65535]) {
        final engine = _runPrimaryRoute(fixture.project, randomSeed: seed);
        expect(
          engine.status,
          StoryEngineStatus.terminated,
          reason: 'seed $seed',
        );
        expect(
          engine.history.eventRoute.length,
          lessThanOrEqualTo(fixture.metrics.eventCount),
          reason: 'seed $seed',
        );
      }
    });
  });
}

StoryEngine _runPrimaryRoute(
  StoryProject project, {
  required int randomSeed,
}) {
  final engine = StoryEngine(project: project, randomSeed: randomSeed);
  engine.start();

  var choicesSelected = 0;
  final selectionGuard = project.events.length * 2;
  while (engine.status == StoryEngineStatus.awaitingChoice) {
    final choices = engine.availableChoices;
    if (choices.isEmpty) {
      fail('Synthetic project reached an interactive event with no choice.');
    }
    engine.choose(choices.first.id);
    choicesSelected++;
    if (choicesSelected > selectionGuard) {
      fail('Synthetic primary route exceeded its forward-progress guard.');
    }
  }

  return engine;
}
