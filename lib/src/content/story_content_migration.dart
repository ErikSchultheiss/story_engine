import '../identity/story_choice_id.dart';
import '../identity/story_content_release_id.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../model/story_project.dart';
import '../runtime/story_runtime_history.dart';
import '../runtime/story_runtime_snapshot.dart';
import '../runtime/story_runtime_snapshot_validator.dart';
import '../identity/story_variable_id.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';
import 'story_save_content_binding.dart';
import 'story_content_release_manifest.dart';

/// Declarative structural migration policy between two content releases.
///
/// Redirects use stable authored IDs only. The plan contains no executable
/// callback. [fallbackEntryPointId] is an explicit host recovery destination;
/// it is never applied automatically because doing so would fabricate a new
/// narrative history while pretending an old save resumed normally.
final class StoryContentMigrationPlan {
  StoryContentMigrationPlan({
    required this.projectId,
    required this.fromReleaseId,
    required this.toReleaseId,
    Map<StoryEventId, StoryEventId> eventRedirects = const {},
    Map<StoryChoiceId, StoryChoiceId> choiceRedirects = const {},
    this.fallbackEntryPointId,
  }) : eventRedirects = Map<StoryEventId, StoryEventId>.unmodifiable(
         eventRedirects,
       ),
       choiceRedirects = Map<StoryChoiceId, StoryChoiceId>.unmodifiable(
         choiceRedirects,
       ) {
    if (fromReleaseId == toReleaseId &&
        (this.eventRedirects.isNotEmpty ||
            this.choiceRedirects.isNotEmpty ||
            fallbackEntryPointId != null)) {
      throw ArgumentError(
        'A content migration plan must move between distinct release IDs.',
      );
    }
  }

  /// Stable wire contract identity.
  static const String contractId = 'open_story.content_migration';

  /// Current content-migration contract revision.
  static const int contractVersion = 1;

  /// Logical narrative project whose saves/content this plan migrates.
  final StoryProjectId projectId;

  /// Source content release.
  final StoryContentReleaseId fromReleaseId;

  /// Target content release.
  final StoryContentReleaseId toReleaseId;

  /// Explicit old-event to replacement-event redirects.
  final Map<StoryEventId, StoryEventId> eventRedirects;

  /// Explicit old-choice to replacement-choice redirects.
  final Map<StoryChoiceId, StoryChoiceId> choiceRedirects;

  /// Optional host-selected safe restart destination if migration cannot resume.
  final StoryEntryPointId? fallbackEntryPointId;

  /// Whether the plan contains structural snapshot redirects.
  bool get hasRedirects =>
      eventRedirects.isNotEmpty || choiceRedirects.isNotEmpty;
}

/// Result category for comparing a save binding with a target content release.
enum StorySaveCompatibilityStatus {
  /// Bound module revisions and bundle identity are exactly unchanged.
  exact,

  /// Changed target modules explicitly accept every bound source revision.
  compatible,

  /// One or more bound revisions require an explicit migration plan.
  migrationRequired,

  /// Resume is not valid; an explicit safe fallback entry point is available.
  fallbackRequired,

  /// No explicit safe compatibility/migration/fallback path exists.
  incompatible,
}

/// Structured result of one deterministic save/content compatibility check.
final class StorySaveCompatibilityResult {
  StorySaveCompatibilityResult({
    required this.status,
    Iterable<StoryModuleRevisionReference> unresolvedModules = const [],
    this.migrationPlan,
  }) : unresolvedModules = List<StoryModuleRevisionReference>.unmodifiable(
         unresolvedModules,
       );

  /// Overall deterministic compatibility category.
  final StorySaveCompatibilityStatus status;

  /// Bound source revisions that were not directly accepted by the target.
  final List<StoryModuleRevisionReference> unresolvedModules;

  /// Explicit migration/fallback policy considered for this result, if any.
  final StoryContentMigrationPlan? migrationPlan;
}

/// Evaluates save compatibility using exact hashes and explicit declarations.
final class StorySaveContentCompatibilityEvaluator {
  const StorySaveContentCompatibilityEvaluator();

  /// Compares [binding] with [target] without guessing from version ordering.
  StorySaveCompatibilityResult evaluate({
    required StorySaveContentBinding binding,
    required StoryContentReleaseManifest target,
    StoryContentMigrationPlan? migrationPlan,
  }) {
    if (binding.projectId != target.projectId) {
      return StorySaveCompatibilityResult(
        status: StorySaveCompatibilityStatus.incompatible,
        unresolvedModules: binding.modules,
      );
    }

    if (binding.releaseId == target.releaseId &&
        binding.bundleId != target.bundleId) {
      return StorySaveCompatibilityResult(
        status: StorySaveCompatibilityStatus.incompatible,
        unresolvedModules: binding.modules,
      );
    }

    final unresolved = <StoryModuleRevisionReference>[];
    var allExact =
        binding.bundleId == target.bundleId &&
        binding.releaseId == target.releaseId;
    for (final sourceRevision in binding.modules) {
      final targetModule = target.moduleFor(sourceRevision.moduleId);
      if (targetModule == null) {
        unresolved.add(sourceRevision);
        allExact = false;
        continue;
      }
      if (targetModule.reference == sourceRevision) {
        continue;
      }
      allExact = false;
      if (!targetModule.acceptsSaveFrom(sourceRevision)) {
        unresolved.add(sourceRevision);
      }
    }

    if (unresolved.isEmpty) {
      return StorySaveCompatibilityResult(
        status: allExact
            ? StorySaveCompatibilityStatus.exact
            : StorySaveCompatibilityStatus.compatible,
      );
    }

    final plan = migrationPlan;
    if (plan == null ||
        plan.projectId != binding.projectId ||
        plan.fromReleaseId != binding.releaseId ||
        plan.toReleaseId != target.releaseId) {
      return StorySaveCompatibilityResult(
        status: StorySaveCompatibilityStatus.incompatible,
        unresolvedModules: unresolved,
      );
    }
    if (plan.hasRedirects) {
      return StorySaveCompatibilityResult(
        status: StorySaveCompatibilityStatus.migrationRequired,
        unresolvedModules: unresolved,
        migrationPlan: plan,
      );
    }
    if (plan.fallbackEntryPointId != null) {
      return StorySaveCompatibilityResult(
        status: StorySaveCompatibilityStatus.fallbackRequired,
        unresolvedModules: unresolved,
        migrationPlan: plan,
      );
    }
    return StorySaveCompatibilityResult(
      status: StorySaveCompatibilityStatus.incompatible,
      unresolvedModules: unresolved,
      migrationPlan: plan,
    );
  }
}

/// Reports an explicit content/snapshot migration that cannot resume safely.
final class StoryContentMigrationException implements Exception {
  const StoryContentMigrationException({required this.message, this.cause});

  /// Human-readable migration failure description.
  final String message;

  /// Optional lower-level validation or state-schema incompatibility.
  final Object? cause;

  @override
  String toString() => 'StoryContentMigrationException: $message';
}

/// Applies declarative ID redirects to a runtime snapshot and revalidates it.
///
/// Stable state-variable IDs and scalar types must remain compatible. Stage 8L
/// intentionally does not invent executable value-transform callbacks. More
/// complex state transformations require an explicit future migration contract.
final class StoryRuntimeSnapshotContentMigrator {
  const StoryRuntimeSnapshotContentMigrator();

  /// Migrates [snapshot] to [targetProject] according to [plan].
  StoryRuntimeSnapshot migrate({
    required StoryRuntimeSnapshot snapshot,
    required StoryProject targetProject,
    required StoryContentMigrationPlan plan,
  }) {
    if (snapshot.projectId != targetProject.id) {
      throw const StoryContentMigrationException(
        message: 'Snapshot and target project IDs do not match.',
      );
    }
    if (plan.projectId != snapshot.projectId) {
      throw const StoryContentMigrationException(
        message: 'Migration plan and snapshot project IDs do not match.',
      );
    }

    try {
      final migrated = StoryRuntimeSnapshot(
        metadata: snapshot.metadata,
        projectId: snapshot.projectId,
        status: snapshot.status,
        state: _migrateState(snapshot.state, targetProject),
        currentEventId: _redirectEvent(snapshot.currentEventId, plan),
        history: StoryRuntimeHistory(
          steps: snapshot.history.steps.map(
            (step) => _redirectStep(step, plan),
          ),
        ),
        randomState: snapshot.randomState,
        maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
      );
      const StoryRuntimeSnapshotValidator().validate(
        snapshot: migrated,
        project: targetProject,
      );
      return migrated;
    } on StoryContentMigrationException {
      rethrow;
    } on Object catch (error) {
      throw StoryContentMigrationException(
        message: 'Migrated snapshot is not compatible with the target content.',
        cause: error,
      );
    }
  }
}

StoryState? _migrateState(StoryState? source, StoryProject targetProject) {
  if (source == null) {
    return null;
  }
  final sourceDefinitions = source.schema.variables;
  final targetDefinitions = targetProject.stateSchema.variables;
  if (sourceDefinitions.length != targetDefinitions.length) {
    throw const StoryContentMigrationException(
      message:
          'Structural Stage 8L migration does not support state-schema '
          'shape changes.',
    );
  }
  for (final definition in sourceDefinitions) {
    final targetDefinition = targetProject.stateSchema.definitionFor(
      definition.id,
    );
    if (targetDefinition == null || targetDefinition.type != definition.type) {
      throw StoryContentMigrationException(
        message:
            'State variable ${definition.id.value} is missing or changed '
            'type in the target project.',
      );
    }
  }

  final values = <StoryVariableId, StoryValue>{};
  for (final entry in source.values.entries) {
    final targetDefinition = targetProject.stateSchema.definitionFor(entry.key);
    if (targetDefinition == null || targetDefinition.type != entry.value.type) {
      throw StoryContentMigrationException(
        message:
            'State variable ${entry.key.value} is missing or changed type '
            'in the target project.',
      );
    }
    values[entry.key] = entry.value;
  }
  return StoryState.fromValues(
    schema: targetProject.stateSchema,
    values: values,
  );
}

StoryEventId? _redirectEvent(
  StoryEventId? eventId,
  StoryContentMigrationPlan plan,
) => eventId == null ? null : (plan.eventRedirects[eventId] ?? eventId);

StoryRuntimeStep _redirectStep(
  StoryRuntimeStep step,
  StoryContentMigrationPlan plan,
) => switch (step) {
  StoryEventEnteredStep(:final eventId) => StoryEventEnteredStep(
    eventId: plan.eventRedirects[eventId] ?? eventId,
  ),
  StoryEventContinuedStep(:final eventId) => StoryEventContinuedStep(
    eventId: plan.eventRedirects[eventId] ?? eventId,
  ),
  StoryChoiceSelectedStep(:final eventId, :final choiceId) =>
    StoryChoiceSelectedStep(
      eventId: plan.eventRedirects[eventId] ?? eventId,
      choiceId: plan.choiceRedirects[choiceId] ?? choiceId,
    ),
};
