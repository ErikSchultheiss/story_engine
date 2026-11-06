import '../identity/story_variable_id.dart';
import '../state/story_value.dart';

/// Declarative description of a state change requested by authored story data.
///
/// Effects are data, not executable callbacks. They do not own navigation and
/// cannot perform arbitrary host application work. Stage 1F supports only
/// scalar story-state effects; richer domain effects and declared host actions
/// are deliberately deferred.
sealed class StoryEffect {
  const StoryEffect();
}

/// Replaces the current value of one declared scalar story variable.
final class StorySetVariableEffect extends StoryEffect {
  const StorySetVariableEffect({required this.variableId, required this.value});

  /// Variable whose current runtime value should be replaced.
  final StoryVariableId variableId;

  /// New scalar value.
  ///
  /// Compatibility with the variable's authored declaration is checked during
  /// effect execution, because the effect itself deliberately does not own or
  /// depend on a specific project schema.
  final StoryValue value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorySetVariableEffect &&
          other.variableId == variableId &&
          other.value == value;

  @override
  int get hashCode => Object.hash(StorySetVariableEffect, variableId, value);

  @override
  String toString() => 'StorySetVariableEffect($variableId = $value)';
}

/// Removes the current value of one declared scalar variable, leaving it unset.
final class StoryUnsetVariableEffect extends StoryEffect {
  const StoryUnsetVariableEffect({required this.variableId});

  final StoryVariableId variableId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryUnsetVariableEffect && other.variableId == variableId;

  @override
  int get hashCode => Object.hash(StoryUnsetVariableEffect, variableId);

  @override
  String toString() => 'StoryUnsetVariableEffect($variableId)';
}

/// Adds a non-negative numeric [amount] to a currently set numeric variable.
///
/// Integer variables require an integer amount and Number variables require a
/// Number amount. There is deliberately no numeric type coercion.
final class StoryIncrementVariableEffect extends StoryEffect {
  StoryIncrementVariableEffect({
    required this.variableId,
    required StoryValue amount,
  }) : amount = _validateNonNegativeNumericAmount(amount);

  final StoryVariableId variableId;

  /// Non-negative Integer or Number amount to add.
  final StoryValue amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryIncrementVariableEffect &&
          other.variableId == variableId &&
          other.amount == amount;

  @override
  int get hashCode =>
      Object.hash(StoryIncrementVariableEffect, variableId, amount);

  @override
  String toString() => 'StoryIncrementVariableEffect($variableId + $amount)';
}

/// Subtracts a non-negative numeric [amount] from a currently set variable.
///
/// Integer variables require an integer amount and Number variables require a
/// Number amount. There is deliberately no numeric type coercion.
final class StoryDecrementVariableEffect extends StoryEffect {
  StoryDecrementVariableEffect({
    required this.variableId,
    required StoryValue amount,
  }) : amount = _validateNonNegativeNumericAmount(amount);

  final StoryVariableId variableId;

  /// Non-negative Integer or Number amount to subtract.
  final StoryValue amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryDecrementVariableEffect &&
          other.variableId == variableId &&
          other.amount == amount;

  @override
  int get hashCode =>
      Object.hash(StoryDecrementVariableEffect, variableId, amount);

  @override
  String toString() => 'StoryDecrementVariableEffect($variableId - $amount)';
}

StoryValue _validateNonNegativeNumericAmount(StoryValue amount) {
  if (amount is StoryIntegerValue) {
    if (amount.value < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Numeric effect amounts must be non-negative. Use the opposite effect '
            'to express the opposite direction.',
      );
    }
    return amount;
  }

  if (amount is StoryNumberValue) {
    if (amount.value < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Numeric effect amounts must be non-negative. Use the opposite effect '
            'to express the opposite direction.',
      );
    }
    return amount;
  }

  throw ArgumentError.value(
    amount,
    'amount',
    'Increment/decrement effects require an Integer or Number amount.',
  );
}
