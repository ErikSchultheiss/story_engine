import '../build/story_content_hash.dart';
import '../identity/story_content_release_id.dart';
import '../identity/story_module_id.dart';
import '../identity/story_project_id.dart';
import 'story_content_release_manifest.dart';

/// Patch/DLC operation applied to one stable narrative module identity.
enum StoryContentPatchOperationKind {
  /// Target release introduces a previously absent module.
  add,

  /// Target release replaces an existing module revision.
  replace,

  /// Target release removes a module from the release set.
  remove,
}

/// One deterministic module-level difference between two content releases.
final class StoryContentPatchOperation {
  StoryContentPatchOperation._({
    required this.kind,
    required this.moduleId,
    this.fromRevision,
    this.toRevision,
  }) {
    if (kind == StoryContentPatchOperationKind.add) {
      if (fromRevision != null || toRevision == null) {
        throw ArgumentError('Add operations require only a target revision.');
      }
    } else if (kind == StoryContentPatchOperationKind.replace) {
      if (fromRevision == null || toRevision == null) {
        throw ArgumentError(
          'Replace operations require source and target revisions.',
        );
      }
    } else {
      if (fromRevision == null || toRevision != null) {
        throw ArgumentError(
          'Remove operations require only a source revision.',
        );
      }
    }
    if (fromRevision != null && fromRevision!.moduleId != moduleId) {
      throw ArgumentError(
        'Source revision must match the operation module ID.',
      );
    }
    if (toRevision != null && toRevision!.moduleId != moduleId) {
      throw ArgumentError(
        'Target revision must match the operation module ID.',
      );
    }
  }

  /// Creates an independent module-add operation.
  factory StoryContentPatchOperation.add(StoryModuleRevisionReference target) =>
      StoryContentPatchOperation._(
        kind: StoryContentPatchOperationKind.add,
        moduleId: target.moduleId,
        toRevision: target,
      );

  /// Creates an independent module-replacement operation.
  factory StoryContentPatchOperation.replace({
    required StoryModuleRevisionReference source,
    required StoryModuleRevisionReference target,
  }) => StoryContentPatchOperation._(
    kind: StoryContentPatchOperationKind.replace,
    moduleId: source.moduleId,
    fromRevision: source,
    toRevision: target,
  );

  /// Creates an explicit module-removal operation.
  factory StoryContentPatchOperation.remove(
    StoryModuleRevisionReference source,
  ) => StoryContentPatchOperation._(
    kind: StoryContentPatchOperationKind.remove,
    moduleId: source.moduleId,
    fromRevision: source,
  );

  /// Kind of release-set change.
  final StoryContentPatchOperationKind kind;

  /// Stable module identity affected by the operation.
  final StoryModuleId moduleId;

  /// Exact source revision for replace/remove operations.
  final StoryModuleRevisionReference? fromRevision;

  /// Exact target revision for add/replace operations.
  final StoryModuleRevisionReference? toRevision;
}

/// Deterministic transport-neutral patch description between two releases.
final class StoryContentPatchManifest {
  StoryContentPatchManifest({
    required this.projectId,
    required this.fromReleaseId,
    required this.toReleaseId,
    required this.fromBundleId,
    required this.toBundleId,
    Iterable<StoryContentPatchOperation> operations = const [],
  }) : operations = List<StoryContentPatchOperation>.unmodifiable(operations) {
    if (fromReleaseId == toReleaseId &&
        (fromBundleId != toBundleId || this.operations.isNotEmpty)) {
      throw ArgumentError(
        'A patch with the same source/target release ID must be an exact no-op.',
      );
    }
    final seen = <StoryModuleId>{};
    for (final operation in this.operations) {
      if (!seen.add(operation.moduleId)) {
        throw ArgumentError.value(
          operation.moduleId,
          'operations',
          'A patch may contain at most one operation per module.',
        );
      }
    }
  }

  /// Stable wire contract identity.
  static const String contractId = 'open_story.content_patch';

  /// Current patch-manifest contract revision.
  static const int contractVersion = 1;

  /// Logical narrative project identity.
  final StoryProjectId projectId;

  /// Source content release.
  final StoryContentReleaseId fromReleaseId;

  /// Target content release.
  final StoryContentReleaseId toReleaseId;

  /// Exact source runtime-bundle identity.
  final StoryContentHash fromBundleId;

  /// Exact target runtime-bundle identity.
  final StoryContentHash toBundleId;

  /// Deterministic module operations; no payload transport is embedded here.
  final List<StoryContentPatchOperation> operations;
}

/// Derives deterministic module add/replace/remove operations between releases.
final class StoryContentPatchPlanner {
  const StoryContentPatchPlanner();

  /// Creates a transport-neutral patch manifest from [source] to [target].
  StoryContentPatchManifest plan({
    required StoryContentReleaseManifest source,
    required StoryContentReleaseManifest target,
  }) {
    if (source.projectId != target.projectId) {
      throw ArgumentError('Patch releases must belong to the same project.');
    }

    final sourceById = <StoryModuleId, StoryContentModuleRevision>{
      for (final module in source.modules) module.moduleId: module,
    };
    final targetById = <StoryModuleId, StoryContentModuleRevision>{
      for (final module in target.modules) module.moduleId: module,
    };
    final operations = <StoryContentPatchOperation>[];

    // Target order is authoritative for adds/replacements.
    for (final targetModule in target.modules) {
      final sourceModule = sourceById[targetModule.moduleId];
      if (sourceModule == null) {
        operations.add(StoryContentPatchOperation.add(targetModule.reference));
      } else if (sourceModule.reference != targetModule.reference) {
        operations.add(
          StoryContentPatchOperation.replace(
            source: sourceModule.reference,
            target: targetModule.reference,
          ),
        );
      }
    }

    // Removed modules follow source declaration order after target operations.
    for (final sourceModule in source.modules) {
      if (!targetById.containsKey(sourceModule.moduleId)) {
        operations.add(
          StoryContentPatchOperation.remove(sourceModule.reference),
        );
      }
    }

    return StoryContentPatchManifest(
      projectId: source.projectId,
      fromReleaseId: source.releaseId,
      toReleaseId: target.releaseId,
      fromBundleId: source.bundleId,
      toBundleId: target.bundleId,
      operations: operations,
    );
  }
}
