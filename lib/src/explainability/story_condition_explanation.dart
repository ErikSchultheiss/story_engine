import '../condition/story_condition.dart';
import '../identity/story_variable_id.dart';
import '../state/story_value.dart';

/// Stable discriminant for one structured condition-explanation node.
enum StoryConditionExplanationKind {
  all,
  any,
  not,
  variableIsSet,
  variableIsUnset,
  variableComparison,
}

/// Immutable, observational result from one actual condition-evaluation pass.
///
/// Explanation values are diagnostic data only. Runtime correctness must never
/// depend on whether they are collected, retained, serialized, or discarded.
/// Composite explanations contain only children that were actually evaluated;
/// `authoredChildCount` on the composite types records how many authored
/// children existed so hosts can distinguish short-circuiting from absence.
sealed class StoryConditionExplanation {
  const StoryConditionExplanation({required this.result});

  /// Portable structural kind suitable for host-side logging/serialization.
  StoryConditionExplanationKind get kind;

  /// Boolean result produced by the actual evaluation pass.
  final bool result;
}

/// Explanation of an authored logical `ALL` condition.
final class StoryAllConditionExplanation extends StoryConditionExplanation {
  factory StoryAllConditionExplanation({
    required bool result,
    required int authoredChildCount,
    required Iterable<StoryConditionExplanation> evaluatedChildren,
  }) {
    final children = List<StoryConditionExplanation>.unmodifiable(
      evaluatedChildren,
    );
    _validateCompositeShape(
      operatorName: 'ALL',
      result: result,
      authoredChildCount: authoredChildCount,
      evaluatedChildren: children,
      shortCircuitValue: false,
    );
    return StoryAllConditionExplanation._(
      result: result,
      authoredChildCount: authoredChildCount,
      evaluatedChildren: children,
    );
  }

  const StoryAllConditionExplanation._({
    required super.result,
    required this.authoredChildCount,
    required this.evaluatedChildren,
  });

  @override
  StoryConditionExplanationKind get kind => StoryConditionExplanationKind.all;

  /// Number of children in the authored condition.
  final int authoredChildCount;

  /// Children actually evaluated, in authored order.
  final List<StoryConditionExplanation> evaluatedChildren;

  /// Whether evaluation stopped before the final authored child.
  bool get shortCircuited => evaluatedChildren.length < authoredChildCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryAllConditionExplanation &&
          other.result == result &&
          other.authoredChildCount == authoredChildCount &&
          _orderedExplanationListsEqual(
            other.evaluatedChildren,
            evaluatedChildren,
          );

  @override
  int get hashCode => Object.hash(
    StoryAllConditionExplanation,
    result,
    authoredChildCount,
    Object.hashAll(evaluatedChildren),
  );

  @override
  String toString() =>
      'StoryAllConditionExplanation(result: $result, '
      'evaluated: ${evaluatedChildren.length}/$authoredChildCount)';
}

/// Explanation of an authored logical `ANY` condition.
final class StoryAnyConditionExplanation extends StoryConditionExplanation {
  factory StoryAnyConditionExplanation({
    required bool result,
    required int authoredChildCount,
    required Iterable<StoryConditionExplanation> evaluatedChildren,
  }) {
    final children = List<StoryConditionExplanation>.unmodifiable(
      evaluatedChildren,
    );
    _validateCompositeShape(
      operatorName: 'ANY',
      result: result,
      authoredChildCount: authoredChildCount,
      evaluatedChildren: children,
      shortCircuitValue: true,
    );
    return StoryAnyConditionExplanation._(
      result: result,
      authoredChildCount: authoredChildCount,
      evaluatedChildren: children,
    );
  }

  const StoryAnyConditionExplanation._({
    required super.result,
    required this.authoredChildCount,
    required this.evaluatedChildren,
  });

  @override
  StoryConditionExplanationKind get kind => StoryConditionExplanationKind.any;

  /// Number of children in the authored condition.
  final int authoredChildCount;

  /// Children actually evaluated, in authored order.
  final List<StoryConditionExplanation> evaluatedChildren;

  /// Whether evaluation stopped before the final authored child.
  bool get shortCircuited => evaluatedChildren.length < authoredChildCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryAnyConditionExplanation &&
          other.result == result &&
          other.authoredChildCount == authoredChildCount &&
          _orderedExplanationListsEqual(
            other.evaluatedChildren,
            evaluatedChildren,
          );

  @override
  int get hashCode => Object.hash(
    StoryAnyConditionExplanation,
    result,
    authoredChildCount,
    Object.hashAll(evaluatedChildren),
  );

  @override
  String toString() =>
      'StoryAnyConditionExplanation(result: $result, '
      'evaluated: ${evaluatedChildren.length}/$authoredChildCount)';
}

/// Explanation of an authored logical `NOT` condition.
final class StoryNotConditionExplanation extends StoryConditionExplanation {
  StoryNotConditionExplanation({required bool result, required this.child})
    : super(result: result) {
    if (result == child.result) {
      throw ArgumentError.value(
        result,
        'result',
        'NOT explanation result must be the inverse of its child result.',
      );
    }
  }

  @override
  StoryConditionExplanationKind get kind => StoryConditionExplanationKind.not;

  /// The one child actually evaluated.
  final StoryConditionExplanation child;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryNotConditionExplanation &&
          other.result == result &&
          other.child == child;

  @override
  int get hashCode => Object.hash(StoryNotConditionExplanation, result, child);

  @override
  String toString() => 'StoryNotConditionExplanation(result: $result)';
}

/// Explanation of an `is set` variable predicate.
final class StoryVariableIsSetConditionExplanation
    extends StoryConditionExplanation {
  StoryVariableIsSetConditionExplanation({
    required bool result,
    required this.variableId,
    required this.currentValue,
  }) : super(result: result) {
    if (result != (currentValue != null)) {
      throw ArgumentError.value(
        result,
        'result',
        'is-set result must reflect whether currentValue is present.',
      );
    }
  }

  @override
  StoryConditionExplanationKind get kind =>
      StoryConditionExplanationKind.variableIsSet;

  final StoryVariableId variableId;

  /// Current scalar value, or null when the declared variable is unset.
  final StoryValue? currentValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableIsSetConditionExplanation &&
          other.result == result &&
          other.variableId == variableId &&
          other.currentValue == currentValue;

  @override
  int get hashCode => Object.hash(
    StoryVariableIsSetConditionExplanation,
    result,
    variableId,
    currentValue,
  );

  @override
  String toString() =>
      'StoryVariableIsSetConditionExplanation($variableId, result: $result)';
}

/// Explanation of an `is unset` variable predicate.
final class StoryVariableIsUnsetConditionExplanation
    extends StoryConditionExplanation {
  StoryVariableIsUnsetConditionExplanation({
    required bool result,
    required this.variableId,
    required this.currentValue,
  }) : super(result: result) {
    if (result != (currentValue == null)) {
      throw ArgumentError.value(
        result,
        'result',
        'is-unset result must reflect whether currentValue is absent.',
      );
    }
  }

  @override
  StoryConditionExplanationKind get kind =>
      StoryConditionExplanationKind.variableIsUnset;

  final StoryVariableId variableId;

  /// Current scalar value, or null when the declared variable is unset.
  final StoryValue? currentValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableIsUnsetConditionExplanation &&
          other.result == result &&
          other.variableId == variableId &&
          other.currentValue == currentValue;

  @override
  int get hashCode => Object.hash(
    StoryVariableIsUnsetConditionExplanation,
    result,
    variableId,
    currentValue,
  );

  @override
  String toString() =>
      'StoryVariableIsUnsetConditionExplanation($variableId, result: $result)';
}

/// Explanation of a variable-to-literal comparison.
final class StoryVariableComparisonConditionExplanation
    extends StoryConditionExplanation {
  StoryVariableComparisonConditionExplanation({
    required bool result,
    required this.variableId,
    required this.operator,
    required this.expectedValue,
    required this.currentValue,
  }) : super(result: result) {
    final current = currentValue;
    if (current == null && result) {
      throw ArgumentError.value(
        result,
        'result',
        'An unset variable cannot satisfy a scalar comparison.',
      );
    }
    if (current != null && current.type != expectedValue.type) {
      throw ArgumentError.value(
        current,
        'currentValue',
        'Comparison explanation operands must have matching StoryValue types.',
      );
    }
    if (_isOrderingOperator(operator) &&
        expectedValue is! StoryIntegerValue &&
        expectedValue is! StoryNumberValue) {
      throw ArgumentError.value(
        operator,
        'operator',
        'Ordering comparison explanations require Integer or Number values.',
      );
    }
    final expectedResult = current == null
        ? false
        : _evaluateComparison(
            current: current,
            operator: operator,
            expected: expectedValue,
          );
    if (result != expectedResult) {
      throw ArgumentError.value(
        result,
        'result',
        'Comparison explanation result must match current/operator/expected.',
      );
    }
  }

  @override
  StoryConditionExplanationKind get kind =>
      StoryConditionExplanationKind.variableComparison;

  final StoryVariableId variableId;
  final StoryComparisonOperator operator;
  final StoryValue expectedValue;

  /// Value observed during evaluation, or null when the variable was unset.
  final StoryValue? currentValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableComparisonConditionExplanation &&
          other.result == result &&
          other.variableId == variableId &&
          other.operator == operator &&
          other.expectedValue == expectedValue &&
          other.currentValue == currentValue;

  @override
  int get hashCode => Object.hash(
    StoryVariableComparisonConditionExplanation,
    result,
    variableId,
    operator,
    expectedValue,
    currentValue,
  );

  @override
  String toString() =>
      'StoryVariableComparisonConditionExplanation($variableId $operator '
      '$expectedValue, current: $currentValue, result: $result)';
}

void _validateCompositeShape({
  required String operatorName,
  required bool result,
  required int authoredChildCount,
  required List<StoryConditionExplanation> evaluatedChildren,
  required bool shortCircuitValue,
}) {
  if (authoredChildCount <= 0) {
    throw ArgumentError.value(
      authoredChildCount,
      'authoredChildCount',
      '$operatorName explanations require at least one authored child.',
    );
  }
  if (evaluatedChildren.isEmpty ||
      evaluatedChildren.length > authoredChildCount) {
    throw ArgumentError.value(
      evaluatedChildren,
      'evaluatedChildren',
      '$operatorName explanations require between one and authoredChildCount '
          'evaluated children.',
    );
  }

  final stoppedEarly = evaluatedChildren.length < authoredChildCount;
  if (stoppedEarly && result != shortCircuitValue) {
    throw ArgumentError.value(
      result,
      'result',
      '$operatorName may stop early only after producing its short-circuit '
          'result.',
    );
  }

  for (var index = 0; index < evaluatedChildren.length; index++) {
    final child = evaluatedChildren[index];
    final isLast = index == evaluatedChildren.length - 1;
    if (!isLast && child.result == shortCircuitValue) {
      throw ArgumentError.value(
        evaluatedChildren,
        'evaluatedChildren',
        '$operatorName cannot evaluate children after its short-circuit value.',
      );
    }
  }

  final lastResult = evaluatedChildren.last.result;
  if (result == shortCircuitValue) {
    if (lastResult != shortCircuitValue) {
      throw ArgumentError.value(
        evaluatedChildren,
        'evaluatedChildren',
        '$operatorName result requires the final evaluated child to produce '
            'the same short-circuit result.',
      );
    }
    return;
  }

  if (evaluatedChildren.length != authoredChildCount ||
      evaluatedChildren.any((child) => child.result == shortCircuitValue)) {
    throw ArgumentError.value(
      evaluatedChildren,
      'evaluatedChildren',
      '$operatorName non-short-circuit result requires every authored child '
          'to be evaluated without producing the short-circuit value.',
    );
  }
}

bool _evaluateComparison({
  required StoryValue current,
  required StoryComparisonOperator operator,
  required StoryValue expected,
}) => switch (operator) {
  StoryComparisonOperator.equal => current == expected,
  StoryComparisonOperator.notEqual => current != expected,
  StoryComparisonOperator.lessThan => _compareOrdered(current, expected) < 0,
  StoryComparisonOperator.lessThanOrEqual =>
    _compareOrdered(current, expected) <= 0,
  StoryComparisonOperator.greaterThan => _compareOrdered(current, expected) > 0,
  StoryComparisonOperator.greaterThanOrEqual =>
    _compareOrdered(current, expected) >= 0,
};

int _compareOrdered(StoryValue current, StoryValue expected) {
  if (current is StoryIntegerValue && expected is StoryIntegerValue) {
    return current.value.compareTo(expected.value);
  }
  if (current is StoryNumberValue && expected is StoryNumberValue) {
    if (current.value < expected.value) {
      return -1;
    }
    if (current.value > expected.value) {
      return 1;
    }
    return 0;
  }
  throw ArgumentError(
    'Ordering comparison explanation values must be matching numeric types.',
  );
}

bool _isOrderingOperator(StoryComparisonOperator operator) =>
    switch (operator) {
      StoryComparisonOperator.lessThan ||
      StoryComparisonOperator.lessThanOrEqual ||
      StoryComparisonOperator.greaterThan ||
      StoryComparisonOperator.greaterThanOrEqual => true,
      StoryComparisonOperator.equal ||
      StoryComparisonOperator.notEqual => false,
    };

bool _orderedExplanationListsEqual(
  List<StoryConditionExplanation> left,
  List<StoryConditionExplanation> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
