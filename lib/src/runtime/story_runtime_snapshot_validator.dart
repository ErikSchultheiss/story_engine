import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../state/story_state_schema.dart';
import '../transition/story_transition.dart';
import 'story_engine_status.dart';
import 'story_runtime_history.dart';
import 'story_runtime_snapshot.dart';
import 'story_seeded_random_source.dart';

/// Stable categories describing why a runtime snapshot cannot safely resume
/// against the supplied engine/project contract.
enum StoryRuntimeSnapshotCompatibilityIssue {
  /// Snapshot data uses a format version this package cannot consume.
  unsupportedFormatVersion,

  /// Snapshot execution semantics differ from the current runtime contract.
  unsupportedRuntimeContractVersion,

  /// Snapshot belongs to a different authored project identity.
  projectIdMismatch,

  /// A persisted set state value no longer resolves with the same scalar type
  /// in the supplied project's state schema.
  stateSchemaMismatch,

  /// The supplied project contains duplicate event IDs, making references
  /// ambiguous during restore.
  duplicateProjectEventId,

  /// The supplied project contains duplicate choice IDs where a persisted
  /// choice reference must resolve unambiguously.
  duplicateProjectChoiceId,

  /// A persisted event reference no longer resolves in the supplied project.
  missingEvent,

  /// A persisted choice reference no longer resolves in its source event.
  missingChoice,

  /// The ordered history is not a possible committed structural trace.
  invalidHistorySequence,

  /// A persisted history edge/termination is not structurally reachable from
  /// the authored transition that should have produced it.
  historyTransitionMismatch,

  /// A persisted explicit action no longer matches the authored flow mode of
  /// the event where that action was recorded.
  historyActionModeMismatch,

  /// The current event's authored flow mode no longer matches the persisted
  /// awaiting status.
  statusEventModeMismatch,

  /// Snapshot random state belongs to an algorithm this runtime cannot resume.
  unsupportedRandomAlgorithm,

  /// Snapshot random state uses an unsupported version of the known algorithm.
  unsupportedRandomAlgorithmVersion,

  /// Snapshot random state payload is malformed for its algorithm/version.
  invalidRandomState,
}

/// Structured incompatibility raised when a well-formed runtime snapshot
/// cannot be resumed safely against the current engine/project contract.
final class StoryRuntimeSnapshotCompatibilityException implements Exception {
  const StoryRuntimeSnapshotCompatibilityException({
    required this.issue,
    required this.path,
    required this.message,
  });

  final StoryRuntimeSnapshotCompatibilityIssue issue;

  /// Machine-oriented location within the snapshot/project compatibility
  /// check. This is deliberately independent from human-readable [message].
  final String path;

  final String message;

  /// Machine-oriented location alias shared with other public data failures.
  String get location => path;

  /// Actionable recovery guidance for the compatibility category.
  String get suggestion => switch (issue) {
    StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion ||
    StoryRuntimeSnapshotCompatibilityIssue.unsupportedRuntimeContractVersion =>
      'Restore this save with a compatible story_engine version, or migrate '
          'the snapshot before loading it.',
    StoryRuntimeSnapshotCompatibilityIssue.projectIdMismatch =>
      'Restore the snapshot against the StoryProject it was created from.',
    StoryRuntimeSnapshotCompatibilityIssue.stateSchemaMismatch =>
      'Use the matching project schema or migrate the saved state values.',
    StoryRuntimeSnapshotCompatibilityIssue.duplicateProjectEventId ||
    StoryRuntimeSnapshotCompatibilityIssue.duplicateProjectChoiceId =>
      'Fix duplicate stable IDs in the supplied project before restoring.',
    StoryRuntimeSnapshotCompatibilityIssue.missingEvent ||
    StoryRuntimeSnapshotCompatibilityIssue.missingChoice ||
    StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence ||
    StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch ||
    StoryRuntimeSnapshotCompatibilityIssue.historyActionModeMismatch ||
    StoryRuntimeSnapshotCompatibilityIssue.statusEventModeMismatch =>
      'Use the authored project revision that matches this save, or migrate '
          'the snapshot/project together.',
    StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithm ||
    StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithmVersion =>
      'Use a runtime version that supports the saved random-state algorithm.',
    StoryRuntimeSnapshotCompatibilityIssue.invalidRandomState =>
      'Discard or repair the corrupted random-state payload before restoring.',
  };

  @override
  String toString() =>
      'StoryRuntimeSnapshotCompatibilityException('
      '${issue.name}) at $path: $message';
}

/// Immutable project-derived lookup data reused by internal restore paths.
///
/// This type is intentionally not exported from the package root. A preparation
/// is bound to one exact immutable [StoryProject] instance so projects or
/// materialized revisions that happen to share an ID cannot share validation
/// indexes accidentally. Snapshot-specific state, lifecycle, history, RNG, and
/// current-event validation still runs for every restore.
final class StoryRuntimeProjectPreparation {
  StoryRuntimeProjectPreparation._({
    required this.project,
    required this.eventLookup,
    required this.choiceLookup,
  });

  factory StoryRuntimeProjectPreparation.prepare(StoryProject project) =>
      _prepare(project);

  factory StoryRuntimeProjectPreparation.prepareForSnapshot({
    required StoryProject project,
    required StoryRuntimeSnapshot snapshot,
  }) {
    const validator = StoryRuntimeSnapshotValidator();
    validator._validateVersions(snapshot);
    validator._validateRandomState(snapshot.randomState);
    validator._validateProjectIdentity(snapshot, project);
    return _prepare(project);
  }

  static StoryRuntimeProjectPreparation _prepare(StoryProject project) {
    const validator = StoryRuntimeSnapshotValidator();
    return StoryRuntimeProjectPreparation._(
      project: project,
      eventLookup: Map<StoryEventId, StoryEvent>.unmodifiable(
        validator._buildEventLookup(project),
      ),
      choiceLookup: Map<StoryChoiceId, StoryEventId>.unmodifiable(
        validator._buildChoiceLookup(project),
      ),
    );
  }

  final StoryProject project;
  final Map<StoryEventId, StoryEvent> eventLookup;
  final Map<StoryChoiceId, StoryEventId> choiceLookup;

  void validateSnapshot({
    required StoryProject project,
    required StoryRuntimeSnapshot snapshot,
  }) {
    _requireExactProject(project);
    const validator = StoryRuntimeSnapshotValidator();
    validator._validateVersions(snapshot);
    validator._validateRandomState(snapshot.randomState);
    validator._validateProjectIdentity(snapshot, project);
    validator._validatePreparedBody(snapshot: snapshot, preparation: this);
  }

  void validateSnapshotAfterPreflight({
    required StoryProject project,
    required StoryRuntimeSnapshot snapshot,
  }) {
    _requireExactProject(project);
    const StoryRuntimeSnapshotValidator()._validatePreparedBody(
      snapshot: snapshot,
      preparation: this,
    );
  }

  void _requireExactProject(StoryProject project) {
    if (!identical(this.project, project)) {
      throw ArgumentError(
        'StoryRuntimeProjectPreparation is bound to a different StoryProject '
        'instance.',
      );
    }
  }
}

/// Validates one committed snapshot against the project/runtime contract that
/// would be used to resume it.
///
/// This validator is intentionally independent from encoded persistence. It is
/// reusable by both the Stage 4B codec and `StoryEngine.restore`. Stage 4D also
/// makes versioned RNG compatibility part of this common validation pass, and
/// Stage 4F validates the persisted history as a structurally possible authored
/// trace without replaying conditions, effects, or random choices. Stage 8I
/// generalizes the first history entry for Stage 8G `startAt` runs: any existing
/// project event may be the legitimate run root.
/// It does not execute the story or invoke `StoryValidator`.
final class StoryRuntimeSnapshotValidator {
  const StoryRuntimeSnapshotValidator();

  void validate({
    required StoryRuntimeSnapshot snapshot,
    required StoryProject project,
  }) {
    final preparation = StoryRuntimeProjectPreparation.prepareForSnapshot(
      project: project,
      snapshot: snapshot,
    );
    preparation.validateSnapshotAfterPreflight(
      project: project,
      snapshot: snapshot,
    );
  }

  void _validatePreparedBody({
    required StoryRuntimeSnapshot snapshot,
    required StoryRuntimeProjectPreparation preparation,
  }) {
    final project = preparation.project;
    _validateStateValues(snapshot, project.stateSchema);
    _validateCurrentEvent(snapshot, preparation.eventLookup);
    _validateHistory(
      snapshot,
      preparation.eventLookup,
      preparation.choiceLookup,
    );
    _validateAwaitingMode(snapshot, preparation.eventLookup);
  }

  void _validateVersions(StoryRuntimeSnapshot snapshot) {
    if (snapshot.metadata.formatVersion !=
        StoryRuntimeSnapshotMetadata.currentFormatVersion) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion,
        path: r'$.formatVersion',
        message:
            'Snapshot format version '
            '${snapshot.metadata.formatVersion} is not supported by the '
            'current runtime snapshot model.',
      );
    }
    if (snapshot.metadata.runtimeContractVersion !=
        StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue
            .unsupportedRuntimeContractVersion,
        path: r'$.runtimeContractVersion',
        message:
            'Snapshot runtime contract version '
            '${snapshot.metadata.runtimeContractVersion} is not supported by '
            'this engine runtime.',
      );
    }
  }

  void _validateRandomState(StoryRuntimeRandomState randomState) {
    if (randomState.algorithmId !=
        StorySeededRandomSource.runtimeStateAlgorithmId) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue:
            StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithm,
        path: r'$.randomState.algorithmId',
        message:
            'Snapshot random algorithm ${randomState.algorithmId} is not '
            'supported by the current StoryEngine runtime.',
      );
    }
    if (randomState.algorithmVersion !=
        StorySeededRandomSource.runtimeStateAlgorithmVersion) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue
            .unsupportedRandomAlgorithmVersion,
        path: r'$.randomState.algorithmVersion',
        message:
            'Snapshot random algorithm version '
            '${randomState.algorithmVersion} is not supported for '
            '${randomState.algorithmId}.',
      );
    }

    try {
      StorySeededRandomSource.validateRuntimeState(randomState);
    } on StorySeededRandomStateException catch (error) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.invalidRandomState,
        path: r'$.randomState.stateWords',
        message: error.message,
      );
    }
  }

  void _validateProjectIdentity(
    StoryRuntimeSnapshot snapshot,
    StoryProject project,
  ) {
    if (snapshot.projectId != project.id) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
        path: r'$.projectId',
        message:
            'Snapshot belongs to ${snapshot.projectId.value}, but the '
            'supplied project is ${project.id.value}.',
      );
    }
  }

  Map<StoryEventId, StoryEvent> _buildEventLookup(StoryProject project) {
    final result = <StoryEventId, StoryEvent>{};
    for (final event in project.events) {
      if (result.containsKey(event.id)) {
        throw StoryRuntimeSnapshotCompatibilityException(
          issue: StoryRuntimeSnapshotCompatibilityIssue.duplicateProjectEventId,
          path: r'$.project.events',
          message:
              'Project event ID ${event.id.value} is duplicated, so '
              'persisted event references are ambiguous.',
        );
      }
      result[event.id] = event;
    }
    return result;
  }

  Map<StoryChoiceId, StoryEventId> _buildChoiceLookup(StoryProject project) {
    final result = <StoryChoiceId, StoryEventId>{};
    for (final event in project.events) {
      for (final choice in event.choices) {
        if (result.containsKey(choice.id)) {
          throw StoryRuntimeSnapshotCompatibilityException(
            issue:
                StoryRuntimeSnapshotCompatibilityIssue.duplicateProjectChoiceId,
            path: r'$.project.events',
            message:
                'Project choice ID ${choice.id.value} is duplicated, so '
                'persisted choice references are ambiguous.',
          );
        }
        result[choice.id] = event.id;
      }
    }
    return result;
  }

  void _validateStateValues(
    StoryRuntimeSnapshot snapshot,
    StoryStateSchema projectSchema,
  ) {
    final state = snapshot.state;
    if (state == null) {
      return;
    }

    for (final entry in state.values.entries) {
      final definition = projectSchema.definitionFor(entry.key);
      if (definition == null || definition.type != entry.value.type) {
        throw StoryRuntimeSnapshotCompatibilityException(
          issue: StoryRuntimeSnapshotCompatibilityIssue.stateSchemaMismatch,
          path: r'$.state',
          message: definition == null
              ? 'Snapshot state references variable ${entry.key.value}, but '
                    'that variable is no longer declared by the supplied '
                    'project.'
              : 'Snapshot value for ${entry.key.value} has type '
                    '${entry.value.type.name}, but the supplied project '
                    'declares ${definition.type.name}.',
        );
      }
    }
  }

  void _validateCurrentEvent(
    StoryRuntimeSnapshot snapshot,
    Map<StoryEventId, StoryEvent> events,
  ) {
    final currentEventId = snapshot.currentEventId;
    if (currentEventId != null && !events.containsKey(currentEventId)) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.missingEvent,
        path: r'$.currentEventId',
        message:
            'Current event ${currentEventId.value} no longer exists in '
            'the supplied project.',
      );
    }
  }

  void _validateHistory(
    StoryRuntimeSnapshot snapshot,
    Map<StoryEventId, StoryEvent> events,
    Map<StoryChoiceId, StoryEventId> choiceLookup,
  ) {
    final steps = snapshot.history.steps;
    if (steps.isEmpty) {
      return;
    }

    StoryEvent? activeEvent;
    StoryTransition? pendingTransition;
    String? pendingTransitionPath;

    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final path = '\$.history.steps[$index]';

      switch (step) {
        case StoryEventEnteredStep(:final eventId):
          final event = _requireEvent(events, eventId, '$path.eventId');

          if (index != 0) {
            final transition = pendingTransition;
            if (transition == null ||
                !_transitionCanReachEvent(transition, eventId)) {
              throw StoryRuntimeSnapshotCompatibilityException(
                issue: StoryRuntimeSnapshotCompatibilityIssue
                    .historyTransitionMismatch,
                path: '$path.eventId',
                message:
                    'History enters event ${eventId.value}, but the '
                    'preceding committed transition cannot structurally reach '
                    'that event.',
              );
            }
          }

          activeEvent = event;
          pendingTransition = null;
          pendingTransitionPath = null;

          if (_isAutomaticEvent(event)) {
            pendingTransition = event.automaticTransition;
            pendingTransitionPath = '$path.eventId';
          } else if (!_isInteractiveEvent(event) &&
              !_isContinuationEvent(event)) {
            throw StoryRuntimeSnapshotCompatibilityException(
              issue: StoryRuntimeSnapshotCompatibilityIssue
                  .historyActionModeMismatch,
              path: '$path.eventId',
              message:
                  'History entered event ${eventId.value}, but that '
                  'event no longer has one valid runtime flow mode.',
            );
          }

        case StoryChoiceSelectedStep(:final eventId, :final choiceId):
          pendingTransition = _historyChoiceTransition(
            events,
            choiceLookup,
            activeEvent?.id,
            pendingTransition,
            eventId,
            choiceId,
            path,
          );
          pendingTransitionPath = '$path.choiceId';

        case StoryEventContinuedStep(:final eventId):
          pendingTransition = _historyContinueTransition(
            events,
            activeEvent?.id,
            pendingTransition,
            eventId,
            path,
          );
          pendingTransitionPath = '$path.eventId';
      }
    }

    _validateHistoryCompletion(
      snapshot.status,
      pendingTransition,
      pendingTransitionPath,
    );
  }

  StoryTransition _historyChoiceTransition(
    Map<StoryEventId, StoryEvent> events,
    Map<StoryChoiceId, StoryEventId> choiceLookup,
    StoryEventId? activeEventId,
    StoryTransition? pendingTransition,
    StoryEventId eventId,
    StoryChoiceId choiceId,
    String path,
  ) {
    if (pendingTransition != null) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        path: path,
        message:
            'An explicit choice cannot occur before the preceding '
            'synchronous transition has entered another event or '
            'terminated.',
      );
    }
    _requireActiveEvent(activeEventId, eventId, path);
    final event = _requireEvent(events, eventId, '$path.eventId');
    if (!_isInteractiveEvent(event)) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.historyActionModeMismatch,
        path: '$path.eventId',
        message:
            'History selects a choice from event ${eventId.value}, '
            'but that event is no longer a valid interactive event.',
      );
    }
    final owner = choiceLookup[choiceId];
    if (owner != eventId || !_eventContainsChoice(event, choiceId)) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.missingChoice,
        path: '$path.choiceId',
        message:
            'Choice ${choiceId.value} no longer belongs to event '
            '${eventId.value}.',
      );
    }
    final choice = event.choices.firstWhere((item) => item.id == choiceId);
    final transition = choice.transition;
    if (transition == null) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
        path: '$path.choiceId',
        message:
            'Choice ${choiceId.value} no longer has a transition '
            'that could have produced the persisted history.',
      );
    }
    return transition;
  }

  StoryTransition? _historyContinueTransition(
    Map<StoryEventId, StoryEvent> events,
    StoryEventId? activeEventId,
    StoryTransition? pendingTransition,
    StoryEventId eventId,
    String path,
  ) {
    if (pendingTransition != null) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        path: path,
        message:
            'An explicit continue cannot occur before the preceding '
            'synchronous transition has entered another event or '
            'terminated.',
      );
    }
    _requireActiveEvent(activeEventId, eventId, path);
    final event = _requireEvent(events, eventId, '$path.eventId');
    if (!_isContinuationEvent(event)) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.historyActionModeMismatch,
        path: '$path.eventId',
        message:
            'History continues event ${eventId.value}, but that '
            'event is no longer a valid continuation event.',
      );
    }
    return event.continuationTransition;
  }

  void _validateHistoryCompletion(
    StoryEngineStatus status,
    StoryTransition? pendingTransition,
    String? pendingTransitionPath,
  ) {
    if (status == StoryEngineStatus.terminated) {
      final transition = pendingTransition;
      if (transition == null || !_transitionCanTerminate(transition)) {
        throw StoryRuntimeSnapshotCompatibilityException(
          issue:
              StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          path: pendingTransitionPath ?? r'$.status',
          message:
              'Snapshot is terminated, but the final committed history '
              'position has no authored transition that can structurally '
              'terminate.',
        );
      }
      return;
    }

    if (pendingTransition != null) {
      throw const StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        path: r'$.history',
        message:
            'A non-terminated snapshot cannot end while a synchronous '
            'transition still requires an event entry or terminal result.',
      );
    }
  }

  void _validateAwaitingMode(
    StoryRuntimeSnapshot snapshot,
    Map<StoryEventId, StoryEvent> events,
  ) {
    final currentEventId = snapshot.currentEventId;
    if (currentEventId == null) {
      return;
    }
    final event = events[currentEventId];
    if (event == null) {
      return;
    }

    final valid = switch (snapshot.status) {
      StoryEngineStatus.awaitingChoice => _isInteractiveEvent(event),
      StoryEngineStatus.awaitingContinue => _isContinuationEvent(event),
      StoryEngineStatus.notStarted => true,
      StoryEngineStatus.terminated => true,
    };

    if (!valid) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.statusEventModeMismatch,
        path: r'$.status',
        message:
            'Snapshot status ${snapshot.status.name} no longer matches '
            'the authored flow mode of event ${currentEventId.value}.',
      );
    }
  }

  StoryEvent _requireEvent(
    Map<StoryEventId, StoryEvent> events,
    StoryEventId eventId,
    String path,
  ) {
    final event = events[eventId];
    if (event == null) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.missingEvent,
        path: path,
        message:
            'Persisted event ${eventId.value} no longer exists in the '
            'supplied project.',
      );
    }
    return event;
  }

  void _requireActiveEvent(
    StoryEventId? lastEntered,
    StoryEventId actionEventId,
    String path,
  ) {
    if (lastEntered != actionEventId) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        path: path,
        message:
            'Runtime action for ${actionEventId.value} does not follow '
            'that event as the latest committed event entry.',
      );
    }
  }
}

bool _transitionCanReachEvent(
  StoryTransition transition,
  StoryEventId eventId,
) => switch (transition) {
  StoryEventTransition(:final destinationEventId) =>
    destinationEventId == eventId,
  StoryConditionalTransition(:final branches, :final fallback) =>
    branches.any(
          (branch) => _transitionCanReachEvent(branch.transition, eventId),
        ) ||
        _transitionCanReachEvent(fallback, eventId),
  StoryWeightedTransition(:final options) => options.any(
    (option) => _transitionCanReachEvent(option.transition, eventId),
  ),
  StoryTerminalTransition() => false,
};

bool _transitionCanTerminate(StoryTransition transition) =>
    switch (transition) {
      StoryEventTransition() => false,
      StoryConditionalTransition(:final branches, :final fallback) =>
        branches.any((branch) => _transitionCanTerminate(branch.transition)) ||
            _transitionCanTerminate(fallback),
      StoryWeightedTransition(:final options) => options.any(
        (option) => _transitionCanTerminate(option.transition),
      ),
      StoryTerminalTransition() => true,
    };

bool _eventContainsChoice(StoryEvent event, StoryChoiceId id) =>
    event.choices.any((choice) => choice.id == id);

bool _isInteractiveEvent(StoryEvent event) =>
    event.choices.isNotEmpty &&
    event.continuationTransition == null &&
    event.automaticTransition == null;

bool _isContinuationEvent(StoryEvent event) =>
    event.choices.isEmpty &&
    event.continuationTransition != null &&
    event.automaticTransition == null;

bool _isAutomaticEvent(StoryEvent event) =>
    event.choices.isEmpty &&
    event.continuationTransition == null &&
    event.automaticTransition != null;
