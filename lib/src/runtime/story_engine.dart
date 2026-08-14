import '../condition/story_condition_context.dart';
import '../condition/story_condition_evaluator.dart';
import '../effect/story_effect_executor.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../model/story_choice.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../state/story_state.dart';
import '../transition/story_transition.dart';
import '../transition/story_transition_resolver.dart';
import 'story_engine_status.dart';
import 'story_runtime_history.dart';
import 'story_runtime_snapshot.dart';
import 'story_runtime_snapshot_validator.dart';
import 'story_seeded_random_source.dart';

/// First integrated pure-Dart runtime for authored story definitions.
///
/// The engine owns state evolution, condition evaluation, transition
/// resolution, seeded randomness, and the completed Stage 4 committed runtime
/// snapshot capture/restoration contract. Public callers observe immutable
/// state/event/choice data and select choices by stable ID; they never mutate
/// runtime state directly.
final class StoryEngine {
  StoryEngine({
    required this.project,
    this.randomSeed = defaultRandomSeed,
    this.maxAutomaticTransitions = defaultMaxAutomaticTransitions,
  }) : _eventIndex = _buildEventIndex(project),
       _initialRandomSource = StorySeededRandomSource.fromSeed(randomSeed) {
    if (maxAutomaticTransitions <= 0) {
      throw ArgumentError.value(
        maxAutomaticTransitions,
        'maxAutomaticTransitions',
        'Automatic transition limit must be greater than zero.',
      );
    }
    _validateChoiceIdentity(project);
  }

  StoryEngine._restored({
    required this.project,
    required StoryRuntimeSnapshot snapshot,
    required StorySeededRandomSource restoredRandomSource,
  }) : randomSeed = restoredRandomSource.initialSeed,
       maxAutomaticTransitions = snapshot.maxAutomaticTransitions,
       _eventIndex = _buildEventIndex(project),
       _initialRandomSource = restoredRandomSource.copy() {
    _validateChoiceIdentity(project);

    _status = snapshot.status;
    final snapshotState = snapshot.state;
    _state = snapshotState == null
        ? null
        : StoryState.fromValues(
            schema: project.stateSchema,
            values: snapshotState.values,
          );
    _currentEvent = snapshot.currentEventId == null
        ? null
        : _eventIndex[snapshot.currentEventId!];
    _randomSource = snapshot.status == StoryEngineStatus.notStarted
        ? null
        : restoredRandomSource.copy();
    _historySteps.addAll(snapshot.history.steps);
  }

  /// Recreates one engine from a committed runtime snapshot.
  ///
  /// Compatibility is validated before any engine instance is returned. The
  /// snapshot's lifecycle status, scalar state, current event, ordered history,
  /// deterministic random stream, and automatic-transition guard are restored
  /// directly; authored entry effects/transitions are not replayed.
  ///
  /// In particular, an `awaitingContinue` snapshot remains paused on that same
  /// event until [continueStory] is called, and an `awaitingChoice` snapshot
  /// recomputes its available choices from the restored committed state.
  factory StoryEngine.restore({
    required StoryProject project,
    required StoryRuntimeSnapshot snapshot,
  }) {
    const StoryRuntimeSnapshotValidator().validate(
      snapshot: snapshot,
      project: project,
    );

    final restoredRandomSource = _restoreRandomSource(snapshot.randomState);
    return StoryEngine._restored(
      project: project,
      snapshot: snapshot,
      restoredRandomSource: restoredRandomSource,
    );
  }

  /// Deterministic seed used when callers do not need run-specific randomness.
  ///
  /// Passing an explicit [randomSeed] remains the way to request a particular
  /// weighted-transition sequence. Keeping the implicit default deterministic
  /// makes tests, examples, and ordinary non-random stories reproducible.
  static const int defaultRandomSeed = 0;

  /// Default guard against accidental non-interactive infinite loops.
  static const int defaultMaxAutomaticTransitions = 10000;

  /// Authored project consumed by this runtime.
  final StoryProject project;

  /// Seed originally used to initialize this run's deterministic stream.
  ///
  /// Defaults to [defaultRandomSeed] when omitted.
  ///
  /// Restored engines recover this provenance from the algorithm-owned snapshot
  /// RNG state; future random continuation uses the persisted current RNG state,
  /// not this seed.
  final int randomSeed;

  /// Maximum automatic transitions resolved by one start/choose/continue operation.
  final int maxAutomaticTransitions;

  final Map<StoryEventId, StoryEvent> _eventIndex;
  final StorySeededRandomSource _initialRandomSource;
  final StoryConditionEvaluator _conditionEvaluator =
      const StoryConditionEvaluator();
  final StoryEffectExecutor _effectExecutor = const StoryEffectExecutor();
  final StoryTransitionResolver _transitionResolver =
      const StoryTransitionResolver();

  StoryEngineStatus _status = StoryEngineStatus.notStarted;
  StoryState? _state;
  StoryEvent? _currentEvent;
  StorySeededRandomSource? _randomSource;
  final List<StoryRuntimeStep> _historySteps = <StoryRuntimeStep>[];

  /// Current lifecycle status.
  StoryEngineStatus get status => _status;

  /// Current immutable narrative-state snapshot, or null before start.
  StoryState? get state => _state;

  /// Immutable snapshot of all successfully committed runtime traversal so far.
  ///
  /// Before start this is empty. Event entries include repeats and automatic
  /// events; choice selections and explicit continues are recorded in committed
  /// order. Failed start/choose/continue operations do not alter history.
  StoryRuntimeHistory get history => StoryRuntimeHistory(steps: _historySteps);

  /// Most recently entered event, or null before start.
  ///
  /// After termination this remains the event from which the terminal result
  /// was reached, which is useful to presentation/debugging layers.
  StoryEvent? get currentEvent => _currentEvent;

  /// Captures the current committed runtime state as an immutable snapshot.
  ///
  /// Public runtime operations are synchronous and transactional, so callers
  /// can observe snapshots only before an operation or after it has committed.
  /// Pending transaction steps and partially applied effects never enter this
  /// value.
  StoryRuntimeSnapshot createSnapshot() {
    final randomSource = _status == StoryEngineStatus.notStarted
        ? _initialRandomSource
        : _randomSource;
    if (randomSource == null) {
      throw const StoryEngineExecutionException(
        message: 'Started StoryEngine random state is internally incomplete.',
        operation: 'createSnapshot',
        suggestion: 'Recreate the engine from the last committed snapshot or '
            'restart the run; this state indicates an internal invariant '
            'failure.',
      );
    }

    return StoryRuntimeSnapshot(
      projectId: project.id,
      status: _status,
      state: _state,
      currentEventId: _currentEvent?.id,
      history: history,
      randomState: randomSource.createRuntimeState(),
      maxAutomaticTransitions: maxAutomaticTransitions,
    );
  }

  /// Choices currently available to the caller in authored order.
  ///
  /// Before start, while awaiting continue, and after termination this returns
  /// an empty immutable list.
  /// Invalid authored condition logic is surfaced as
  /// [StoryEngineExecutionException] rather than silently hiding the choice.
  List<StoryChoice> get availableChoices {
    if (_status != StoryEngineStatus.awaitingChoice) {
      return const [];
    }

    final event = _currentEvent;
    final state = _state;
    if (event == null || state == null) {
      throw const StoryEngineExecutionException(
        message: 'Engine awaiting-choice state is internally incomplete.',
        operation: 'availableChoices',
        suggestion: 'Recreate the engine from the last committed snapshot or '
            'restart the run; this state indicates an internal invariant '
            'failure.',
      );
    }

    try {
      return List<StoryChoice>.unmodifiable(
        event.choices.where((choice) => _isChoiceAvailable(choice, state)),
      );
    } catch (error) {
      if (error is StoryEngineException) {
        rethrow;
      }
      throw StoryEngineExecutionException(
        message: 'Failed to evaluate available choices for ${event.id}.',
        cause: error,
        operation: 'availableChoices',
        eventId: event.id,
        suggestion: 'Validate the project and repair the failing choice '
            'condition before evaluating available choices.',
      );
    }
  }

  /// Starts traversal at [StoryProject.entryEventId].
  ///
  /// If [initialState] is omitted, the project's declared initial scalar state
  /// is used. The supplied state must use exactly the project's state schema.
  /// Start is transactional for the current scalar-only runtime: if any entry
  /// effect, condition, transition, or automatic-flow step fails, this engine
  /// remains not started and its random stream remains untouched.
  void start({StoryState? initialState}) {
    if (_status != StoryEngineStatus.notStarted) {
      throw const StoryEngineOperationException(
        message: 'StoryEngine.start may only be called once.',
        operation: 'start',
        suggestion: 'Create a new StoryEngine for a fresh run, or restore a '
            'saved snapshot instead of starting this instance again.',
      );
    }

    final entryEventId = project.entryEventId;
    if (entryEventId == null) {
      throw const StoryEngineConfigurationException(
        message: 'StoryProject has no entryEventId and cannot be started.',
        operation: 'start',
        suggestion: 'Run StoryValidator.validate(project) and set entryEventId '
            'to an authored event before starting.',
      );
    }
    if (!_eventIndex.containsKey(entryEventId)) {
      throw StoryEngineConfigurationException(
        message: 'StoryProject entry event does not exist: $entryEventId.',
        operation: 'start',
        eventId: entryEventId,
        suggestion: 'Run StoryValidator.validate(project) and point '
            'entryEventId at an existing event.',
      );
    }

    final startState = initialState ?? StoryState.initial(project.stateSchema);
    if (startState.schema != project.stateSchema) {
      throw const StoryEngineOperationException(
        message: 'Initial StoryState schema does not match StoryProject schema.',
        operation: 'start',
        suggestion: 'Create the initial state from project.stateSchema, for '
            'example with StoryState.initial or StoryState.fromRawValues.',
      );
    }

    final transaction = _RuntimeTransaction(
      state: startState,
      status: StoryEngineStatus.notStarted,
      currentEvent: null,
      randomSource: _initialRandomSource.copy(),
      operation: 'start',
    );

    _runTransaction(transaction, () {
      _enterEvent(transaction, entryEventId);
    });

    _commit(transaction);
  }

  /// Selects one currently available choice by stable machine ID.
  ///
  /// Choice availability is checked against the current state. Choice effects
  /// are then applied in authored order, and the choice transition is resolved
  /// against that post-effect state before the destination event is entered.
  /// The operation is transactional for the current scalar-only runtime.
  void choose(StoryChoiceId choiceId) {
    if (_status == StoryEngineStatus.notStarted) {
      throw StoryEngineOperationException(
        message: 'Cannot choose before StoryEngine.start succeeds.',
        operation: 'choose',
        choiceId: choiceId,
        suggestion: 'Call start() successfully before selecting a choice.',
      );
    }
    if (_status == StoryEngineStatus.terminated) {
      throw StoryEngineOperationException(
        message: 'Cannot choose after the story has terminated.',
        operation: 'choose',
        choiceId: choiceId,
        suggestion: 'Create a new run or restore a non-terminated snapshot.',
      );
    }
    if (_status != StoryEngineStatus.awaitingChoice) {
      throw StoryEngineOperationException(
        message: 'Current event is not waiting for a choice selection.',
        operation: 'choose',
        eventId: _currentEvent?.id,
        choiceId: choiceId,
        suggestion: 'Inspect status/availableChoices and only call choose() '
            'while status is awaitingChoice.',
      );
    }

    final event = _currentEvent;
    final state = _state;
    final randomSource = _randomSource;
    if (event == null || state == null || randomSource == null) {
      throw StoryEngineExecutionException(
        message: 'Running StoryEngine state is internally incomplete.',
        operation: 'choose',
        eventId: event?.id,
        choiceId: choiceId,
        suggestion: 'Recreate the engine from the last committed snapshot or '
            'restart the run; this state indicates an internal invariant '
            'failure.',
      );
    }

    StoryChoice? selected;
    for (final choice in event.choices) {
      if (choice.id == choiceId) {
        selected = choice;
        break;
      }
    }
    if (selected == null) {
      throw StoryEngineOperationException(
        message: 'Choice $choiceId does not belong to current event ${event.id}.',
        operation: 'choose',
        eventId: event.id,
        choiceId: choiceId,
        suggestion: 'Choose one of the IDs returned by availableChoices for '
            'the current event.',
      );
    }

    final choice = selected;
    bool isAvailable;
    try {
      isAvailable = _isChoiceAvailable(choice, state);
    } catch (error) {
      if (error is StoryEngineException) {
        rethrow;
      }
      throw StoryEngineExecutionException(
        message: 'Failed to evaluate availability of choice ${choice.id}.',
        cause: error,
        operation: 'choose',
        eventId: event.id,
        choiceId: choice.id,
        suggestion: 'Validate the project and repair this choice condition '
            'before selecting it.',
      );
    }
    if (!isAvailable) {
      throw StoryEngineOperationException(
        message: 'Choice ${choice.id} is not currently available.',
        operation: 'choose',
        eventId: event.id,
        choiceId: choice.id,
        suggestion: 'Re-read availableChoices after state changes and only '
            'select a currently available choice.',
      );
    }

    final transition = choice.transition;
    if (transition == null) {
      throw StoryEngineConfigurationException(
        message: 'Choice ${choice.id} has no transition.',
        operation: 'choose',
        eventId: event.id,
        choiceId: choice.id,
        suggestion: 'Run StoryValidator.validate(project) and add a transition '
            'to this choice.',
      );
    }

    final transaction = _RuntimeTransaction(
      state: state,
      status: _status,
      currentEvent: event,
      randomSource: randomSource.copy(),
      operation: 'choose',
      choiceId: choice.id,
    );

    _runTransaction(transaction, () {
      transaction.pendingHistorySteps.add(
        StoryChoiceSelectedStep(eventId: event.id, choiceId: choice.id),
      );
      transaction.state = _effectExecutor.applyAll(
        choice.effects,
        transaction.state,
      );
      _resolveAndAdvance(transaction, transition);
    });

    _commit(transaction);
  }

  /// Continues from the current host-visible no-choice event.
  ///
  /// Continuation transitions are resolved against the state after the
  /// current event's entry effects. The operation is transactional: if the
  /// transition or destination traversal fails, the engine remains on the
  /// current continuation event and no continue-history step is committed.
  void continueStory() {
    if (_status == StoryEngineStatus.notStarted) {
      throw const StoryEngineOperationException(
        message: 'Cannot continue before StoryEngine.start succeeds.',
        operation: 'continueStory',
        suggestion: 'Call start() successfully before continuing.',
      );
    }
    if (_status == StoryEngineStatus.terminated) {
      throw const StoryEngineOperationException(
        message: 'Cannot continue after the story has terminated.',
        operation: 'continueStory',
        suggestion: 'Create a new run or restore a non-terminated snapshot.',
      );
    }
    if (_status != StoryEngineStatus.awaitingContinue) {
      throw StoryEngineOperationException(
        message: 'Current event is not waiting for a continue action.',
        operation: 'continueStory',
        eventId: _currentEvent?.id,
        suggestion: 'Inspect status and only call continueStory() while status '
            'is awaitingContinue.',
      );
    }

    final event = _currentEvent;
    final state = _state;
    final randomSource = _randomSource;
    if (event == null || state == null || randomSource == null) {
      throw StoryEngineExecutionException(
        message: 'Awaiting-continue StoryEngine state is internally incomplete.',
        operation: 'continueStory',
        eventId: event?.id,
        suggestion: 'Recreate the engine from the last committed snapshot or '
            'restart the run; this state indicates an internal invariant '
            'failure.',
      );
    }

    final transition = event.continuationTransition;
    if (transition == null) {
      throw StoryEngineConfigurationException(
        message: 'Event ${event.id} has no continuation transition.',
        operation: 'continueStory',
        eventId: event.id,
        suggestion: 'Run StoryValidator.validate(project) and add the missing '
            'continuation transition.',
      );
    }

    final transaction = _RuntimeTransaction(
      state: state,
      status: _status,
      currentEvent: event,
      randomSource: randomSource.copy(),
      operation: 'continueStory',
    );

    _runTransaction(transaction, () {
      transaction.pendingHistorySteps.add(
        StoryEventContinuedStep(eventId: event.id),
      );
      _resolveAndAdvance(transaction, transition);
    });

    _commit(transaction);
  }

  bool _isChoiceAvailable(StoryChoice choice, StoryState state) {
    final condition = choice.availabilityCondition;
    if (condition == null) {
      return true;
    }
    return _conditionEvaluator.evaluate(
      condition,
      StoryConditionContext(state: state),
    );
  }

  void _enterEvent(_RuntimeTransaction transaction, StoryEventId eventId) {
    var nextEventId = eventId;

    while (true) {
      final event = _eventIndex[nextEventId];
      if (event == null) {
        throw StoryEngineConfigurationException(
          message: 'Transition references missing event: $nextEventId.',
          operation: transaction.operation,
          eventId: nextEventId,
          choiceId: transaction.choiceId,
          suggestion: 'Run StoryValidator.validate(project) and repair the '
              'missing transition destination.',
        );
      }

      final hasChoices = event.choices.isNotEmpty;
      final hasContinuationTransition = event.continuationTransition != null;
      final hasAutomaticTransition = event.automaticTransition != null;
      final flowModeCount =
          (hasChoices ? 1 : 0) +
          (hasContinuationTransition ? 1 : 0) +
          (hasAutomaticTransition ? 1 : 0);
      if (flowModeCount != 1) {
        throw StoryEngineConfigurationException(
          message: flowModeCount == 0
              ? 'Event ${event.id} has no runtime flow. Add choices, a '
                    'continuation transition, or an automatic transition.'
              : 'Event ${event.id} is ambiguous: exactly one of choices, '
                    'continuation transition, or automatic transition may '
                    'define runtime flow.',
          operation: transaction.operation,
          eventId: event.id,
          choiceId: transaction.choiceId,
          suggestion: 'Run StoryValidator.validate(project) and keep exactly '
              'one valid flow mode for this event.',
        );
      }

      final eventCondition = event.availabilityCondition;
      if (eventCondition != null &&
          !_conditionEvaluator.evaluate(
            eventCondition,
            StoryConditionContext(state: transaction.state),
          )) {
        throw StoryEngineExecutionException(
          message: 'Event ${event.id} is not available in the incoming state.',
          operation: transaction.operation,
          eventId: event.id,
          choiceId: transaction.choiceId,
          suggestion: 'Check the transition/condition design or incoming state '
              'so runtime flow does not enter an unavailable event.',
        );
      }

      transaction.pendingHistorySteps.add(
        StoryEventEnteredStep(eventId: event.id),
      );
      transaction.currentEvent = event;
      transaction.state = _effectExecutor.applyAll(
        event.entryEffects,
        transaction.state,
      );

      if (hasChoices) {
        transaction.status = StoryEngineStatus.awaitingChoice;
        return;
      }

      final continuationTransition = event.continuationTransition;
      if (continuationTransition != null) {
        transaction.status = StoryEngineStatus.awaitingContinue;
        return;
      }

      final automaticTransition = event.automaticTransition!;
      transaction.automaticTransitions++;
      if (transaction.automaticTransitions > maxAutomaticTransitions) {
        throw StoryEngineExecutionException(
          message: 'Automatic flow exceeded the configured limit of '
              '$maxAutomaticTransitions transitions. This usually indicates '
              'an accidental non-interactive cycle.',
          operation: transaction.operation,
          eventId: event.id,
          choiceId: transaction.choiceId,
          suggestion: 'Run StoryValidator.validate(project) and break the '
              'automatic cycle, rather than only increasing the guard limit.',
        );
      }

      final resolution = _resolveTransition(
        transition: automaticTransition,
        transaction: transaction,
      );
      switch (resolution) {
        case StoryTerminalTransitionResolution():
          transaction.status = StoryEngineStatus.terminated;
          return;
        case StoryEventTransitionResolution(:final destinationEventId):
          nextEventId = destinationEventId;
          continue;
      }
    }
  }

  void _resolveAndAdvance(
    _RuntimeTransaction transaction,
    StoryTransition transition,
  ) {
    final resolution = _resolveTransition(
      transition: transition,
      transaction: transaction,
    );

    switch (resolution) {
      case StoryTerminalTransitionResolution():
        transaction.status = StoryEngineStatus.terminated;
        return;
      case StoryEventTransitionResolution(:final destinationEventId):
        _enterEvent(transaction, destinationEventId);
        return;
    }
  }

  StoryTransitionResolution _resolveTransition({
    required StoryTransition transition,
    required _RuntimeTransaction transaction,
  }) => _transitionResolver.resolve(
    transition: transition,
    context: StoryConditionContext(state: transaction.state),
    randomSource: transaction.randomSource,
  );

  void _runTransaction(
    _RuntimeTransaction transaction,
    void Function() action,
  ) {
    try {
      action();
    } catch (error) {
      if (error is StoryEngineException) {
        rethrow;
      }
      throw StoryEngineExecutionException(
        message: 'Story runtime execution failed.',
        cause: error,
        operation: transaction.operation,
        eventId: transaction.currentEvent?.id,
        choiceId: transaction.choiceId,
        suggestion: 'Inspect the underlying cause and run '
            'StoryValidator.validate(project) to locate authored logic errors.',
      );
    }
  }

  void _commit(_RuntimeTransaction transaction) {
    _state = transaction.state;
    _status = transaction.status;
    _currentEvent = transaction.currentEvent;
    _randomSource = transaction.randomSource;
    _historySteps.addAll(transaction.pendingHistorySteps);
  }
}

StorySeededRandomSource _restoreRandomSource(
  StoryRuntimeRandomState randomState,
) {
  if (randomState.algorithmId !=
      StorySeededRandomSource.runtimeStateAlgorithmId) {
    throw StoryRuntimeSnapshotCompatibilityException(
      issue: StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithm,
      path: r'$.randomState.algorithmId',
      message: 'Snapshot random algorithm ${randomState.algorithmId} is not '
          'supported by the current StoryEngine runtime.',
    );
  }
  if (randomState.algorithmVersion !=
      StorySeededRandomSource.runtimeStateAlgorithmVersion) {
    throw StoryRuntimeSnapshotCompatibilityException(
      issue: StoryRuntimeSnapshotCompatibilityIssue
          .unsupportedRandomAlgorithmVersion,
      path: r'$.randomState.algorithmVersion',
      message: 'Snapshot random algorithm version '
          '${randomState.algorithmVersion} is not supported for '
          '${randomState.algorithmId}.',
    );
  }

  try {
    return StorySeededRandomSource.restoreRuntimeState(randomState);
  } on StorySeededRandomStateException catch (error) {
    throw StoryRuntimeSnapshotCompatibilityException(
      issue: StoryRuntimeSnapshotCompatibilityIssue.invalidRandomState,
      path: r'$.randomState.stateWords',
      message: error.message,
    );
  }
}

Map<StoryEventId, StoryEvent> _buildEventIndex(StoryProject project) {
  final events = <StoryEventId, StoryEvent>{};
  for (final event in project.events) {
    if (events.containsKey(event.id)) {
      throw StoryEngineConfigurationException(
        message: 'StoryProject contains duplicate event ID ${event.id}.',
        operation: 'construct',
        eventId: event.id,
        suggestion: 'Run StoryValidator.validate(project) and assign every '
            'event a unique stable ID.',
      );
    }
    events[event.id] = event;
  }
  return Map<StoryEventId, StoryEvent>.unmodifiable(events);
}

void _validateChoiceIdentity(StoryProject project) {
  final seen = <StoryChoiceId>{};
  for (final event in project.events) {
    for (final choice in event.choices) {
      if (!seen.add(choice.id)) {
        throw StoryEngineConfigurationException(
          message: 'StoryProject contains duplicate choice ID ${choice.id}.',
          operation: 'construct',
          eventId: event.id,
          choiceId: choice.id,
          suggestion: 'Run StoryValidator.validate(project) and assign every '
              'choice a unique stable ID across the project.',
        );
      }
    }
  }
}

final class _RuntimeTransaction {
  _RuntimeTransaction({
    required this.state,
    required this.status,
    required this.currentEvent,
    required this.randomSource,
    required this.operation,
    this.choiceId,
  });

  StoryState state;
  StoryEngineStatus status;
  StoryEvent? currentEvent;
  StorySeededRandomSource randomSource;
  final String operation;
  final StoryChoiceId? choiceId;
  final List<StoryRuntimeStep> pendingHistorySteps = <StoryRuntimeStep>[];
  int automaticTransitions = 0;
}

/// Base exception for public StoryEngine lifecycle/configuration/execution
/// failures.
sealed class StoryEngineException implements Exception {
  const StoryEngineException({
    required this.message,
    this.cause,
    this.operation,
    this.eventId,
    this.choiceId,
    this.suggestion,
  });

  /// Human-readable failure explanation.
  final String message;

  /// Optional underlying authored/runtime failure.
  final Object? cause;

  /// Public engine operation being attempted, when known.
  ///
  /// Current engine-owned values include `construct`, `start`, `choose`,
  /// `continueStory`, `availableChoices`, and `createSnapshot`. Consumers should
  /// present this as context rather than using it as a compatibility enum.
  final String? operation;

  /// Most relevant event identity, when known.
  final StoryEventId? eventId;

  /// Most relevant choice identity, when known.
  final StoryChoiceId? choiceId;

  /// Actionable human-facing recovery guidance, when available.
  final String? suggestion;

  /// Compact machine-ID context suitable for logs and developer output.
  String get contextString {
    final parts = <String>[
      if (operation != null) 'operation=$operation',
      if (eventId != null) 'event=${eventId!.value}',
      if (choiceId != null) 'choice=${choiceId!.value}',
    ];
    return parts.join(', ');
  }

  @override
  String toString() {
    final context = contextString;
    final contextText = context.isEmpty ? '' : ' [$context]';
    final suggestionText = suggestion == null
        ? ''
        : ' Suggested fix: $suggestion';
    final cause = this.cause;
    final causeText = cause == null ? '' : ' Cause: $cause';
    return '$runtimeType$contextText: $message$suggestionText$causeText';
  }
}

/// Authored project structure is insufficient or contradictory for runtime.
final class StoryEngineConfigurationException extends StoryEngineException {
  const StoryEngineConfigurationException({
    required super.message,
    super.cause,
    super.operation,
    super.eventId,
    super.choiceId,
    super.suggestion,
  });
}

/// Caller attempted an operation that is invalid for the current lifecycle or
/// selected an unavailable/non-current choice.
final class StoryEngineOperationException extends StoryEngineException {
  const StoryEngineOperationException({
    required super.message,
    super.cause,
    super.operation,
    super.eventId,
    super.choiceId,
    super.suggestion,
  });
}

/// Runtime evaluation/execution failed while processing otherwise-addressable
/// authored content.
final class StoryEngineExecutionException extends StoryEngineException {
  const StoryEngineExecutionException({
    required super.message,
    super.cause,
    super.operation,
    super.eventId,
    super.choiceId,
    super.suggestion,
  });
}
