import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';
import 'story_engine_status.dart';
import 'story_runtime_history.dart';

/// Format and runtime-contract metadata carried by a [StoryRuntimeSnapshot].
///
/// Snapshot format versioning is deliberately independent from package
/// semantic versioning and from the future authored Story Format version.
/// [formatVersion] describes the persisted snapshot data shape, while
/// [runtimeContractVersion] describes execution semantics that a restore
/// implementation must understand before resuming the snapshot.
final class StoryRuntimeSnapshotMetadata {
  const StoryRuntimeSnapshotMetadata({
    this.formatVersion = currentFormatVersion,
    this.runtimeContractVersion = currentRuntimeContractVersion,
  }) : assert(formatVersion > 0),
       assert(runtimeContractVersion > 0);

  /// Snapshot data-shape version emitted by the current engine contract.
  static const int currentFormatVersion = 1;

  /// Runtime execution compatibility version understood by the current
  /// snapshot contract.
  static const int currentRuntimeContractVersion = 1;

  /// Version of the runtime-snapshot persisted representation.
  final int formatVersion;

  /// Version of runtime semantics required to resume execution safely.
  final int runtimeContractVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryRuntimeSnapshotMetadata &&
          other.formatVersion == formatVersion &&
          other.runtimeContractVersion == runtimeContractVersion;

  @override
  int get hashCode => Object.hash(formatVersion, runtimeContractVersion);

  @override
  String toString() =>
      'StoryRuntimeSnapshotMetadata(formatVersion: $formatVersion, '
      'runtimeContractVersion: $runtimeContractVersion)';
}

/// Versioned, algorithm-owned pseudo-random state stored in a runtime snapshot.
///
/// This is persistence data, not a caller-controlled random-number generator.
/// Stage 4D freezes the current engine RNG as the versioned
/// `story_engine.lcg32` v1 snapshot contract. Consumers must still treat
/// [stateWords] as opaque; only the matching engine RNG implementation owns
/// their interpretation.
final class StoryRuntimeRandomState {
  StoryRuntimeRandomState({
    required this.algorithmId,
    required this.algorithmVersion,
    required Iterable<int> stateWords,
  }) : stateWords = List<int>.unmodifiable(stateWords) {
    if (!_algorithmIdPattern.hasMatch(algorithmId)) {
      throw ArgumentError.value(
        algorithmId,
        'algorithmId',
        'Random algorithm IDs must be stable lower-case machine tokens.',
      );
    }
    if (algorithmVersion <= 0) {
      throw ArgumentError.value(
        algorithmVersion,
        'algorithmVersion',
        'Random algorithm version must be greater than zero.',
      );
    }
    if (this.stateWords.isEmpty) {
      throw ArgumentError.value(
        stateWords,
        'stateWords',
        'Random state must contain at least one state word.',
      );
    }
    for (final word in this.stateWords) {
      if (word < 0 || word > StoryIntegerValue.maxPortableValue) {
        throw ArgumentError.value(
          word,
          'stateWords',
          'Random state words must remain within the portable exact integer '
              'range.',
        );
      }
    }
  }

  static final RegExp _algorithmIdPattern = RegExp(
    r'^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$',
  );

  /// Stable machine identifier for the deterministic RNG algorithm.
  final String algorithmId;

  /// Compatibility version of [algorithmId].
  final int algorithmVersion;

  /// Algorithm-specific deterministic state in a portable integer form.
  ///
  /// Consumers must treat these words as opaque. Only the matching engine RNG
  /// implementation should interpret them.
  final List<int> stateWords;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryRuntimeRandomState &&
          other.algorithmId == algorithmId &&
          other.algorithmVersion == algorithmVersion &&
          _intListsEqual(other.stateWords, stateWords);

  @override
  int get hashCode => Object.hash(
    algorithmId,
    algorithmVersion,
    Object.hashAll(stateWords),
  );

  @override
  String toString() =>
      'StoryRuntimeRandomState(algorithmId: $algorithmId, '
      'algorithmVersion: $algorithmVersion, stateWords: ${stateWords.length})';
}

/// Immutable committed runtime state required to resume one playthrough.
///
/// This model is deliberately distinct from authored-project serialization.
/// It stores runtime facts only: project identity, lifecycle status, current
/// authored state/event, the canonical committed history trace, deterministic
/// RNG state, and the runtime configuration that can influence future
/// execution.
///
/// Stage 4A defines the public snapshot value contract, Stage 4B adds external
/// encoding/compatibility validation, Stage 4C adds direct committed-state
/// capture/restoration, and Stages 4D-4F freeze deterministic RNG/parity and
/// harden compatibility without embedding representation logic in this value.
final class StoryRuntimeSnapshot {
  StoryRuntimeSnapshot({
    this.metadata = const StoryRuntimeSnapshotMetadata(),
    required this.projectId,
    required this.status,
    required this.state,
    required this.currentEventId,
    required this.history,
    required this.randomState,
    required this.maxAutomaticTransitions,
  }) {
    if (maxAutomaticTransitions <= 0) {
      throw ArgumentError.value(
        maxAutomaticTransitions,
        'maxAutomaticTransitions',
        'Automatic transition limit must be greater than zero.',
      );
    }
    _validateCommittedShape();
  }

  /// Snapshot-format/runtime compatibility metadata.
  final StoryRuntimeSnapshotMetadata metadata;

  /// Authored project identity this playthrough belongs to.
  ///
  /// Project identity is necessary but not by itself a complete authored-
  /// content compatibility proof. Stage 4 deliberately does not embed a
  /// whole-project semantic fingerprint; applications pair snapshots with the
  /// intended authored project revision until a later project/version contract
  /// defines stronger revision identity.
  final StoryProjectId projectId;

  /// Lifecycle status at the committed snapshot boundary.
  final StoryEngineStatus status;

  /// Current authored scalar state, or null only before successful start.
  final StoryState? state;

  /// Most recently entered event, or null only before successful start.
  final StoryEventId? currentEventId;

  /// One canonical ordered trace of all committed runtime observations.
  ///
  /// Visited-event lists, selected-choice lists, and occurrence counters are
  /// intentionally not persisted separately; they remain derived views of
  /// [history].
  final StoryRuntimeHistory history;

  /// Full deterministic pseudo-random state required for future random parity.
  final StoryRuntimeRandomState randomState;

  /// Automatic traversal guard used by the run.
  ///
  /// This is execution-affecting runtime configuration. Restoring with a
  /// different guard could change whether a future automatic chain succeeds.
  final int maxAutomaticTransitions;

  void _validateCommittedShape() {
    switch (status) {
      case StoryEngineStatus.notStarted:
        if (state != null || currentEventId != null || history.isNotEmpty) {
          throw ArgumentError(
            'A not-started runtime snapshot must have null state/current event '
            'and empty committed history.',
          );
        }
        break;
      case StoryEngineStatus.awaitingChoice:
      case StoryEngineStatus.awaitingContinue:
      case StoryEngineStatus.terminated:
        final state = this.state;
        final currentEventId = this.currentEventId;
        if (state == null || currentEventId == null) {
          throw ArgumentError(
            'A started runtime snapshot must contain state and current event.',
          );
        }
        final route = history.eventRoute;
        if (route.isEmpty || route.last != currentEventId) {
          throw ArgumentError(
            'A started runtime snapshot history must end at the current event.',
          );
        }
        break;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryRuntimeSnapshot &&
          other.metadata == metadata &&
          other.projectId == projectId &&
          other.status == status &&
          other.state == state &&
          other.currentEventId == currentEventId &&
          other.history == history &&
          other.randomState == randomState &&
          other.maxAutomaticTransitions == maxAutomaticTransitions;

  @override
  int get hashCode => Object.hash(
    metadata,
    projectId,
    status,
    state,
    currentEventId,
    history,
    randomState,
    maxAutomaticTransitions,
  );

  @override
  String toString() =>
      'StoryRuntimeSnapshot(projectId: $projectId, status: ${status.name}, '
      'currentEventId: $currentEventId, historySteps: ${history.steps.length})';
}

bool _intListsEqual(List<int> left, List<int> right) {
  if (identical(left, right)) {
    return true;
  }
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
