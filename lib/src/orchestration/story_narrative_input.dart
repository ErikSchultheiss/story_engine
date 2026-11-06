import '../identity/story_choice_id.dart';
import '../identity/story_host_action_request_id.dart';

/// Base class for explicit authority-submitted narrative-session inputs.
///
/// Stage 8J makes host/server authority explicit: a UI, network client, replay
/// harness, or authoritative server may all submit the same stable machine-ID
/// inputs. The runtime does not infer input ordering from wall-clock time,
/// scheduler timing, or widget callbacks.
sealed class StoryNarrativeInput {
  const StoryNarrativeInput({required this.sessionIndex});

  /// Target session in deterministic activation order.
  final int sessionIndex;
}

/// Selects one stable choice ID in a narrative session.
final class StoryNarrativeChoiceInput extends StoryNarrativeInput {
  const StoryNarrativeChoiceInput({
    required super.sessionIndex,
    required this.choiceId,
  });

  final StoryChoiceId choiceId;
}

/// Explicitly continues one continuation-mode narrative session.
final class StoryNarrativeContinueInput extends StoryNarrativeInput {
  const StoryNarrativeContinueInput({required super.sessionIndex});
}

/// Supplies successful completion of one pending host action.
final class StoryNarrativeHostActionCompletedInput extends StoryNarrativeInput {
  const StoryNarrativeHostActionCompletedInput({
    required super.sessionIndex,
    required this.requestId,
    this.value,
  });

  final StoryHostActionRequestId requestId;
  final Object? value;
}

/// Supplies explicit failure of one pending host action.
final class StoryNarrativeHostActionFailedInput extends StoryNarrativeInput {
  const StoryNarrativeHostActionFailedInput({
    required super.sessionIndex,
    required this.requestId,
    required this.code,
    required this.message,
  });

  final StoryHostActionRequestId requestId;
  final String code;
  final String message;
}

/// Supplies explicit cancellation of one pending host action.
final class StoryNarrativeHostActionCancelledInput extends StoryNarrativeInput {
  const StoryNarrativeHostActionCancelledInput({
    required super.sessionIndex,
    required this.requestId,
    required this.code,
    this.message,
  });

  final StoryHostActionRequestId requestId;
  final String code;
  final String? message;
}
