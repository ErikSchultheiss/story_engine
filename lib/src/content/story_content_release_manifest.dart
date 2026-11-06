import '../build/story_content_hash.dart';
import '../build/story_runtime_bundle_manifest.dart';
import '../identity/story_content_release_id.dart';
import '../identity/story_module_id.dart';
import '../identity/story_module_version.dart';
import '../identity/story_project_id.dart';

/// Exact identity of one concrete module revision used by content/save checks.
final class StoryModuleRevisionReference {
  const StoryModuleRevisionReference({
    required this.moduleId,
    required this.moduleVersion,
    required this.contentHash,
  });

  /// Stable module identity.
  final StoryModuleId moduleId;

  /// Opaque authored/published version label.
  final StoryModuleVersion moduleVersion;

  /// SHA-256 identity of the exact compiled module bytes.
  final StoryContentHash contentHash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryModuleRevisionReference &&
          other.moduleId == moduleId &&
          other.moduleVersion == moduleVersion &&
          other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(moduleId, moduleVersion, contentHash);

  @override
  String toString() =>
      'StoryModuleRevisionReference(${moduleId.value}@${moduleVersion.value}, '
      '${contentHash.value})';
}

/// Version/hash/dependency metadata for one module in a content release.
///
/// [compatibleSaveSources] is explicit compatibility metadata. A target module
/// may resume a save bound to one of those exact source revisions without a
/// structural snapshot migration. Version strings alone never imply this.
final class StoryContentModuleRevision {
  StoryContentModuleRevision({
    required this.moduleId,
    required this.moduleVersion,
    required this.contentHash,
    Iterable<StoryModuleId> dependencies = const [],
    Iterable<StoryModuleRevisionReference> compatibleSaveSources = const [],
  }) : dependencies = List<StoryModuleId>.unmodifiable(dependencies),
       compatibleSaveSources = List<StoryModuleRevisionReference>.unmodifiable(
         compatibleSaveSources,
       ) {
    final dependencySet = <StoryModuleId>{};
    for (final dependency in this.dependencies) {
      if (dependency == moduleId || !dependencySet.add(dependency)) {
        throw ArgumentError.value(
          this.dependencies,
          'dependencies',
          'Module dependencies must be unique and may not contain self.',
        );
      }
    }
    final sourceSet = <StoryModuleRevisionReference>{};
    for (final source in this.compatibleSaveSources) {
      if (source.moduleId != moduleId) {
        throw ArgumentError.value(
          source,
          'compatibleSaveSources',
          'Compatible save sources must refer to the same stable module ID.',
        );
      }
      if (!sourceSet.add(source)) {
        throw ArgumentError.value(
          source,
          'compatibleSaveSources',
          'Compatible save source revisions must be unique.',
        );
      }
    }
  }

  /// Stable module identity.
  final StoryModuleId moduleId;

  /// Opaque version label for this revision.
  final StoryModuleVersion moduleVersion;

  /// SHA-256 identity of the exact compiled module artifact.
  final StoryContentHash contentHash;

  /// Other release modules required by this module.
  final List<StoryModuleId> dependencies;

  /// Exact older revisions explicitly declared save-compatible with this one.
  final List<StoryModuleRevisionReference> compatibleSaveSources;

  /// Exact reference to this revision.
  StoryModuleRevisionReference get reference => StoryModuleRevisionReference(
    moduleId: moduleId,
    moduleVersion: moduleVersion,
    contentHash: contentHash,
  );

  /// Whether [source] is explicitly safe for unchanged snapshot restoration.
  bool acceptsSaveFrom(StoryModuleRevisionReference source) =>
      source.moduleId == moduleId &&
      (source.contentHash == contentHash ||
          compatibleSaveSources.contains(source));
}

/// Versioned content-release manifest layered over a Stage 8K runtime bundle.
///
/// This manifest defines release/module revision identity and save-compatibility
/// metadata. It deliberately contains no patch URLs, CDN details, platform
/// package identifiers, or transport technology.
final class StoryContentReleaseManifest {
  /// Creates a release manifest directly from a verified Stage 8K bundle
  /// manifest and explicit module-version/compatibility metadata.
  factory StoryContentReleaseManifest.fromRuntimeBundleManifest({
    required StoryContentReleaseId releaseId,
    required StoryRuntimeBundleManifest bundleManifest,
    required Map<StoryModuleId, StoryModuleVersion> moduleVersions,
    Map<StoryModuleId, Iterable<StoryModuleRevisionReference>>
        compatibleSaveSources =
        const {},
  }) {
    final expected = <StoryModuleId>{
      for (final module in bundleManifest.modules) module.moduleId,
    };
    if (moduleVersions.keys.toSet().length != expected.length ||
        !moduleVersions.keys.toSet().containsAll(expected)) {
      throw ArgumentError(
        'Module-version set must exactly match the runtime bundle modules.',
      );
    }
    for (final moduleId in compatibleSaveSources.keys) {
      if (!expected.contains(moduleId)) {
        throw ArgumentError.value(
          moduleId,
          'compatibleSaveSources',
          'Compatibility metadata references a module outside the bundle.',
        );
      }
    }
    return StoryContentReleaseManifest(
      releaseId: releaseId,
      projectId: bundleManifest.projectId,
      bundleId: bundleManifest.bundleId,
      modules: [
        for (final module in bundleManifest.modules)
          StoryContentModuleRevision(
            moduleId: module.moduleId,
            moduleVersion: moduleVersions[module.moduleId]!,
            contentHash: module.contentHash,
            dependencies: module.dependencies,
            compatibleSaveSources:
                compatibleSaveSources[module.moduleId] ??
                const <StoryModuleRevisionReference>[],
          ),
      ],
    );
  }

  StoryContentReleaseManifest({
    required this.releaseId,
    required this.projectId,
    required this.bundleId,
    Iterable<StoryContentModuleRevision> modules = const [],
  }) : modules = List<StoryContentModuleRevision>.unmodifiable(modules) {
    final moduleIds = <StoryModuleId>{};
    for (final module in this.modules) {
      if (!moduleIds.add(module.moduleId)) {
        throw ArgumentError.value(
          module.moduleId,
          'modules',
          'Content release module IDs must be unique.',
        );
      }
    }
    for (final module in this.modules) {
      for (final dependency in module.dependencies) {
        if (!moduleIds.contains(dependency)) {
          throw ArgumentError.value(
            dependency,
            'modules',
            'Module dependency must resolve inside the same content release.',
          );
        }
      }
    }
  }

  /// Stable wire contract identity.
  static const String contractId = 'open_story.content_release';

  /// Current content-release contract revision.
  static const int contractVersion = 1;

  /// Opaque release identity.
  final StoryContentReleaseId releaseId;

  /// Logical narrative project identity.
  final StoryProjectId projectId;

  /// Exact Stage 8K runtime-bundle identity represented by this release.
  final StoryContentHash bundleId;

  /// Module revisions in deterministic release-manifest order.
  final List<StoryContentModuleRevision> modules;

  /// Module revision for [moduleId], or null when the release omits it.
  StoryContentModuleRevision? moduleFor(StoryModuleId moduleId) {
    for (final module in modules) {
      if (module.moduleId == moduleId) {
        return module;
      }
    }
    return null;
  }
}
