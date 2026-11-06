import '../identity/story_event_id.dart';
import '../identity/story_variable_id.dart';
import '../state/story_value.dart';
import '../validation/story_diagnostic_location.dart';
import 'story_condition_explanation.dart';
import 'story_decision_explanation.dart';
import 'story_effect_explanation.dart';

/// Whether the operation's attempted execution survives its commit boundary.
enum StoryRuntimeExecutionOutcome { committed, rolledBack }

/// Event flow selected after availability and entry effects succeed.
enum StoryRuntimeEventFlow { choice, continuation, automatic }

/// One immutable causal record from the actual execution pass.
sealed class StoryRuntimeExplanationStep {
  const StoryRuntimeExplanationStep();
}

/// Completed evaluation of an incoming event's pre-entry availability.
final class StoryEventAvailabilityExplanation
    extends StoryRuntimeExplanationStep {
  const StoryEventAvailabilityExplanation({
    required this.eventId,
    required this.condition,
  });

  final StoryEventId eventId;
  final StoryConditionExplanation? condition;
  bool get available => condition?.result ?? true;
}

/// An event whose availability and entry effects completed successfully.
///
/// Entry remains attempted when the enclosing execution is rolled back.
final class StoryEventTraversalExplanation extends StoryRuntimeExplanationStep {
  const StoryEventTraversalExplanation({
    required this.eventId,
    required this.flow,
  });

  final StoryEventId eventId;
  final StoryRuntimeEventFlow flow;
}

/// Actual selected-choice availability, including a rejected selection.
final class StoryRuntimeChoiceExplanation extends StoryRuntimeExplanationStep {
  const StoryRuntimeChoiceExplanation(this.choice);
  final StoryChoiceExplanation choice;
}

/// An authored effect in the causal order in which it was attempted.
final class StoryRuntimeEffectExplanation extends StoryRuntimeExplanationStep {
  const StoryRuntimeEffectExplanation(this.effect);
  final StoryEffectExplanation effect;
}

/// Guard check before resolving one automatic transition.
final class StoryAutomaticTraversalExplanation
    extends StoryRuntimeExplanationStep {
  StoryAutomaticTraversalExplanation({
    required this.eventId,
    required this.transitionNumber,
    required this.maximumTransitions,
  }) {
    if (transitionNumber <= 0 || maximumTransitions <= 0) {
      throw ArgumentError('Automatic traversal counts must be positive.');
    }
  }

  final StoryEventId eventId;
  final int transitionNumber;
  final int maximumTransitions;
  bool get allowed => transitionNumber <= maximumTransitions;
}

/// One completed conditional branch evaluation at its nested authored location.
///
/// Only evaluated branches appear; an exception is never invented as false.
final class StoryTransitionBranchExplanation
    extends StoryRuntimeExplanationStep {
  const StoryTransitionBranchExplanation({
    required this.location,
    required this.condition,
  });

  final StoryDiagnosticLocation location;
  final StoryConditionExplanation condition;
}

/// First-match/fallback decision, emitted before descending into the winner.
final class StoryConditionalTransitionExplanation
    extends StoryRuntimeExplanationStep {
  StoryConditionalTransitionExplanation({
    required this.location,
    required this.authoredBranchCount,
    required this.selectedBranchIndex,
  }) {
    if (authoredBranchCount <= 0 ||
        (selectedBranchIndex != null &&
            (selectedBranchIndex! < 0 ||
                selectedBranchIndex! >= authoredBranchCount))) {
      throw ArgumentError('Conditional transition selection is out of range.');
    }
  }

  final StoryDiagnosticLocation location;
  final int authoredBranchCount;
  final int? selectedBranchIndex;
  bool get usedFallback => selectedBranchIndex == null;
  int get evaluatedBranchCount => selectedBranchIndex == null
      ? authoredBranchCount
      : selectedBranchIndex! + 1;
}

/// One real weighted draw and the interval that selected its authored option.
final class StoryWeightedTransitionExplanation
    extends StoryRuntimeExplanationStep {
  StoryWeightedTransitionExplanation({
    required this.location,
    required Iterable<int> weights,
    required this.sampledOffset,
    required this.selectedOptionIndex,
  }) : weights = List<int>.unmodifiable(weights) {
    if (this.weights.isEmpty ||
        this.weights.any((weight) => weight <= 0) ||
        selectedOptionIndex < 0 ||
        selectedOptionIndex >= this.weights.length) {
      throw ArgumentError('Invalid weighted transition options.');
    }
    var total = 0;
    for (final weight in this.weights) {
      if (total > StoryIntegerValue.maxPortableValue - weight) {
        throw ArgumentError('Weights exceed the portable exact-integer range.');
      }
      total += weight;
    }
    final lower = this.weights
        .take(selectedOptionIndex)
        .fold(0, (a, b) => a + b);
    if (sampledOffset < lower ||
        sampledOffset >= lower + this.weights[selectedOptionIndex]) {
      throw ArgumentError(
        'Sample does not select the recorded weighted option.',
      );
    }
  }

  final StoryDiagnosticLocation location;
  final List<int> weights;
  final int sampledOffset;
  final int selectedOptionIndex;
  int get totalWeight => weights.fold(0, (a, b) => a + b);
}

/// Resolved direct destination at the selected nested transition location.
final class StoryEventTransitionExplanation
    extends StoryRuntimeExplanationStep {
  const StoryEventTransitionExplanation({
    required this.location,
    required this.destinationEventId,
  });
  final StoryDiagnosticLocation location;
  final StoryEventId destinationEventId;
}

/// Explicit terminal outcome at the selected nested transition location.
final class StoryTerminalTransitionExplanation
    extends StoryRuntimeExplanationStep {
  const StoryTerminalTransitionExplanation({required this.location});
  final StoryDiagnosticLocation location;
}

/// Ordered attempted execution, separate from persisted committed history.
///
/// An incomplete operation retains its completed causal prefix. It contains no
/// engine/state/RNG references and is never restored or replayed from a save.
final class StoryRuntimeExecutionExplanation {
  StoryRuntimeExecutionExplanation({
    required this.operation,
    required this.outcome,
    required Iterable<StoryRuntimeExplanationStep> steps,
  }) : steps = List<StoryRuntimeExplanationStep>.unmodifiable(
         outcome == StoryRuntimeExecutionOutcome.rolledBack
             ? _rolledBackSteps(steps)
             : steps,
       ) {
    if (operation.isEmpty) {
      throw ArgumentError('An execution explanation requires an operation.');
    }
    if (outcome == StoryRuntimeExecutionOutcome.committed &&
        this.steps.any(
          (step) => switch (step) {
            StoryRuntimeEffectExplanation(:final effect) =>
              effect.outcome == StoryEffectOutcome.rejected ||
                  effect.outcome == StoryEffectOutcome.rolledBack,
            StoryEventAvailabilityExplanation() => !step.available,
            StoryRuntimeChoiceExplanation(:final choice) => !choice.available,
            StoryAutomaticTraversalExplanation() => !step.allowed,
            _ => false,
          },
        )) {
      throw ArgumentError(
        'A committed execution cannot contain a failed step.',
      );
    }
  }

  final String operation;
  final StoryRuntimeExecutionOutcome outcome;
  final List<StoryRuntimeExplanationStep> steps;

  List<StoryEffectExplanation> get effects =>
      List<StoryEffectExplanation>.unmodifiable(
        steps.whereType<StoryRuntimeEffectExplanation>().map(
          (step) => step.effect,
        ),
      );

  /// Reclassifies attempts when a later aggregate commit cannot survive.
  StoryRuntimeExecutionExplanation asRolledBack() =>
      StoryRuntimeExecutionExplanation(
        operation: operation,
        outcome: StoryRuntimeExecutionOutcome.rolledBack,
        steps: steps,
      );
}

/// Net committed change to one shared variable, including set/unset values.
final class StoryPersistentVariableChange {
  StoryPersistentVariableChange({
    required this.variableId,
    required this.beforeValue,
    required this.afterValue,
  }) {
    if (beforeValue == afterValue) {
      throw ArgumentError('A committed delta must change the value.');
    }
  }
  final StoryVariableId variableId;
  final StoryValue? beforeValue;
  final StoryValue? afterValue;
}

/// One successful shared-state revision and the sibling views updated with it.
///
/// Deltas are in schema order; sibling indexes are in active-session order.
/// No notification is emitted for unchanged state or a failed aggregate commit.
final class StoryPersistentStateCommitExplanation {
  StoryPersistentStateCommitExplanation({
    required this.sourceSessionIndex,
    required this.previousRevision,
    required this.revision,
    required Iterable<StoryPersistentVariableChange> changes,
    required Iterable<int> propagatedSessionIndexes,
  }) : changes = List<StoryPersistentVariableChange>.unmodifiable(changes),
       propagatedSessionIndexes = List<int>.unmodifiable(
         propagatedSessionIndexes,
       ) {
    if (sourceSessionIndex < 0 ||
        previousRevision < 0 ||
        revision != previousRevision + 1 ||
        this.changes.isEmpty ||
        this.changes.map((change) => change.variableId).toSet().length !=
            this.changes.length ||
        this.propagatedSessionIndexes.any(
          (index) => index < 0 || index == sourceSessionIndex,
        ) ||
        this.propagatedSessionIndexes.toSet().length !=
            this.propagatedSessionIndexes.length) {
      throw ArgumentError('Invalid shared-state commit explanation.');
    }
  }
  final int sourceSessionIndex;
  final int previousRevision;
  final int revision;
  final List<StoryPersistentVariableChange> changes;
  final List<int> propagatedSessionIndexes;
}

Iterable<StoryRuntimeExplanationStep> _rolledBackSteps(
  Iterable<StoryRuntimeExplanationStep> steps,
) => steps.map((step) {
  if (step is! StoryRuntimeEffectExplanation) {
    return step;
  }
  final effect = step.effect;
  if (effect.outcome == StoryEffectOutcome.rejected ||
      effect.outcome == StoryEffectOutcome.rolledBack) {
    return step;
  }
  return StoryRuntimeEffectExplanation(
    StoryEffectExplanation(
      source: effect.source,
      authoredIndex: effect.authoredIndex,
      variableId: effect.variableId,
      operation: effect.operation,
      operand: effect.operand,
      beforeValue: effect.beforeValue,
      afterValue: effect.afterValue,
      outcome: StoryEffectOutcome.rolledBack,
    ),
  );
});
