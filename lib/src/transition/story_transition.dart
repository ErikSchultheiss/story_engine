import '../condition/story_condition.dart';
import '../identity/story_event_id.dart';

/// Declarative control-flow decision produced by authored story data.
///
/// Transitions own navigation. They do not mutate story state and they do not
/// execute arbitrary application code. Stage 1G supports direct event
/// destinations, ordered conditional alternatives, weighted alternatives, and
/// explicit terminal outcomes.
sealed class StoryTransition {
  const StoryTransition();
}

/// Navigates directly to one authored event identity.
final class StoryEventTransition extends StoryTransition {
  const StoryEventTransition({required this.destinationEventId});

  /// Stable machine identity of the destination event.
  final StoryEventId destinationEventId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEventTransition &&
          other.destinationEventId == destinationEventId;

  @override
  int get hashCode => Object.hash(StoryEventTransition, destinationEventId);

  @override
  String toString() => 'StoryEventTransition($destinationEventId)';
}

/// One ordered condition/transition alternative in a conditional transition.
final class StoryConditionalTransitionBranch {
  const StoryConditionalTransitionBranch({
    required this.condition,
    required this.transition,
  });

  /// Predicate that must be true for this branch to be selected.
  final StoryCondition condition;

  /// Transition resolved when [condition] is the first matching branch.
  final StoryTransition transition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryConditionalTransitionBranch &&
          other.condition == condition &&
          other.transition == transition;

  @override
  int get hashCode => Object.hash(
    StoryConditionalTransitionBranch,
    condition,
    transition,
  );

  @override
  String toString() =>
      'StoryConditionalTransitionBranch($condition -> $transition)';
}

/// Resolves the first true branch in authored order, otherwise [fallback].
///
/// A fallback is mandatory. This keeps an executed conditional transition
/// total: valid authored data always describes what happens when no condition
/// matches instead of creating an implicit runtime dead end.
final class StoryConditionalTransition extends StoryTransition {
  factory StoryConditionalTransition({
    required Iterable<StoryConditionalTransitionBranch> branches,
    required StoryTransition fallback,
  }) {
    final copied = List<StoryConditionalTransitionBranch>.unmodifiable(
      branches,
    );
    if (copied.isEmpty) {
      throw ArgumentError.value(
        branches,
        'branches',
        'StoryConditionalTransition requires at least one conditional branch. '
            'Use the fallback transition directly when no conditions exist.',
      );
    }
    return StoryConditionalTransition._(
      branches: copied,
      fallback: fallback,
    );
  }

  const StoryConditionalTransition._({
    required this.branches,
    required this.fallback,
  });

  /// Conditional alternatives in deterministic authored order.
  final List<StoryConditionalTransitionBranch> branches;

  /// Explicit transition used when every branch condition is false.
  final StoryTransition fallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryConditionalTransition &&
          _orderedBranchesEqual(branches, other.branches) &&
          other.fallback == fallback;

  @override
  int get hashCode => Object.hash(
    StoryConditionalTransition,
    Object.hashAll(branches),
    fallback,
  );

  @override
  String toString() =>
      'StoryConditionalTransition(branches: $branches, fallback: $fallback)';
}

/// One weighted alternative in a [StoryWeightedTransition].
///
/// Weights are positive integers rather than floating-point probabilities.
/// Relative magnitude determines probability: weights 1 and 3 represent a
/// 25%/75% split without storing authored floating-point probability data.
final class StoryWeightedTransitionOption {
  StoryWeightedTransitionOption({
    required this.weight,
    required this.transition,
  }) {
    if (weight <= 0) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Weighted transition options require a positive integer weight.',
      );
    }
    if (weight > StoryWeightedTransition.maxPortableTotalWeight) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Weight exceeds the portable deterministic integer range.',
      );
    }
  }

  /// Positive relative selection weight.
  final int weight;

  /// Transition selected when this option owns the sampled interval.
  final StoryTransition transition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryWeightedTransitionOption &&
          other.weight == weight &&
          other.transition == transition;

  @override
  int get hashCode => Object.hash(
    StoryWeightedTransitionOption,
    weight,
    transition,
  );

  @override
  String toString() =>
      'StoryWeightedTransitionOption(weight: $weight, $transition)';
}

/// Selects one transition by positive integer relative weight.
///
/// Authored data contains weights only. Random-number generation is an engine
/// runtime responsibility and is deliberately absent from this public model.
final class StoryWeightedTransition extends StoryTransition {
  factory StoryWeightedTransition({
    required Iterable<StoryWeightedTransitionOption> options,
  }) {
    final copied = List<StoryWeightedTransitionOption>.unmodifiable(options);
    if (copied.isEmpty) {
      throw ArgumentError.value(
        options,
        'options',
        'StoryWeightedTransition requires at least one option.',
      );
    }

    var total = 0;
    for (final option in copied) {
      // Check before addition so the calculation itself never leaves the
      // portable exact-integer range when compiled for web.
      if (total > maxPortableTotalWeight - option.weight) {
        throw ArgumentError.value(
          options,
          'options',
          'Combined weighted-transition total exceeds the portable '
              'deterministic integer range.',
        );
      }
      total += option.weight;
    }

    return StoryWeightedTransition._(
      options: copied,
      totalWeight: total,
    );
  }

  const StoryWeightedTransition._({
    required this.options,
    required this.totalWeight,
  });

  /// Largest exact integer total accepted on every intended Dart target,
  /// including JavaScript-based web runtimes.
  static const int maxPortableTotalWeight = 9007199254740991;

  /// Weighted alternatives in deterministic authored order.
  final List<StoryWeightedTransitionOption> options;

  /// Prevalidated sum of all positive option weights.
  final int totalWeight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryWeightedTransition &&
          _orderedOptionsEqual(options, other.options);

  @override
  int get hashCode => Object.hash(
    StoryWeightedTransition,
    Object.hashAll(options),
  );

  @override
  String toString() => 'StoryWeightedTransition($options)';
}

/// Explicitly ends control flow without selecting another event.
///
/// Stage 1G intentionally does not attach ending IDs, achievements, labels, or
/// presentation metadata. Rich ending/outcome domains can be layered on later
/// without making ordinary runtime termination implicit.
final class StoryTerminalTransition extends StoryTransition {
  const StoryTerminalTransition();

  @override
  bool operator ==(Object other) => other is StoryTerminalTransition;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'StoryTerminalTransition()';
}

bool _orderedBranchesEqual(
  List<StoryConditionalTransitionBranch> left,
  List<StoryConditionalTransitionBranch> right,
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

bool _orderedOptionsEqual(
  List<StoryWeightedTransitionOption> left,
  List<StoryWeightedTransitionOption> right,
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
