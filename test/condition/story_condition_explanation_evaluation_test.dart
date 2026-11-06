import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  final readyId = StoryVariableId('var_ready');
  final trustId = StoryVariableId('var_trust');
  final unsetId = StoryVariableId('var_unset');

  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: readyId,
        type: StoryValueType.boolean,
        initialValue: const StoryBooleanValue(true),
      ),
      StoryVariableDefinition(
        id: trustId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(70),
      ),
      StoryVariableDefinition(id: unsetId, type: StoryValueType.boolean),
    ],
  );

  final context = StoryConditionContext(state: StoryState.initial(schema));
  const evaluator = StoryConditionEvaluator();

  StoryVariableComparisonCondition trustAtLeast(int value) =>
      StoryVariableComparisonCondition(
        variableId: trustId,
        operator: StoryComparisonOperator.greaterThanOrEqual,
        value: StoryIntegerValue(value),
      );

  StoryVariableComparisonCondition readyIsTrue() =>
      StoryVariableComparisonCondition(
        variableId: readyId,
        operator: StoryComparisonOperator.equal,
        value: const StoryBooleanValue(true),
      );

  group('evaluateWithExplanation', () {
    test('captures comparison operator and actual current/expected values', () {
      final explanation = evaluator.evaluateWithExplanation(
        trustAtLeast(60),
        context,
      );

      expect(explanation, isA<StoryVariableComparisonConditionExplanation>());
      final comparison =
          explanation as StoryVariableComparisonConditionExplanation;
      expect(comparison.result, isTrue);
      expect(comparison.variableId, trustId);
      expect(comparison.operator, StoryComparisonOperator.greaterThanOrEqual);
      expect(comparison.currentValue, StoryIntegerValue(70));
      expect(comparison.expectedValue, StoryIntegerValue(60));
    });

    test('captures set and unset current values from the actual state', () {
      final setExplanation = evaluator.evaluateWithExplanation(
        StoryVariableIsSetCondition(variableId: readyId),
        context,
      );
      final unsetExplanation = evaluator.evaluateWithExplanation(
        StoryVariableIsUnsetCondition(variableId: unsetId),
        context,
      );

      expect(
        setExplanation,
        StoryVariableIsSetConditionExplanation(
          result: true,
          variableId: readyId,
          currentValue: const StoryBooleanValue(true),
        ),
      );
      expect(
        unsetExplanation,
        StoryVariableIsUnsetConditionExplanation(
          result: true,
          variableId: unsetId,
          currentValue: null,
        ),
      );
    });

    test('ALL explanation stops at the first false child', () {
      final skippedMalformed = StoryVariableIsSetCondition(
        variableId: StoryVariableId('var_missing'),
      );
      final condition = StoryAllCondition([trustAtLeast(80), skippedMalformed]);

      final explanation = evaluator.evaluateWithExplanation(condition, context);

      expect(explanation, isA<StoryAllConditionExplanation>());
      final all = explanation as StoryAllConditionExplanation;
      expect(all.result, isFalse);
      expect(all.authoredChildCount, 2);
      expect(all.evaluatedChildren, hasLength(1));
      expect(all.shortCircuited, isTrue);
      expect(all.evaluatedChildren.single.result, isFalse);
    });

    test('ANY explanation stops at the first true child', () {
      final skippedMalformed = StoryVariableIsSetCondition(
        variableId: StoryVariableId('var_missing'),
      );
      final condition = StoryAnyCondition([readyIsTrue(), skippedMalformed]);

      final explanation = evaluator.evaluateWithExplanation(condition, context);

      expect(explanation, isA<StoryAnyConditionExplanation>());
      final any = explanation as StoryAnyConditionExplanation;
      expect(any.result, isTrue);
      expect(any.authoredChildCount, 2);
      expect(any.evaluatedChildren, hasLength(1));
      expect(any.shortCircuited, isTrue);
      expect(any.evaluatedChildren.single.result, isTrue);
    });

    test('nested explanations preserve actual authored evaluation order', () {
      final condition = StoryAllCondition([
        readyIsTrue(),
        StoryAnyCondition([
          trustAtLeast(80),
          StoryNotCondition(trustAtLeast(80)),
        ]),
      ]);

      final explanation = evaluator.evaluateWithExplanation(condition, context);

      final all = explanation as StoryAllConditionExplanation;
      expect(all.result, isTrue);
      expect(all.evaluatedChildren, hasLength(2));

      final any = all.evaluatedChildren[1] as StoryAnyConditionExplanation;
      expect(any.result, isTrue);
      expect(any.evaluatedChildren, hasLength(2));
      expect(any.shortCircuited, isFalse);

      final not = any.evaluatedChildren[1] as StoryNotConditionExplanation;
      expect(not.result, isTrue);
      expect(not.child.result, isFalse);
    });

    test('diagnostic and ordinary evaluation produce identical results', () {
      final conditions = <StoryCondition>[
        readyIsTrue(),
        trustAtLeast(60),
        trustAtLeast(80),
        StoryVariableIsSetCondition(variableId: readyId),
        StoryVariableIsUnsetCondition(variableId: unsetId),
        StoryNotCondition(trustAtLeast(80)),
        StoryAllCondition([readyIsTrue(), trustAtLeast(60)]),
        StoryAnyCondition([trustAtLeast(80), readyIsTrue()]),
      ];

      for (final condition in conditions) {
        expect(
          evaluator.evaluateWithExplanation(condition, context).result,
          evaluator.evaluate(condition, context),
          reason: '$condition',
        );
      }
    });

    test('authored failures preserve evaluator exception semantics', () {
      final malformedConditions = <StoryCondition>[
        StoryVariableIsSetCondition(variableId: StoryVariableId('var_missing')),
        StoryVariableComparisonCondition(
          variableId: trustId,
          operator: StoryComparisonOperator.equal,
          value: StoryNumberValue(70.0),
        ),
      ];

      StoryConditionEvaluationException capture(void Function() operation) {
        try {
          operation();
        } on StoryConditionEvaluationException catch (error) {
          return error;
        }
        fail('Expected StoryConditionEvaluationException.');
      }

      for (final malformed in malformedConditions) {
        final ordinary = capture(() => evaluator.evaluate(malformed, context));
        final explained = capture(
          () => evaluator.evaluateWithExplanation(malformed, context),
        );

        expect(explained.condition, same(malformed));
        expect(explained.message, ordinary.message);
        expect(explained.suggestion, ordinary.suggestion);
        expect(explained.toString(), ordinary.toString());
      }
    });
  });
}
