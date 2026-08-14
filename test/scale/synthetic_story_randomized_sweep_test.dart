import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../support/synthetic_story_project_generator.dart';

void main() {
  test('24 seeded randomized valid projects remain reproducible and runnable', () {
    var totalEvents = 0;
    var totalChoices = 0;
    var totalAutomaticEvents = 0;
    var totalConditionalTransitions = 0;
    var totalWeightedTransitions = 0;
    var deepestCondition = 0;

    for (var generatorSeed = 0; generatorSeed < 24; generatorSeed++) {
      final first = SyntheticStoryProjectGenerator.randomized(
        seed: generatorSeed,
      );
      final second = SyntheticStoryProjectGenerator.randomized(
        seed: generatorSeed,
      );

      expect(second.signature, first.signature, reason: 'seed $generatorSeed');
      expect(first.metrics.eventCount, 120, reason: 'seed $generatorSeed');
      expect(
        first.metrics.missingDestinationCount,
        0,
        reason: 'seed $generatorSeed',
      );
      expect(
        first.metrics.invalidVariableReferenceCount,
        0,
        reason: 'seed $generatorSeed',
      );

      final runtimeSeed = (generatorSeed * 7919 + 17) & 0xffffffff;
      final firstRun = _runPrimaryRoute(first.project, randomSeed: runtimeSeed);
      final secondRun = _runPrimaryRoute(
        second.project,
        randomSeed: runtimeSeed,
      );

      expect(
        firstRun.status,
        StoryEngineStatus.terminated,
        reason: 'generator seed $generatorSeed',
      );
      expect(secondRun.state, firstRun.state, reason: 'seed $generatorSeed');
      expect(
        secondRun.history,
        firstRun.history,
        reason: 'seed $generatorSeed',
      );
      expect(
        secondRun.currentEvent?.id,
        firstRun.currentEvent?.id,
        reason: 'seed $generatorSeed',
      );

      totalEvents += first.metrics.eventCount;
      totalChoices += first.metrics.choiceCount;
      totalAutomaticEvents += first.metrics.automaticEventCount;
      totalConditionalTransitions += first.metrics.conditionalTransitionCount;
      totalWeightedTransitions += first.metrics.weightedTransitionCount;
      if (first.metrics.maxConditionDepth > deepestCondition) {
        deepestCondition = first.metrics.maxConditionDepth;
      }
    }

    // This aggregate acts as the Stage 2F "random noise" pressure layer while
    // every individual failure remains reproducible from its generator seed.
    expect(totalEvents, 2880);
    expect(totalChoices, greaterThan(5000));
    expect(totalAutomaticEvents, greaterThan(150));
    expect(totalConditionalTransitions, greaterThan(100));
    expect(totalWeightedTransitions, greaterThan(100));

    // The stable structured profiles separately guarantee condition depth >= 3.
    // The randomized sweep only needs to prove that compound conditions occur;
    // it should not depend on one particular random topology appearing.
    expect(deepestCondition, greaterThanOrEqualTo(2));
  });
}

StoryEngine _runPrimaryRoute(StoryProject project, {required int randomSeed}) {
  final engine = StoryEngine(project: project, randomSeed: randomSeed);
  engine.start();

  var selections = 0;
  final guard = project.events.length * 2;
  while (engine.status == StoryEngineStatus.awaitingChoice) {
    final choices = engine.availableChoices;
    if (choices.isEmpty) {
      fail('Randomized fixture reached an interactive event with no choice.');
    }
    engine.choose(choices.first.id);
    selections++;
    if (selections > guard) {
      fail('Randomized primary route exceeded its forward-progress guard.');
    }
  }

  return engine;
}
