import '../host_action/story_host_action_protocol.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_project_id.dart';
import '../runtime/story_runtime_snapshot.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';

/// Format and orchestration-contract metadata carried by a
/// [StoryNarrativeRuntimeSnapshot].
///
/// These versions are independent from package semantic versioning, Story
/// Format v1, and the core [StoryRuntimeSnapshotMetadata] versions. The
/// aggregate layer therefore may evolve without changing the frozen authored
/// format or reinterpreting an existing core runtime checkpoint.
final class StoryNarrativeRuntimeSnapshotMetadata {
  const StoryNarrativeRuntimeSnapshotMetadata({
    this.formatVersion = currentFormatVersion,
    this.runtimeContractVersion = currentRuntimeContractVersion,
  }) : assert(formatVersion > 0),
       assert(runtimeContractVersion > 0);

  /// Persisted data-shape version emitted by the aggregate snapshot contract.
  static const int currentFormatVersion = 1;

  /// Orchestration semantics required to resume an aggregate checkpoint.
  static const int currentRuntimeContractVersion = 1;

  final int formatVersion;
  final int runtimeContractVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryNarrativeRuntimeSnapshotMetadata &&
          other.formatVersion == formatVersion &&
          other.runtimeContractVersion == runtimeContractVersion;

  @override
  int get hashCode => Object.hash(formatVersion, runtimeContractVersion);

  @override
  String toString() =>
      'StoryNarrativeRuntimeSnapshotMetadata('
      'formatVersion: $formatVersion, '
      'runtimeContractVersion: $runtimeContractVersion)';
}

/// Atomic checkpoint data for one suspendable narrative session.
///
/// A persistence layer stores the core [runtimeSnapshot] and
/// [hostActionSnapshot] together. Restoring the latter does not re-dispatch a
/// pending host operation; trusted host code reconciles the stable request ID
/// and then supplies exactly one completion/failure/cancellation input.
///
/// When the session belongs to a [StoryNarrativeRuntimeSnapshot], this value is
/// checkpoint data inside the aggregate authority. It is not a supported
/// durable substitute for aggregate restore: by itself it cannot reconstruct
/// shared persistent-state authority, orchestration RNG, allocation/observation
/// cursors, sibling sessions, or cross-session invariants.
///
/// The representation remains data-only. Cross-object validation such as
/// aggregate project identity, session ordering, host-action scope, and
/// shared-state consistency belongs to the aggregate validator.
final class StoryNarrativeSessionSnapshot {
  const StoryNarrativeSessionSnapshot({
    required this.sessionIndex,
    required this.entryPointId,
    required this.runtimeSnapshot,
    required this.hostActionSnapshot,
  });

  final int sessionIndex;
  final StoryEntryPointId entryPointId;
  final StoryRuntimeSnapshot runtimeSnapshot;
  final StoryHostActionProtocolSnapshot hostActionSnapshot;
}

/// Immutable data-only checkpoint for one complete narrative runtime.
///
/// This aggregate model layers around existing core/session persistence data;
/// it does not replace [StoryRuntimeSnapshot]. It contains the complete durable
/// state identified by Narrative Runtime Persistence Contract Revision 1 and is
/// deliberately free of observers, callbacks, loaders, host implementations,
/// and other live dependencies.
///
/// This is the authoritative durable checkpoint for a
/// `StoryNarrativeRuntime`. Retained [StoryNarrativeSessionSnapshot] values are
/// components of this aggregate and must not be restored independently as a
/// replacement for the aggregate authority.
///
/// Local value-shape checks happen in the constructor. Cross-field and
/// project-aware compatibility rules are centralized in the aggregate validator
/// so malformed decoded data can be diagnosed uniformly before restoration
/// becomes observable.
final class StoryNarrativeRuntimeSnapshot {
  StoryNarrativeRuntimeSnapshot({
    this.metadata = const StoryNarrativeRuntimeSnapshotMetadata(),
    required this.projectId,
    required this.persistentState,
    required this.persistentStateRevision,
    required this.orchestrationRandomState,
    required this.maxAutomaticTransitions,
    required this.nextSessionIndex,
    required this.nextObservationSequence,
    Iterable<StoryNarrativeSessionSnapshot> sessions = const [],
  }) : sessions = List<StoryNarrativeSessionSnapshot>.unmodifiable(sessions) {
    _validatePortableCursor(persistentStateRevision, 'persistentStateRevision');
    _validatePortableCursor(nextSessionIndex, 'nextSessionIndex');
    _validatePortableCursor(nextObservationSequence, 'nextObservationSequence');
    if (maxAutomaticTransitions <= 0) {
      throw ArgumentError.value(
        maxAutomaticTransitions,
        'maxAutomaticTransitions',
        'Automatic transition limit must be greater than zero.',
      );
    }
  }

  /// Aggregate persisted-data and orchestration compatibility metadata.
  final StoryNarrativeRuntimeSnapshotMetadata metadata;

  /// Logical authored-project identity for the complete runtime.
  final StoryProjectId projectId;

  /// Current committed persistent scalar narrative state.
  final StoryState persistentState;

  /// Monotonic observational revision of [persistentState].
  final int persistentStateRevision;

  /// Complete deterministic orchestration RNG state.
  ///
  /// Session-local RNG state remains inside each session's
  /// [StoryRuntimeSnapshot].
  final StoryRuntimeRandomState orchestrationRandomState;

  /// Runtime traversal guard used by current and future sessions.
  final int maxAutomaticTransitions;

  /// Stable identity that will be assigned to the next activated session.
  final int nextSessionIndex;

  /// Sequence identity that will be assigned to the next emitted observation.
  ///
  /// Observers and past observation payloads themselves are not persisted.
  final int nextObservationSequence;

  /// Every retained session in deterministic activation order.
  ///
  /// Completed sessions remain present in Revision 1. Active membership is
  /// derived later from each validated session's composite status rather than
  /// persisted in a second authoritative list.
  final List<StoryNarrativeSessionSnapshot> sessions;

  @override
  String toString() =>
      'StoryNarrativeRuntimeSnapshot(projectId: $projectId, '
      'sessions: ${sessions.length}, nextSessionIndex: $nextSessionIndex, '
      'persistentStateRevision: $persistentStateRevision)';
}

void _validatePortableCursor(int value, String name) {
  if (value < 0 || value > StoryIntegerValue.maxPortableValue) {
    throw ArgumentError.value(
      value,
      name,
      'Aggregate persistence cursors must be non-negative portable integers.',
    );
  }
}
