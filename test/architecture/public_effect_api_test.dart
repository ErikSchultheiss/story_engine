import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Stage 1F effect declarations are usable from the package root', () {
    final variableId = StoryVariableId('var_trust');
    final effects = <StoryEffect>[
      StorySetVariableEffect(
        variableId: variableId,
        value: StoryIntegerValue(50),
      ),
      StoryIncrementVariableEffect(
        variableId: variableId,
        amount: StoryIntegerValue(5),
      ),
      StoryDecrementVariableEffect(
        variableId: variableId,
        amount: StoryIntegerValue(2),
      ),
      StoryUnsetVariableEffect(variableId: variableId),
    ];

    expect(effects, hasLength(4));
  });

  test('effect execution and mutable-state machinery stay internal', () {
    final barrel = File('lib/story_engine.dart').readAsStringSync();

    expect(barrel, contains("export 'src/effect/story_effect.dart' show"));
    expect(barrel, isNot(contains('story_effect_executor.dart')));
    expect(barrel, isNot(contains('StoryStateMutation')));
  });
}
