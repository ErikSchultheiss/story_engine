import '../identity/story_variable_id.dart';
import '../state/story_value.dart';
import '../state/story_value_type.dart';

/// Declarative, side-effect-free predicate over story/runtime facts.
///
/// Stage 1E conditions may inspect scalar story state only. Runtime-history
/// conditions (visited event, selected choice, occurrence count, and similar)
/// and developer-defined custom conditions are deliberately deferred while
/// keeping this hierarchy closed to executable user subclasses.
sealed class StoryCondition {
  const StoryCondition();
}

/// Logical conjunction. Every child condition must evaluate to true.
final class StoryAllCondition extends StoryCondition {
  factory StoryAllCondition(Iterable<StoryCondition> conditions) {
    final copied = List<StoryCondition>.unmodifiable(conditions);
    if (copied.isEmpty) {
      throw ArgumentError.value(
        conditions,
        'conditions',
        'StoryAllCondition requires at least one child condition. '
            'Use absence of a condition to represent unconditional behavior.',
      );
    }
    return StoryAllCondition._(copied);
  }

  const StoryAllCondition._(this.conditions);

  /// Child conditions in deterministic authored order.
  final List<StoryCondition> conditions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryAllCondition &&
          _orderedConditionsEqual(conditions, other.conditions);

  @override
  int get hashCode => Object.hash(StoryAllCondition, Object.hashAll(conditions));

  @override
  String toString() => 'StoryAllCondition($conditions)';
}

/// Logical disjunction. At least one child condition must evaluate to true.
final class StoryAnyCondition extends StoryCondition {
  factory StoryAnyCondition(Iterable<StoryCondition> conditions) {
    final copied = List<StoryCondition>.unmodifiable(conditions);
    if (copied.isEmpty) {
      throw ArgumentError.value(
        conditions,
        'conditions',
        'StoryAnyCondition requires at least one child condition.',
      );
    }
    return StoryAnyCondition._(copied);
  }

  const StoryAnyCondition._(this.conditions);

  /// Child conditions in deterministic authored order.
  final List<StoryCondition> conditions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryAnyCondition &&
          _orderedConditionsEqual(conditions, other.conditions);

  @override
  int get hashCode => Object.hash(StoryAnyCondition, Object.hashAll(conditions));

  @override
  String toString() => 'StoryAnyCondition($conditions)';
}

/// Logical negation of exactly one child condition.
final class StoryNotCondition extends StoryCondition {
  const StoryNotCondition(this.condition);

  final StoryCondition condition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryNotCondition && other.condition == condition;

  @override
  int get hashCode => Object.hash(StoryNotCondition, condition);

  @override
  String toString() => 'StoryNotCondition($condition)';
}

/// Tests whether a declared scalar variable currently has a runtime value.
final class StoryVariableIsSetCondition extends StoryCondition {
  const StoryVariableIsSetCondition({required this.variableId});

  final StoryVariableId variableId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableIsSetCondition && other.variableId == variableId;

  @override
  int get hashCode => Object.hash(StoryVariableIsSetCondition, variableId);

  @override
  String toString() => 'StoryVariableIsSetCondition($variableId)';
}

/// Tests whether a declared scalar variable is intentionally/currently unset.
final class StoryVariableIsUnsetCondition extends StoryCondition {
  const StoryVariableIsUnsetCondition({required this.variableId});

  final StoryVariableId variableId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableIsUnsetCondition && other.variableId == variableId;

  @override
  int get hashCode => Object.hash(StoryVariableIsUnsetCondition, variableId);

  @override
  String toString() => 'StoryVariableIsUnsetCondition($variableId)';
}

/// Operators supported by scalar variable-to-literal comparisons.
enum StoryComparisonOperator {
  /// Values are equal.
  equal,

  /// Values are not equal.
  notEqual,

  /// Current value is strictly less than the comparison value.
  lessThan,

  /// Current value is less than or equal to the comparison value.
  lessThanOrEqual,

  /// Current value is strictly greater than the comparison value.
  greaterThan,

  /// Current value is greater than or equal to the comparison value.
  greaterThanOrEqual,
}

/// Compares one declared scalar variable against one portable literal value.
///
/// Stage 1E deliberately supports variable-to-literal comparisons only.
/// Variable-to-variable comparisons and richer operands can be added later if
/// a concrete narrative use case justifies them.
final class StoryVariableComparisonCondition extends StoryCondition {
  StoryVariableComparisonCondition({
    required this.variableId,
    required this.operator,
    required this.value,
  }) {
    if (_isOrderingOperator(operator) && !_supportsOrdering(value.type)) {
      throw ArgumentError.value(
        operator,
        'operator',
        'Ordering comparisons are supported only for integer and number '
            'story values. Boolean and string values support equality and '
            'inequality only.',
      );
    }
  }

  final StoryVariableId variableId;
  final StoryComparisonOperator operator;

  /// Literal comparison operand.
  final StoryValue value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableComparisonCondition &&
          other.variableId == variableId &&
          other.operator == operator &&
          other.value == value;

  @override
  int get hashCode => Object.hash(
    StoryVariableComparisonCondition,
    variableId,
    operator,
    value,
  );

  @override
  String toString() =>
      'StoryVariableComparisonCondition($variableId $operator $value)';
}

bool _isOrderingOperator(StoryComparisonOperator operator) => switch (operator) {
  StoryComparisonOperator.lessThan ||
  StoryComparisonOperator.lessThanOrEqual ||
  StoryComparisonOperator.greaterThan ||
  StoryComparisonOperator.greaterThanOrEqual => true,
  StoryComparisonOperator.equal || StoryComparisonOperator.notEqual => false,
};

bool _supportsOrdering(StoryValueType type) => switch (type) {
  StoryValueType.integer || StoryValueType.number => true,
  StoryValueType.boolean || StoryValueType.string => false,
};

bool _orderedConditionsEqual(
  List<StoryCondition> left,
  List<StoryCondition> right,
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
