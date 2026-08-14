import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';

/// One committed, deterministic observation in a [StoryRuntimeHistory].
///
/// Stage 2G records only structural runtime facts. Steps contain
/// stable authored identities, not timestamps, state copies, presentation
/// strings, or host-specific debugging payloads.
sealed class StoryRuntimeStep {
  const StoryRuntimeStep();
}

/// Records that runtime traversal successfully entered [eventId].
///
/// Repeated entries are recorded repeatedly. This means self-transitions,
/// loops, and automatic-event chains remain visible in the ordered route.
final class StoryEventEnteredStep extends StoryRuntimeStep {
  const StoryEventEnteredStep({required this.eventId});

  final StoryEventId eventId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEventEnteredStep && other.eventId == eventId;

  @override
  int get hashCode => Object.hash(StoryEventEnteredStep, eventId);

  @override
  String toString() => 'StoryEventEnteredStep(eventId: $eventId)';
}

/// Records that the host explicitly continued from [eventId].
///
/// Unlike a choice selection, a continue action carries no authored decision
/// identity. It is still recorded because it is a committed user/runtime
/// action needed for exact route replay and playtest inspection.
final class StoryEventContinuedStep extends StoryRuntimeStep {
  const StoryEventContinuedStep({required this.eventId});

  final StoryEventId eventId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEventContinuedStep && other.eventId == eventId;

  @override
  int get hashCode => Object.hash(StoryEventContinuedStep, eventId);

  @override
  String toString() => 'StoryEventContinuedStep(eventId: $eventId)';
}

/// Records that [choiceId] was successfully accepted while [eventId] was
/// current.
///
/// The source event is stored explicitly even though choice IDs are globally
/// stable. This keeps route/debug output self-contained and avoids requiring a
/// project lookup merely to identify where a choice was selected.
final class StoryChoiceSelectedStep extends StoryRuntimeStep {
  const StoryChoiceSelectedStep({
    required this.eventId,
    required this.choiceId,
  });

  final StoryEventId eventId;
  final StoryChoiceId choiceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryChoiceSelectedStep &&
          other.eventId == eventId &&
          other.choiceId == choiceId;

  @override
  int get hashCode => Object.hash(StoryChoiceSelectedStep, eventId, choiceId);

  @override
  String toString() =>
      'StoryChoiceSelectedStep(eventId: $eventId, choiceId: $choiceId)';
}

/// Immutable public snapshot of committed runtime traversal history.
///
/// The ordered [steps] sequence is the source of truth. Convenience views are
/// derived from it so event routes, repeat counts, selected-choice order, and
/// continue order cannot drift apart.
///
/// A history snapshot never changes after construction, even if the owning
/// StoryEngine continues running.
final class StoryRuntimeHistory {
  StoryRuntimeHistory({Iterable<StoryRuntimeStep> steps = const []})
    : steps = List<StoryRuntimeStep>.unmodifiable(steps);

  /// Ordered committed runtime observations.
  final List<StoryRuntimeStep> steps;

  /// Ordered sequence of entered event IDs, including repeats and automatic
  /// events.
  List<StoryEventId> get eventRoute => List<StoryEventId>.unmodifiable(
    steps.whereType<StoryEventEnteredStep>().map((step) => step.eventId),
  );

  /// Event IDs in first-visit order, with duplicates removed.
  List<StoryEventId> get visitedEventIds {
    final seen = <StoryEventId>{};
    final result = <StoryEventId>[];
    for (final step in steps.whereType<StoryEventEnteredStep>()) {
      if (seen.add(step.eventId)) {
        result.add(step.eventId);
      }
    }
    return List<StoryEventId>.unmodifiable(result);
  }

  /// Choice IDs in the exact order in which the runtime accepted them.
  List<StoryChoiceId> get selectedChoiceIds => List<StoryChoiceId>.unmodifiable(
    steps.whereType<StoryChoiceSelectedStep>().map((step) => step.choiceId),
  );

  /// Event IDs in the exact order in which explicit continue actions occurred.
  List<StoryEventId> get continuedEventIds => List<StoryEventId>.unmodifiable(
    steps.whereType<StoryEventContinuedStep>().map((step) => step.eventId),
  );

  /// Number of successfully committed entries into [eventId].
  int eventOccurrenceCount(StoryEventId eventId) {
    var count = 0;
    for (final step in steps.whereType<StoryEventEnteredStep>()) {
      if (step.eventId == eventId) {
        count++;
      }
    }
    return count;
  }

  /// Whether [eventId] has been entered at least once.
  bool hasVisitedEvent(StoryEventId eventId) =>
      eventOccurrenceCount(eventId) > 0;

  /// Whether [choiceId] has been selected at least once.
  bool hasSelectedChoice(StoryChoiceId choiceId) {
    for (final step in steps.whereType<StoryChoiceSelectedStep>()) {
      if (step.choiceId == choiceId) {
        return true;
      }
    }
    return false;
  }

  /// Whether [eventId] has been explicitly continued at least once.
  bool hasContinuedEvent(StoryEventId eventId) {
    for (final step in steps.whereType<StoryEventContinuedStep>()) {
      if (step.eventId == eventId) {
        return true;
      }
    }
    return false;
  }

  bool get isEmpty => steps.isEmpty;
  bool get isNotEmpty => steps.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryRuntimeHistory && _stepListsEqual(steps, other.steps);

  @override
  int get hashCode => Object.hashAll(steps);

  @override
  String toString() => 'StoryRuntimeHistory(steps: $steps)';
}

bool _stepListsEqual(
  List<StoryRuntimeStep> left,
  List<StoryRuntimeStep> right,
) {
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
