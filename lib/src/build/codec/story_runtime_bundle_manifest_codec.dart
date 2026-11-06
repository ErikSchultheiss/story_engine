import 'dart:convert';

import '../../identity/story_module_id.dart';
import '../../identity/story_project_id.dart';
import '../story_content_hash.dart';
import '../story_runtime_bundle_manifest.dart';

/// Strict deterministic JSON codec for Runtime Bundle Contract Revision 1.
final class StoryRuntimeBundleManifestCodec {
  const StoryRuntimeBundleManifestCodec();

  /// Creates a manifest and derives its stable bundle ID from the canonical
  /// unsigned identity payload.
  StoryRuntimeBundleManifest create({
    required StoryProjectId projectId,
    required String buildProfile,
    required String builderId,
    required String builderVersion,
    required StoryRuntimeArtifactDescriptor indexArtifact,
    required Iterable<StoryRuntimeModuleArtifactDescriptor> modules,
  }) {
    final copiedModules =
        List<StoryRuntimeModuleArtifactDescriptor>.unmodifiable(modules);
    final unsigned = _unsignedRoot(
      projectId: projectId,
      buildProfile: buildProfile,
      builderId: builderId,
      builderVersion: builderVersion,
      indexArtifact: indexArtifact,
      modules: copiedModules,
    );
    final bundleId = StoryContentHash.fromBytes(
      utf8.encode(_encodeCanonical(unsigned)),
    );
    return StoryRuntimeBundleManifest(
      bundleId: bundleId,
      projectId: projectId,
      buildProfile: buildProfile,
      builderId: builderId,
      builderVersion: builderVersion,
      indexArtifact: indexArtifact,
      modules: copiedModules,
    );
  }

  /// Encodes [manifest] as canonical UTF-8-compatible JSON text.
  String encode(StoryRuntimeBundleManifest manifest) {
    _verifyBundleId(manifest);
    final unsigned = _unsignedRootFromManifest(manifest);
    return _encodeCanonical(<String, Object?>{
      'contract': unsigned['contract'],
      'contractVersion': unsigned['contractVersion'],
      'bundleId': manifest.bundleId.value,
      'projectId': unsigned['projectId'],
      'sourceStoryFormatVersion': unsigned['sourceStoryFormatVersion'],
      'buildProfile': unsigned['buildProfile'],
      'builder': unsigned['builder'],
      'index': unsigned['index'],
      'modules': unsigned['modules'],
    });
  }

  /// Encodes [manifest] directly to UTF-8 bytes.
  List<int> encodeBytes(StoryRuntimeBundleManifest manifest) =>
      List<int>.unmodifiable(utf8.encode(encode(manifest)));

  /// Strictly decodes one canonical runtime-bundle manifest.
  StoryRuntimeBundleManifest decode(String source) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw StoryRuntimeBundleManifestFormatException(
        message: 'Manifest is not valid JSON.',
        cause: error,
      );
    }
    final root = _map(decoded, r'$');
    _expectKeys(root, const {
      'contract',
      'contractVersion',
      'bundleId',
      'projectId',
      'sourceStoryFormatVersion',
      'buildProfile',
      'builder',
      'index',
      'modules',
    }, r'$');

    if (_string(root['contract'], r'$.contract') !=
        StoryRuntimeBundleManifest.contractId) {
      throw const StoryRuntimeBundleManifestFormatException(
        message: 'Unsupported runtime-bundle contract identity.',
      );
    }
    if (_integer(root['contractVersion'], r'$.contractVersion') !=
        StoryRuntimeBundleManifest.contractVersion) {
      throw const StoryRuntimeBundleManifestFormatException(
        message: 'Unsupported runtime-bundle contract version.',
      );
    }
    if (_integer(
          root['sourceStoryFormatVersion'],
          r'$.sourceStoryFormatVersion',
        ) !=
        StoryRuntimeBundleManifest.sourceStoryFormatVersion) {
      throw const StoryRuntimeBundleManifestFormatException(
        message: 'Unsupported source Story Format version.',
      );
    }

    final builder = _map(root['builder'], r'$.builder');
    _expectKeys(builder, const {'id', 'version'}, r'$.builder');
    final index = _decodeArtifact(root['index'], r'$.index');
    final rawModules = _list(root['modules'], r'$.modules');
    final modules = <StoryRuntimeModuleArtifactDescriptor>[];
    for (var i = 0; i < rawModules.length; i++) {
      modules.add(_decodeModule(rawModules[i], r'$.modules[$i]'));
    }

    late final StoryRuntimeBundleManifest manifest;
    try {
      manifest = StoryRuntimeBundleManifest(
        bundleId: StoryContentHash.parse(
          _string(root['bundleId'], r'$.bundleId'),
        ),
        projectId: StoryProjectId(_string(root['projectId'], r'$.projectId')),
        buildProfile: _string(root['buildProfile'], r'$.buildProfile'),
        builderId: _string(builder['id'], r'$.builder.id'),
        builderVersion: _string(builder['version'], r'$.builder.version'),
        indexArtifact: index,
        modules: modules,
      );
    } on Object catch (error) {
      if (error is StoryRuntimeBundleManifestFormatException) {
        rethrow;
      }
      throw StoryRuntimeBundleManifestFormatException(
        message: 'Manifest contains an invalid identity or descriptor.',
        cause: error,
      );
    }
    _verifyBundleId(manifest);
    return manifest;
  }

  /// Strictly decodes UTF-8 manifest bytes.
  StoryRuntimeBundleManifest decodeBytes(List<int> bytes) {
    late final String source;
    try {
      source = utf8.decode(bytes);
    } on FormatException catch (error) {
      throw StoryRuntimeBundleManifestFormatException(
        message: 'Manifest bytes are not valid UTF-8.',
        cause: error,
      );
    }
    return decode(source);
  }

  void _verifyBundleId(StoryRuntimeBundleManifest manifest) {
    final expected = StoryContentHash.fromBytes(
      utf8.encode(_encodeCanonical(_unsignedRootFromManifest(manifest))),
    );
    if (manifest.bundleId != expected) {
      throw StoryRuntimeBundleManifestFormatException(
        message:
            'Runtime-bundle ID does not match its canonical identity '
            'payload. Expected ${expected.value}.',
      );
    }
  }
}

/// Reports malformed or self-inconsistent runtime-bundle manifest data.
final class StoryRuntimeBundleManifestFormatException implements Exception {
  const StoryRuntimeBundleManifestFormatException({
    required this.message,
    this.cause,
  });

  /// Human-readable failure description.
  final String message;

  /// Optional underlying parse/validation failure.
  final Object? cause;

  @override
  String toString() => 'StoryRuntimeBundleManifestFormatException: $message';
}

Map<String, Object?> _unsignedRootFromManifest(
  StoryRuntimeBundleManifest manifest,
) => _unsignedRoot(
  projectId: manifest.projectId,
  buildProfile: manifest.buildProfile,
  builderId: manifest.builderId,
  builderVersion: manifest.builderVersion,
  indexArtifact: manifest.indexArtifact,
  modules: manifest.modules,
);

Map<String, Object?> _unsignedRoot({
  required StoryProjectId projectId,
  required String buildProfile,
  required String builderId,
  required String builderVersion,
  required StoryRuntimeArtifactDescriptor indexArtifact,
  required List<StoryRuntimeModuleArtifactDescriptor> modules,
}) => <String, Object?>{
  'contract': StoryRuntimeBundleManifest.contractId,
  'contractVersion': StoryRuntimeBundleManifest.contractVersion,
  'projectId': projectId.value,
  'sourceStoryFormatVersion':
      StoryRuntimeBundleManifest.sourceStoryFormatVersion,
  'buildProfile': buildProfile,
  'builder': <String, Object?>{'id': builderId, 'version': builderVersion},
  'index': _artifactMap(indexArtifact),
  'modules': <Object?>[for (final module in modules) _moduleMap(module)],
};

Map<String, Object?> _artifactMap(StoryRuntimeArtifactDescriptor artifact) =>
    <String, Object?>{
      'path': artifact.path,
      'contentHash': artifact.contentHash.value,
      'byteLength': artifact.byteLength,
    };

Map<String, Object?> _moduleMap(StoryRuntimeModuleArtifactDescriptor module) =>
    <String, Object?>{
      'moduleId': module.moduleId.value,
      'path': module.path,
      'contentHash': module.contentHash.value,
      'byteLength': module.byteLength,
      'dependencies': <Object?>[
        for (final dependency in module.dependencies) dependency.value,
      ],
    };

StoryRuntimeArtifactDescriptor _decodeArtifact(Object? raw, String path) {
  final map = _map(raw, path);
  _expectKeys(map, const {'path', 'contentHash', 'byteLength'}, path);
  try {
    return StoryRuntimeArtifactDescriptor(
      path: _string(map['path'], '$path.path'),
      contentHash: StoryContentHash.parse(
        _string(map['contentHash'], '$path.contentHash'),
      ),
      byteLength: _integer(map['byteLength'], '$path.byteLength'),
    );
  } on Object catch (error) {
    throw StoryRuntimeBundleManifestFormatException(
      message: 'Invalid artifact descriptor at $path.',
      cause: error,
    );
  }
}

StoryRuntimeModuleArtifactDescriptor _decodeModule(Object? raw, String path) {
  final map = _map(raw, path);
  _expectKeys(map, const {
    'moduleId',
    'path',
    'contentHash',
    'byteLength',
    'dependencies',
  }, path);
  final rawDependencies = _list(map['dependencies'], '$path.dependencies');
  try {
    return StoryRuntimeModuleArtifactDescriptor(
      moduleId: StoryModuleId(_string(map['moduleId'], '$path.moduleId')),
      path: _string(map['path'], '$path.path'),
      contentHash: StoryContentHash.parse(
        _string(map['contentHash'], '$path.contentHash'),
      ),
      byteLength: _integer(map['byteLength'], '$path.byteLength'),
      dependencies: [
        for (var i = 0; i < rawDependencies.length; i++)
          StoryModuleId(_string(rawDependencies[i], '$path.dependencies[$i]')),
      ],
    );
  } on Object catch (error) {
    throw StoryRuntimeBundleManifestFormatException(
      message: 'Invalid module descriptor at $path.',
      cause: error,
    );
  }
}

const _canonicalJsonEncoder = JsonEncoder.withIndent('  ');

String _encodeCanonical(Object? value) =>
    '${_canonicalJsonEncoder.convert(value)}\n';

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) {
    throw StoryRuntimeBundleManifestFormatException(
      message: 'Value at $path must be an object.',
    );
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw StoryRuntimeBundleManifestFormatException(
        message: 'Object key at $path must be a string.',
      );
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) {
    throw StoryRuntimeBundleManifestFormatException(
      message: 'Value at $path must be an array.',
    );
  }
  return List<Object?>.of(value, growable: false);
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryRuntimeBundleManifestFormatException(
      message: 'Value at $path must be a string.',
    );
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw StoryRuntimeBundleManifestFormatException(
      message: 'Value at $path must be an integer.',
    );
  }
  return value;
}

void _expectKeys(Map<String, Object?> map, Set<String> expected, String path) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw StoryRuntimeBundleManifestFormatException(
      message:
          'Object at $path must contain exactly: '
          '${(expected.toList()..sort()).join(', ')}.',
    );
  }
}
