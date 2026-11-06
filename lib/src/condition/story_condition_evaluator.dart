import '../explainability/story_condition_explanation.dart';
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
      _evaluate(condition, context);

  /// Evaluates [condition] once and returns its structured causal explanation.
  ///
  /// The returned explanation comes from the same evaluation pass that
  /// produced [StoryConditionExplanation.result]. Composite conditions include
  /// only children that were actually evaluated, preserving `ALL` / `ANY`
  /// short-circuit behavior. This method does not perform a second speculative
  /// evaluation for diagnostics.
  ///
  /// Authored-condition failures throw the same
  /// [StoryConditionEvaluationException] as [evaluate]. A failed evaluation
  /// does not manufacture a completed Boolean explanation.
  StoryConditionExplanation evaluateWithExplanation(
    StoryCondition condition,
    StoryConditionContext context,
  ) {
    StoryConditionExplanation? explanation;
    _evaluate(
      condition,
      context,
      onExplanation: (value) => explanation = value,
    );
    return explanation!;
  }

  bool _evaluate(
    StoryCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) => switch (condition) {
    StoryAllCondition condition => _evaluateAll(
      condition,
      context,
      onExplanation: onExplanation,
    ),
    StoryAnyCondition condition => _evaluateAny(
      condition,
      context,
      onExplanation: onExplanation,
    ),
    StoryNotCondition condition => _evaluateNot(
      condition,
      context,
      onExplanation: onExplanation,
    ),
    StoryVariableIsSetCondition condition => _evaluateIsSet(
      condition,
      context,
      onExplanation: onExplanation,
    ),
    StoryVariableIsUnsetCondition condition => _evaluateIsUnset(
      condition,
      context,
      onExplanation: onExplanation,
    ),
    StoryVariableComparisonCondition condition => _evaluateComparison(
      condition,
      context,
      onExplanation: onExplanation,
    ),
  };

  bool _evaluateAll(
    StoryAllCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) {
    final explanations = onExplanation == null
        ? null
        : <StoryConditionExplanation>[];

    for (final child in condition.conditions) {
      final childResult = _evaluate(
        child,
        context,
        onExplanation: explanations?.add,
      );
      if (!childResult) {
        if (onExplanation != null) {
          onExplanation(
            StoryAllConditionExplanation(
              result: false,
              authoredChildCount: condition.conditions.length,
              evaluatedChildren: explanations!,
            ),
          );
        }
        return false;
      }
    }

    if (onExplanation != null) {
      onExplanation(
        StoryAllConditionExplanation(
          result: true,
          authoredChildCount: condition.conditions.length,
          evaluatedChildren: explanations!,
        ),
      );
    }
    return true;
  }

  bool _evaluateAny(
    StoryAnyCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) {
    final explanations = onExplanation == null
        ? null
        : <StoryConditionExplanation>[];

    for (final child in condition.conditions) {
      final childResult = _evaluate(
        child,
        context,
        onExplanation: explanations?.add,
      );
      if (childResult) {
        if (onExplanation != null) {
          onExplanation(
            StoryAnyConditionExplanation(
              result: true,
              authoredChildCount: condition.conditions.length,
              evaluatedChildren: explanations!,
            ),
          );
        }
        return true;
      }
    }

    if (onExplanation != null) {
      onExplanation(
        StoryAnyConditionExplanation(
          result: false,
          authoredChildCount: condition.conditions.length,
          evaluatedChildren: explanations!,
        ),
      );
    }
    return false;
  }

  bool _evaluateNot(
    StoryNotCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) {
    StoryConditionExplanation? childExplanation;
    final childResult = _evaluate(
      condition.condition,
      context,
      onExplanation: onExplanation == null
          ? null
          : (value) => childExplanation = value,
    );
    final result = !childResult;
    if (onExplanation != null) {
      onExplanation(
        StoryNotConditionExplanation(result: result, child: childExplanation!),
      );
    }
    return result;
  }

  bool _evaluateIsSet(
    StoryVariableIsSetCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) {
    final currentValue = _readDeclaredValue(
      variableId: condition.variableId,
      condition: condition,
      context: context,
    );
    final result = currentValue != null;
    if (onExplanation != null) {
      onExplanation(
        StoryVariableIsSetConditionExplanation(
          result: result,
          variableId: condition.variableId,
          currentValue: currentValue,
        ),
      );
    }
    return result;
  }

  bool _evaluateIsUnset(
    StoryVariableIsUnsetCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) {
    final currentValue = _readDeclaredValue(
      variableId: condition.variableId,
      condition: condition,
      context: context,
    );
    final result = currentValue == null;
    if (onExplanation != null) {
      onExplanation(
        StoryVariableIsUnsetConditionExplanation(
          result: result,
          variableId: condition.variableId,
          currentValue: currentValue,
        ),
      );
    }
    return result;
  }

  StoryValue? _readDeclaredValue({
    required StoryVariableId variableId,
    required StoryCondition condition,
    required StoryConditionContext context,
  }) {
    final definition = context.state.schema.definitionFor(variableId);
    if (definition == null) {
      throw StoryConditionEvaluationException(
        condition: condition,
        message:
            'Condition references an undeclared story variable: '
            '$variableId.',
      );
    }
    return context.state.valueOf(variableId);
  }

  bool _evaluateComparison(
    StoryVariableComparisonCondition condition,
    StoryConditionContext context, {
    _StoryConditionExplanationSink? onExplanation,
  }) {
    final definition = context.state.schema.definitionFor(condition.variableId);
    if (definition == null) {
      throw StoryConditionEvaluationException(
        condition: condition,
        message:
            'Condition references an undeclared story variable: '
            '${condition.variableId}.',
      );
    }

    if (definition.type != condition.value.type) {
      throw StoryConditionEvaluationException(
        condition: condition,
        message:
            'Comparison operand type ${condition.value.type.name} does '
            'not match declared variable type ${definition.type.name} for '
            '${condition.variableId}.',
      );
    }

    final current = context.state.valueOf(condition.variableId);

    // Unset is not a scalar value. It never satisfies a scalar comparison,
    // including `!=`. Authors must use an explicit is-set/is-unset predicate.
    final result = current == null
        ? false
        : switch (condition.operator) {
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

    if (onExplanation != null) {
      onExplanation(
        StoryVariableComparisonConditionExplanation(
          result: result,
          variableId: condition.variableId,
          operator: condition.operator,
          expectedValue: condition.value,
          currentValue: current,
        ),
      );
    }
    return result;
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
      // Story Number ordering is ordinary finite IEEE-754 numerical ordering,
      // not Dart num.compareTo's host-specific total ordering. In particular,
      // -0.0 and +0.0 are numerically equal and neither orders before the
      // other. NaN is outside the StoryNumberValue domain.
      if (current.value < expected.value) {
        return -1;
      }
      if (current.value > expected.value) {
        return 1;
      }
      return 0;
    }

    throw StoryConditionEvaluationException(
      condition: condition,
      message:
          'Ordering comparison requires matching integer or number '
          'values.',
    );
  }
}

typedef _StoryConditionExplanationSink =
    void Function(StoryConditionExplanation explanation);

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
  String get suggestion =>
      'Run StoryValidator.validate(project) before '
      'execution and repair the reported condition/schema mismatch.';

  @override
  String toString() => 'StoryConditionEvaluationException: $message';
}

/// Internal one-pass capture that retains the authoritative Boolean separately
/// from its observational data. This helper is not exported by the facade.
({bool result, StoryConditionExplanation explanation})
evaluateStoryConditionWithExplanationResult(
  StoryConditionEvaluator evaluator,
  StoryCondition condition,
  StoryConditionContext context,
) {
  StoryConditionExplanation? explanation;
  final result = evaluator._evaluate(
    condition,
    context,
    onExplanation: (value) => explanation = value,
  );
  return (result: result, explanation: explanation!);
}
