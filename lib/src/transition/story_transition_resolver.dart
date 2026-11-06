import '../condition/story_condition_context.dart';
import '../condition/story_condition_evaluator.dart';
import '../identity/story_event_id.dart';
import '../explainability/story_runtime_execution_explanation.dart';
import '../validation/story_diagnostic_location.dart';
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
    void Function(StoryRuntimeExplanationStep)? onExplanation,
    StoryDiagnosticLocation? explanationLocation,
  }) {
    switch (transition) {
      case StoryEventTransition():
        onExplanation?.call(
          StoryEventTransitionExplanation(
            location: explanationLocation!,
            destinationEventId: transition.destinationEventId,
          ),
        );
        return StoryEventTransitionResolution(
          destinationEventId: transition.destinationEventId,
        );
      case StoryTerminalTransition():
        onExplanation?.call(
          StoryTerminalTransitionExplanation(location: explanationLocation!),
        );
        return const StoryTerminalTransitionResolution();
      case StoryConditionalTransition():
        return _resolveConditional(
          transition: transition,
          context: context,
          randomSource: randomSource,
          onExplanation: onExplanation,
          explanationLocation: explanationLocation,
        );
      case StoryWeightedTransition():
        return _resolveWeighted(
          transition: transition,
          context: context,
          randomSource: randomSource,
          onExplanation: onExplanation,
          explanationLocation: explanationLocation,
        );
    }
  }

  StoryTransitionResolution _resolveConditional({
    required StoryConditionalTransition transition,
    required StoryConditionContext context,
    required StoryRandomSource randomSource,
    required void Function(StoryRuntimeExplanationStep)? onExplanation,
    required StoryDiagnosticLocation? explanationLocation,
  }) {
    for (var index = 0; index < transition.branches.length; index++) {
      final branch = transition.branches[index];
      final condition = onExplanation == null
          ? null
          : evaluateStoryConditionWithExplanationResult(
              conditionEvaluator,
              branch.condition,
              context,
            );
      final matches =
          condition?.result ??
          conditionEvaluator.evaluate(branch.condition, context);
      if (condition != null) {
        onExplanation!(
          StoryTransitionBranchExplanation(
            location: StoryDiagnosticLocation.condition(
              projectId: explanationLocation!.projectId,
              eventId: explanationLocation.eventId,
              choiceId: explanationLocation.choiceId,
              path: [
                ...explanationLocation.path,
                const StoryDiagnosticPathSegment.field('branches'),
                StoryDiagnosticPathSegment.index(index),
                const StoryDiagnosticPathSegment.field('condition'),
              ],
            ),
            condition: condition.explanation,
          ),
        );
      }
      if (matches) {
        onExplanation?.call(
          StoryConditionalTransitionExplanation(
            location: explanationLocation!,
            authoredBranchCount: transition.branches.length,
            selectedBranchIndex: index,
          ),
        );
        return resolve(
          transition: branch.transition,
          context: context,
          randomSource: randomSource,
          onExplanation: onExplanation,
          explanationLocation: explanationLocation == null
              ? null
              : _nestedLocation(explanationLocation, [
                  const StoryDiagnosticPathSegment.field('branches'),
                  StoryDiagnosticPathSegment.index(index),
                  const StoryDiagnosticPathSegment.field('transition'),
                ]),
        );
      }
    }
    onExplanation?.call(
      StoryConditionalTransitionExplanation(
        location: explanationLocation!,
        authoredBranchCount: transition.branches.length,
        selectedBranchIndex: null,
      ),
    );
    return resolve(
      transition: transition.fallback,
      context: context,
      randomSource: randomSource,
      onExplanation: onExplanation,
      explanationLocation: explanationLocation == null
          ? null
          : _nestedLocation(explanationLocation, const [
              StoryDiagnosticPathSegment.field('fallback'),
            ]),
    );
  }

  StoryTransitionResolution _resolveWeighted({
    required StoryWeightedTransition transition,
    required StoryConditionContext context,
    required StoryRandomSource randomSource,
    required void Function(StoryRuntimeExplanationStep)? onExplanation,
    required StoryDiagnosticLocation? explanationLocation,
  }) {
    final sampled = randomSource.nextInt(transition.totalWeight);
    if (sampled < 0 || sampled >= transition.totalWeight) {
      throw StoryTransitionResolutionException(
        transition: transition,
        message:
            'Random source returned $sampled for an exclusive upper '
            'bound of ${transition.totalWeight}.',
      );
    }
    var upperExclusive = 0;
    for (var index = 0; index < transition.options.length; index++) {
      final option = transition.options[index];
      upperExclusive += option.weight;
      if (sampled < upperExclusive) {
        onExplanation?.call(
          StoryWeightedTransitionExplanation(
            location: explanationLocation!,
            weights: transition.options.map((option) => option.weight),
            sampledOffset: sampled,
            selectedOptionIndex: index,
          ),
        );
        return resolve(
          transition: option.transition,
          context: context,
          randomSource: randomSource,
          onExplanation: onExplanation,
          explanationLocation: explanationLocation == null
              ? null
              : _nestedLocation(explanationLocation, [
                  const StoryDiagnosticPathSegment.field('options'),
                  StoryDiagnosticPathSegment.index(index),
                  const StoryDiagnosticPathSegment.field('transition'),
                ]),
        );
      }
    }
    throw StoryTransitionResolutionException(
      transition: transition,
      message:
          'Weighted transition could not map a valid sampled value to '
          'an authored option.',
    );
  }

  StoryDiagnosticLocation _nestedLocation(
    StoryDiagnosticLocation parent,
    List<StoryDiagnosticPathSegment> suffix,
  ) => StoryDiagnosticLocation.transition(
    projectId: parent.projectId,
    eventId: parent.eventId,
    choiceId: parent.choiceId,
    path: [...parent.path, ...suffix],
  );
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
  int get hashCode =>
      Object.hash(StoryEventTransitionResolution, destinationEventId);
}

/// Concrete terminal result selected by transition resolution.
final class StoryTerminalTransitionResolution
    extends StoryTransitionResolution {
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
