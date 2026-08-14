/// Package-internal raw-document migration contract for runtime snapshots.
///
/// Migrations operate on JSON-compatible maps before current-version decoding.
/// They are intentionally separate from `StoryRuntimeSnapshot` so old encoded
/// shapes do not have to be representable by today's domain constructors.
abstract interface class StoryRuntimeSnapshotMigrationStep {
  const StoryRuntimeSnapshotMigrationStep();

  int get fromVersion;
  int get toVersion;

  Map<String, Object?> migrate(Map<String, Object?> document);
}

/// Ordered package-owned migration pipeline used by the public snapshot codec.
///
/// Stage 4B has only format version 1, so [builtIn] is empty. The pipeline and
/// its invariants are established now so a future format version adds a small
/// N -> N+1 transformation rather than ad-hoc branching in the decoder.
final class StoryRuntimeSnapshotMigrationPipeline {
  StoryRuntimeSnapshotMigrationPipeline({
    Iterable<StoryRuntimeSnapshotMigrationStep> steps = const [],
  }) : _steps = _indexSteps(steps);

  factory StoryRuntimeSnapshotMigrationPipeline.builtIn() =>
      StoryRuntimeSnapshotMigrationPipeline();

  final Map<int, StoryRuntimeSnapshotMigrationStep> _steps;

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
        'No complete runtime-snapshot migration path exists from format '
        '$fromVersion to $toVersion.',
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
          'Runtime-snapshot migration ${step.fromVersion} -> '
          '${step.toVersion} did not emit its declared formatVersion.',
        );
      }
      version = step.toVersion;
    }
    return current;
  }
}

Map<int, StoryRuntimeSnapshotMigrationStep> _indexSteps(
  Iterable<StoryRuntimeSnapshotMigrationStep> steps,
) {
  final result = <int, StoryRuntimeSnapshotMigrationStep>{};
  for (final step in steps) {
    if (step.fromVersion <= 0 || step.toVersion != step.fromVersion + 1) {
      throw ArgumentError.value(
        step,
        'steps',
        'Runtime snapshot migrations must advance exactly one positive format '
            'version at a time.',
      );
    }
    if (result.containsKey(step.fromVersion)) {
      throw ArgumentError.value(
        step.fromVersion,
        'steps',
        'Only one migration step may own each source format version.',
      );
    }
    result[step.fromVersion] = step;
  }
  return Map<int, StoryRuntimeSnapshotMigrationStep>.unmodifiable(result);
}
