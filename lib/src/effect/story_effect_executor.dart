import '../explainability/story_effect_explanation.dart';
import '../identity/story_variable_id.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';
import '../state/story_value_type.dart';
import 'story_effect.dart';

/// Package-internal executor for declarative scalar effects.
///
/// This type is intentionally not exported from `package:story_engine/`.
/// Public callers can author [StoryEffect] values and observe immutable
/// [StoryState] snapshots, but state evolution remains an engine responsibility.
final class StoryEffectExecutor {
  const StoryEffectExecutor();

  /// Applies one [effect] and returns a new immutable state snapshot.
  ///
  /// Malformed or schema-incompatible authored logic throws
  /// [StoryEffectExecutionException]. The input [state] is never mutated.
  StoryState apply(StoryEffect effect, StoryState state) => switch (effect) {
    StorySetVariableEffect effect => _applySet(effect, state),
    StoryUnsetVariableEffect effect => _applyUnset(effect, state),
    StoryIncrementVariableEffect effect => _applyIncrement(effect, state),
    StoryDecrementVariableEffect effect => _applyDecrement(effect, state),
  };

  /// Applies [effects] sequentially in authored order.
  ///
  /// Because every step creates an immutable state snapshot, the caller's
  /// original [state] remains unchanged even if a later effect fails. Stage 1F
  /// contains no external side effects, so a failed batch exposes no partial
  /// state result to the caller.
  StoryState applyAll(Iterable<StoryEffect> effects, StoryState state) {
    var next = state;
    for (final effect in effects) {
      next = apply(effect, next);
    }
    return next;
  }

  /// Applies [effects] while recording the actual authored effect attempts.
  ///
  /// This package-internal diagnostic path executes each effect exactly once.
  /// Successful attempts are initially recorded as committed/no-op outcomes.
  /// If a later effect in this batch fails, earlier successful attempts from
  /// this batch are rewritten as rolled back and the failing effect is recorded
  /// as rejected before the original [StoryEffectExecutionException] is
  /// rethrown. Higher-level runtime transactions may likewise reclassify
  /// successful attempts as rolled back when a later transition/event step
  /// prevents the enclosing transaction from committing.
  StoryState applyAllWithExplanations({
    required Iterable<StoryEffect> effects,
    required StoryState state,
    required StoryEffectSource source,
    required List<StoryEffectExplanation> explanations,
  }) {
    final batchStartIndex = explanations.length;
    var next = state;
    var authoredIndex = 0;

    for (final effect in effects) {
      final variableId = _variableIdOf(effect);
      final beforeValue = next.values[variableId];
      try {
        final afterState = apply(effect, next);
        final afterValue = afterState.values[variableId];
        explanations.add(
          StoryEffectExplanation(
            source: source,
            authoredIndex: authoredIndex,
            variableId: variableId,
            operation: _operationOf(effect),
            operand: _operandOf(effect),
            beforeValue: beforeValue,
            afterValue: afterValue,
            outcome: beforeValue == afterValue
                ? StoryEffectOutcome.noOp
                : StoryEffectOutcome.committed,
          ),
        );
        next = afterState;
      } on StoryEffectExecutionException {
        explanations.add(
          StoryEffectExplanation(
            source: source,
            authoredIndex: authoredIndex,
            variableId: variableId,
            operation: _operationOf(effect),
            operand: _operandOf(effect),
            beforeValue: beforeValue,
            afterValue: null,
            outcome: StoryEffectOutcome.rejected,
          ),
        );
        _markRolledBack(
          explanations,
          startIndex: batchStartIndex,
          endExclusive: explanations.length - 1,
        );
        rethrow;
      }
      authoredIndex++;
    }

    return next;
  }

  StoryState _applySet(StorySetVariableEffect effect, StoryState state) {
    final definition = state.schema.definitionFor(effect.variableId);
    if (definition == null) {
      throw _failure(
        effect,
        'Set effect references an undeclared story variable: '
        '${effect.variableId}.',
      );
    }

    if (definition.type != effect.value.type) {
      throw _failure(
        effect,
        'Set value type ${effect.value.type.name} does not match declared '
        'variable type ${definition.type.name} for ${effect.variableId}.',
      );
    }

    return StoryStateMutation.set(state, effect.variableId, effect.value);
  }

  StoryState _applyUnset(StoryUnsetVariableEffect effect, StoryState state) {
    if (!state.schema.contains(effect.variableId)) {
      throw _failure(
        effect,
        'Unset effect references an undeclared story variable: '
        '${effect.variableId}.',
      );
    }

    return StoryStateMutation.unset(state, effect.variableId);
  }

  StoryState _applyIncrement(
    StoryIncrementVariableEffect effect,
    StoryState state,
  ) => _applyNumericAdjustment(
    effect: effect,
    variableId: effect.variableId,
    amount: effect.amount,
    state: state,
    subtract: false,
  );

  StoryState _applyDecrement(
    StoryDecrementVariableEffect effect,
    StoryState state,
  ) => _applyNumericAdjustment(
    effect: effect,
    variableId: effect.variableId,
    amount: effect.amount,
    state: state,
    subtract: true,
  );

  StoryState _applyNumericAdjustment({
    required StoryEffect effect,
    required StoryVariableId variableId,
    required StoryValue amount,
    required StoryState state,
    required bool subtract,
  }) {
    final definition = state.schema.definitionFor(variableId);
    if (definition == null) {
      throw _failure(
        effect,
        'Numeric effect references an undeclared story variable: $variableId.',
      );
    }

    if (definition.type != StoryValueType.integer &&
        definition.type != StoryValueType.number) {
      throw _failure(
        effect,
        'Numeric adjustment requires an Integer or Number variable, but '
        '$variableId is declared as ${definition.type.name}.',
      );
    }

    if (definition.type != amount.type) {
      throw _failure(
        effect,
        'Numeric amount type ${amount.type.name} does not match declared '
        'variable type ${definition.type.name} for $variableId.',
      );
    }

    final current = state.valueOf(variableId);
    if (current == null) {
      throw _failure(
        effect,
        'Cannot adjust unset story variable $variableId. Set it explicitly '
        'before incrementing or decrementing it.',
      );
    }

    try {
      final nextValue = _adjustValue(
        current: current,
        amount: amount,
        subtract: subtract,
      );
      return StoryStateMutation.set(state, variableId, nextValue);
    } on ArgumentError catch (error) {
      throw StoryEffectExecutionException(
        effect: effect,
        message:
            'Numeric adjustment for $variableId would produce a value '
            'outside the portable StoryValue domain.',
        cause: error,
      );
    }
  }

  StoryValue _adjustValue({
    required StoryValue current,
    required StoryValue amount,
    required bool subtract,
  }) {
    if (current is StoryIntegerValue && amount is StoryIntegerValue) {
      final next = subtract
          ? current.value - amount.value
          : current.value + amount.value;
      return StoryIntegerValue(next);
    }

    if (current is StoryNumberValue && amount is StoryNumberValue) {
      final next = subtract
          ? current.value - amount.value
          : current.value + amount.value;
      return StoryNumberValue(next);
    }

    // The schema/type checks above should make this unreachable. Keeping an
    // explicit failure protects the executor if the value hierarchy evolves.
    throw StateError(
      'Numeric adjustment reached incompatible runtime value types: '
      '${current.runtimeType} and ${amount.runtimeType}.',
    );
  }

  StoryEffectExecutionException _failure(StoryEffect effect, String message) =>
      StoryEffectExecutionException(effect: effect, message: message);
}

StoryVariableId _variableIdOf(StoryEffect effect) => switch (effect) {
  StorySetVariableEffect(:final variableId) => variableId,
  StoryUnsetVariableEffect(:final variableId) => variableId,
  StoryIncrementVariableEffect(:final variableId) => variableId,
  StoryDecrementVariableEffect(:final variableId) => variableId,
};

StoryEffectOperation _operationOf(StoryEffect effect) => switch (effect) {
  StorySetVariableEffect() => StoryEffectOperation.set,
  StoryUnsetVariableEffect() => StoryEffectOperation.unset,
  StoryIncrementVariableEffect() => StoryEffectOperation.increment,
  StoryDecrementVariableEffect() => StoryEffectOperation.decrement,
};

StoryValue? _operandOf(StoryEffect effect) => switch (effect) {
  StorySetVariableEffect(:final value) => value,
  StoryUnsetVariableEffect() => null,
  StoryIncrementVariableEffect(:final amount) => amount,
  StoryDecrementVariableEffect(:final amount) => amount,
};

void _markRolledBack(
  List<StoryEffectExplanation> explanations, {
  required int startIndex,
  required int endExclusive,
}) {
  for (var index = startIndex; index < endExclusive; index++) {
    final explanation = explanations[index];
    if (explanation.outcome == StoryEffectOutcome.rejected ||
        explanation.outcome == StoryEffectOutcome.rolledBack) {
      continue;
    }
    explanations[index] = StoryEffectExplanation(
      source: explanation.source,
      authoredIndex: explanation.authoredIndex,
      variableId: explanation.variableId,
      operation: explanation.operation,
      operand: explanation.operand,
      beforeValue: explanation.beforeValue,
      afterValue: explanation.afterValue,
      outcome: StoryEffectOutcome.rolledBack,
    );
  }
}

/// Signals malformed or schema-incompatible authored effect logic.
///
/// This is intentionally distinct from ordinary successful effect execution.
/// A later validation stage should normally identify these problems before a
/// production runtime reaches them.
final class StoryEffectExecutionException implements Exception {
  const StoryEffectExecutionException({
    required this.effect,
    required this.message,
    this.cause,
  });

  final StoryEffect effect;
  final String message;
  final Object? cause;

  @override
  String toString() => 'StoryEffectExecutionException: $message';
}
