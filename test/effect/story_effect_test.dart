import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('scalar effect declarations', () {
    final variableId = StoryVariableId('var_gold');

    test('set and unset effects are immutable value objects', () {
      const value = StoryBooleanValue(true);
      final setA = StorySetVariableEffect(variableId: variableId, value: value);
      final setB = StorySetVariableEffect(variableId: variableId, value: value);
      final unsetA = StoryUnsetVariableEffect(variableId: variableId);
      final unsetB = StoryUnsetVariableEffect(variableId: variableId);

      expect(setA, setB);
      expect(setA.hashCode, setB.hashCode);
      expect(unsetA, unsetB);
      expect(unsetA.hashCode, unsetB.hashCode);
    });

    test('increment/decrement accept integer and number amounts', () {
      expect(
        StoryIncrementVariableEffect(
          variableId: variableId,
          amount: StoryIntegerValue(5),
        ).amount,
        StoryIntegerValue(5),
      );
      expect(
        StoryDecrementVariableEffect(
          variableId: variableId,
          amount: StoryNumberValue(2.5),
        ).amount,
        StoryNumberValue(2.5),
      );
    });

    test('numeric adjustment amounts may be zero', () {
      expect(
        StoryIncrementVariableEffect(
          variableId: variableId,
          amount: StoryIntegerValue(0),
        ).amount,
        StoryIntegerValue(0),
      );
    });

    test('numeric adjustment rejects negative amounts', () {
      expect(
        () => StoryIncrementVariableEffect(
          variableId: variableId,
          amount: StoryIntegerValue(-1),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryDecrementVariableEffect(
          variableId: variableId,
          amount: StoryNumberValue(-0.5),
        ),
        throwsArgumentError,
      );
    });

    test('numeric adjustment rejects boolean and string amounts', () {
      expect(
        () => StoryIncrementVariableEffect(
          variableId: variableId,
          amount: const StoryBooleanValue(true),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryDecrementVariableEffect(
          variableId: variableId,
          amount: const StoryStringValue('5'),
        ),
        throwsArgumentError,
      );
    });
  });
}
