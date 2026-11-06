import '../explainability/story_decision_explanation.dart';
import '../explainability/story_effect_explanation.dart';
import '../explainability/story_runtime_execution_explanation.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_host_action_request_id.dart';

/// Optional non-authoritative bridge from runtime explanations to host tools.
///
/// Authoring tools, debuggers, QA tools, and advanced hosts may subclass this
/// adapter and override only the explanation channels they need. Attaching an
/// adapter enables explanation capture at the relevant narrative-runtime
/// decision/transaction sites. Callback failures are isolated by
/// the narrative runtime and must never alter narrative semantics.
///
/// This adapter owns no UI, persistence, external transport, or execution
/// authority. Explanation values remain immutable diagnostic data.
abstract class StoryNarrativeDebugAdapter {
  const StoryNarrativeDebugAdapter();

  /// Receives the actual eligibility evaluation for an explicitly requested
  /// entry point.
  void onEntryPointEligibility(StoryEntryPointExplanation explanation) {}

  /// Receives one completed automatic entry-point resolution.
  void onEntryPointResolution(
    StoryEntryPointResolutionExplanation explanation,
  ) {}

  /// Receives availability explanations for all authored choices at one
  /// committed interactive pause.
  void onChoiceExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) {}

  /// Receives the effect attempts captured by one diagnostics-enabled engine
  /// transaction. [sessionIndex] is null only when session startup failed
  /// before a narrative session could commit.
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) {}

  /// Receives an ordered execution attempt after its aggregate outcome is known.
  /// Failed startup has no committed session identity and uses a null index.
  void onExecutionExplanation({
    required int? sessionIndex,
    required StoryRuntimeExecutionExplanation explanation,
  }) {}

  /// Receives only successful changed-state commits, in revision order.
  /// This causal channel does not alter the existing lifecycle sequence.
  void onPersistentStateCommitExplanation(
    StoryPersistentStateCommitExplanation explanation,
  ) {}
}

/// Non-authoritative sink for structured narrative-runtime observations.
///
/// Observers may feed debuggers, QA logs, telemetry adapters, or nothing at all.
/// They must never be required for narrative semantics.
abstract interface class StoryNarrativeObserver {
  void onNarrativeObservation(StoryNarrativeObservation observation);
}

/// Base data event emitted by Stage 8N runtime observability hooks.
///
/// [sequence] is runtime-local deterministic emission order. It is not a wall
/// clock value, distributed ordering token, or authored semantic input.
sealed class StoryNarrativeObservation {
  const StoryNarrativeObservation({
    required this.sequence,
    required this.sessionIndex,
  });

  final int sequence;
  final int? sessionIndex;
}

/// Reports successful activation of one local narrative session.
final class StoryNarrativeSessionStarted extends StoryNarrativeObservation {
  const StoryNarrativeSessionStarted({
    required super.sequence,
    required int sessionIndex,
    required this.entryPointId,
    required this.entryEventId,
    required this.randomSeed,
  }) : super(sessionIndex: sessionIndex);

  final StoryEntryPointId entryPointId;
  final StoryEventId entryEventId;
  final int randomSeed;
}

/// Reports one committed event entry, including automatic traversal entries.
final class StoryNarrativeEventEntered extends StoryNarrativeObservation {
  const StoryNarrativeEventEntered({
    required super.sequence,
    required int sessionIndex,
    required this.eventId,
  }) : super(sessionIndex: sessionIndex);

  final StoryEventId eventId;
}

/// Reports one choice made available at a committed interactive pause.
final class StoryNarrativeChoicePresented extends StoryNarrativeObservation {
  const StoryNarrativeChoicePresented({
    required super.sequence,
    required int sessionIndex,
    required this.eventId,
    required this.choiceId,
  }) : super(sessionIndex: sessionIndex);

  final StoryEventId eventId;
  final StoryChoiceId choiceId;
}

/// Reports one successfully accepted authored choice.
final class StoryNarrativeChoiceSelected extends StoryNarrativeObservation {
  const StoryNarrativeChoiceSelected({
    required super.sequence,
    required int sessionIndex,
    required this.eventId,
    required this.choiceId,
  }) : super(sessionIndex: sessionIndex);

  final StoryEventId eventId;
  final StoryChoiceId choiceId;
}

/// Reports suspension on one stable external host-action request.
final class StoryNarrativeHostActionRequested
    extends StoryNarrativeObservation {
  const StoryNarrativeHostActionRequested({
    required super.sequence,
    required int sessionIndex,
    required this.requestId,
    required this.schemaNamespace,
    required this.actionId,
  }) : super(sessionIndex: sessionIndex);

  final StoryHostActionRequestId requestId;
  final String schemaNamespace;
  final String actionId;
}

/// Explicit outcome category for one completed host-action protocol request.
enum StoryNarrativeHostActionResolution { completed, failed, cancelled }

/// Reports that a previously pending host-action request left `awaitingHost`.
final class StoryNarrativeHostActionCompleted
    extends StoryNarrativeObservation {
  const StoryNarrativeHostActionCompleted({
    required super.sequence,
    required int sessionIndex,
    required this.requestId,
    required this.resolution,
    this.code,
  }) : super(sessionIndex: sessionIndex);

  final StoryHostActionRequestId requestId;
  final StoryNarrativeHostActionResolution resolution;
  final String? code;
}

/// Reports successful termination of one local narrative session.
final class StoryNarrativeSessionEnded extends StoryNarrativeObservation {
  const StoryNarrativeSessionEnded({
    required super.sequence,
    required int sessionIndex,
    required this.entryPointId,
  }) : super(sessionIndex: sessionIndex);

  final StoryEntryPointId entryPointId;
}

/// Portable high-level category for a failed narrative-runtime operation.
enum StoryNarrativeErrorCategory {
  configuration,
  operation,
  resolution,
  execution,
  unknown,
}

/// Reports a failed narrative operation without changing the failure itself.
final class StoryNarrativeError extends StoryNarrativeObservation {
  const StoryNarrativeError({
    required super.sequence,
    required super.sessionIndex,
    required this.category,
    required this.operation,
    required this.message,
  });

  final StoryNarrativeErrorCategory category;
  final String operation;
  final String message;
}
