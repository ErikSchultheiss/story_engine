import '../state/story_state.dart';

/// Read-only facts visible while evaluating a story condition.
///
/// Stage 1E exposes only immutable scalar [StoryState]. Later stages may add
/// optional runtime-history/read-model inputs without exposing mutable engine
/// internals to conditions.
final class StoryConditionContext {
  const StoryConditionContext({required this.state});

  /// Immutable authored scalar state snapshot visible to the predicate.
  final StoryState state;
}
