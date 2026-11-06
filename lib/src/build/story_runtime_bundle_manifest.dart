import '../identity/story_module_id.dart';
import '../identity/story_project_id.dart';
import 'story_content_hash.dart';
import 'story_runtime_bundle_layout.dart';

/// Descriptor for one byte-exact artifact in a deterministic runtime bundle.
final class StoryRuntimeArtifactDescriptor {
  StoryRuntimeArtifactDescriptor({
    required this.path,
    required this.contentHash,
    required this.byteLength,
  }) {
    if (!StoryRuntimeBundleLayout.isPortablePath(path)) {
      throw ArgumentError.value(path, 'path', 'Artifact path is not portable.');
    }
    if (byteLength < 0 || byteLength > _maxPortableInteger) {
      throw ArgumentError.value(
        byteLength,
        'byteLength',
        'Artifact byte length must be a non-negative portable integer.',
      );
    }
  }

  /// Portable path inside the shipping bundle.
  final String path;

  /// SHA-256 digest of the exact artifact bytes.
  final StoryContentHash contentHash;

  /// Exact artifact byte count.
  final int byteLength;
}

/// Descriptor for one independently addressable compiled narrative module.
final class StoryRuntimeModuleArtifactDescriptor {
  StoryRuntimeModuleArtifactDescriptor({
    required this.moduleId,
    required this.path,
    required this.contentHash,
    required this.byteLength,
    Iterable<StoryModuleId> dependencies = const [],
  }) : dependencies = List<StoryModuleId>.unmodifiable(dependencies) {
    if (!StoryRuntimeBundleLayout.isPortablePath(path)) {
      throw ArgumentError.value(path, 'path', 'Module path is not portable.');
    }
    if (byteLength < 0 || byteLength > _maxPortableInteger) {
      throw ArgumentError.value(
        byteLength,
        'byteLength',
        'Module byte length must be a non-negative portable integer.',
      );
    }
  }

  /// Stable Stage 8H module identity.
  final StoryModuleId moduleId;

  /// Portable path inside the runtime bundle.
  final String path;

  /// SHA-256 digest of the exact compiled module bytes.
  final StoryContentHash contentHash;

  /// Exact compiled module byte count.
  final int byteLength;

  /// Stage 8H module dependencies in deterministic declaration order.
  final List<StoryModuleId> dependencies;
}

/// Canonical manifest for Runtime Bundle Contract Revision 1.
final class StoryRuntimeBundleManifest {
  StoryRuntimeBundleManifest({
    required this.bundleId,
    required this.projectId,
    required this.buildProfile,
    required this.builderId,
    required this.builderVersion,
    required this.indexArtifact,
    Iterable<StoryRuntimeModuleArtifactDescriptor> modules = const [],
  }) : modules = List<StoryRuntimeModuleArtifactDescriptor>.unmodifiable(
         modules,
       ) {
    _validateBuildToken(buildProfile, 'buildProfile');
    _validateBuildToken(builderId, 'builderId');
    _validateBuildToken(builderVersion, 'builderVersion');
    if (indexArtifact.path != StoryRuntimeBundleLayout.indexPath) {
      throw ArgumentError.value(
        indexArtifact.path,
        'indexArtifact',
        'Runtime Bundle v1 requires the canonical index.runtime path.',
      );
    }

    final moduleIds = <StoryModuleId>{};
    final paths = <String>{indexArtifact.path};
    for (final module in this.modules) {
      final expectedPath = StoryRuntimeBundleLayout.modulePath(module.moduleId);
      if (module.path != expectedPath) {
        throw ArgumentError.value(
          module.path,
          'modules',
          'Runtime Bundle v1 module path must be derived from module ID.',
        );
      }
      if (!moduleIds.add(module.moduleId)) {
        throw ArgumentError.value(
          module.moduleId,
          'modules',
          'Runtime bundle module IDs must be unique.',
        );
      }
      if (!paths.add(module.path)) {
        throw ArgumentError.value(
          module.path,
          'modules',
          'Runtime bundle artifact paths must be unique.',
        );
      }
      final dependencies = <StoryModuleId>{};
      for (final dependency in module.dependencies) {
        if (dependency == module.moduleId || !dependencies.add(dependency)) {
          throw ArgumentError.value(
            module.dependencies,
            'modules',
            'Module dependencies must be unique and may not contain self.',
          );
        }
      }
    }
    for (final module in this.modules) {
      for (final dependency in module.dependencies) {
        if (!moduleIds.contains(dependency)) {
          throw ArgumentError.value(
            dependency,
            'modules',
            'Module dependency must reference another manifest module.',
          );
        }
      }
    }
  }

  /// Stable wire contract identity.
  static const String contractId = 'open_story.runtime_bundle';

  /// Current runtime-bundle contract revision.
  static const int contractVersion = 1;

  /// Story Format revision from which Revision 1 builds originate.
  static const int sourceStoryFormatVersion = 1;

  /// SHA-256 identity of the canonical unsigned manifest payload.
  final StoryContentHash bundleId;

  /// Logical narrative-project identity.
  final StoryProjectId projectId;

  /// Versioned compiler/output profile selected by the build pipeline.
  final String buildProfile;

  /// Stable identity of the tool producing artifact bytes.
  final String builderId;

  /// Builder/tool version participating in reproducible identity.
  final String builderVersion;

  /// Compiled lightweight-index artifact descriptor.
  final StoryRuntimeArtifactDescriptor indexArtifact;

  /// Compiled module descriptors in Stage 8H index declaration order.
  final List<StoryRuntimeModuleArtifactDescriptor> modules;
}

void _validateBuildToken(String value, String name) {
  if (!_buildTokenPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      name,
      'Build identity tokens must be 1-128 portable ASCII characters.',
    );
  }
}

final _buildTokenPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$');

const int _maxPortableInteger = 9007199254740991;
