import '../condition/story_condition_context.dart';
import '../condition/story_condition_evaluator.dart';
import '../identity/story_event_id.dart';
import 'story_transition.dart';

/// Package-internal source of deterministic runtime random selections.
///
/// The eventual StoryEngine owns the concrete seeded/stateful implementation.
/// Transition declarations never instantiate or hide random-number generators.
abstract interface class StoryRandomSource {
  /// Returns one integer in the range `0 <= value < maxExclusive`.
  int nextInt(int maxExclusive);
}

/// Package-internal resolver for declarative transition trees.
///
/// It is intentionally not exported from `package:story_engine/`. Public
/// callers author [StoryTransition] data; the future runtime resolves it using
/// its own condition context and controlled RNG state.
final class StoryTransitionResolver {
  const StoryTransitionResolver({
    this.conditionEvaluator = const StoryConditionEvaluator(),
  });

  final StoryConditionEvaluator conditionEvaluator;

  /// Resolves [transition] to one concrete event destination or termination.
  ///
  /// Conditional transitions are first-match in authored order. Weighted
  /// transitions consume exactly one RNG draw for each weighted transition
  /// encountered along the selected path.
  StoryTransitionResolution resolve({
    required StoryTransition transition,
    required StoryConditionContext context,
    required StoryRandomSource randomSource,
  }) => switch (transition) {
    StoryEventTransition transition => StoryEventTransitionResolution(
      destinationEventId: transition.destinationEventId,
    ),
    StoryTerminalTransition _ => const StoryTerminalTransitionResolution(),
    StoryConditionalTransition transition => _resolveConditional(
      transition: transition,
      context: context,
      randomSource: randomSource,
    ),
    StoryWeightedTransition transition => _resolveWeighted(
      transition: transition,
      context: context,
      randomSource: randomSource,
    ),
  };

  StoryTransitionResolution _resolveConditional({
    required StoryConditionalTransition transition,
    required StoryConditionContext context,
    required StoryRandomSource randomSource,
  }) {
    for (final branch in transition.branches) {
      if (conditionEvaluator.evaluate(branch.condition, context)) {
        return resolve(
          transition: branch.transition,
          context: context,
          randomSource: randomSource,
        );
      }
    }

    return resolve(
      transition: transition.fallback,
      context: context,
      randomSource: randomSource,
    );
  }

  StoryTransitionResolution _resolveWeighted({
    required StoryWeightedTransition transition,
    required StoryConditionContext context,
    required StoryRandomSource randomSource,
  }) {
    final sampled = randomSource.nextInt(transition.totalWeight);
    if (sampled < 0 || sampled >= transition.totalWeight) {
      throw StoryTransitionResolutionException(
        transition: transition,
        message: 'Random source returned $sampled for an exclusive upper '
            'bound of ${transition.totalWeight}.',
      );
    }

    var upperExclusive = 0;
    for (final option in transition.options) {
      upperExclusive += option.weight;
      if (sampled < upperExclusive) {
        return resolve(
          transition: option.transition,
          context: context,
          randomSource: randomSource,
        );
      }
    }

    // Constructor validation plus the sampled range check make this
    // unreachable. Keep an explicit failure in case the model evolves.
    throw StoryTransitionResolutionException(
      transition: transition,
      message: 'Weighted transition could not map a valid sampled value to '
          'an authored option.',
    );
  }
}

/// Internal concrete result after all authored transition logic is resolved.
sealed class StoryTransitionResolution {
  const StoryTransitionResolution();
}

/// Concrete destination selected by transition resolution.
final class StoryEventTransitionResolution extends StoryTransitionResolution {
  const StoryEventTransitionResolution({required this.destinationEventId});

  final StoryEventId destinationEventId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEventTransitionResolution &&
          other.destinationEventId == destinationEventId;

  @override
  int get hashCode => Object.hash(
    StoryEventTransitionResolution,
    destinationEventId,
  );
}

/// Concrete terminal result selected by transition resolution.
final class StoryTerminalTransitionResolution extends StoryTransitionResolution {
  const StoryTerminalTransitionResolution();

  @override
  bool operator ==(Object other) => other is StoryTerminalTransitionResolution;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Signals an invalid transition-resolution runtime invariant.
///
/// Authored condition failures retain their more specific
/// `StoryConditionEvaluationException`; this exception covers transition/RNG
/// resolution invariants rather than collapsing all failures into one type.
final class StoryTransitionResolutionException implements Exception {
  const StoryTransitionResolutionException({
    required this.transition,
    required this.message,
  });

  final StoryTransition transition;
  final String message;

  @override
  String toString() => 'StoryTransitionResolutionException: $message';
}
