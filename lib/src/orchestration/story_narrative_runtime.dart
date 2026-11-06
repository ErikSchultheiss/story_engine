import '../condition/story_condition_context.dart';
import '../condition/story_condition_evaluator.dart';
import '../explainability/story_condition_explanation.dart';
import '../explainability/story_decision_explanation.dart';
import '../explainability/story_effect_explanation.dart';
import '../explainability/story_runtime_execution_explanation.dart';
import '../identity/story_choice_id.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_host_action_request_id.dart';
import '../host_action/story_host_action.dart';
import '../host_action/story_host_action_protocol.dart';
import '../model/story_choice.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../observability/story_narrative_observer.dart';
import '../runtime/story_engine.dart';
import '../runtime/story_engine_status.dart';
import '../runtime/story_runtime_history.dart';
import '../runtime/story_runtime_snapshot.dart';
import '../runtime/story_runtime_snapshot_validator.dart';
import '../runtime/story_seeded_random_source.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';
import 'story_entry_point.dart';
import 'story_narrative_input.dart';
import 'story_narrative_runtime_snapshot.dart';
import 'story_narrative_runtime_snapshot_validator.dart';

/// Temporary Stage 9D5 diagnostic strategy for isolating rollback-history cost.
///
/// This enum is intentionally not exported from the package root. It exists so
/// the Stage 9D5 A/B benchmark can compare rollback preparation and committed-
/// history observation independently in one source revision.
enum StoryNarrativeRuntimeHistoryStrategy {
  eagerCopied,
  eagerIndexed,
  lazyCopied,
  lazyIndexed,
  selectiveIndexed,
  hybridIndexed,
}

/// Internal Stage 9D6B fault/probe seam for exceptional rollback tests.
///
/// This is intentionally absent from the package root. Normal runtimes never
/// install a probe, so production semantics remain unchanged. The seam lets
/// white-box tests fail sibling propagation only after one or more real sibling
/// replacements have already been prepared and observe the rollback sequence
/// without replacing the validated restore implementation itself.
final class Stage9d6RollbackTestProbe {
  Stage9d6RollbackTestProbe._({
    required this.failAfterPreparedSiblingCount,
    this.rollbackSnapshotTransform,
  });

  final int failAfterPreparedSiblingCount;
  final StoryRuntimeSnapshot Function(StoryRuntimeSnapshot snapshot)?
  rollbackSnapshotTransform;

  int selectiveRollbackMaterializationCount = 0;
  int preparedSiblingReplacementCount = 0;
  int rollbackRestoreAttemptCount = 0;
  final List<String> _events = <String>[];

  List<String> get events => List<String>.unmodifiable(_events);
}

extension on StoryNarrativeRuntimeHistoryStrategy {
  bool eagerRollbackFor(int activeSessionCount) => switch (this) {
    StoryNarrativeRuntimeHistoryStrategy.eagerCopied ||
    StoryNarrativeRuntimeHistoryStrategy.eagerIndexed => true,
    StoryNarrativeRuntimeHistoryStrategy.lazyCopied ||
    StoryNarrativeRuntimeHistoryStrategy.lazyIndexed ||
    StoryNarrativeRuntimeHistoryStrategy.selectiveIndexed => false,
    StoryNarrativeRuntimeHistoryStrategy.hybridIndexed =>
      activeSessionCount > 1,
  };

  bool get materializesRollbackBeforeSharedPropagation =>
      this == StoryNarrativeRuntimeHistoryStrategy.selectiveIndexed;

  bool get usesIndexedHistory => switch (this) {
    StoryNarrativeRuntimeHistoryStrategy.eagerCopied ||
    StoryNarrativeRuntimeHistoryStrategy.lazyCopied => false,
    StoryNarrativeRuntimeHistoryStrategy.eagerIndexed ||
    StoryNarrativeRuntimeHistoryStrategy.lazyIndexed ||
    StoryNarrativeRuntimeHistoryStrategy.selectiveIndexed ||
    StoryNarrativeRuntimeHistoryStrategy.hybridIndexed => true,
  };
}

typedef _PreparedChoicePresentation = ({
  List<StoryChoice> choices,
  List<StoryChoiceExplanation>? explanations,
});

/// Coordinates host-driven activation of independent local narrative sessions.
///
/// Stage 8J permits multiple logically active sessions while preserving one
/// deterministic execution authority for shared persistent state. The host owns
/// world traversal and explicit input order; this runtime owns deterministic
/// entry resolution, atomic persistent-state commits, per-session execution,
/// and session-boundary history. Inputs within one runtime are serialized rather
/// than resolved by wall-clock or scheduler races.
final class StoryNarrativeRuntime {
  factory StoryNarrativeRuntime({
    required StoryProject project,
    required Iterable<StoryEntryPoint> entryPoints,
    StoryState? initialState,
    int randomSeed = StoryEngine.defaultRandomSeed,
    int maxAutomaticTransitions = StoryEngine.defaultMaxAutomaticTransitions,
    Iterable<StoryNarrativeObserver> observers = const [],
    StoryNarrativeDebugAdapter? debugAdapter,
  }) {
    final copiedEntryPoints = List<StoryEntryPoint>.unmodifiable(entryPoints);
    final eventIds = <StoryEventId>{
      for (final event in project.events) event.id,
    };
    final seenEntryPointIds = <StoryEntryPointId>{};
    final hostRequirements =
        <StoryHostConditionKey, StoryHostConditionRequirement>{};
    for (final entryPoint in copiedEntryPoints) {
      if (!seenEntryPointIds.add(entryPoint.id)) {
        throw StoryNarrativeConfigurationException(
          message: 'Duplicate narrative entry-point ID ${entryPoint.id}.',
        );
      }
      if (!eventIds.contains(entryPoint.eventId)) {
        throw StoryNarrativeConfigurationException(
          message:
              'Entry point ${entryPoint.id} targets missing event '
              '${entryPoint.eventId}.',
        );
      }
      for (final requirement in entryPoint.hostConditions) {
        final previous = hostRequirements[requirement.key];
        if (previous != null &&
            !_sameHostConditionRequest(previous, requirement)) {
          throw StoryNarrativeConfigurationException(
            message:
                'Host-condition key ${requirement.key} identifies '
                'conflicting condition requests across entry points.',
          );
        }
        hostRequirements[requirement.key] = requirement;
      }
    }

    final state = initialState ?? StoryState.initial(project.stateSchema);
    if (state.schema != project.stateSchema) {
      throw const StoryNarrativeConfigurationException(
        message: 'Initial persistent state schema does not match the project.',
      );
    }
    if (maxAutomaticTransitions <= 0) {
      throw ArgumentError.value(
        maxAutomaticTransitions,
        'maxAutomaticTransitions',
        'Automatic transition limit must be greater than zero.',
      );
    }

    return StoryNarrativeRuntime._(
      project: project,
      entryPoints: copiedEntryPoints,
      persistentState: state,
      randomSeed: randomSeed,
      maxAutomaticTransitions: maxAutomaticTransitions,
      orchestrationRandomSource: StorySeededRandomSource.fromSeed(randomSeed),
      observers: List<StoryNarrativeObserver>.unmodifiable(observers),
      debugAdapter: debugAdapter,
    );
  }

  StoryNarrativeRuntime._({
    required this.project,
    required this.entryPoints,
    required StoryState persistentState,
    required this.randomSeed,
    required this.maxAutomaticTransitions,
    required StorySeededRandomSource orchestrationRandomSource,
    required List<StoryNarrativeObserver> observers,
    required StoryNarrativeDebugAdapter? debugAdapter,
    int persistentStateRevision = 0,
    int observationSequence = 0,
    int nextSessionIndex = 0,
  }) : _persistentState = persistentState,
       _orchestrationRandomSource = orchestrationRandomSource,
       _observers = observers,
       _debugAdapter = debugAdapter,
       _persistentStateRevision = persistentStateRevision,
       _observationSequence = observationSequence,
       _nextSessionIndex = nextSessionIndex,
       _entryPointIndex = <StoryEntryPointId, StoryEntryPoint>{
         for (final entryPoint in entryPoints) entryPoint.id: entryPoint,
       };

  /// Recreates one complete narrative runtime from an aggregate checkpoint.
  ///
  /// Validation completes before any runtime object is returned and before
  /// caller-supplied observers are attached. Retained sessions, core engine
  /// state, host-action protocol state, shared persistent state, deterministic
  /// random streams, allocation identity, and observation sequence are restored
  /// directly without replaying activation, effects, choices, transitions, or
  /// host work.
  ///
  /// A runtime owned by this orchestration layer must be resumed through the
  /// aggregate restore path. Independently restoring retained session/core
  /// checkpoints cannot reconstruct runtime-level shared-state authority, RNG,
  /// identity cursors, observation sequence, or cross-session invariants.
  /// Content-release compatibility, when used, is a host preflight before this
  /// restore rather than an alternative session-by-session restore mechanism.
  /// When [debugAdapter] is supplied, it observes only future execution;
  /// restoration never replays historical explanation callbacks.
  factory StoryNarrativeRuntime.restore({
    required StoryProject project,
    required Iterable<StoryEntryPoint> entryPoints,
    required StoryNarrativeRuntimeSnapshot snapshot,
    Iterable<StoryNarrativeObserver> observers = const [],
    StoryNarrativeDebugAdapter? debugAdapter,
  }) {
    final copiedEntryPoints = List<StoryEntryPoint>.unmodifiable(entryPoints);

    const StoryNarrativeRuntimeSnapshotValidator().validate(
      snapshot: snapshot,
      project: project,
      entryPoints: copiedEntryPoints,
    );
    _validateHostConditionConfiguration(copiedEntryPoints);

    final restoredRandomSource = StorySeededRandomSource.restoreRuntimeState(
      snapshot.orchestrationRandomState,
    );
    final restoredPersistentState = StoryState.fromValues(
      schema: project.stateSchema,
      values: snapshot.persistentState.values,
    );
    final runtime = StoryNarrativeRuntime._(
      project: project,
      entryPoints: copiedEntryPoints,
      persistentState: restoredPersistentState,
      randomSeed: restoredRandomSource.initialSeed,
      maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
      orchestrationRandomSource: restoredRandomSource,
      observers: const <StoryNarrativeObserver>[],
      debugAdapter: debugAdapter,
      persistentStateRevision: snapshot.persistentStateRevision,
      observationSequence: snapshot.nextObservationSequence,
      nextSessionIndex: snapshot.nextSessionIndex,
    );

    for (final sessionSnapshot in snapshot.sessions) {
      final entryPoint =
          runtime._entryPointIndex[sessionSnapshot.entryPointId]!;
      final preparation = runtime._projectPreparation ??=
          StoryRuntimeProjectPreparation.prepare(project);
      final engine = restoreStoryEngineWithProjectPreparation(
        project: project,
        snapshot: sessionSnapshot.runtimeSnapshot,
        preparation: preparation,
      );
      final session = StoryNarrativeSession._(
        owner: runtime,
        index: sessionSnapshot.sessionIndex,
        entryPoint: entryPoint,
        engine: engine,
        hostActions: StoryHostActionProtocol.restore(
          sessionSnapshot.hostActionSnapshot,
        ),
      );
      runtime._sessions.add(session);
      if (engine.status != StoryEngineStatus.terminated) {
        runtime._activeSessions.add(session);
      }
    }

    runtime._observers = List<StoryNarrativeObserver>.unmodifiable(observers);
    return runtime;
  }

  final StoryProject project;
  final List<StoryEntryPoint> entryPoints;

  /// Seed of the orchestration stream used for deterministic entry resolution
  /// and deterministic per-session seed allocation.
  final int randomSeed;

  final int maxAutomaticTransitions;

  /// Non-authoritative structured observation sinks in registration order.
  ///
  /// Observer failures are isolated from narrative execution. Observers receive
  /// no runtime handle and must not be used as an authored control-flow channel.
  List<StoryNarrativeObserver> get observers => _observers;

  /// Optional non-authoritative explanation bridge for authoring/debug tools.
  ///
  /// The adapter is intentionally absent from snapshots and restoration data.
  /// Its callbacks are isolated from narrative execution and cannot supply
  /// authored input or mutate runtime authority.
  StoryNarrativeDebugAdapter? get debugAdapter => _debugAdapter;

  final Map<StoryEntryPointId, StoryEntryPoint> _entryPointIndex;
  StoryRuntimeProjectPreparation? _projectPreparation;
  StoryNarrativeRuntimeHistoryStrategy _stage9d5HistoryStrategy =
      StoryNarrativeRuntimeHistoryStrategy.selectiveIndexed;
  Stage9d6RollbackTestProbe? _stage9d6RollbackTestProbe;
  StoryState _persistentState;
  StorySeededRandomSource _orchestrationRandomSource;
  List<StoryNarrativeObserver> _observers;
  final StoryNarrativeDebugAdapter? _debugAdapter;
  final List<StoryNarrativeSession> _sessions = <StoryNarrativeSession>[];
  final List<StoryNarrativeSession> _activeSessions = <StoryNarrativeSession>[];
  bool _executionInProgress = false;
  int _persistentStateRevision;
  int _observationSequence;
  int _nextSessionIndex;

  /// Scalar narrative state carried from one session to the next.
  ///
  /// Stage 8G treats every current StoryProject scalar variable as persistent.
  /// Session-local authored variables are not introduced implicitly; adding a
  /// separate local-state schema remains a future explicit contract decision.
  StoryState get persistentState => _persistentState;

  /// Immutable view of all currently unfinished narrative sessions.
  ///
  /// Sessions are ordered by deterministic activation index. They may be
  /// logically active at the same time, but shared-state execution is serialized
  /// by this runtime.
  List<StoryNarrativeSession> get activeSessions =>
      List<StoryNarrativeSession>.unmodifiable(_activeSessions);

  /// Backward-compatible convenience view of the most recently activated
  /// unfinished session, or null when no session remains active.
  ///
  /// Stage 8J permits more than one active session; new integrations that need
  /// the complete set should use [activeSessions].
  StoryNarrativeSession? get activeSession =>
      _activeSessions.isEmpty ? null : _activeSessions.last;

  /// Monotonic revision of committed persistent scalar narrative state.
  ///
  /// The revision advances only when a serialized operation changes persistent
  /// state. It is observational metadata, not a wall-clock or concurrency token.
  int get persistentStateRevision => _persistentStateRevision;

  /// Immutable session-boundary history snapshot.
  StoryNarrativeRuntimeHistory get history => StoryNarrativeRuntimeHistory(
    sessions: _sessions.map((session) => session._historySnapshot()),
  );

  /// Captures one atomic checkpoint of the complete orchestration runtime.
  ///
  /// Aggregate checkpoints are available only at completed serialized-operation
  /// boundaries. The returned value contains no observers or other live host
  /// dependencies and does not consume either deterministic random stream.
  /// Persist this checkpoint as the authoritative orchestration continuation;
  /// when content-release binding is used, the host stores the companion
  /// `StorySaveContentBinding` in the same logical save revision.
  StoryNarrativeRuntimeSnapshot createSnapshot() {
    if (_executionInProgress) {
      throw const StoryNarrativeOperationException(
        message:
            'Cannot capture an aggregate narrative snapshot while a '
            'serialized runtime operation is in progress.',
        operation: 'createSnapshot',
      );
    }

    return StoryNarrativeRuntimeSnapshot(
      projectId: project.id,
      persistentState: _persistentState,
      persistentStateRevision: _persistentStateRevision,
      orchestrationRandomState: _orchestrationRandomSource.createRuntimeState(),
      maxAutomaticTransitions: maxAutomaticTransitions,
      nextSessionIndex: _nextSessionIndex,
      nextObservationSequence: _observationSequence,
      sessions: _sessions.map((session) => session.createSnapshot()),
    );
  }

  /// Starts a session at one explicitly named entry point.
  ///
  /// The entry point must be eligible against current persistent state and all
  /// explicit host-condition results. No graph edge from a prior session is
  /// required. A successful start commits entry effects to persistent state.
  StoryNarrativeSession startSession(
    StoryEntryPointId entryPointId, {
    StoryHostContext? hostContext,
  }) => _runSerialized('startSession', () {
    final entryPoint = _entryPointIndex[entryPointId];
    if (entryPoint == null) {
      throw StoryNarrativeOperationException(
        message: 'Unknown narrative entry point $entryPointId.',
        operation: 'startSession',
      );
    }

    final context = hostContext ?? StoryHostContext.empty;
    final eligible = _isEligible(
      entryPoint,
      context,
      onExplanation: _debugAdapter == null
          ? null
          : _emitEntryPointEligibilityExplanation,
    );
    if (!eligible) {
      throw StoryNarrativeOperationException(
        message:
            'Narrative entry point $entryPointId is not currently '
            'eligible.',
        operation: 'startSession',
      );
    }

    final randomTransaction = _orchestrationRandomSource.copy();
    return _startResolvedEntryPoint(entryPoint, randomTransaction);
  });

  /// Explains one entry point's current eligibility without starting it.
  ///
  /// This diagnostic probe evaluates only the named candidate against the
  /// current persistent state and supplied host facts. A missing required host
  /// fact is represented as `hostConditionMissing` instead of being converted
  /// into a normal false result. Authoritative [startSession] and
  /// [resolveAndStartSession] continue to treat that situation as a resolution
  /// error.
  ///
  /// The probe does not consume orchestration RNG, allocate a session, mutate
  /// persistent state, or emit narrative observations.
  StoryEntryPointExplanation explainEntryPointEligibility(
    StoryEntryPointId entryPointId, {
    StoryHostContext? hostContext,
  }) {
    if (_executionInProgress) {
      throw const StoryNarrativeOperationException(
        message:
            'Entry-point diagnostics cannot run during narrative '
            'execution.',
        operation: 'explainEntryPointEligibility',
      );
    }

    final entryPoint = _entryPointIndex[entryPointId];
    if (entryPoint == null) {
      throw StoryNarrativeOperationException(
        message: 'Unknown narrative entry point $entryPointId.',
        operation: 'explainEntryPointEligibility',
      );
    }

    StoryEntryPointExplanation? explanation;
    _isEligible(
      entryPoint,
      hostContext ?? StoryHostContext.empty,
      missingHostFactIsError: false,
      onExplanation: (value) => explanation = value,
    );
    return explanation!;
  }

  /// Resolves and starts the best currently eligible entry point.
  ///
  /// Resolution order is deterministic:
  /// 1. evaluate non-fallback entry points in declaration order;
  /// 2. only when none are eligible, evaluate fallback entries;
  /// 3. retain the highest priority;
  /// 4. if one candidate remains, select it without a resolution RNG draw;
  /// 5. otherwise perform one authored-order weighted draw.
  ///
  /// Returns null when no entry point in either tier is eligible. Missing
  /// required host facts are resolution errors rather than implicit false.
  StoryNarrativeSession? resolveAndStartSession({
    StoryHostContext? hostContext,
  }) => _runSerialized('resolveAndStartSession', () {
    final context = hostContext ?? StoryHostContext.empty;
    final randomTransaction = _orchestrationRandomSource.copy();
    final entryPoint = _resolveEntryPoint(
      hostContext: context,
      randomSource: randomTransaction,
      onExplanation: _debugAdapter == null
          ? null
          : _emitEntryPointResolutionExplanation,
    );
    if (entryPoint == null) {
      return null;
    }
    return _startResolvedEntryPoint(entryPoint, randomTransaction);
  });

  /// Resolves and starts an entry point while returning the causal resolution.
  ///
  /// This is the opt-in diagnostic counterpart to [resolveAndStartSession].
  /// Eligibility conditions, host requirements, fallback handling, priority,
  /// and any weighted RNG sample are recorded during the same authoritative
  /// resolver pass used to select the returned session. No condition or random
  /// draw is repeated merely to construct the explanation.
  ///
  /// When no candidate is eligible, `session` is null and the explanation uses
  /// [StoryEntryPointSelectionMethod.none]. Missing required host facts preserve
  /// the normal [StoryNarrativeResolutionException] behavior because no
  /// completed resolution exists in that case.
  ({
    StoryNarrativeSession? session,
    StoryEntryPointResolutionExplanation explanation,
  })
  resolveAndStartSessionWithExplanation({StoryHostContext? hostContext}) =>
      _runSerialized('resolveAndStartSession', () {
        final context = hostContext ?? StoryHostContext.empty;
        final randomTransaction = _orchestrationRandomSource.copy();
        StoryEntryPointResolutionExplanation? explanation;
        final entryPoint = _resolveEntryPoint(
          hostContext: context,
          randomSource: randomTransaction,
          onExplanation: (value) {
            explanation = value;
            _emitEntryPointResolutionExplanation(value);
          },
        );
        if (entryPoint == null) {
          return (session: null, explanation: explanation!);
        }
        final session = _startResolvedEntryPoint(entryPoint, randomTransaction);
        return (session: session, explanation: explanation!);
      });

  StoryNarrativeSession _startResolvedEntryPoint(
    StoryEntryPoint entryPoint,
    StorySeededRandomSource randomTransaction,
  ) {
    // The orchestration stream and each local session stream are intentionally
    // separate. Internal random draws in one dialogue therefore cannot alter
    // which entry point is selected the next time the host requests a session.
    final sessionSeed = randomTransaction.nextInt(
      StorySeededRandomSource.maxSeed + 1,
    );
    late final StoryEngine engine;
    try {
      engine = StoryEngine(
        project: project,
        randomSeed: sessionSeed,
        maxAutomaticTransitions: maxAutomaticTransitions,
      );
    } on StoryEngineException catch (error) {
      throw StoryNarrativeExecutionException(
        message: 'Failed to start narrative entry point ${entryPoint.id}.',
        operation: 'startSession',
        cause: error,
      );
    }

    List<StoryEffectExplanation>? effectExplanations;
    StoryRuntimeExecutionExplanation? executionExplanation;
    try {
      if (_debugAdapter == null) {
        engine.startAt(entryPoint.eventId, initialState: _persistentState);
      } else {
        executionExplanation = engine.startAtWithExplanations(
          entryPoint.eventId,
          initialState: _persistentState,
        );
        effectExplanations = engine.lastEffectExplanations;
      }
    } on StoryEngineException catch (error) {
      final failedExplanations = engine.lastEffectExplanations;
      if (failedExplanations.isNotEmpty) {
        _emitEffectExplanations(
          sessionIndex: null,
          explanations: failedExplanations,
        );
      }
      _emitExecutionExplanation(
        sessionIndex: null,
        explanation: engine.lastExecutionExplanation,
        rolledBack: true,
      );
      throw StoryNarrativeExecutionException(
        message: 'Failed to start narrative entry point ${entryPoint.id}.',
        operation: 'startSession',
        cause: error,
      );
    }

    final sessionIndex = _nextSessionIndex;
    final session = StoryNarrativeSession._(
      owner: this,
      index: sessionIndex,
      entryPoint: entryPoint,
      engine: engine,
      hostActions: StoryHostActionProtocol(scope: 'session_$sessionIndex'),
    );
    final _PreparedChoicePresentation presentation;
    try {
      presentation = _prepareChoicePresentation(session);
    } on Object {
      _emitEffectExplanations(
        sessionIndex: null,
        explanations: effectExplanations ?? const [],
        rolledBack: true,
      );
      _emitExecutionExplanation(
        sessionIndex: null,
        explanation: executionExplanation,
        rolledBack: true,
      );
      rethrow;
    }
    late final StoryPersistentStateCommitExplanation? commitExplanation;
    _sessions.add(session);
    if (engine.status != StoryEngineStatus.terminated) {
      _activeSessions.add(session);
    }
    try {
      commitExplanation = _commitPersistentState(session);
    } catch (_) {
      _activeSessions.remove(session);
      _sessions.removeLast();
      _emitEffectExplanations(
        sessionIndex: null,
        explanations: effectExplanations ?? const [],
        rolledBack: true,
      );
      _emitExecutionExplanation(
        sessionIndex: null,
        explanation: executionExplanation,
        rolledBack: true,
      );
      rethrow;
    }
    _nextSessionIndex++;
    _orchestrationRandomSource = randomTransaction;
    if (effectExplanations != null && effectExplanations.isNotEmpty) {
      _emitEffectExplanations(
        sessionIndex: session.index,
        explanations: effectExplanations,
      );
    }
    _emitExecutionExplanation(
      sessionIndex: session.index,
      explanation: executionExplanation,
    );
    _emitPersistentStateCommitExplanation(commitExplanation);
    _emitObservation(
      (sequence) => StoryNarrativeSessionStarted(
        sequence: sequence,
        sessionIndex: session.index,
        entryPointId: entryPoint.id,
        entryEventId: entryPoint.eventId,
        randomSeed: session.randomSeed,
      ),
    );
    _emitSessionProgress(
      session,
      fromHistoryIndex: 0,
      presentation: presentation,
    );
    return session;
  }

  StoryEntryPoint? _resolveEntryPoint({
    required StoryHostContext hostContext,
    required StorySeededRandomSource randomSource,
    void Function(StoryEntryPointResolutionExplanation)? onExplanation,
  }) {
    final candidateExplanations = onExplanation == null
        ? null
        : <StoryEntryPointId, StoryEntryPointExplanation>{};
    var candidates = _eligibleEntries(
      fallback: false,
      hostContext: hostContext,
      explanations: candidateExplanations,
    );
    if (candidates.isEmpty) {
      candidates = _eligibleEntries(
        fallback: true,
        hostContext: hostContext,
        explanations: candidateExplanations,
      );
    }
    if (candidates.isEmpty) {
      if (onExplanation != null) {
        onExplanation(
          StoryEntryPointResolutionExplanation(
            candidates: _orderedEntryPointExplanations(candidateExplanations!),
            selectionMethod: StoryEntryPointSelectionMethod.none,
          ),
        );
      }
      return null;
    }

    var winningPriority = candidates.first.priority;
    for (final candidate in candidates.skip(1)) {
      if (candidate.priority > winningPriority) {
        winningPriority = candidate.priority;
      }
    }
    final finalists = <StoryEntryPoint>[
      for (final candidate in candidates)
        if (candidate.priority == winningPriority) candidate,
    ];
    if (finalists.length == 1) {
      final selected = finalists.single;
      if (onExplanation != null) {
        onExplanation(
          StoryEntryPointResolutionExplanation(
            candidates: _orderedEntryPointExplanations(candidateExplanations!),
            selectionMethod: StoryEntryPointSelectionMethod.soleFinalist,
            selectedEntryPointId: selected.id,
            winningFallbackTier: selected.isFallback,
            winningPriority: winningPriority,
            finalists: [
              StoryEntryPointFinalistExplanation(
                entryPointId: selected.id,
                weight: selected.weight,
              ),
            ],
          ),
        );
      }
      return selected;
    }

    var totalWeight = 0;
    for (final finalist in finalists) {
      totalWeight += finalist.weight;
      if (totalWeight > StoryIntegerValue.maxPortableValue) {
        throw const StoryNarrativeResolutionException(
          message:
              'Winning entry-point weights exceed the portable integer '
              'range.',
        );
      }
    }

    final sampled = randomSource.nextInt(totalWeight);
    var upperExclusive = 0;
    for (final finalist in finalists) {
      upperExclusive += finalist.weight;
      if (sampled < upperExclusive) {
        if (onExplanation != null) {
          onExplanation(
            StoryEntryPointResolutionExplanation(
              candidates: _orderedEntryPointExplanations(
                candidateExplanations!,
              ),
              selectionMethod: StoryEntryPointSelectionMethod.weightedDraw,
              selectedEntryPointId: finalist.id,
              winningFallbackTier: finalist.isFallback,
              winningPriority: winningPriority,
              finalists: [
                for (final candidate in finalists)
                  StoryEntryPointFinalistExplanation(
                    entryPointId: candidate.id,
                    weight: candidate.weight,
                  ),
              ],
              totalWeight: totalWeight,
              sampledWeightOffset: sampled,
            ),
          );
        }
        return finalist;
      }
    }

    throw const StoryNarrativeResolutionException(
      message: 'A valid weighted entry-point sample could not be mapped.',
    );
  }

  List<StoryEntryPoint> _eligibleEntries({
    required bool fallback,
    required StoryHostContext hostContext,
    Map<StoryEntryPointId, StoryEntryPointExplanation>? explanations,
  }) {
    final result = <StoryEntryPoint>[];
    for (final entryPoint in entryPoints) {
      if (entryPoint.isFallback != fallback) {
        continue;
      }
      final explanationSink = explanations == null
          ? null
          : (StoryEntryPointExplanation explanation) {
              explanations[entryPoint.id] = explanation;
            };
      if (_isEligible(
        entryPoint,
        hostContext,
        onExplanation: explanationSink,
      )) {
        result.add(entryPoint);
      }
    }
    return result;
  }

  bool _isEligible(
    StoryEntryPoint entryPoint,
    StoryHostContext hostContext, {
    bool missingHostFactIsError = true,
    void Function(StoryEntryPointExplanation)? onExplanation,
  }) {
    StoryConditionExplanation? conditionExplanation;
    final condition = entryPoint.eligibilityCondition;
    if (condition != null) {
      try {
        final bool result;
        if (onExplanation == null) {
          result = const StoryConditionEvaluator().evaluate(
            condition,
            StoryConditionContext(state: _persistentState),
          );
        } else {
          final evaluated = const StoryConditionEvaluator()
              .evaluateWithExplanation(
                condition,
                StoryConditionContext(state: _persistentState),
              );
          conditionExplanation = evaluated;
          result = evaluated.result;
        }
        if (!result) {
          if (onExplanation != null) {
            onExplanation(
              _entryPointExplanation(
                entryPoint: entryPoint,
                status: StoryEntryPointCandidateStatus.stateConditionRejected,
                eligibilityCondition: conditionExplanation,
              ),
            );
          }
          return false;
        }
      } catch (error) {
        throw StoryNarrativeResolutionException(
          message: 'Failed to evaluate eligibility for ${entryPoint.id}.',
          cause: error,
        );
      }
    }

    final hostExplanations = onExplanation == null
        ? null
        : <StoryHostConditionExplanation>[];
    for (final requirement in entryPoint.hostConditions) {
      final result = hostContext.resultFor(requirement.key);
      hostExplanations?.add(
        StoryHostConditionExplanation(
          key: requirement.key,
          schemaNamespace: requirement.schemaNamespace,
          conditionId: requirement.conditionId,
          arguments: requirement.arguments,
          expected: requirement.expected,
          actual: result,
        ),
      );
      if (result == null) {
        if (onExplanation != null) {
          onExplanation(
            _entryPointExplanation(
              entryPoint: entryPoint,
              status: StoryEntryPointCandidateStatus.hostConditionMissing,
              eligibilityCondition: conditionExplanation,
              evaluatedHostConditions: hostExplanations!,
            ),
          );
        }
        if (missingHostFactIsError) {
          throw StoryNarrativeResolutionException(
            message:
                'Missing explicit host-condition result for '
                '${requirement.key} required by ${entryPoint.id}.',
          );
        }
        return false;
      }
      if (result != requirement.expected) {
        if (onExplanation != null) {
          onExplanation(
            _entryPointExplanation(
              entryPoint: entryPoint,
              status: StoryEntryPointCandidateStatus.hostConditionRejected,
              eligibilityCondition: conditionExplanation,
              evaluatedHostConditions: hostExplanations!,
            ),
          );
        }
        return false;
      }
    }

    if (onExplanation != null) {
      onExplanation(
        _entryPointExplanation(
          entryPoint: entryPoint,
          status: StoryEntryPointCandidateStatus.eligible,
          eligibilityCondition: conditionExplanation,
          evaluatedHostConditions: hostExplanations!,
        ),
      );
    }
    return true;
  }

  StoryEntryPointExplanation _entryPointExplanation({
    required StoryEntryPoint entryPoint,
    required StoryEntryPointCandidateStatus status,
    StoryConditionExplanation? eligibilityCondition,
    Iterable<StoryHostConditionExplanation> evaluatedHostConditions = const [],
  }) => StoryEntryPointExplanation(
    entryPointId: entryPoint.id,
    eventId: entryPoint.eventId,
    isFallback: entryPoint.isFallback,
    priority: entryPoint.priority,
    weight: entryPoint.weight,
    status: status,
    eligibilityCondition: eligibilityCondition,
    authoredHostConditionCount: entryPoint.hostConditions.length,
    evaluatedHostConditions: evaluatedHostConditions,
  );

  List<StoryEntryPointExplanation> _orderedEntryPointExplanations(
    Map<StoryEntryPointId, StoryEntryPointExplanation> evaluated,
  ) => List<StoryEntryPointExplanation>.unmodifiable([
    for (final entryPoint in entryPoints)
      evaluated[entryPoint.id] ??
          _entryPointExplanation(
            entryPoint: entryPoint,
            status: StoryEntryPointCandidateStatus.notEvaluated,
          ),
  ]);

  /// Returns the session with [index], including completed historical sessions.
  StoryNarrativeSession sessionByIndex(int index) {
    if (index < 0 || index >= _sessions.length) {
      throw StoryNarrativeOperationException(
        message: 'Unknown narrative session index $index.',
        operation: 'sessionByIndex',
      );
    }
    return _sessions[index];
  }

  /// Applies one explicit authority-submitted input by stable IDs.
  ///
  /// This API is intentionally UI-neutral. A local widget, replay harness, or
  /// authoritative server may all submit the same input objects. Ordering is the
  /// caller authority's explicit invocation order; this runtime never orders
  /// conflicting inputs by wall-clock or scheduler timing.
  void applyInput(StoryNarrativeInput input) {
    final session = sessionByIndex(input.sessionIndex);
    switch (input) {
      case StoryNarrativeChoiceInput(:final choiceId):
        session.choose(choiceId);
        return;
      case StoryNarrativeContinueInput():
        session.continueStory();
        return;
      case StoryNarrativeHostActionCompletedInput(
        :final requestId,
        :final value,
      ):
        session.completeHostAction(requestId, value: value);
        return;
      case StoryNarrativeHostActionFailedInput(
        :final requestId,
        :final code,
        :final message,
      ):
        session.failHostAction(requestId, code: code, message: message);
        return;
      case StoryNarrativeHostActionCancelledInput(
        :final requestId,
        :final code,
        :final message,
      ):
        session.cancelHostAction(requestId, code: code, message: message);
        return;
    }
  }

  T _runSerialized<T>(
    String operation,
    T Function() body, {
    int? sessionIndex,
    void Function()? onFailure,
  }) {
    if (_executionInProgress) {
      throw StoryNarrativeOperationException(
        message:
            'Re-entrant narrative execution is not permitted. Submit '
            'inputs only after the current operation commits or fails.',
        operation: operation,
      );
    }
    _executionInProgress = true;
    try {
      return body();
    } on Object catch (error) {
      try {
        onFailure?.call();
      } on Object {
        // Failure diagnostics cannot replace the authoritative exception.
      }
      _emitObservation(
        (sequence) => StoryNarrativeError(
          sequence: sequence,
          sessionIndex: sessionIndex,
          category: _observationErrorCategory(error),
          operation: operation,
          message: error.toString(),
        ),
      );
      rethrow;
    } finally {
      _executionInProgress = false;
    }
  }

  T _runSessionOperation<T>(
    StoryNarrativeSession session,
    String operation,
    T Function() body, {
    bool commitPersistentState = false,
    void Function()? afterPersistentCommit,
    void Function()? onFailure,
  }) {
    return _runSerialized(
      operation,
      () {
        if (!_activeSessions.contains(session)) {
          throw StoryNarrativeOperationException(
            message: 'This narrative session is no longer active.',
            operation: operation,
          );
        }

        StoryEngineMutationCheckpoint? beforeCheckpoint;
        StoryRuntimeSnapshot? eagerRollbackSnapshot;
        var beforeHistoryLength = 0;
        if (commitPersistentState) {
          final eagerRollback = _stage9d5HistoryStrategy.eagerRollbackFor(
            _activeSessions.length,
          );
          if (eagerRollback) {
            eagerRollbackSnapshot = session._engine.createSnapshot();
            beforeHistoryLength = eagerRollbackSnapshot.history.steps.length;
          } else {
            beforeCheckpoint = captureStoryEngineMutationCheckpoint(
              session._engine,
            );
            beforeHistoryLength = beforeCheckpoint.historyLength;
          }
        }
        final result = body();
        if (commitPersistentState) {
          void Function()? beforeSiblingPropagation;
          if (_stage9d5HistoryStrategy
                  .materializesRollbackBeforeSharedPropagation &&
              beforeCheckpoint != null &&
              _activeSessions.length > 1) {
            beforeSiblingPropagation = () {
              eagerRollbackSnapshot ??=
                  materializeStoryEngineMutationCheckpoint(
                    session._engine,
                    beforeCheckpoint!,
                  );
              assert(() {
                final probe = _stage9d6RollbackTestProbe;
                if (probe != null) {
                  probe.selectiveRollbackMaterializationCount++;
                  probe._events.add('selectiveRollbackMaterialized');
                }
                return true;
              }());
            };
          }
          late final _PreparedChoicePresentation presentation;
          late final StoryPersistentStateCommitExplanation? commitExplanation;
          try {
            // Choice conditions are fallible authored logic. Prepare once before
            // publishing shared state, then deliver only the prepared data.
            presentation = _prepareChoicePresentation(session);
            commitExplanation = _commitPersistentState(
              session,
              beforeSiblingPropagation: beforeSiblingPropagation,
            );
          } catch (_) {
            var rollbackSnapshot =
                eagerRollbackSnapshot ??
                materializeStoryEngineMutationCheckpoint(
                  session._engine,
                  beforeCheckpoint!,
                );
            assert(() {
              final probe = _stage9d6RollbackTestProbe;
              if (probe != null) {
                probe.rollbackRestoreAttemptCount++;
                probe._events.add('rollbackRestoreAttempt');
                rollbackSnapshot =
                    probe.rollbackSnapshotTransform?.call(rollbackSnapshot) ??
                    rollbackSnapshot;
              }
              return true;
            }());
            session._engine = StoryEngine.restore(
              project: project,
              snapshot: rollbackSnapshot,
            );
            rethrow;
          }
          afterPersistentCommit?.call();
          _emitPersistentStateCommitExplanation(commitExplanation);
          _emitSessionProgress(
            session,
            fromHistoryIndex: beforeHistoryLength,
            presentation: presentation,
          );
        }
        return result;
      },
      sessionIndex: session.index,
      onFailure: onFailure,
    );
  }

  _PreparedChoicePresentation _prepareChoicePresentation(
    StoryNarrativeSession session,
  ) {
    if (session.sessionStatus != StoryNarrativeSessionStatus.awaitingChoice) {
      return (choices: const [], explanations: null);
    }
    if (_debugAdapter == null) {
      return (choices: session.availableChoices, explanations: null);
    }
    try {
      return (choices: const [], explanations: session.choiceExplanations);
    } on StoryEngineExecutionException catch (error) {
      // Both modes present the same authoritative choice-availability failure.
      // The public diagnostic getter retains its own diagnostic error context.
      throw StoryEngineExecutionException(
        message:
            'Failed to evaluate available choices for ${session.currentEvent!.id}.',
        cause: error.cause,
        operation: 'availableChoices',
        eventId: session.currentEvent!.id,
        suggestion:
            'Validate the project and repair the failing choice '
            'condition before evaluating available choices.',
      );
    }
  }

  void _emitSessionProgress(
    StoryNarrativeSession session, {
    required int fromHistoryIndex,
    required _PreparedChoicePresentation presentation,
  }) {
    if (_stage9d5HistoryStrategy.usesIndexedHistory) {
      final historyLength = storyEngineCommittedHistoryLength(session._engine);
      for (var index = fromHistoryIndex; index < historyLength; index++) {
        _emitSessionProgressStep(
          session,
          storyEngineCommittedHistoryStepAt(session._engine, index),
        );
      }
    } else {
      final steps = session.history.steps;
      for (var index = fromHistoryIndex; index < steps.length; index++) {
        _emitSessionProgressStep(session, steps[index]);
      }
    }

    if (session.sessionStatus == StoryNarrativeSessionStatus.awaitingChoice) {
      final eventId = session.currentEvent!.id;
      final explanations = presentation.explanations;
      if (explanations == null) {
        for (final choice in presentation.choices) {
          _emitObservation(
            (sequence) => StoryNarrativeChoicePresented(
              sequence: sequence,
              sessionIndex: session.index,
              eventId: eventId,
              choiceId: choice.id,
            ),
          );
        }
      } else {
        _emitChoiceAvailabilityExplanations(
          sessionIndex: session.index,
          explanations: explanations,
        );
        for (final explanation in explanations) {
          if (!explanation.available) {
            continue;
          }
          _emitObservation(
            (sequence) => StoryNarrativeChoicePresented(
              sequence: sequence,
              sessionIndex: session.index,
              eventId: eventId,
              choiceId: explanation.choiceId,
            ),
          );
        }
      }
    }
    if (session.sessionStatus == StoryNarrativeSessionStatus.terminated) {
      _emitObservation(
        (sequence) => StoryNarrativeSessionEnded(
          sequence: sequence,
          sessionIndex: session.index,
          entryPointId: session.entryPoint.id,
        ),
      );
    }
  }

  void _emitSessionProgressStep(
    StoryNarrativeSession session,
    StoryRuntimeStep step,
  ) {
    switch (step) {
      case StoryEventEnteredStep(:final eventId):
        _emitObservation(
          (sequence) => StoryNarrativeEventEntered(
            sequence: sequence,
            sessionIndex: session.index,
            eventId: eventId,
          ),
        );
        break;
      case StoryChoiceSelectedStep(:final eventId, :final choiceId):
        _emitObservation(
          (sequence) => StoryNarrativeChoiceSelected(
            sequence: sequence,
            sessionIndex: session.index,
            eventId: eventId,
            choiceId: choiceId,
          ),
        );
        break;
      case StoryEventContinuedStep():
        break;
    }
  }

  void _emitEntryPointEligibilityExplanation(
    StoryEntryPointExplanation explanation,
  ) {
    _emitDebug((adapter) => adapter.onEntryPointEligibility(explanation));
  }

  void _emitEntryPointResolutionExplanation(
    StoryEntryPointResolutionExplanation explanation,
  ) {
    _emitDebug((adapter) => adapter.onEntryPointResolution(explanation));
  }

  void _emitChoiceAvailabilityExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) {
    _emitDebug(
      (adapter) => adapter.onChoiceExplanations(
        sessionIndex: sessionIndex,
        explanations: explanations,
      ),
    );
  }

  void _emitExecutionExplanation({
    required int? sessionIndex,
    required StoryRuntimeExecutionExplanation? explanation,
    bool rolledBack = false,
  }) {
    if (explanation == null) return;
    _emitDebug(
      (adapter) => adapter.onExecutionExplanation(
        sessionIndex: sessionIndex,
        explanation: rolledBack ? explanation.asRolledBack() : explanation,
      ),
    );
  }

  void _emitPersistentStateCommitExplanation(
    StoryPersistentStateCommitExplanation? explanation,
  ) {
    if (explanation == null) return;
    _emitDebug(
      (adapter) => adapter.onPersistentStateCommitExplanation(explanation),
    );
  }

  void _emitEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
    bool rolledBack = false,
  }) {
    if (explanations.isEmpty) {
      return;
    }
    _emitDebug(
      (adapter) => adapter.onEffectExplanations(
        sessionIndex: sessionIndex,
        explanations: rolledBack
            ? List<StoryEffectExplanation>.unmodifiable([
                for (final explanation in explanations)
                  if (explanation.outcome == StoryEffectOutcome.rejected ||
                      explanation.outcome == StoryEffectOutcome.rolledBack)
                    explanation
                  else
                    StoryEffectExplanation(
                      source: explanation.source,
                      authoredIndex: explanation.authoredIndex,
                      variableId: explanation.variableId,
                      operation: explanation.operation,
                      operand: explanation.operand,
                      beforeValue: explanation.beforeValue,
                      afterValue: explanation.afterValue,
                      outcome: StoryEffectOutcome.rolledBack,
                    ),
              ])
            : explanations,
      ),
    );
  }

  void _emitDebug(void Function(StoryNarrativeDebugAdapter adapter) notify) {
    final adapter = _debugAdapter;
    if (adapter == null) {
      return;
    }
    try {
      notify(adapter);
    } on Object {
      // Debug explanation delivery is explicitly non-authoritative. Broken
      // authoring/debug tooling must not alter narrative semantics.
    }
  }

  void _emitObservation(
    StoryNarrativeObservation Function(int sequence) create,
  ) {
    if (_observers.isEmpty) {
      return;
    }
    final observation = create(_observationSequence++);
    for (final observer in _observers) {
      try {
        observer.onNarrativeObservation(observation);
      } on Object {
        // Observation is explicitly non-authoritative. A broken debugger,
        // logger, or telemetry adapter must not alter narrative semantics.
      }
    }
  }

  StoryRuntimeProjectPreparation _projectPreparationForSiblingRestore() =>
      _projectPreparation ??= StoryRuntimeProjectPreparation.prepare(project);

  StoryPersistentStateCommitExplanation? _commitPersistentState(
    StoryNarrativeSession source, {
    void Function()? beforeSiblingPropagation,
  }) {
    final state = source._engine.state;
    if (state == null) {
      throw const StoryNarrativeExecutionException(
        message: 'A started narrative session lost its committed state.',
        operation: 'commitSession',
      );
    }

    StoryPersistentStateCommitExplanation? commitExplanation;
    final changed = state != _persistentState;
    if (changed) {
      beforeSiblingPropagation?.call();
      final replacements = <StoryNarrativeSession, StoryEngine>{};
      for (final session in _activeSessions) {
        if (!identical(session, source)) {
          replacements[session] = session._engineWithPersistentState(state);
          assert(() {
            final probe = _stage9d6RollbackTestProbe;
            if (probe != null) {
              probe.preparedSiblingReplacementCount++;
              probe._events.add('siblingReplacementPrepared');
              if (probe.preparedSiblingReplacementCount ==
                  probe.failAfterPreparedSiblingCount) {
                throw StateError(
                  'Injected Stage 9D6B sibling preparation failure after '
                  '${probe.preparedSiblingReplacementCount} prepared sibling '
                  'replacement(s).',
                );
              }
            }
            return true;
          }());
        }
      }

      if (_debugAdapter != null) {
        commitExplanation = StoryPersistentStateCommitExplanation(
          sourceSessionIndex: source.index,
          previousRevision: _persistentStateRevision,
          revision: _persistentStateRevision + 1,
          changes: [
            for (final variable in project.stateSchema.variables)
              if (_persistentState.values[variable.id] !=
                  state.values[variable.id])
                StoryPersistentVariableChange(
                  variableId: variable.id,
                  beforeValue: _persistentState.values[variable.id],
                  afterValue: state.values[variable.id],
                ),
          ],
          propagatedSessionIndexes: replacements.keys.map(
            (session) => session.index,
          ),
        );
      }

      // Commit the global state and all sibling session views only after every
      // replacement has been prepared successfully. A propagation failure can
      // therefore never leave half the runtime on an older persistent state.
      _persistentState = state;
      _persistentStateRevision++;
      for (final entry in replacements.entries) {
        entry.key._engine = entry.value;
      }
    }

    if (source.status == StoryEngineStatus.terminated) {
      _activeSessions.remove(source);
    }
    return commitExplanation;
  }
}

/// Creates a narrative runtime with one explicit Stage 9D5 diagnostic strategy.
///
/// Benchmark-only seam: not exported from the package root and not a supported
/// consumer API. Normal [StoryNarrativeRuntime] construction keeps the current
/// production strategy.
StoryNarrativeRuntime createStoryNarrativeRuntimeForStage9d5Benchmark({
  required StoryProject project,
  required Iterable<StoryEntryPoint> entryPoints,
  required StoryNarrativeRuntimeHistoryStrategy historyStrategy,
  StoryState? initialState,
  int randomSeed = StoryEngine.defaultRandomSeed,
  int maxAutomaticTransitions = StoryEngine.defaultMaxAutomaticTransitions,
}) {
  final runtime = StoryNarrativeRuntime(
    project: project,
    entryPoints: entryPoints,
    initialState: initialState,
    randomSeed: randomSeed,
    maxAutomaticTransitions: maxAutomaticTransitions,
  );
  runtime._stage9d5HistoryStrategy = historyStrategy;
  return runtime;
}

/// Restores a diagnostic runtime from one identical aggregate checkpoint.
StoryNarrativeRuntime restoreStoryNarrativeRuntimeForStage9d5Benchmark({
  required StoryProject project,
  required Iterable<StoryEntryPoint> entryPoints,
  required StoryNarrativeRuntimeSnapshot snapshot,
  required StoryNarrativeRuntimeHistoryStrategy historyStrategy,
}) {
  final runtime = StoryNarrativeRuntime.restore(
    project: project,
    entryPoints: entryPoints,
    snapshot: snapshot,
  );
  runtime._stage9d5HistoryStrategy = historyStrategy;
  return runtime;
}

/// Prepares the exact-project sibling-restore indexes outside a timed commit.
void warmStoryNarrativeRuntimeProjectPreparationForStage9d5Benchmark(
  StoryNarrativeRuntime runtime,
) {
  runtime._projectPreparationForSiblingRestore();
}

/// Installs a preparation bound to another project so a sibling restore fails.
///
/// This exists only to exercise the exceptional rollback contract in Stage 9D5
/// white-box tests without weakening production validation.
void installMismatchedProjectPreparationForStage9d5RollbackTest(
  StoryNarrativeRuntime runtime,
  StoryProject otherProject,
) {
  runtime._projectPreparation = StoryRuntimeProjectPreparation.prepare(
    otherProject,
  );
}

/// Installs one internal Stage 9D6B rollback probe/fault injector.
///
/// The failure is raised only after the requested number of real sibling
/// replacement engines have been prepared successfully. The optional snapshot
/// transform runs immediately before the normal validated `StoryEngine.restore`
/// rollback call so tests can prove validation is still part of the exceptional
/// path. This helper is repository test infrastructure, not consumer API.
Stage9d6RollbackTestProbe installStage9d6RollbackTestProbe({
  required StoryNarrativeRuntime runtime,
  required int failAfterPreparedSiblingCount,
  StoryRuntimeSnapshot Function(StoryRuntimeSnapshot snapshot)?
  rollbackSnapshotTransform,
}) {
  if (failAfterPreparedSiblingCount <= 0) {
    throw ArgumentError.value(
      failAfterPreparedSiblingCount,
      'failAfterPreparedSiblingCount',
      'Must be greater than zero.',
    );
  }
  final probe = Stage9d6RollbackTestProbe._(
    failAfterPreparedSiblingCount: failAfterPreparedSiblingCount,
    rollbackSnapshotTransform: rollbackSnapshotTransform,
  );
  runtime._stage9d6RollbackTestProbe = probe;
  return probe;
}

/// Host-visible lifecycle of one [StoryNarrativeSession].
///
/// This composes the underlying core engine pause with Stage 8I's suspendable
/// host-action protocol without adding `awaitingHost` to Core Runtime Semantics
/// Revision 1 or frozen Story Format v1.
enum StoryNarrativeSessionStatus {
  awaitingChoice,
  awaitingContinue,
  awaitingHost,
  terminated,
}

/// One host-visible local narrative execution started by [StoryNarrativeRuntime].
///
/// Session traversal state/history and local RNG are isolated to this object;
/// successful scalar StoryState commits are propagated back to the owning
/// runtime as persistent narrative state.
final class StoryNarrativeSession {
  StoryNarrativeSession._({
    required StoryNarrativeRuntime owner,
    required this.index,
    required this.entryPoint,
    required StoryEngine engine,
    required StoryHostActionProtocol hostActions,
  }) : _owner = owner,
       _engine = engine,
       _hostActions = hostActions;

  final StoryNarrativeRuntime _owner;
  StoryEngine _engine;
  final StoryHostActionProtocol _hostActions;

  /// Zero-based deterministic activation order within the runtime instance.
  final int index;

  final StoryEntryPoint entryPoint;

  /// Underlying Core Runtime Semantics lifecycle state.
  ///
  /// Use [sessionStatus] when host-action suspension is relevant. While a host
  /// action is pending this getter intentionally remains at the committed core
  /// pause from which the request was emitted.
  StoryEngineStatus get status => _engine.status;

  /// Composite session lifecycle including the Stage 8I `awaitingHost` state.
  StoryNarrativeSessionStatus get sessionStatus {
    if (_hostActions.status == StoryHostActionProtocolStatus.awaitingHost) {
      return StoryNarrativeSessionStatus.awaitingHost;
    }
    return switch (_engine.status) {
      StoryEngineStatus.awaitingChoice =>
        StoryNarrativeSessionStatus.awaitingChoice,
      StoryEngineStatus.awaitingContinue =>
        StoryNarrativeSessionStatus.awaitingContinue,
      StoryEngineStatus.terminated => StoryNarrativeSessionStatus.terminated,
      StoryEngineStatus.notStarted => throw StateError(
        'A StoryNarrativeSession cannot expose an unstarted StoryEngine.',
      ),
    };
  }

  StoryState get state => _engine.state!;
  StoryEvent? get currentEvent => _engine.currentEvent;
  List<StoryChoice> get availableChoices =>
      sessionStatus == StoryNarrativeSessionStatus.awaitingHost
      ? const <StoryChoice>[]
      : _engine.availableChoices;
  List<StoryChoiceExplanation> get choiceExplanations =>
      sessionStatus == StoryNarrativeSessionStatus.awaitingHost
      ? const <StoryChoiceExplanation>[]
      : _engine.choiceExplanations;
  StoryRuntimeHistory get history => _engine.history;
  int get randomSeed => _engine.randomSeed;

  StoryHostActionRequest? get pendingHostAction => _hostActions.pendingRequest;

  bool get isTerminated =>
      sessionStatus == StoryNarrativeSessionStatus.terminated;

  void choose(StoryChoiceId choiceId) {
    List<StoryEffectExplanation>? explanations;
    StoryRuntimeExecutionExplanation? executionExplanation;
    _owner._runSessionOperation(
      this,
      'choose',
      () {
        _requireNotAwaitingHost('choose');
        if (_owner._debugAdapter == null) {
          _engine.choose(choiceId);
          return;
        }
        try {
          executionExplanation = _engine.chooseWithExplanations(choiceId);
          explanations = _engine.lastEffectExplanations;
        } on Object {
          explanations = _engine.lastEffectExplanations;
          executionExplanation = _engine.lastExecutionExplanation;
          rethrow;
        }
      },
      commitPersistentState: true,
      afterPersistentCommit: () {
        _owner._emitEffectExplanations(
          sessionIndex: index,
          explanations: explanations ?? const [],
        );
        _owner._emitExecutionExplanation(
          sessionIndex: index,
          explanation: executionExplanation,
        );
      },
      onFailure: () {
        _owner._emitEffectExplanations(
          sessionIndex: index,
          explanations: explanations ?? const [],
          rolledBack: true,
        );
        _owner._emitExecutionExplanation(
          sessionIndex: index,
          explanation: executionExplanation,
          rolledBack: true,
        );
      },
    );
  }

  void continueStory() {
    List<StoryEffectExplanation>? explanations;
    StoryRuntimeExecutionExplanation? executionExplanation;
    _owner._runSessionOperation(
      this,
      'continueStory',
      () {
        _requireNotAwaitingHost('continueStory');
        if (_owner._debugAdapter == null) {
          _engine.continueStory();
          return;
        }
        try {
          executionExplanation = _engine.continueStoryWithExplanations();
          explanations = _engine.lastEffectExplanations;
        } on Object {
          explanations = _engine.lastEffectExplanations;
          executionExplanation = _engine.lastExecutionExplanation;
          rethrow;
        }
      },
      commitPersistentState: true,
      afterPersistentCommit: () {
        _owner._emitEffectExplanations(
          sessionIndex: index,
          explanations: explanations ?? const [],
        );
        _owner._emitExecutionExplanation(
          sessionIndex: index,
          explanation: executionExplanation,
        );
      },
      onFailure: () {
        _owner._emitEffectExplanations(
          sessionIndex: index,
          explanations: explanations ?? const [],
          rolledBack: true,
        );
        _owner._emitExecutionExplanation(
          sessionIndex: index,
          explanation: executionExplanation,
          rolledBack: true,
        );
      },
    );
  }

  /// Suspends this committed session on one portable host-action request.
  ///
  /// Stage 8I defines the suspend/resume protocol independently from the future
  /// authored representation that will cause such a request. The request may be
  /// emitted only from a host-visible committed pause. Request identity uses a
  /// monotonic session-local ordinal and consumes neither narrative RNG stream.
  StoryHostActionRequest requestHostAction({
    required String schemaNamespace,
    required String actionId,
    Map<String, Object> arguments = const {},
    StoryHostActionValueType? resultType,
  }) {
    return _owner._runSessionOperation(this, 'requestHostAction', () {
      if (_engine.status != StoryEngineStatus.awaitingChoice &&
          _engine.status != StoryEngineStatus.awaitingContinue) {
        throw const StoryNarrativeOperationException(
          message:
              'Host actions may be requested only from a committed '
              'choice/continue pause.',
          operation: 'requestHostAction',
        );
      }
      try {
        final request = _hostActions.request(
          schemaNamespace: schemaNamespace,
          actionId: actionId,
          arguments: arguments,
          resultType: resultType,
        );
        _owner._emitObservation(
          (sequence) => StoryNarrativeHostActionRequested(
            sequence: sequence,
            sessionIndex: index,
            requestId: request.id,
            schemaNamespace: request.schemaNamespace,
            actionId: request.actionId,
          ),
        );
        return request;
      } on StoryHostActionProtocolException catch (error) {
        throw StoryNarrativeOperationException(
          message: error.message,
          operation: 'requestHostAction',
          cause: error,
        );
      }
    });
  }

  /// Supplies a successful typed result and resumes the prior core pause.
  StoryHostActionCompleted completeHostAction(
    StoryHostActionRequestId requestId, {
    Object? value,
  }) {
    return _owner._runSessionOperation(this, 'completeHostAction', () {
      try {
        final outcome = _hostActions.complete(requestId, value: value);
        _owner._emitObservation(
          (sequence) => StoryNarrativeHostActionCompleted(
            sequence: sequence,
            sessionIndex: index,
            requestId: requestId,
            resolution: StoryNarrativeHostActionResolution.completed,
          ),
        );
        return outcome;
      } on StoryHostActionProtocolException catch (error) {
        throw StoryNarrativeOperationException(
          message: error.message,
          operation: 'completeHostAction',
          cause: error,
        );
      }
    });
  }

  /// Supplies an explicit host failure and resumes the prior core pause.
  StoryHostActionFailed failHostAction(
    StoryHostActionRequestId requestId, {
    required String code,
    required String message,
  }) {
    return _owner._runSessionOperation(this, 'failHostAction', () {
      try {
        final outcome = _hostActions.fail(
          requestId,
          code: code,
          message: message,
        );
        _owner._emitObservation(
          (sequence) => StoryNarrativeHostActionCompleted(
            sequence: sequence,
            sessionIndex: index,
            requestId: requestId,
            resolution: StoryNarrativeHostActionResolution.failed,
            code: code,
          ),
        );
        return outcome;
      } on StoryHostActionProtocolException catch (error) {
        throw StoryNarrativeOperationException(
          message: error.message,
          operation: 'failHostAction',
          cause: error,
        );
      }
    });
  }

  /// Supplies an explicit host cancellation and resumes the prior core pause.
  StoryHostActionCancelled cancelHostAction(
    StoryHostActionRequestId requestId, {
    required String code,
    String? message,
  }) {
    return _owner._runSessionOperation(this, 'cancelHostAction', () {
      try {
        final outcome = _hostActions.cancel(
          requestId,
          code: code,
          message: message,
        );
        _owner._emitObservation(
          (sequence) => StoryNarrativeHostActionCompleted(
            sequence: sequence,
            sessionIndex: index,
            requestId: requestId,
            resolution: StoryNarrativeHostActionResolution.cancelled,
            code: code,
          ),
        );
        return outcome;
      } on StoryHostActionProtocolException catch (error) {
        throw StoryNarrativeOperationException(
          message: error.message,
          operation: 'cancelHostAction',
          cause: error,
        );
      }
    });
  }

  /// Captures the core runtime and host-action protocol at one host boundary.
  ///
  /// For a session owned by [StoryNarrativeRuntime], this is a component of the
  /// aggregate checkpoint. It is not a supported durable substitute for
  /// [StoryNarrativeRuntime.createSnapshot] and aggregate restore because it
  /// does not contain the orchestration authority's shared state/RNG/cursors or
  /// sibling-session relationship.
  StoryNarrativeSessionSnapshot createSnapshot() =>
      StoryNarrativeSessionSnapshot(
        sessionIndex: index,
        entryPointId: entryPoint.id,
        runtimeSnapshot: _engine.createSnapshot(),
        hostActionSnapshot: _hostActions.createSnapshot(),
      );

  StoryEngine _engineWithPersistentState(StoryState persistentState) {
    final snapshot = _engine.createSnapshot();
    if (snapshot.state == persistentState) {
      return _engine;
    }
    return restoreStoryEngineWithProjectPreparation(
      project: _owner.project,
      snapshot: StoryRuntimeSnapshot(
        metadata: snapshot.metadata,
        projectId: snapshot.projectId,
        status: snapshot.status,
        state: persistentState,
        currentEventId: snapshot.currentEventId,
        history: snapshot.history,
        randomState: snapshot.randomState,
        maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
      ),
      preparation: _owner._projectPreparationForSiblingRestore(),
    );
  }

  void _requireNotAwaitingHost(String operation) {
    if (_hostActions.status == StoryHostActionProtocolStatus.awaitingHost) {
      throw StoryNarrativeOperationException(
        message:
            'Narrative input is suspended while host action '
            '${_hostActions.pendingRequest!.id} is pending.',
        operation: operation,
      );
    }
  }

  StoryNarrativeSessionHistory _historySnapshot() =>
      StoryNarrativeSessionHistory(
        sessionIndex: index,
        entryPointId: entryPoint.id,
        entryEventId: entryPoint.eventId,
        randomSeed: randomSeed,
        status: status,
        isAwaitingHost:
            _hostActions.status == StoryHostActionProtocolStatus.awaitingHost,
        history: history,
      );
}

/// Immutable structural history snapshot for one narrative session.
final class StoryNarrativeSessionHistory {
  const StoryNarrativeSessionHistory({
    required this.sessionIndex,
    required this.entryPointId,
    required this.entryEventId,
    required this.randomSeed,
    required this.status,
    this.isAwaitingHost = false,
    required this.history,
  }) : assert(
         !isAwaitingHost ||
             status == StoryEngineStatus.awaitingChoice ||
             status == StoryEngineStatus.awaitingContinue,
       );

  final int sessionIndex;
  final StoryEntryPointId entryPointId;
  final StoryEventId entryEventId;
  final int randomSeed;
  final StoryEngineStatus status;

  /// Whether Stage 8I host work is suspended over this core pause.
  final bool isAwaitingHost;

  /// Composite status at the time this history snapshot was captured.
  StoryNarrativeSessionStatus get sessionStatus {
    if (isAwaitingHost) {
      return StoryNarrativeSessionStatus.awaitingHost;
    }
    return switch (status) {
      StoryEngineStatus.awaitingChoice =>
        StoryNarrativeSessionStatus.awaitingChoice,
      StoryEngineStatus.awaitingContinue =>
        StoryNarrativeSessionStatus.awaitingContinue,
      StoryEngineStatus.terminated => StoryNarrativeSessionStatus.terminated,
      StoryEngineStatus.notStarted => throw StateError(
        'A narrative session history cannot represent an unstarted engine.',
      ),
    };
  }

  final StoryRuntimeHistory history;
}

/// Immutable ordered view of session-boundary narrative history.
///
/// Core [StoryRuntimeHistory] remains session-local. This wrapper preserves
/// session boundaries so later history-derived conditions can define their
/// scope deliberately instead of flattening unrelated dialogues implicitly.
final class StoryNarrativeRuntimeHistory {
  StoryNarrativeRuntimeHistory({
    Iterable<StoryNarrativeSessionHistory> sessions = const [],
  }) : sessions = List<StoryNarrativeSessionHistory>.unmodifiable(sessions);

  final List<StoryNarrativeSessionHistory> sessions;

  List<StoryEventId> get eventRoute => List<StoryEventId>.unmodifiable(
    sessions.expand((session) => session.history.eventRoute),
  );
}

void _validateHostConditionConfiguration(
  Iterable<StoryEntryPoint> entryPoints,
) {
  final hostRequirements =
      <StoryHostConditionKey, StoryHostConditionRequirement>{};
  for (final entryPoint in entryPoints) {
    for (final requirement in entryPoint.hostConditions) {
      final previous = hostRequirements[requirement.key];
      if (previous != null &&
          !_sameHostConditionRequest(previous, requirement)) {
        throw StoryNarrativeConfigurationException(
          message:
              'Host-condition key ${requirement.key} identifies '
              'conflicting condition requests across entry points.',
        );
      }
      hostRequirements[requirement.key] = requirement;
    }
  }
}

bool _sameHostConditionRequest(
  StoryHostConditionRequirement left,
  StoryHostConditionRequirement right,
) {
  if (left.schemaNamespace != right.schemaNamespace ||
      left.conditionId != right.conditionId ||
      left.arguments.length != right.arguments.length) {
    return false;
  }
  for (final entry in left.arguments.entries) {
    if (!right.arguments.containsKey(entry.key) ||
        right.arguments[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

StoryNarrativeErrorCategory _observationErrorCategory(Object error) {
  if (error is StoryNarrativeConfigurationException ||
      error is StoryEngineConfigurationException) {
    return StoryNarrativeErrorCategory.configuration;
  }
  if (error is StoryNarrativeOperationException ||
      error is StoryEngineOperationException) {
    return StoryNarrativeErrorCategory.operation;
  }
  if (error is StoryNarrativeResolutionException) {
    return StoryNarrativeErrorCategory.resolution;
  }
  if (error is StoryNarrativeExecutionException ||
      error is StoryEngineExecutionException) {
    return StoryNarrativeErrorCategory.execution;
  }
  return StoryNarrativeErrorCategory.unknown;
}

/// Reports an invalid or failed narrative-orchestration operation.
sealed class StoryNarrativeRuntimeException implements Exception {
  const StoryNarrativeRuntimeException({
    required this.message,
    this.operation,
    this.cause,
  });

  final String message;
  final String? operation;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Reports invalid narrative-runtime configuration.
final class StoryNarrativeConfigurationException
    extends StoryNarrativeRuntimeException {
  const StoryNarrativeConfigurationException({
    required super.message,
    super.cause,
  });
}

/// Reports an operation that is invalid for the current narrative-runtime state.
final class StoryNarrativeOperationException
    extends StoryNarrativeRuntimeException {
  const StoryNarrativeOperationException({
    required super.message,
    required super.operation,
    super.cause,
  });
}

/// Reports a failure while resolving an eligible narrative entry point.
final class StoryNarrativeResolutionException
    extends StoryNarrativeRuntimeException {
  const StoryNarrativeResolutionException({
    required super.message,
    super.cause,
  });
}

/// Reports a failure while executing an activated narrative session.
final class StoryNarrativeExecutionException
    extends StoryNarrativeRuntimeException {
  const StoryNarrativeExecutionException({
    required super.message,
    required super.operation,
    super.cause,
  });
}
