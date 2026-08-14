import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Stage 1G transition declarations are usable from package root', () {
    final flagId = StoryVariableId('var_flag');
    final eventA = StoryEventId('evt_a');
    final eventB = StoryEventId('evt_b');

    final transition = StoryConditionalTransition(
      branches: [
        StoryConditionalTransitionBranch(
          condition: StoryVariableComparisonCondition(
            variableId: flagId,
            operator: StoryComparisonOperator.equal,
            value: const StoryBooleanValue(true),
          ),
          transition: StoryEventTransition(destinationEventId: eventA),
        ),
      ],
      fallback: StoryWeightedTransition(
        options: [
          StoryWeightedTransitionOption(
            weight: 3,
            transition: StoryEventTransition(destinationEventId: eventB),
          ),
          StoryWeightedTransitionOption(
            weight: 1,
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
    );

    expect(transition, isA<StoryTransition>());
  });

  test('transition resolution and RNG machinery stay internal', () {
    final barrel = File('lib/story_engine.dart').readAsStringSync();

    expect(barrel, contains("export 'src/transition/story_transition.dart' show"));
    expect(barrel, isNot(contains('story_transition_resolver.dart')));
    expect(barrel, isNot(contains('StoryRandomSource')));
    expect(barrel, isNot(contains('StoryTransitionResolver')));
  });
}
