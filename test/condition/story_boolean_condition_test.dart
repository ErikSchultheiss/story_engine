import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  final readyId = StoryVariableId('var_ready');
  final trustId = StoryVariableId('var_trust');

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
    ],
  );

  final context = StoryConditionContext(state: StoryState.initial(schema));
  const evaluator = StoryConditionEvaluator();

  StoryCondition readyIsTrue() => StoryVariableComparisonCondition(
    variableId: readyId,
    operator: StoryComparisonOperator.equal,
    value: const StoryBooleanValue(true),
  );

  StoryCondition trustAtLeast(int value) => StoryVariableComparisonCondition(
    variableId: trustId,
    operator: StoryComparisonOperator.greaterThanOrEqual,
    value: StoryIntegerValue(value),
  );

  group('boolean composition', () {
    test('ALL requires all children', () {
      expect(
        evaluator.evaluate(
          StoryAllCondition([readyIsTrue(), trustAtLeast(60)]),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryAllCondition([readyIsTrue(), trustAtLeast(80)]),
          context,
        ),
        isFalse,
      );
    });

    test('ANY requires at least one true child', () {
      expect(
        evaluator.evaluate(
          StoryAnyCondition([trustAtLeast(80), readyIsTrue()]),
          context,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          StoryAnyCondition([trustAtLeast(80), trustAtLeast(90)]),
          context,
        ),
        isFalse,
      );
    });

    test('NOT negates exactly one condition', () {
      expect(
        evaluator.evaluate(StoryNotCondition(trustAtLeast(80)), context),
        isTrue,
      );
      expect(
        evaluator.evaluate(StoryNotCondition(readyIsTrue()), context),
        isFalse,
      );
    });

    test('nested ALL/ANY/NOT supports declarative expression trees', () {
      final condition = StoryAllCondition([
        readyIsTrue(),
        StoryAnyCondition([
          trustAtLeast(90),
          StoryNotCondition(trustAtLeast(80)),
        ]),
      ]);

      expect(evaluator.evaluate(condition, context), isTrue);
    });

    test('ALL and ANY reject empty groups', () {
      expect(() => StoryAllCondition(const []), throwsArgumentError);
      expect(() => StoryAnyCondition(const []), throwsArgumentError);
    });

    test('condition child lists are immutable snapshots', () {
      final source = <StoryCondition>[readyIsTrue()];
      final all = StoryAllCondition(source);
      source.add(trustAtLeast(60));

      expect(all.conditions, hasLength(1));
      expect(
        () => all.conditions.add(trustAtLeast(50)),
        throwsUnsupportedError,
      );
    });

    test('ALL short-circuits after false child', () {
      final malformed = StoryVariableIsSetCondition(
        variableId: StoryVariableId('var_missing'),
      );
      final condition = StoryAllCondition([trustAtLeast(80), malformed]);

      expect(evaluator.evaluate(condition, context), isFalse);
    });

    test('ANY short-circuits after true child', () {
      final malformed = StoryVariableIsSetCondition(
        variableId: StoryVariableId('var_missing'),
      );
      final condition = StoryAnyCondition([readyIsTrue(), malformed]);

      expect(evaluator.evaluate(condition, context), isTrue);
    });
  });

  test('equivalent condition trees have deterministic equality/hash codes', () {
    final left = StoryAllCondition([readyIsTrue(), trustAtLeast(60)]);
    final right = StoryAllCondition([readyIsTrue(), trustAtLeast(60)]);

    expect(left, equals(right));
    expect(left.hashCode, equals(right.hashCode));
  });
}
