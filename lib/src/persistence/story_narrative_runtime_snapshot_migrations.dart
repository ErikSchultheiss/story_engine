/// Package-internal raw-document migration contract for aggregate narrative
/// runtime snapshots.
///
/// Migrations operate on JSON-compatible maps before current-version decoding.
/// They are deliberately separate from `StoryNarrativeRuntimeSnapshot` so old
/// persisted shapes never have to be representable by today's domain model.
abstract interface class StoryNarrativeRuntimeSnapshotMigrationStep {
  const StoryNarrativeRuntimeSnapshotMigrationStep();

  int get fromVersion;
  int get toVersion;

  Map<String, Object?> migrate(Map<String, Object?> document);
}

/// Ordered package-owned migration pipeline used by the aggregate snapshot
/// codec.
///
/// Stage 9A4 has only format version 1, so [builtIn] is currently empty. The
/// pipeline exists now so a future format version adds one deterministic
/// N -> N+1 transformation rather than ad-hoc branching in the decoder.
final class StoryNarrativeRuntimeSnapshotMigrationPipeline {
  StoryNarrativeRuntimeSnapshotMigrationPipeline({
    Iterable<StoryNarrativeRuntimeSnapshotMigrationStep> steps = const [],
  }) : _steps = _indexSteps(steps);

  factory StoryNarrativeRuntimeSnapshotMigrationPipeline.builtIn() =>
      StoryNarrativeRuntimeSnapshotMigrationPipeline();

  final Map<int, StoryNarrativeRuntimeSnapshotMigrationStep> _steps;

  bool canMigrate({required int fromVersion, required int toVersion}) {
    if (fromVersion <= 0 || toVersion <= 0 || fromVersion > toVersion) {
      return false;
    }
    var version = fromVersion;
    while (version < toVersion) {
      final step = _steps[version];
      if (step == null || step.toVersion != version + 1) {
        return false;
      }
      version = step.toVersion;
    }
    return true;
  }

  Map<String, Object?> migrate({
    required Map<String, Object?> document,
    required int fromVersion,
    required int toVersion,
  }) {
    if (!canMigrate(fromVersion: fromVersion, toVersion: toVersion)) {
      throw StateError(
        'No complete aggregate narrative-runtime snapshot migration path '
        'exists from format $fromVersion to $toVersion.',
      );
    }

    var current = Map<String, Object?>.of(document);
    var version = fromVersion;
    while (version < toVersion) {
      final step = _steps[version]!;
      current = Map<String, Object?>.of(step.migrate(current));
      final migratedVersion = current['formatVersion'];
      if (migratedVersion != step.toVersion) {
        throw StateError(
          'Aggregate snapshot migration ${step.fromVersion} -> '
          '${step.toVersion} did not emit its declared formatVersion.',
        );
      }
      version = step.toVersion;
    }
    return current;
  }
}

Map<int, StoryNarrativeRuntimeSnapshotMigrationStep> _indexSteps(
  Iterable<StoryNarrativeRuntimeSnapshotMigrationStep> steps,
) {
  final result = <int, StoryNarrativeRuntimeSnapshotMigrationStep>{};
  for (final step in steps) {
    if (step.fromVersion <= 0 || step.toVersion != step.fromVersion + 1) {
      throw ArgumentError.value(
        step,
        'steps',
        'Aggregate snapshot migrations must advance exactly one positive '
            'format version at a time.',
      );
    }
    if (result.containsKey(step.fromVersion)) {
      throw ArgumentError.value(
        step.fromVersion,
        'steps',
        'Only one aggregate snapshot migration step may own each source '
            'format version.',
      );
    }
    result[step.fromVersion] = step;
  }
  return Map<int, StoryNarrativeRuntimeSnapshotMigrationStep>.unmodifiable(
    result,
  );
}
