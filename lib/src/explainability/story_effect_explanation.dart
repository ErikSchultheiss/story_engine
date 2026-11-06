import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_variable_id.dart';
import '../state/story_value.dart';

/// Authored scalar operation represented by one effect explanation.
enum StoryEffectOperation { set, unset, increment, decrement }

/// Transactional disposition of an explained authored effect.
enum StoryEffectOutcome {
  /// The transaction committed and the effect changed the variable value.
  committed,

  /// The transaction committed but the effect did not change the value.
  noOp,

  /// The effect itself failed before the enclosing transaction could commit.
  rejected,

  /// The effect executed in a transaction whose later failure prevented commit.
  rolledBack,
}

/// Authored list that owns an effect.
enum StoryEffectOwnerKind { eventEntry, choice }

/// Stable authored location for an explained effect list.
final class StoryEffectSource {
  const StoryEffectSource.eventEntry({required this.eventId}) : choiceId = null;

  const StoryEffectSource.choice({
    required this.eventId,
    required this.choiceId,
  });

  final StoryEventId eventId;
  final StoryChoiceId? choiceId;

  StoryEffectOwnerKind get kind => choiceId == null
      ? StoryEffectOwnerKind.eventEntry
      : StoryEffectOwnerKind.choice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEffectSource &&
          other.eventId == eventId &&
          other.choiceId == choiceId;

  @override
  int get hashCode => Object.hash(StoryEffectSource, eventId, choiceId);

  @override
  String toString() =>
      'StoryEffectSource(${kind.name}, event: $eventId, choice: $choiceId)';
}

/// Structured before/operation/after record for one authored scalar effect.
///
/// [afterValue] is the value produced by the effect attempt, not necessarily a
/// committed value. [outcome] distinguishes committed/no-op changes from
/// rejected or transactionally rolled-back attempts.
final class StoryEffectExplanation {
  StoryEffectExplanation({
    required this.source,
    required this.authoredIndex,
    required this.variableId,
    required this.operation,
    this.operand,
    required this.beforeValue,
    required this.afterValue,
    required this.outcome,
  }) {
    if (authoredIndex < 0) {
      throw ArgumentError.value(
        authoredIndex,
        'authoredIndex',
        'Authored effect index cannot be negative.',
      );
    }

    final needsOperand = operation != StoryEffectOperation.unset;
    if (needsOperand != (operand != null)) {
      throw ArgumentError.value(
        operand,
        'operand',
        '${operation.name} effect explanations '
            '${needsOperand ? 'require' : 'must not contain'} an operand.',
      );
    }

    if (operation == StoryEffectOperation.increment ||
        operation == StoryEffectOperation.decrement) {
      final numericOperand = operand;
      if (numericOperand is! StoryIntegerValue &&
          numericOperand is! StoryNumberValue) {
        throw ArgumentError.value(
          numericOperand,
          'operand',
          'Increment/decrement explanations require a numeric StoryValue '
              'operand.',
        );
      }
      if ((numericOperand is StoryIntegerValue && numericOperand.value < 0) ||
          (numericOperand is StoryNumberValue && numericOperand.value < 0)) {
        throw ArgumentError.value(
          numericOperand,
          'operand',
          'Increment/decrement explanation amounts must be non-negative.',
        );
      }
    }

    if (outcome != StoryEffectOutcome.rejected) {
      _validateSuccessfulEffectShape(
        operation: operation,
        operand: operand,
        beforeValue: beforeValue,
        afterValue: afterValue,
      );
    }

    if (outcome == StoryEffectOutcome.noOp && beforeValue != afterValue) {
      throw ArgumentError(
        'A no-op effect explanation must have identical before/after values.',
      );
    }
    if (outcome == StoryEffectOutcome.committed && beforeValue == afterValue) {
      throw ArgumentError(
        'A committed-delta effect explanation must change the variable value; '
        'use StoryEffectOutcome.noOp otherwise.',
      );
    }
  }

  final StoryEffectSource source;

  /// Zero-based index in the owning event-entry or choice effect list.
  final int authoredIndex;

  final StoryVariableId variableId;
  final StoryEffectOperation operation;

  /// Set value or numeric adjustment amount; null only for `unset`.
  final StoryValue? operand;

  /// Value observed immediately before this authored effect, or null if unset.
  final StoryValue? beforeValue;

  /// Value produced by this effect attempt, or null when unset/no value exists.
  final StoryValue? afterValue;

  final StoryEffectOutcome outcome;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEffectExplanation &&
          other.source == source &&
          other.authoredIndex == authoredIndex &&
          other.variableId == variableId &&
          other.operation == operation &&
          other.operand == operand &&
          other.beforeValue == beforeValue &&
          other.afterValue == afterValue &&
          other.outcome == outcome;

  @override
  int get hashCode => Object.hash(
    StoryEffectExplanation,
    source,
    authoredIndex,
    variableId,
    operation,
    operand,
    beforeValue,
    afterValue,
    outcome,
  );

  @override
  String toString() =>
      'StoryEffectExplanation(${source.kind.name}[$authoredIndex], '
      '$variableId ${operation.name}, outcome: ${outcome.name})';
}

void _validateSuccessfulEffectShape({
  required StoryEffectOperation operation,
  required StoryValue? operand,
  required StoryValue? beforeValue,
  required StoryValue? afterValue,
}) {
  switch (operation) {
    case StoryEffectOperation.set:
      if (afterValue != operand) {
        throw ArgumentError(
          'A successful set explanation must produce its operand as afterValue.',
        );
      }
      return;
    case StoryEffectOperation.unset:
      if (afterValue != null) {
        throw ArgumentError(
          'A successful unset explanation must leave the variable unset.',
        );
      }
      return;
    case StoryEffectOperation.increment:
    case StoryEffectOperation.decrement:
      final amount = operand!;
      final before = beforeValue;
      final after = afterValue;
      if (before == null || after == null) {
        throw ArgumentError(
          'A successful numeric adjustment requires set before/after values.',
        );
      }
      if (before.type != amount.type || after.type != amount.type) {
        throw ArgumentError(
          'Numeric adjustment before/operand/after values must share one '
          'StoryValue type.',
        );
      }
      if (before is StoryIntegerValue &&
          amount is StoryIntegerValue &&
          after is StoryIntegerValue) {
        _validateIntegerAdjustmentResult(operation, before, amount, after);
        return;
      }
      if (before is StoryNumberValue &&
          amount is StoryNumberValue &&
          after is StoryNumberValue) {
        _validateNumberAdjustmentResult(operation, before, amount, after);
        return;
      }
      throw ArgumentError(
        'Numeric adjustment explanation values use incompatible numeric types.',
      );
  }
}

void _validateIntegerAdjustmentResult(
  StoryEffectOperation operation,
  StoryIntegerValue before,
  StoryIntegerValue amount,
  StoryIntegerValue after,
) {
  final expected = operation == StoryEffectOperation.increment
      ? before.value + amount.value
      : before.value - amount.value;
  if (expected < StoryIntegerValue.minPortableValue ||
      expected > StoryIntegerValue.maxPortableValue ||
      after.value != expected) {
    throw ArgumentError(
      'Numeric adjustment afterValue must equal the authored operation '
      'applied to beforeValue.',
    );
  }
}

void _validateNumberAdjustmentResult(
  StoryEffectOperation operation,
  StoryNumberValue before,
  StoryNumberValue amount,
  StoryNumberValue after,
) {
  final expected = operation == StoryEffectOperation.increment
      ? before.value + amount.value
      : before.value - amount.value;
  if (!expected.isFinite || after.value != expected) {
    throw ArgumentError(
      'Numeric adjustment afterValue must equal the authored operation '
      'applied to beforeValue.',
    );
  }
}
