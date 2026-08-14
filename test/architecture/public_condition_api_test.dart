import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Stage 1E condition vocabulary is usable from package root only', () {
    final trustId = StoryVariableId('var_trust');
    final schema = StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: trustId,
          alias: StoryAlias('mara_trust'),
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(70),
        ),
      ],
    );
    final state = StoryState.initial(schema);
    final condition = StoryVariableComparisonCondition(
      variableId: trustId,
      operator: StoryComparisonOperator.greaterThanOrEqual,
      value: StoryIntegerValue(60),
    );

    expect(
      const StoryConditionEvaluator().evaluate(
        condition,
        StoryConditionContext(state: state),
      ),
      isTrue,
    );
  });
}
