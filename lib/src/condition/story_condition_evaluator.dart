import '../identity/story_variable_id.dart';
import '../state/story_value.dart';
import 'story_condition.dart';
import 'story_condition_context.dart';

/// Evaluates declarative conditions without mutating story/runtime state.
final class StoryConditionEvaluator {
  const StoryConditionEvaluator();

  /// Evaluates [condition] using the read-only [context].
  ///
  /// A valid condition returns true or false. Structurally invalid authored
  /// logic (for example an undeclared variable or incompatible comparison
  /// operand type) throws [StoryConditionEvaluationException] rather than
  /// silently being interpreted as false.
  bool evaluate(StoryCondition condition, StoryConditionContext context) =>
      switch (condition) {
        StoryAllCondition condition => _evaluateAll(condition, context),
        StoryAnyCondition condition => _evaluateAny(condition, context),
        StoryNotCondition condition => !evaluate(condition.condition, context),
        StoryVariableIsSetCondition condition =>
          _evaluateIsSet(condition, context),
        StoryVariableIsUnsetCondition condition =>
          !_evaluateIsSetById(condition.variableId, condition, context),
        StoryVariableComparisonCondition condition =>
          _evaluateComparison(condition, context),
      };

  bool _evaluateAll(
    StoryAllCondition condition,
    StoryConditionContext context,
  ) {
    for (final child in condition.conditions) {
      if (!evaluate(child, context)) {
        return false;
      }
    }
    return true;
  }

  bool _evaluateAny(
    StoryAnyCondition condition,
    StoryConditionContext context,
  ) {
    for (final child in condition.conditions) {
      if (evaluate(child, context)) {
        return true;
      }
    }
    return false;
  }

  bool _evaluateIsSet(
    StoryVariableIsSetCondition condition,
    StoryConditionContext context,
  ) => _evaluateIsSetById(condition.variableId, condition, context);

  bool _evaluateIsSetById(
    StoryVariableId variableId,
    StoryCondition condition,
    StoryConditionContext context,
  ) {
    final definition = context.state.schema.definitionFor(variableId);
    if (definition == null) {
      throw StoryConditionEvaluationException(
        condition: condition,
        message: 'Condition references an undeclared story variable: '
            '$variableId.',
      );
    }
    return context.state.isSet(variableId);
  }

  bool _evaluateComparison(
    StoryVariableComparisonCondition condition,
    StoryConditionContext context,
  ) {
    final definition = context.state.schema.definitionFor(condition.variableId);
    if (definition == null) {
      throw StoryConditionEvaluationException(
        condition: condition,
        message: 'Condition references an undeclared story variable: '
            '${condition.variableId}.',
      );
    }

    if (definition.type != condition.value.type) {
      throw StoryConditionEvaluationException(
        condition: condition,
        message: 'Comparison operand type ${condition.value.type.name} does '
            'not match declared variable type ${definition.type.name} for '
            '${condition.variableId}.',
      );
    }

    final current = context.state.valueOf(condition.variableId);

    // Unset is not a scalar value. It never satisfies a scalar comparison,
    // including `!=`. Authors must use an explicit is-set/is-unset predicate.
    if (current == null) {
      return false;
    }

    return switch (condition.operator) {
      StoryComparisonOperator.equal => current == condition.value,
      StoryComparisonOperator.notEqual => current != condition.value,
      StoryComparisonOperator.lessThan =>
        _compareOrdered(current, condition.value, condition) < 0,
      StoryComparisonOperator.lessThanOrEqual =>
        _compareOrdered(current, condition.value, condition) <= 0,
      StoryComparisonOperator.greaterThan =>
        _compareOrdered(current, condition.value, condition) > 0,
      StoryComparisonOperator.greaterThanOrEqual =>
        _compareOrdered(current, condition.value, condition) >= 0,
    };
  }

  int _compareOrdered(
    StoryValue current,
    StoryValue expected,
    StoryVariableComparisonCondition condition,
  ) {
    if (current is StoryIntegerValue && expected is StoryIntegerValue) {
      return current.value.compareTo(expected.value);
    }
    if (current is StoryNumberValue && expected is StoryNumberValue) {
      return current.value.compareTo(expected.value);
    }

    throw StoryConditionEvaluationException(
      condition: condition,
      message: 'Ordering comparison requires matching integer or number '
          'values.',
    );
  }
}

/// Signals malformed/incompatible authored condition logic during evaluation.
///
/// This exception is distinct from a legitimate false predicate. A later
/// validation stage should normally detect these problems before runtime.
final class StoryConditionEvaluationException implements Exception {
  const StoryConditionEvaluationException({
    required this.condition,
    required this.message,
  });

  /// Condition whose evaluation failed.
  final StoryCondition condition;

  /// Human-readable diagnostic describing the incompatibility.
  final String message;

  /// Developer guidance for authored condition failures.
  String get suggestion => 'Run StoryValidator.validate(project) before '
      'execution and repair the reported condition/schema mismatch.';

  @override
  String toString() => 'StoryConditionEvaluationException: $message';
}
