import '../condition/story_condition_context.dart';
import '../condition/story_condition_evaluator.dart';
import '../effect/story_effect.dart';
import '../effect/story_effect_executor.dart';
import '../explainability/story_decision_explanation.dart';
import '../explainability/story_runtime_execution_explanation.dart';
import '../validation/story_diagnostic_location.dart';
import '../explainability/story_effect_explanation.dart';
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
    required Map<StoryEventId, StoryEvent> eventIndex,
  }) : randomSeed = restoredRandomSource.initialSeed,
       maxAutomaticTransitions = snapshot.maxAutomaticTransitions,
       _eventIndex = eventIndex,
       _initialRandomSource = restoredRandomSource.copy() {
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
    final preparation = StoryRuntimeProjectPreparation.prepareForSnapshot(
      project: project,
      snapshot: snapshot,
    );
    preparation.validateSnapshotAfterPreflight(
      project: project,
      snapshot: snapshot,
    );
    return _restoreStoryEngineFromValidatedPreparation(
      project: project,
      snapshot: snapshot,
      preparation: preparation,
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
  List<StoryEffectExplanation> _lastEffectExplanations =
      const <StoryEffectExplanation>[];

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

  /// Effect explanations from the most recent diagnostics-enabled runtime
  /// operation.
  ///
  /// Successful diagnostic operations expose committed/no-op effects. If that
  /// operation throws after one or more effect attempts, this list remains
  /// available after the exception and marks earlier successful attempts as
  /// rolled back while preserving the failing effect as rejected. Ordinary
  /// [start], [startAt], [choose], and [continueStory] clear this value and do
  /// not allocate effect explanations.
  List<StoryEffectExplanation> get lastEffectExplanations =>
      _lastEffectExplanations;

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
        suggestion:
            'Recreate the engine from the last committed snapshot or '
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
        suggestion:
            'Recreate the engine from the last committed snapshot or '
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
        suggestion:
            'Validate the project and repair the failing choice '
            'condition before evaluating available choices.',
      );
    }
  }

  /// Structured availability explanations for every authored choice in order.
  ///
  /// Before start, while awaiting continue, and after termination this returns
  /// an empty immutable list, matching [availableChoices]. Unconditional
  /// choices are represented as available with a null condition explanation.
  /// Conditioned choices are evaluated exactly once for this diagnostic pass
  /// through [StoryConditionEvaluator.evaluateWithExplanation].
  ///
  /// This getter is observational only: it does not mutate story state, history,
  /// lifecycle status, or deterministic RNG state.
  List<StoryChoiceExplanation> get choiceExplanations {
    if (_status != StoryEngineStatus.awaitingChoice) {
      return const [];
    }

    final event = _currentEvent;
    final state = _state;
    if (event == null || state == null) {
      throw const StoryEngineExecutionException(
        message: 'Engine awaiting-choice state is internally incomplete.',
        operation: 'choiceExplanations',
        suggestion:
            'Recreate the engine from the last committed snapshot or '
            'restart the run; this state indicates an internal invariant '
            'failure.',
      );
    }

    try {
      return List<StoryChoiceExplanation>.unmodifiable(
        event.choices.map(
          (choice) => _explainChoiceAvailability(
            eventId: event.id,
            choice: choice,
            state: state,
          ),
        ),
      );
    } catch (error) {
      if (error is StoryEngineException) {
        rethrow;
      }
      throw StoryEngineExecutionException(
        message: 'Failed to explain available choices for ${event.id}.',
        cause: error,
        operation: 'choiceExplanations',
        eventId: event.id,
        suggestion:
            'Validate the project and repair the failing choice '
            'condition before requesting choice explanations.',
      );
    }
  }

  /// Last opt-in execution attempt, or null after ordinary/effect-only input.
  /// Restore starts without an explanation; saved execution is never replayed.
  StoryRuntimeExecutionExplanation? get lastExecutionExplanation =>
      _lastExecutionExplanation;

  StoryRuntimeExecutionExplanation? _lastExecutionExplanation;

  /// Executes start once and returns its causal trace.
  StoryRuntimeExecutionExplanation startWithExplanations({
    StoryState? initialState,
  }) => _captureRuntimeExecution(
    'start',
    (steps) => _startFromProjectEntry(
      initialState: initialState,
      collectEffectExplanations: true,
      explanationSteps: steps,
    ),
  );

  /// Executes an explicit start once and returns its causal trace.
  StoryRuntimeExecutionExplanation startAtWithExplanations(
    StoryEventId entryEventId, {
    StoryState? initialState,
  }) => _captureRuntimeExecution(
    'startAt',
    (steps) => _startAt(
      entryEventId: entryEventId,
      initialState: initialState,
      operation: 'startAt',
      collectEffectExplanations: true,
      explanationSteps: steps,
    ),
  );

  /// Selects a choice once and returns its causal trace.
  StoryRuntimeExecutionExplanation chooseWithExplanations(
    StoryChoiceId choiceId,
  ) => _captureRuntimeExecution(
    'choose',
    (steps) => _choose(
      choiceId,
      collectEffectExplanations: true,
      explanationSteps: steps,
    ),
  );

  /// Continues once and returns its causal trace.
  StoryRuntimeExecutionExplanation continueStoryWithExplanations() =>
      _captureRuntimeExecution(
        'continueStory',
        (steps) => _continueStory(
          collectEffectExplanations: true,
          explanationSteps: steps,
        ),
      );

  StoryRuntimeExecutionExplanation _captureRuntimeExecution(
    String operation,
    List<StoryEffectExplanation> Function(List<StoryRuntimeExplanationStep>)
    action,
  ) {
    final steps = <StoryRuntimeExplanationStep>[];
    try {
      action(steps);
      return _lastExecutionExplanation = StoryRuntimeExecutionExplanation(
        operation: operation,
        outcome: StoryRuntimeExecutionOutcome.committed,
        steps: steps,
      );
    } on Object {
      _lastExecutionExplanation = StoryRuntimeExecutionExplanation(
        operation: operation,
        outcome: StoryRuntimeExecutionOutcome.rolledBack,
        steps: steps,
      );
      rethrow;
    }
  }

  /// Starts traversal at [StoryProject.entryEventId].
  ///
  /// This preserves the original single-run contract. Host-driven systems that
  /// already resolved a local narrative entry may instead call [startAt].
  void start({StoryState? initialState}) {
    _startFromProjectEntry(
      initialState: initialState,
      collectEffectExplanations: false,
    );
  }

  /// Starts traversal while returning explanations for effects actually run.
  ///
  /// This executes the same transaction as [start]. The returned explanations
  /// are committed/no-op outcomes from that transaction. If the operation
  /// throws, inspect [lastEffectExplanations] for rejected/rolled-back attempts;
  /// the authoritative exception itself is unchanged.
  List<StoryEffectExplanation> startWithEffectExplanations({
    StoryState? initialState,
  }) => _startFromProjectEntry(
    initialState: initialState,
    collectEffectExplanations: true,
  );

  List<StoryEffectExplanation> _startFromProjectEntry({
    required StoryState? initialState,
    required bool collectEffectExplanations,
    List<StoryRuntimeExplanationStep>? explanationSteps,
  }) {
    _lastExecutionExplanation = null;
    _lastEffectExplanations = const <StoryEffectExplanation>[];
    if (_status != StoryEngineStatus.notStarted) {
      throw const StoryEngineOperationException(
        message: 'StoryEngine.start may only be called once.',
        operation: 'start',
        suggestion:
            'Create a new StoryEngine for a fresh run, or restore a '
            'saved snapshot instead of starting this instance again.',
      );
    }

    final entryEventId = project.entryEventId;
    if (entryEventId == null) {
      throw const StoryEngineConfigurationException(
        message: 'StoryProject has no entryEventId and cannot be started.',
        operation: 'start',
        suggestion:
            'Run StoryValidator.validate(project) and set entryEventId '
            'to an authored event before starting.',
      );
    }
    return _startAt(
      entryEventId: entryEventId,
      initialState: initialState,
      operation: 'start',
      collectEffectExplanations: collectEffectExplanations,
      explanationSteps: explanationSteps,
      resetEffectExplanations: false,
    );
  }

  /// Starts one fresh run at an explicitly host-selected [entryEventId].
  ///
  /// Stage 8G adds this minimal activation primitive so a higher-level
  /// narrative-session runtime can begin unrelated local dialogue/event flows
  /// without cloning the authored project or requiring a graph edge from the
  /// previously executed event. It does not alter [StoryProject.entryEventId]
  /// and may still be called only while this engine is `notStarted`.
  ///
  /// If [initialState] is omitted, the project's declared initial scalar state
  /// is used. The supplied state must use exactly the project's state schema.
  /// Start is transactional: if event availability, entry effects, transition
  /// resolution, or automatic flow fails, this engine remains not started and
  /// its deterministic random stream remains untouched.
  void startAt(StoryEventId entryEventId, {StoryState? initialState}) {
    _startAt(
      entryEventId: entryEventId,
      initialState: initialState,
      operation: 'startAt',
      collectEffectExplanations: false,
    );
  }

  /// Starts at [entryEventId] while returning actual effect explanations.
  ///
  /// This is the diagnostics-enabled counterpart to [startAt]. It performs one
  /// authoritative transaction and never replays effects merely to explain
  /// them. Failure details remain available through [lastEffectExplanations].
  List<StoryEffectExplanation> startAtWithEffectExplanations(
    StoryEventId entryEventId, {
    StoryState? initialState,
  }) => _startAt(
    entryEventId: entryEventId,
    initialState: initialState,
    operation: 'startAt',
    collectEffectExplanations: true,
  );

  List<StoryEffectExplanation> _startAt({
    required StoryEventId entryEventId,
    required StoryState? initialState,
    required String operation,
    required bool collectEffectExplanations,
    List<StoryRuntimeExplanationStep>? explanationSteps,
    bool resetEffectExplanations = true,
  }) {
    _lastExecutionExplanation = null;
    if (resetEffectExplanations) {
      _lastEffectExplanations = const <StoryEffectExplanation>[];
    }
    if (_status != StoryEngineStatus.notStarted) {
      throw StoryEngineOperationException(
        message: 'StoryEngine.$operation may only be called once.',
        operation: operation,
        eventId: entryEventId,
        suggestion:
            'Create a new StoryEngine for a fresh run, or restore a '
            'saved snapshot instead of starting this instance again.',
      );
    }

    if (!_eventIndex.containsKey(entryEventId)) {
      throw StoryEngineConfigurationException(
        message: 'StoryProject entry event does not exist: $entryEventId.',
        operation: operation,
        eventId: entryEventId,
        suggestion:
            'Run StoryValidator.validate(project) and activate an '
            'existing event.',
      );
    }

    final startState = initialState ?? StoryState.initial(project.stateSchema);
    if (startState.schema != project.stateSchema) {
      throw StoryEngineOperationException(
        message:
            'Initial StoryState schema does not match StoryProject schema.',
        operation: operation,
        eventId: entryEventId,
        suggestion:
            'Create the initial state from project.stateSchema, for '
            'example with StoryState.initial or StoryState.fromRawValues.',
      );
    }

    final transaction = _RuntimeTransaction(
      state: startState,
      status: StoryEngineStatus.notStarted,
      currentEvent: null,
      randomSource: _initialRandomSource.copy(),
      operation: operation,
      collectEffectExplanations: collectEffectExplanations,
      explanationSteps: explanationSteps,
    );

    _runTransaction(transaction, () {
      _enterEvent(transaction, entryEventId);
    });

    _commit(transaction);
    return _completeEffectExplanationCapture(transaction);
  }

  /// Selects one currently available choice by stable machine ID.
  ///
  /// Choice availability is checked against the current state. Choice effects
  /// are then applied in authored order, and the choice transition is resolved
  /// against that post-effect state before the destination event is entered.
  /// The operation is transactional for the current scalar-only runtime.
  void choose(StoryChoiceId choiceId) {
    _choose(choiceId, collectEffectExplanations: false);
  }

  /// Selects [choiceId] and returns explanations for every effect actually run.
  ///
  /// The diagnostic path shares the authoritative transaction with [choose].
  /// If later execution fails, the same exception is thrown and
  /// [lastEffectExplanations] records rejected/rolled-back effect attempts.
  List<StoryEffectExplanation> chooseWithEffectExplanations(
    StoryChoiceId choiceId,
  ) => _choose(choiceId, collectEffectExplanations: true);

  List<StoryEffectExplanation> _choose(
    StoryChoiceId choiceId, {
    required bool collectEffectExplanations,
    List<StoryRuntimeExplanationStep>? explanationSteps,
  }) {
    _lastExecutionExplanation = null;
    _lastEffectExplanations = const <StoryEffectExplanation>[];
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
        suggestion:
            'Inspect status/availableChoices and only call choose() '
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
        suggestion:
            'Recreate the engine from the last committed snapshot or '
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
        message:
            'Choice $choiceId does not belong to current event ${event.id}.',
        operation: 'choose',
        eventId: event.id,
        choiceId: choiceId,
        suggestion:
            'Choose one of the IDs returned by availableChoices for '
            'the current event.',
      );
    }

    final choice = selected;
    bool isAvailable;
    try {
      if (explanationSteps == null) {
        isAvailable = _isChoiceAvailable(choice, state);
      } else {
        final condition = choice.availabilityCondition;
        final evaluation = condition == null
            ? null
            : evaluateStoryConditionWithExplanationResult(
                _conditionEvaluator,
                condition,
                StoryConditionContext(state: state),
              );
        isAvailable = evaluation?.result ?? true;
        explanationSteps.add(
          StoryRuntimeChoiceExplanation(
            StoryChoiceExplanation(
              eventId: event.id,
              choiceId: choice.id,
              available: isAvailable,
              condition: evaluation?.explanation,
            ),
          ),
        );
      }
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
        suggestion:
            'Validate the project and repair this choice condition '
            'before selecting it.',
      );
    }
    if (!isAvailable) {
      throw StoryEngineOperationException(
        message: 'Choice ${choice.id} is not currently available.',
        operation: 'choose',
        eventId: event.id,
        choiceId: choice.id,
        suggestion:
            'Re-read availableChoices after state changes and only '
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
        suggestion:
            'Run StoryValidator.validate(project) and add a transition '
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
      collectEffectExplanations: collectEffectExplanations,
      explanationSteps: explanationSteps,
    );

    _runTransaction(transaction, () {
      transaction.pendingHistorySteps.add(
        StoryChoiceSelectedStep(eventId: event.id, choiceId: choice.id),
      );
      transaction.state = _applyEffects(
        transaction: transaction,
        effects: choice.effects,
        source: StoryEffectSource.choice(
          eventId: event.id,
          choiceId: choice.id,
        ),
      );
      _resolveAndAdvance(transaction, transition);
    });

    _commit(transaction);
    return _completeEffectExplanationCapture(transaction);
  }

  /// Continues from the current host-visible no-choice event.
  ///
  /// Continuation transitions are resolved against the state after the
  /// current event's entry effects. The operation is transactional: if the
  /// transition or destination traversal fails, the engine remains on the
  /// current continuation event and no continue-history step is committed.
  void continueStory() {
    _continueStory(collectEffectExplanations: false);
  }

  /// Continues and returns explanations for destination entry effects run by
  /// the authoritative transaction.
  ///
  /// If execution fails after any effect attempt, the same exception is thrown
  /// and [lastEffectExplanations] retains rejected/rolled-back diagnostics.
  List<StoryEffectExplanation> continueStoryWithEffectExplanations() =>
      _continueStory(collectEffectExplanations: true);

  List<StoryEffectExplanation> _continueStory({
    required bool collectEffectExplanations,
    List<StoryRuntimeExplanationStep>? explanationSteps,
  }) {
    _lastExecutionExplanation = null;
    _lastEffectExplanations = const <StoryEffectExplanation>[];
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
        suggestion:
            'Inspect status and only call continueStory() while status '
            'is awaitingContinue.',
      );
    }

    final event = _currentEvent;
    final state = _state;
    final randomSource = _randomSource;
    if (event == null || state == null || randomSource == null) {
      throw StoryEngineExecutionException(
        message:
            'Awaiting-continue StoryEngine state is internally incomplete.',
        operation: 'continueStory',
        eventId: event?.id,
        suggestion:
            'Recreate the engine from the last committed snapshot or '
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
        suggestion:
            'Run StoryValidator.validate(project) and add the missing '
            'continuation transition.',
      );
    }

    final transaction = _RuntimeTransaction(
      state: state,
      status: _status,
      currentEvent: event,
      randomSource: randomSource.copy(),
      operation: 'continueStory',
      collectEffectExplanations: collectEffectExplanations,
      explanationSteps: explanationSteps,
    );

    _runTransaction(transaction, () {
      transaction.pendingHistorySteps.add(
        StoryEventContinuedStep(eventId: event.id),
      );
      _resolveAndAdvance(transaction, transition);
    });

    _commit(transaction);
    return _completeEffectExplanationCapture(transaction);
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

  StoryChoiceExplanation _explainChoiceAvailability({
    required StoryEventId eventId,
    required StoryChoice choice,
    required StoryState state,
  }) {
    final condition = choice.availabilityCondition;
    if (condition == null) {
      return StoryChoiceExplanation(
        eventId: eventId,
        choiceId: choice.id,
        available: true,
      );
    }

    final explanation = _conditionEvaluator.evaluateWithExplanation(
      condition,
      StoryConditionContext(state: state),
    );
    return StoryChoiceExplanation(
      eventId: eventId,
      choiceId: choice.id,
      available: explanation.result,
      condition: explanation,
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
          suggestion:
              'Run StoryValidator.validate(project) and repair the '
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
          suggestion:
              'Run StoryValidator.validate(project) and keep exactly '
              'one valid flow mode for this event.',
        );
      }

      final eventCondition = event.availabilityCondition;
      bool available;
      if (transaction.explanationSteps == null) {
        available =
            eventCondition == null ||
            _conditionEvaluator.evaluate(
              eventCondition,
              StoryConditionContext(state: transaction.state),
            );
      } else {
        final condition = eventCondition == null
            ? null
            : evaluateStoryConditionWithExplanationResult(
                _conditionEvaluator,
                eventCondition,
                StoryConditionContext(state: transaction.state),
              );
        final explanation = StoryEventAvailabilityExplanation(
          eventId: event.id,
          condition: condition?.explanation,
        );
        transaction.explanationSteps!.add(explanation);
        available = condition?.result ?? true;
      }
      if (!available) {
        throw StoryEngineExecutionException(
          message: 'Event ${event.id} is not available in the incoming state.',
          operation: transaction.operation,
          eventId: event.id,
          choiceId: transaction.choiceId,
          suggestion:
              'Check the transition/condition design or incoming state '
              'so runtime flow does not enter an unavailable event.',
        );
      }

      transaction.pendingHistorySteps.add(
        StoryEventEnteredStep(eventId: event.id),
      );
      transaction.currentEvent = event;
      transaction.state = _applyEffects(
        transaction: transaction,
        effects: event.entryEffects,
        source: StoryEffectSource.eventEntry(eventId: event.id),
      );

      transaction.explanationSteps?.add(
        StoryEventTraversalExplanation(
          eventId: event.id,
          flow: hasChoices
              ? StoryRuntimeEventFlow.choice
              : hasContinuationTransition
              ? StoryRuntimeEventFlow.continuation
              : StoryRuntimeEventFlow.automatic,
        ),
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
      transaction.explanationSteps?.add(
        StoryAutomaticTraversalExplanation(
          eventId: event.id,
          transitionNumber: transaction.automaticTransitions,
          maximumTransitions: maxAutomaticTransitions,
        ),
      );
      if (transaction.automaticTransitions > maxAutomaticTransitions) {
        throw StoryEngineExecutionException(
          message:
              'Automatic flow exceeded the configured limit of '
              '$maxAutomaticTransitions transitions. This usually indicates '
              'an accidental non-interactive cycle.',
          operation: transaction.operation,
          eventId: event.id,
          choiceId: transaction.choiceId,
          suggestion:
              'Run StoryValidator.validate(project) and break the '
              'automatic cycle, rather than only increasing the guard limit.',
        );
      }

      final resolution = _resolveTransition(
        transition: automaticTransition,
        transaction: transaction,
        transitionField: 'automaticTransition',
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
      transitionField: transaction.choiceId == null
          ? 'continuationTransition'
          : 'transition',
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
    required String transitionField,
  }) => _transitionResolver.resolve(
    transition: transition,
    context: StoryConditionContext(state: transaction.state),
    randomSource: transaction.randomSource,
    onExplanation: transaction.explanationSteps?.add,
    explanationLocation: transaction.explanationSteps == null
        ? null
        : _transitionLocation(transaction, transitionField),
  );

  StoryDiagnosticLocation _transitionLocation(
    _RuntimeTransaction transaction,
    String transitionField,
  ) {
    final event = transaction.currentEvent!;
    final choiceId = transitionField == 'transition'
        ? transaction.choiceId
        : null;
    return StoryDiagnosticLocation.transition(
      projectId: project.id,
      eventId: event.id,
      choiceId: choiceId,
      path: [
        const StoryDiagnosticPathSegment.field('events'),
        StoryDiagnosticPathSegment.index(project.events.indexOf(event)),
        if (choiceId != null) ...[
          const StoryDiagnosticPathSegment.field('choices'),
          StoryDiagnosticPathSegment.index(
            event.choices.indexWhere((choice) => choice.id == choiceId),
          ),
        ],
        StoryDiagnosticPathSegment.field(transitionField),
      ],
    );
  }

  StoryState _applyEffects({
    required _RuntimeTransaction transaction,
    required Iterable<StoryEffect> effects,
    required StoryEffectSource source,
  }) {
    if (!transaction.collectEffectExplanations) {
      return _effectExecutor.applyAll(effects, transaction.state);
    }
    final firstEffect = transaction.pendingEffectExplanations.length;
    try {
      return _effectExecutor.applyAllWithExplanations(
        effects: effects,
        state: transaction.state,
        source: source,
        explanations: transaction.pendingEffectExplanations,
      );
    } finally {
      final steps = transaction.explanationSteps;
      if (steps != null) {
        for (
          var index = firstEffect;
          index < transaction.pendingEffectExplanations.length;
          index++
        ) {
          steps.add(
            StoryRuntimeEffectExplanation(
              transaction.pendingEffectExplanations[index],
            ),
          );
        }
      }
    }
  }

  List<StoryEffectExplanation> _completeEffectExplanationCapture(
    _RuntimeTransaction transaction,
  ) {
    if (!transaction.collectEffectExplanations) {
      _lastEffectExplanations = const <StoryEffectExplanation>[];
      return const <StoryEffectExplanation>[];
    }
    final completed = List<StoryEffectExplanation>.unmodifiable(
      transaction.pendingEffectExplanations,
    );
    _lastEffectExplanations = completed;
    return completed;
  }

  void _retainRolledBackEffectExplanations(_RuntimeTransaction transaction) {
    if (!transaction.collectEffectExplanations ||
        transaction.pendingEffectExplanations.isEmpty) {
      _lastEffectExplanations = const <StoryEffectExplanation>[];
      return;
    }

    final failed = <StoryEffectExplanation>[
      for (final explanation in transaction.pendingEffectExplanations)
        explanation.outcome == StoryEffectOutcome.rejected
            ? explanation
            : StoryEffectExplanation(
                source: explanation.source,
                authoredIndex: explanation.authoredIndex,
                variableId: explanation.variableId,
                operation: explanation.operation,
                operand: explanation.operand,
                beforeValue: explanation.beforeValue,
                afterValue: explanation.afterValue,
                outcome: StoryEffectOutcome.rolledBack,
              ),
    ];
    _lastEffectExplanations = List<StoryEffectExplanation>.unmodifiable(failed);
  }

  void _runTransaction(
    _RuntimeTransaction transaction,
    void Function() action,
  ) {
    try {
      action();
    } catch (error) {
      _retainRolledBackEffectExplanations(transaction);
      if (error is StoryEngineException) {
        rethrow;
      }
      throw StoryEngineExecutionException(
        message: 'Story runtime execution failed.',
        cause: error,
        operation: transaction.operation,
        eventId: transaction.currentEvent?.id,
        choiceId: transaction.choiceId,
        suggestion:
            'Inspect the underlying cause and run '
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

/// Internal O(1) checkpoint for one orchestration-owned core mutation.
///
/// This is deliberately not exported from the package root. It retains only
/// immutable/reference-stable committed fields plus the pre-operation history
/// length. If orchestration rollback is ever required, a normal immutable
/// [StoryRuntimeSnapshot] is materialized lazily from the retained prefix and
/// then restored through the validated public restore path.
final class StoryEngineMutationCheckpoint {
  StoryEngineMutationCheckpoint._({
    required StoryEngine engine,
    required StoryEngineStatus status,
    required StoryState? state,
    required StoryEvent? currentEvent,
    required StorySeededRandomSource? randomSource,
    required this.historyLength,
  }) : _engine = engine,
       _status = status,
       _state = state,
       _currentEvent = currentEvent,
       _randomSource = randomSource;

  final StoryEngine _engine;
  final StoryEngineStatus _status;
  final StoryState? _state;
  final StoryEvent? _currentEvent;
  final StorySeededRandomSource? _randomSource;

  /// Number of committed history steps before the guarded mutation.
  final int historyLength;
}

/// Captures the constant-size committed fields required to reconstruct the
/// pre-operation snapshot if orchestration propagation later fails.
///
/// The core engine itself is transactional: choose/continue run against copied
/// RNG/state and append history only on commit. Consequently the references
/// stored here remain valid representations of the previous committed state.
StoryEngineMutationCheckpoint captureStoryEngineMutationCheckpoint(
  StoryEngine engine,
) => StoryEngineMutationCheckpoint._(
  engine: engine,
  status: engine._status,
  state: engine._state,
  currentEvent: engine._currentEvent,
  randomSource: engine._randomSource,
  historyLength: engine._historySteps.length,
);

/// Materializes the pre-operation immutable snapshot represented by
/// [checkpoint].
///
/// This copies the retained history prefix only on the exceptional rollback
/// path. Ordinary successful orchestration operations therefore avoid copying
/// the entire committed history solely for rollback preparedness.
StoryRuntimeSnapshot materializeStoryEngineMutationCheckpoint(
  StoryEngine engine,
  StoryEngineMutationCheckpoint checkpoint,
) {
  if (!identical(engine, checkpoint._engine)) {
    throw StateError(
      'A StoryEngine mutation checkpoint may only be materialized for the '
      'engine instance that created it.',
    );
  }
  if (checkpoint.historyLength < 0 ||
      checkpoint.historyLength > engine._historySteps.length) {
    throw StateError(
      'StoryEngine history no longer contains the checkpoint prefix.',
    );
  }

  final randomSource = checkpoint._status == StoryEngineStatus.notStarted
      ? engine._initialRandomSource
      : checkpoint._randomSource;
  if (randomSource == null) {
    throw StateError(
      'A started StoryEngine mutation checkpoint has no committed RNG state.',
    );
  }

  return StoryRuntimeSnapshot(
    projectId: engine.project.id,
    status: checkpoint._status,
    state: checkpoint._state,
    currentEventId: checkpoint._currentEvent?.id,
    history: StoryRuntimeHistory(
      steps: engine._historySteps.getRange(0, checkpoint.historyLength),
    ),
    randomState: randomSource.createRuntimeState(),
    maxAutomaticTransitions: engine.maxAutomaticTransitions,
  );
}

/// Internal committed-history length without allocating a public history
/// snapshot.
int storyEngineCommittedHistoryLength(StoryEngine engine) =>
    engine._historySteps.length;

/// Internal indexed access to one immutable committed history step.
///
/// Narrative observation delivery is serialized and re-entry is rejected, so
/// the engine cannot mutate the history list while orchestration walks the
/// newly committed suffix.
StoryRuntimeStep storyEngineCommittedHistoryStepAt(
  StoryEngine engine,
  int index,
) => engine._historySteps[index];

/// Internal restore path that reuses project-derived immutable lookup data.
///
/// The preparation is bound to the exact supplied [StoryProject] instance.
/// Snapshot-specific lifecycle, state, history, RNG, and current-event
/// validation still runs for every restore. This helper is intentionally not
/// exported from the package root.
StoryEngine restoreStoryEngineWithProjectPreparation({
  required StoryProject project,
  required StoryRuntimeSnapshot snapshot,
  required StoryRuntimeProjectPreparation preparation,
}) {
  preparation.validateSnapshot(project: project, snapshot: snapshot);
  return _restoreStoryEngineFromValidatedPreparation(
    project: project,
    snapshot: snapshot,
    preparation: preparation,
  );
}

StoryEngine _restoreStoryEngineFromValidatedPreparation({
  required StoryProject project,
  required StoryRuntimeSnapshot snapshot,
  required StoryRuntimeProjectPreparation preparation,
}) {
  final restoredRandomSource = _restoreRandomSource(snapshot.randomState);
  return StoryEngine._restored(
    project: project,
    snapshot: snapshot,
    restoredRandomSource: restoredRandomSource,
    eventIndex: preparation.eventLookup,
  );
}

StorySeededRandomSource _restoreRandomSource(
  StoryRuntimeRandomState randomState,
) {
  if (randomState.algorithmId !=
      StorySeededRandomSource.runtimeStateAlgorithmId) {
    throw StoryRuntimeSnapshotCompatibilityException(
      issue: StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithm,
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
        suggestion:
            'Run StoryValidator.validate(project) and assign every '
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
          suggestion:
              'Run StoryValidator.validate(project) and assign every '
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
    required this.collectEffectExplanations,
    this.choiceId,
    this.explanationSteps,
  });

  StoryState state;
  StoryEngineStatus status;
  StoryEvent? currentEvent;
  StorySeededRandomSource randomSource;
  final String operation;
  final bool collectEffectExplanations;
  final List<StoryRuntimeExplanationStep>? explanationSteps;
  final StoryChoiceId? choiceId;
  final List<StoryRuntimeStep> pendingHistorySteps = <StoryRuntimeStep>[];
  final List<StoryEffectExplanation> pendingEffectExplanations =
      <StoryEffectExplanation>[];
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
  /// Current engine-owned values include `construct`, `start`, `startAt`,
  /// `choose`, `continueStory`, `availableChoices`, and `createSnapshot`.
  /// Consumers should
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
