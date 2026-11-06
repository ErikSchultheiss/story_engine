import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  final boolId = StoryVariableId('var_bool');
  final intId = StoryVariableId('var_int');
  final numberId = StoryVariableId('var_number');
  final stringId = StoryVariableId('var_string');
  final unsetId = StoryVariableId('var_unset');

  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: boolId,
        type: StoryValueType.boolean,
        initialValue: const StoryBooleanValue(true),
      ),
      StoryVariableDefinition(
        id: intId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(65),
      ),
      StoryVariableDefinition(
        id: numberId,
        type: StoryValueType.number,
        initialValue: StoryNumberValue(3.5),
      ),
      StoryVariableDefinition(
        id: stringId,
        type: StoryValueType.string,
        initialValue: const StoryStringValue('forest'),
      ),
      StoryVariableDefinition(id: unsetId, type: StoryValueType.boolean),
    ],
  );

  late StoryConditionContext context;
  const evaluator = StoryConditionEvaluator();

  setUp(() {
    context = StoryConditionContext(state: StoryState.initial(schema));
  });

  group('presence conditions', () {
    test('distinguish set and unset declared variables', () {
      expect(
        evaluator.evaluate(
          StoryVariableIsSetCondition(variableId: boolId),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryVariableIsUnsetCondition(variableId: boolId),
          context,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          StoryVariableIsSetCondition(variableId: unsetId),
          context,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          StoryVariableIsUnsetCondition(variableId: unsetId),
          context,
        ),
        isTrue,
      );
    });

    test('undeclared variable is malformed logic, not false', () {
      final condition = StoryVariableIsSetCondition(
        variableId: StoryVariableId('var_missing'),
      );

      expect(
        () => evaluator.evaluate(condition, context),
        throwsA(isA<StoryConditionEvaluationException>()),
      );
    });
  });

  group('scalar comparisons', () {
    test('support equality and inequality for all scalar types', () {
      expect(
        evaluator.evaluate(
          StoryVariableComparisonCondition(
            variableId: boolId,
            operator: StoryComparisonOperator.equal,
            value: const StoryBooleanValue(true),
          ),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryVariableComparisonCondition(
            variableId: stringId,
            operator: StoryComparisonOperator.notEqual,
            value: const StoryStringValue('castle'),
          ),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryVariableComparisonCondition(
            variableId: intId,
            operator: StoryComparisonOperator.equal,
            value: StoryIntegerValue(65),
          ),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryVariableComparisonCondition(
            variableId: numberId,
            operator: StoryComparisonOperator.equal,
            value: StoryNumberValue(3.5),
          ),
          context,
        ),
        isTrue,
      );
    });

    test('support ordering for integer and number variables', () {
      expect(
        evaluator.evaluate(
          StoryVariableComparisonCondition(
            variableId: intId,
            operator: StoryComparisonOperator.greaterThanOrEqual,
            value: StoryIntegerValue(60),
          ),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryVariableComparisonCondition(
            variableId: numberId,
            operator: StoryComparisonOperator.lessThan,
            value: StoryNumberValue(4.0),
          ),
          context,
        ),
        isTrue,
      );
    });

    test('number ordering treats signed zero as numerically equal', () {
      final zeroId = StoryVariableId('var_zero');
      final zeroSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: zeroId,
            type: StoryValueType.number,
            initialValue: StoryNumberValue(-0.0),
          ),
        ],
      );
      final zeroContext = StoryConditionContext(
        state: StoryState.initial(zeroSchema),
      );

      for (final operator in [
        StoryComparisonOperator.equal,
        StoryComparisonOperator.lessThanOrEqual,
        StoryComparisonOperator.greaterThanOrEqual,
      ]) {
        expect(
          evaluator.evaluate(
            StoryVariableComparisonCondition(
              variableId: zeroId,
              operator: operator,
              value: StoryNumberValue(0.0),
            ),
            zeroContext,
          ),
          isTrue,
        );
      }

      for (final operator in [
        StoryComparisonOperator.notEqual,
        StoryComparisonOperator.lessThan,
        StoryComparisonOperator.greaterThan,
      ]) {
        expect(
          evaluator.evaluate(
            StoryVariableComparisonCondition(
              variableId: zeroId,
              operator: operator,
              value: StoryNumberValue(0.0),
            ),
            zeroContext,
          ),
          isFalse,
        );
      }
    });

    test('reject ordering operators for Boolean and String literals', () {
      expect(
        () => StoryVariableComparisonCondition(
          variableId: boolId,
          operator: StoryComparisonOperator.greaterThan,
          value: const StoryBooleanValue(true),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryVariableComparisonCondition(
          variableId: stringId,
          operator: StoryComparisonOperator.lessThan,
          value: const StoryStringValue('village'),
        ),
        throwsArgumentError,
      );
    });

    test('comparison operand must exactly match declared variable type', () {
      final condition = StoryVariableComparisonCondition(
        variableId: intId,
        operator: StoryComparisonOperator.equal,
        value: StoryNumberValue(65.0),
      );

      expect(
        () => evaluator.evaluate(condition, context),
        throwsA(isA<StoryConditionEvaluationException>()),
      );
    });

    test(
      'all scalar comparisons against unset evaluate false, including !=',
      () {
        final equal = StoryVariableComparisonCondition(
          variableId: unsetId,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(true),
        );
        final notEqual = StoryVariableComparisonCondition(
          variableId: unsetId,
          operator: StoryComparisonOperator.notEqual,
          value: const StoryBooleanValue(true),
        );

        expect(evaluator.evaluate(equal, context), isFalse);
        expect(evaluator.evaluate(notEqual, context), isFalse);
      },
    );
  });
}
