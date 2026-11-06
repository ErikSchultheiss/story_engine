import '../build/story_content_hash.dart';
import '../identity/story_content_release_id.dart';
import '../identity/story_module_id.dart';
import '../identity/story_project_id.dart';
import '../modular/story_project_index.dart';
import '../runtime/story_runtime_snapshot.dart';
import 'story_content_release_manifest.dart';

/// Content/module revision identity persisted alongside one runtime save.
///
/// This is deliberately separate from `StoryRuntimeSnapshot` so the frozen
/// runtime-snapshot wire format remains independent from shipping-content
/// versioning. A save may bind only the module revisions its committed route
/// actually references rather than every module in a large corpus.
final class StorySaveContentBinding {
  StorySaveContentBinding({
    required this.projectId,
    required this.releaseId,
    required this.bundleId,
    Iterable<StoryModuleRevisionReference> modules = const [],
  }) : modules = List<StoryModuleRevisionReference>.unmodifiable(modules) {
    final seen = <StoryModuleId>{};
    for (final module in this.modules) {
      if (!seen.add(module.moduleId)) {
        throw ArgumentError.value(
          module.moduleId,
          'modules',
          'Save content bindings may reference each module only once.',
        );
      }
    }
  }

  /// Stable wire contract identity.
  static const String contractId = 'open_story.save_content_binding';

  /// Current save-content-binding contract revision.
  static const int contractVersion = 1;

  /// Project identity shared with the runtime snapshot.
  final StoryProjectId projectId;

  /// Content release against which the save was committed.
  final StoryContentReleaseId releaseId;

  /// Exact runtime-bundle identity used by that release.
  final StoryContentHash bundleId;

  /// Exact revisions of route/current modules plus their dependency closure.
  final List<StoryModuleRevisionReference> modules;

  /// Derives a bounded binding from one committed core runtime [snapshot].
  ///
  /// For aggregate narrative-runtime saves, prefer
  /// [fromRetainedSessionSnapshots] so every retained session contributes its
  /// current/history modules to the same companion binding.
  factory StorySaveContentBinding.fromSnapshot({
    required StoryRuntimeSnapshot snapshot,
    required StoryProjectIndex index,
    required StoryContentReleaseManifest release,
  }) => StorySaveContentBinding.fromRetainedSessionSnapshots(
    projectId: snapshot.projectId,
    snapshots: [snapshot],
    index: index,
    release: release,
  );

  /// Derives one bounded binding for every retained aggregate session.
  ///
  /// [snapshots] must be supplied in deterministic retained-session order. The
  /// resulting module list is the first-reference union of every session's
  /// committed history/current event plus the Stage 8H dependency closure of
  /// those modules. Completed sessions are intentionally included: their
  /// retained history remains part of the durable aggregate checkpoint.
  ///
  /// An aggregate checkpoint with no retained sessions produces a valid empty
  /// module list while still binding [projectId], release, and bundle identity.
  /// The aggregate runtime snapshot itself remains free of content-release
  /// fields; hosts persist this companion object atomically beside it.
  factory StorySaveContentBinding.fromRetainedSessionSnapshots({
    required StoryProjectId projectId,
    required Iterable<StoryRuntimeSnapshot> snapshots,
    required StoryProjectIndex index,
    required StoryContentReleaseManifest release,
  }) {
    if (projectId != index.projectId || projectId != release.projectId) {
      throw ArgumentError(
        'Aggregate project, project index, and content release must share '
        'project ID.',
      );
    }

    final referencedModuleIds = <StoryModuleId>[];
    final seen = <StoryModuleId>{};

    void addModuleClosure(StoryModuleId moduleId) {
      if (!seen.add(moduleId)) {
        return;
      }
      final indexedModule = index.moduleFor(moduleId);
      if (indexedModule == null) {
        throw ArgumentError.value(
          moduleId,
          'index',
          'Snapshot-relevant module is missing from the project index.',
        );
      }
      referencedModuleIds.add(moduleId);
      for (final dependency in indexedModule.dependencies) {
        addModuleClosure(dependency);
      }
    }

    var snapshotIndex = 0;
    for (final snapshot in snapshots) {
      if (snapshot.projectId != projectId) {
        throw ArgumentError.value(
          snapshot.projectId,
          'snapshots',
          'Retained session snapshot at index $snapshotIndex belongs to a '
              'different project.',
        );
      }

      for (final eventId in snapshot.history.eventRoute) {
        final indexedEvent = index.eventFor(eventId);
        if (indexedEvent == null) {
          throw ArgumentError.value(
            eventId,
            'snapshots',
            'Retained session snapshot at index $snapshotIndex contains a '
                'history event missing from the project index.',
          );
        }
        addModuleClosure(indexedEvent.moduleId);
      }
      final currentEventId = snapshot.currentEventId;
      if (currentEventId != null) {
        final indexedEvent = index.eventFor(currentEventId);
        if (indexedEvent == null) {
          throw ArgumentError.value(
            currentEventId,
            'snapshots',
            'Retained session snapshot at index $snapshotIndex contains a '
                'current event missing from the project index.',
          );
        }
        addModuleClosure(indexedEvent.moduleId);
      }
      snapshotIndex++;
    }

    final revisions = <StoryModuleRevisionReference>[];
    for (final moduleId in referencedModuleIds) {
      final module = release.moduleFor(moduleId);
      if (module == null) {
        throw ArgumentError.value(
          moduleId,
          'release',
          'Referenced snapshot module is missing from the content release.',
        );
      }
      final indexedModule = index.moduleFor(moduleId)!;
      if (!_sameModuleIds(module.dependencies, indexedModule.dependencies)) {
        throw ArgumentError.value(
          moduleId,
          'release',
          'Content release dependencies do not match the project index.',
        );
      }
      revisions.add(module.reference);
    }

    return StorySaveContentBinding(
      projectId: projectId,
      releaseId: release.releaseId,
      bundleId: release.bundleId,
      modules: revisions,
    );
  }
}

bool _sameModuleIds(List<StoryModuleId> first, List<StoryModuleId> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) {
      return false;
    }
  }
  return true;
}
