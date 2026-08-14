import '../story_format_bundle.dart';

/// Package-internal one-version Story Format bundle migration.
///
/// Migrations operate on the logical authored bundle before current-version
/// decoding. They are deliberately package-owned: third-party callers should
/// not reinterpret unknown core Story Format semantics with ad-hoc migrations.
/// A step may rewrite any bundle file because a future Story Format version may
/// legitimately evolve both JSON shape and physical bundle layout.
abstract interface class StoryFormatMigrationStep {
  const StoryFormatMigrationStep();

  /// Source Story Format version handled by this step.
  int get fromVersion;

  /// Destination Story Format version emitted by this step.
  int get toVersion;

  /// Deterministically migrates [bundle] to [toVersion].
  StoryFormatBundle migrate(StoryFormatBundle bundle);
}

/// Ordered package-owned Story Format migration pipeline.
///
/// Story Format v1 is the first public authored format, so [builtIn] is empty.
/// The pipeline is established now so a future v2 adds one explicit v1 -> v2
/// bundle transform instead of embedding legacy branches throughout the v2
/// decoder. No fictional v0 production format is introduced.
final class StoryFormatMigrationPipeline {
  StoryFormatMigrationPipeline({
    Iterable<StoryFormatMigrationStep> steps = const [],
  }) : _steps = _indexSteps(steps);

  /// Package-owned migrations supported by the current release.
  factory StoryFormatMigrationPipeline.builtIn() =>
      StoryFormatMigrationPipeline();

  final Map<int, StoryFormatMigrationStep> _steps;

  /// Whether every consecutive migration step exists from [fromVersion] to
  /// [toVersion].
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

  /// Applies the complete deterministic migration path.
  StoryFormatBundle migrate({
    required StoryFormatBundle bundle,
    required int fromVersion,
    required int toVersion,
  }) {
    if (!canMigrate(fromVersion: fromVersion, toVersion: toVersion)) {
      throw StateError(
        'No complete Story Format migration path exists from version '
        '$fromVersion to $toVersion.',
      );
    }

    var current = bundle;
    var version = fromVersion;
    while (version < toVersion) {
      final step = _steps[version]!;
      current = step.migrate(current);
      version = step.toVersion;
    }
    return current;
  }
}

Map<int, StoryFormatMigrationStep> _indexSteps(
  Iterable<StoryFormatMigrationStep> steps,
) {
  final result = <int, StoryFormatMigrationStep>{};
  for (final step in steps) {
    if (step.fromVersion <= 0 || step.toVersion != step.fromVersion + 1) {
      throw ArgumentError.value(
        step,
        'steps',
        'Story Format migrations must advance exactly one positive format '
            'version at a time.',
      );
    }
    if (result.containsKey(step.fromVersion)) {
      throw ArgumentError.value(
        step.fromVersion,
        'steps',
        'Only one Story Format migration step may own each source version.',
      );
    }
    result[step.fromVersion] = step;
  }
  return Map<int, StoryFormatMigrationStep>.unmodifiable(result);
}
