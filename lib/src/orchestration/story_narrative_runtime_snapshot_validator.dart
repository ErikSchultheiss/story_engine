import '../identity/story_entry_point_id.dart';
import '../model/story_project.dart';
import '../runtime/story_engine_status.dart';
import '../runtime/story_runtime_snapshot_validator.dart';
import '../runtime/story_seeded_random_source.dart';
import 'story_entry_point.dart';
import 'story_narrative_runtime_snapshot.dart';

/// Stable categories describing why an aggregate narrative-runtime snapshot
/// cannot safely resume against the supplied orchestration configuration.
enum StoryNarrativeRuntimeSnapshotCompatibilityIssue {
  /// Aggregate persisted data uses an unsupported format version.
  unsupportedFormatVersion,

  /// Aggregate orchestration semantics differ from the current contract.
  unsupportedRuntimeContractVersion,

  /// Aggregate snapshot belongs to a different authored project identity.
  projectIdMismatch,

  /// Aggregate shared state is incompatible with the supplied project schema.
  persistentStateSchemaMismatch,

  /// Supplied restore configuration contains duplicate entry-point IDs.
  duplicateEntryPointId,

  /// A supplied entry point targets an event absent from the project.
  missingEntryPointEvent,

  /// Aggregate orchestration random state uses an unsupported algorithm.
  unsupportedOrchestrationRandomAlgorithm,

  /// Aggregate orchestration random state uses an unsupported algorithm
  /// version.
  unsupportedOrchestrationRandomAlgorithmVersion,

  /// Aggregate orchestration random-state payload is malformed.
  invalidOrchestrationRandomState,

  /// Retained session indexes are not the contiguous activation sequence
  /// required by aggregate persistence Revision 1.
  invalidSessionIndexSequence,

  /// The next session identity is inconsistent with retained sessions.
  invalidNextSessionIndex,

  /// A retained session references no supplied entry point.
  missingSessionEntryPoint,

  /// A retained core runtime snapshot is incompatible with the supplied
  /// project/runtime contract.
  sessionRuntimeSnapshotIncompatible,

  /// A retained session uses a different automatic-transition guard from the
  /// aggregate runtime.
  sessionMaxAutomaticTransitionsMismatch,

  /// A retained narrative session contains a core runtime that never started.
  unstartedSession,

  /// A retained host-action protocol scope does not match its session ID.
  hostActionScopeMismatch,

  /// Pending host-action state is impossible for the retained core lifecycle.
  invalidPendingHostActionState,

  /// An unfinished session does not contain the aggregate committed shared
  /// persistent state.
  unfinishedSessionStateMismatch,

  /// The first committed event of a session does not match its stored entry
  /// point's target event.
  sessionEntryPointOriginMismatch,
}

/// Structured incompatibility raised when an aggregate runtime checkpoint
/// cannot be restored safely against the supplied project/configuration.
final class StoryNarrativeRuntimeSnapshotCompatibilityException
    implements Exception {
  const StoryNarrativeRuntimeSnapshotCompatibilityException({
    required this.issue,
    required this.path,
    required this.message,
    this.cause,
  });

  final StoryNarrativeRuntimeSnapshotCompatibilityIssue issue;

  /// Machine-oriented location within the aggregate checkpoint/configuration.
  final String path;

  final String message;
  final Object? cause;

  /// Machine-oriented location alias shared with other public data failures.
  String get location => path;

  /// Actionable recovery guidance for the incompatibility category.
  String get suggestion => switch (issue) {
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .unsupportedRuntimeContractVersion =>
      'Restore this save with a compatible story_engine version, or migrate '
          'the aggregate snapshot before loading it.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.projectIdMismatch =>
      'Restore the aggregate snapshot against the StoryProject it was created '
          'from.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .persistentStateSchemaMismatch =>
      'Use a project schema compatible with the saved scalar values, or '
          'migrate the aggregate state before restore.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.duplicateEntryPointId ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.missingEntryPointEvent =>
      'Fix the supplied narrative entry-point configuration before restoring.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .unsupportedOrchestrationRandomAlgorithm ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .unsupportedOrchestrationRandomAlgorithmVersion =>
      'Use a runtime version that supports the saved orchestration random '
          'stream.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .invalidOrchestrationRandomState =>
      'Discard or repair the corrupted orchestration random-state payload '
          'before restoring.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .invalidSessionIndexSequence ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.invalidNextSessionIndex ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.missingSessionEntryPoint ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .sessionMaxAutomaticTransitionsMismatch ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.unstartedSession ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue.hostActionScopeMismatch ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .invalidPendingHostActionState ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .unfinishedSessionStateMismatch ||
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .sessionEntryPointOriginMismatch =>
      'Use the matching aggregate checkpoint/configuration, or migrate the '
          'inconsistent session data before restore.',
    StoryNarrativeRuntimeSnapshotCompatibilityIssue
        .sessionRuntimeSnapshotIncompatible =>
      'Resolve the nested core runtime snapshot incompatibility before '
          'restoring the aggregate runtime.',
  };

  @override
  String toString() =>
      'StoryNarrativeRuntimeSnapshotCompatibilityException('
      '${issue.name}) at $path: $message';
}

/// Validates one aggregate narrative-runtime checkpoint before restoration.
///
/// The validator is deliberately side-effect free. It reuses
/// [StoryRuntimeSnapshotValidator] for every retained core checkpoint, then
/// applies only the orchestration-level invariants frozen by Narrative Runtime
/// Persistence Contract Revision 1. It does not reconstruct sessions, consume
/// random state, emit observations, or dispatch host work.
final class StoryNarrativeRuntimeSnapshotValidator {
  const StoryNarrativeRuntimeSnapshotValidator();

  void validate({
    required StoryNarrativeRuntimeSnapshot snapshot,
    required StoryProject project,
    required Iterable<StoryEntryPoint> entryPoints,
  }) {
    _validateVersions(snapshot);
    _validateProjectIdentity(snapshot, project);
    _validatePersistentStateSchema(snapshot, project);
    _validateOrchestrationRandomState(snapshot);

    final entryPointLookup = _buildEntryPointLookup(project, entryPoints);
    _validateSessions(snapshot, project, entryPointLookup);
  }

  void _validateVersions(StoryNarrativeRuntimeSnapshot snapshot) {
    if (snapshot.metadata.formatVersion !=
        StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedFormatVersion,
        path: r'$.formatVersion',
        message:
            'Aggregate snapshot format version '
            '${snapshot.metadata.formatVersion} is not supported by the '
            'current narrative runtime.',
      );
    }
    if (snapshot.metadata.runtimeContractVersion !=
        StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedRuntimeContractVersion,
        path: r'$.runtimeContractVersion',
        message:
            'Aggregate snapshot runtime contract version '
            '${snapshot.metadata.runtimeContractVersion} is not supported by '
            'the current narrative runtime.',
      );
    }
  }

  void _validateProjectIdentity(
    StoryNarrativeRuntimeSnapshot snapshot,
    StoryProject project,
  ) {
    if (snapshot.projectId != project.id) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue:
            StoryNarrativeRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
        path: r'$.projectId',
        message:
            'Aggregate snapshot belongs to ${snapshot.projectId.value}, '
            'but restore project is ${project.id.value}.',
      );
    }
  }

  void _validatePersistentStateSchema(
    StoryNarrativeRuntimeSnapshot snapshot,
    StoryProject project,
  ) {
    for (final entry in snapshot.persistentState.values.entries) {
      final definition = project.stateSchema.definitionFor(entry.key);
      if (definition == null || definition.type != entry.value.type) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .persistentStateSchemaMismatch,
          path: r'$.persistentState',
          message: definition == null
              ? 'Aggregate persistent state references variable '
                    '${entry.key.value}, but that variable is not declared by '
                    'the supplied project.'
              : 'Aggregate persistent-state value for ${entry.key.value} has '
                    'type ${entry.value.type.name}, but the supplied project '
                    'declares ${definition.type.name}.',
        );
      }
    }
  }

  void _validateOrchestrationRandomState(
    StoryNarrativeRuntimeSnapshot snapshot,
  ) {
    final randomState = snapshot.orchestrationRandomState;
    if (randomState.algorithmId !=
        StorySeededRandomSource.runtimeStateAlgorithmId) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedOrchestrationRandomAlgorithm,
        path: r'$.orchestrationRandomState.algorithmId',
        message:
            'Aggregate orchestration random algorithm '
            '${randomState.algorithmId} is not supported.',
      );
    }
    if (randomState.algorithmVersion !=
        StorySeededRandomSource.runtimeStateAlgorithmVersion) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedOrchestrationRandomAlgorithmVersion,
        path: r'$.orchestrationRandomState.algorithmVersion',
        message:
            'Aggregate orchestration random algorithm version '
            '${randomState.algorithmVersion} is not supported for '
            '${randomState.algorithmId}.',
      );
    }

    try {
      StorySeededRandomSource.validateRuntimeState(randomState);
    } on StorySeededRandomStateException catch (error) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .invalidOrchestrationRandomState,
        path: r'$.orchestrationRandomState.stateWords',
        message: error.message,
        cause: error,
      );
    }
  }

  Map<StoryEntryPointId, StoryEntryPoint> _buildEntryPointLookup(
    StoryProject project,
    Iterable<StoryEntryPoint> entryPoints,
  ) {
    final eventIds = {for (final event in project.events) event.id};
    final result = <StoryEntryPointId, StoryEntryPoint>{};
    var index = 0;
    for (final entryPoint in entryPoints) {
      if (result.containsKey(entryPoint.id)) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .duplicateEntryPointId,
          path: '\$.entryPoints[$index].id',
          message:
              'Entry-point ID ${entryPoint.id.value} is duplicated in '
              'restore configuration.',
        );
      }
      if (!eventIds.contains(entryPoint.eventId)) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .missingEntryPointEvent,
          path: '\$.entryPoints[$index].eventId',
          message:
              'Entry point ${entryPoint.id.value} targets missing event '
              '${entryPoint.eventId.value}.',
        );
      }
      result[entryPoint.id] = entryPoint;
      index++;
    }
    return result;
  }

  void _validateSessions(
    StoryNarrativeRuntimeSnapshot snapshot,
    StoryProject project,
    Map<StoryEntryPointId, StoryEntryPoint> entryPoints,
  ) {
    StoryRuntimeProjectPreparation? preparation;
    final sessions = snapshot.sessions;

    for (var index = 0; index < sessions.length; index++) {
      final session = sessions[index];
      final path = '\$.sessions[$index]';

      if (session.sessionIndex != index) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .invalidSessionIndexSequence,
          path: '$path.sessionIndex',
          message:
              'Revision 1 retained sessions must have contiguous '
              'activation indexes beginning at 0; expected $index but found '
              '${session.sessionIndex}.',
        );
      }

      final entryPoint = entryPoints[session.entryPointId];
      if (entryPoint == null) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .missingSessionEntryPoint,
          path: '$path.entryPointId',
          message:
              'Retained session ${session.sessionIndex} references '
              'unknown entry point ${session.entryPointId.value}.',
        );
      }

      try {
        // Reuse only immutable project lookups. The first checkpoint keeps
        // the standalone validator's preflight/error order; every subsequent
        // checkpoint still receives complete snapshot-specific validation.
        final prepared = preparation;
        if (prepared == null) {
          preparation = StoryRuntimeProjectPreparation.prepareForSnapshot(
            project: project,
            snapshot: session.runtimeSnapshot,
          );
          preparation.validateSnapshotAfterPreflight(
            project: project,
            snapshot: session.runtimeSnapshot,
          );
        } else {
          prepared.validateSnapshot(
            project: project,
            snapshot: session.runtimeSnapshot,
          );
        }
      } on StoryRuntimeSnapshotCompatibilityException catch (error) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .sessionRuntimeSnapshotIncompatible,
          path: '$path.runtimeSnapshot${_nestedPathSuffix(error.path)}',
          message:
              'Retained session ${session.sessionIndex} contains an '
              'incompatible core runtime snapshot: ${error.message}',
          cause: error,
        );
      }

      if (session.runtimeSnapshot.maxAutomaticTransitions !=
          snapshot.maxAutomaticTransitions) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .sessionMaxAutomaticTransitionsMismatch,
          path: '$path.runtimeSnapshot.maxAutomaticTransitions',
          message:
              'Session ${session.sessionIndex} uses automatic-transition '
              'limit ${session.runtimeSnapshot.maxAutomaticTransitions}, but '
              'the aggregate runtime uses ${snapshot.maxAutomaticTransitions}.',
        );
      }

      final status = session.runtimeSnapshot.status;
      if (status == StoryEngineStatus.notStarted) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue:
              StoryNarrativeRuntimeSnapshotCompatibilityIssue.unstartedSession,
          path: '$path.runtimeSnapshot.status',
          message:
              'A retained StoryNarrativeSession cannot contain an '
              'unstarted core runtime.',
        );
      }

      final expectedScope = 'session_${session.sessionIndex}';
      if (session.hostActionSnapshot.scope != expectedScope) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .hostActionScopeMismatch,
          path: '$path.hostActionSnapshot.scope',
          message:
              'Session ${session.sessionIndex} host-action scope must be '
              '$expectedScope, but found ${session.hostActionSnapshot.scope}.',
        );
      }

      final pendingRequest = session.hostActionSnapshot.pendingRequest;
      if (pendingRequest != null &&
          status != StoryEngineStatus.awaitingChoice &&
          status != StoryEngineStatus.awaitingContinue) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .invalidPendingHostActionState,
          path: '$path.hostActionSnapshot.pendingRequest',
          message:
              'A pending host action requires a committed choice or '
              'continue pause; core status is ${status.name}.',
        );
      }

      if (status != StoryEngineStatus.terminated &&
          session.runtimeSnapshot.state != snapshot.persistentState) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .unfinishedSessionStateMismatch,
          path: '$path.runtimeSnapshot.state',
          message:
              'Unfinished session ${session.sessionIndex} does not '
              'contain the aggregate committed persistent state.',
        );
      }

      final eventRoute = session.runtimeSnapshot.history.eventRoute;
      if (eventRoute.isEmpty || eventRoute.first != entryPoint.eventId) {
        throw StoryNarrativeRuntimeSnapshotCompatibilityException(
          issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
              .sessionEntryPointOriginMismatch,
          path: '$path.runtimeSnapshot.history',
          message:
              'Session ${session.sessionIndex} first committed event does '
              'not match entry point ${entryPoint.id.value} target '
              '${entryPoint.eventId.value}.',
        );
      }
    }

    if (snapshot.nextSessionIndex != sessions.length) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .invalidNextSessionIndex,
        path: r'$.nextSessionIndex',
        message:
            'Revision 1 without session compaction requires '
            'nextSessionIndex to equal retained session count '
            '${sessions.length}, but found ${snapshot.nextSessionIndex}.',
      );
    }
  }
}

String _nestedPathSuffix(String path) {
  if (path == r'$') {
    return '';
  }
  if (path.startsWith(r'$.')) {
    return path.substring(1);
  }
  return '.$path';
}
