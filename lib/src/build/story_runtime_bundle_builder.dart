import '../identity/story_module_id.dart';
import '../modular/story_module_validator.dart';
import '../modular/story_project_index.dart';
import 'codec/story_runtime_bundle_manifest_codec.dart';
import 'story_content_hash.dart';
import 'story_runtime_bundle.dart';
import 'story_runtime_bundle_layout.dart';
import 'story_runtime_bundle_manifest.dart';

/// Deterministic reference packager for compiled/indexed runtime artifacts.
///
/// Stage 8K deliberately does not define a production compiler. Callers provide
/// deterministic compiled index/module bytes; this builder validates their
/// Stage 8H module set, computes content hashes, creates the canonical manifest,
/// and emits a reproducible byte bundle.
final class StoryRuntimeBundleBuilder {
  const StoryRuntimeBundleBuilder({
    StoryModuleValidator moduleValidator = const StoryModuleValidator(),
    StoryRuntimeBundleManifestCodec manifestCodec =
        const StoryRuntimeBundleManifestCodec(),
  }) : _moduleValidator = moduleValidator,
       _manifestCodec = manifestCodec;

  final StoryModuleValidator _moduleValidator;
  final StoryRuntimeBundleManifestCodec _manifestCodec;

  /// Packages deterministic compiled artifacts according to Contract Revision 1.
  StoryRuntimeBundle build({
    required StoryProjectIndex index,
    required List<int> compiledIndexBytes,
    required Map<StoryModuleId, List<int>> compiledModuleBytes,
    required String buildProfile,
    required String builderId,
    required String builderVersion,
  }) {
    final indexReport = _moduleValidator.validateIndex(index);
    if (!indexReport.isValid) {
      throw StoryRuntimeBundleBuildException(
        message:
            'Cannot build from an invalid Stage 8H project index '
            '(${indexReport.issues.length} issue(s)).',
      );
    }

    final expectedModuleIds = <StoryModuleId>{
      for (final module in index.modules) module.id,
    };
    final providedModuleIds = compiledModuleBytes.keys.toSet();
    final missing = expectedModuleIds.difference(providedModuleIds);
    final extra = providedModuleIds.difference(expectedModuleIds);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw StoryRuntimeBundleBuildException(
        message:
            'Compiled module artifact set does not match the project '
            'index. Missing: ${_moduleValues(missing)}; '
            'extra: ${_moduleValues(extra)}.',
      );
    }

    final indexBytes = List<int>.unmodifiable(compiledIndexBytes);
    final indexArtifact = StoryRuntimeArtifactDescriptor(
      path: StoryRuntimeBundleLayout.indexPath,
      contentHash: StoryContentHash.fromBytes(indexBytes),
      byteLength: indexBytes.length,
    );

    final moduleDescriptors = <StoryRuntimeModuleArtifactDescriptor>[];
    final moduleBytesByPath = <String, List<int>>{};
    for (final module in index.modules) {
      final bytes = List<int>.unmodifiable(compiledModuleBytes[module.id]!);
      final path = StoryRuntimeBundleLayout.modulePath(module.id);
      moduleBytesByPath[path] = bytes;
      moduleDescriptors.add(
        StoryRuntimeModuleArtifactDescriptor(
          moduleId: module.id,
          path: path,
          contentHash: StoryContentHash.fromBytes(bytes),
          byteLength: bytes.length,
          dependencies: module.dependencies,
        ),
      );
    }

    late final StoryRuntimeBundleManifest manifest;
    try {
      manifest = _manifestCodec.create(
        projectId: index.projectId,
        buildProfile: buildProfile,
        builderId: builderId,
        builderVersion: builderVersion,
        indexArtifact: indexArtifact,
        modules: moduleDescriptors,
      );
    } on Object catch (error) {
      throw StoryRuntimeBundleBuildException(
        message: 'Failed to create runtime-bundle manifest.',
        cause: error,
      );
    }

    final files = <String, List<int>>{
      StoryRuntimeBundleLayout.manifestPath: _manifestCodec.encodeBytes(
        manifest,
      ),
      StoryRuntimeBundleLayout.indexPath: indexBytes,
      for (final descriptor in moduleDescriptors)
        descriptor.path: moduleBytesByPath[descriptor.path]!,
    };
    final bundle = StoryRuntimeBundle(manifest: manifest, files: files);
    verifyIntegrity(bundle);
    return bundle;
  }

  /// Verifies manifest identity, exact file set, byte lengths, and SHA-256 hashes.
  void verifyIntegrity(StoryRuntimeBundle bundle) {
    final manifestBytes = bundle.file(StoryRuntimeBundleLayout.manifestPath);
    if (manifestBytes == null) {
      throw const StoryRuntimeBundleBuildException(
        message: 'Runtime bundle is missing runtime-manifest.json.',
      );
    }

    late final StoryRuntimeBundleManifest decoded;
    try {
      decoded = _manifestCodec.decodeBytes(manifestBytes);
    } on Object catch (error) {
      throw StoryRuntimeBundleBuildException(
        message: 'Runtime-bundle manifest is invalid.',
        cause: error,
      );
    }
    late final List<int> declaredManifestBytes;
    try {
      declaredManifestBytes = _manifestCodec.encodeBytes(bundle.manifest);
    } on Object catch (error) {
      throw StoryRuntimeBundleBuildException(
        message: 'Runtime-bundle metadata is internally inconsistent.',
        cause: error,
      );
    }
    if (!_sameBytes(manifestBytes, declaredManifestBytes)) {
      throw const StoryRuntimeBundleBuildException(
        message: 'Runtime-bundle manifest does not match bundle metadata.',
      );
    }

    final canonicalManifestBytes = _manifestCodec.encodeBytes(decoded);
    if (!_sameBytes(manifestBytes, canonicalManifestBytes)) {
      throw const StoryRuntimeBundleBuildException(
        message: 'Runtime-bundle manifest bytes are not canonical.',
      );
    }

    final expectedPaths = <String>{
      StoryRuntimeBundleLayout.manifestPath,
      decoded.indexArtifact.path,
      for (final module in decoded.modules) module.path,
    };
    if (bundle.files.keys.toSet().length != expectedPaths.length ||
        !bundle.files.keys.toSet().containsAll(expectedPaths)) {
      throw const StoryRuntimeBundleBuildException(
        message: 'Runtime bundle file set does not match its manifest.',
      );
    }

    _verifyArtifact(bundle, decoded.indexArtifact);
    for (final module in decoded.modules) {
      final bytes = bundle.file(module.path);
      if (bytes == null) {
        throw StoryRuntimeBundleBuildException(
          message: 'Runtime bundle is missing module ${module.moduleId.value}.',
        );
      }
      if (bytes.length != module.byteLength ||
          StoryContentHash.fromBytes(bytes) != module.contentHash) {
        throw StoryRuntimeBundleBuildException(
          message:
              'Runtime module ${module.moduleId.value} failed content '
              'integrity verification.',
        );
      }
    }
  }

  void _verifyArtifact(
    StoryRuntimeBundle bundle,
    StoryRuntimeArtifactDescriptor descriptor,
  ) {
    final bytes = bundle.file(descriptor.path);
    if (bytes == null ||
        bytes.length != descriptor.byteLength ||
        StoryContentHash.fromBytes(bytes) != descriptor.contentHash) {
      throw StoryRuntimeBundleBuildException(
        message:
            'Runtime artifact ${descriptor.path} failed content integrity '
            'verification.',
      );
    }
  }
}

/// Reports deterministic runtime-bundle packaging or integrity failures.
final class StoryRuntimeBundleBuildException implements Exception {
  const StoryRuntimeBundleBuildException({required this.message, this.cause});

  /// Human-readable failure description.
  final String message;

  /// Optional underlying validation/manifest error.
  final Object? cause;

  @override
  String toString() => 'StoryRuntimeBundleBuildException: $message';
}

String _moduleValues(Iterable<StoryModuleId> ids) {
  final values = ids.map((id) => id.value).toList()..sort();
  return values.isEmpty ? '<none>' : values.join(', ');
}

bool _sameBytes(List<int> first, List<int> second) {
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
