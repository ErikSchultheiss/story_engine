import 'dart:convert';

import '../story_runtime_capability.dart';

/// Strict data-format failure for Stage 8M capability contracts.
final class StoryRuntimeCapabilityFormatException implements Exception {
  const StoryRuntimeCapabilityFormatException(
    this.path,
    this.message, {
    this.cause,
  });

  final String path;
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StoryRuntimeCapabilityFormatException at $path: $message';
}

/// Deterministic JSON codec for `open_story.runtime_capability_profile` v1.
final class StoryRuntimeCapabilityProfileCodec {
  const StoryRuntimeCapabilityProfileCodec();

  String encode(StoryRuntimeCapabilityProfile profile) =>
      _pretty(<String, Object?>{
        'contract': StoryRuntimeCapabilityProfile.contractId,
        'contractVersion': StoryRuntimeCapabilityProfile.contractVersion,
        'profileId': profile.profileId,
        'profileVersion': profile.profileVersion,
        'requiredFeatures': profile.requiredFeatures
            .map(
              (requirement) => <String, Object?>{
                'featureId': requirement.featureId.value,
                'minimumRevision': requirement.minimumRevision,
                if (requirement.maximumRevision != null)
                  'maximumRevision': requirement.maximumRevision,
              },
            )
            .toList(growable: false),
        'requiredExtensions': profile.requiredExtensions
            .map(
              (requirement) => <String, Object?>{
                'namespace': requirement.namespace,
                'minimumSchemaVersion': requirement.minimumSchemaVersion,
                if (requirement.maximumSchemaVersion != null)
                  'maximumSchemaVersion': requirement.maximumSchemaVersion,
              },
            )
            .toList(growable: false),
      });

  StoryRuntimeCapabilityProfile decode(String source) {
    final root = _decodeRoot(source);
    _allowOnly(root, const {
      'contract',
      'contractVersion',
      'profileId',
      'profileVersion',
      'requiredFeatures',
      'requiredExtensions',
    }, r'$');
    _expectContract(
      root,
      StoryRuntimeCapabilityProfile.contractId,
      StoryRuntimeCapabilityProfile.contractVersion,
    );
    try {
      return StoryRuntimeCapabilityProfile(
        profileId: _string(root['profileId'], r'$.profileId'),
        profileVersion: _integer(root['profileVersion'], r'$.profileVersion'),
        requiredFeatures: _list(root['requiredFeatures'], r'$.requiredFeatures')
            .asMap()
            .entries
            .map(
              (entry) => _decodeFeatureRequirement(
                entry.value,
                r'$.requiredFeatures[${entry.key}]',
              ),
            ),
        requiredExtensions:
            _list(
              root['requiredExtensions'],
              r'$.requiredExtensions',
            ).asMap().entries.map(
              (entry) => _decodeExtensionRequirement(
                entry.value,
                r'$.requiredExtensions[${entry.key}]',
              ),
            ),
      );
    } on StoryRuntimeCapabilityFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryRuntimeCapabilityFormatException(
        r'$',
        'Invalid runtime capability profile.',
        cause: error,
      );
    }
  }
}

/// Deterministic JSON codec for `open_story.runtime_capabilities` v1.
final class StoryRuntimeCapabilitiesCodec {
  const StoryRuntimeCapabilitiesCodec();

  String encode(StoryRuntimeCapabilities capabilities) =>
      _pretty(<String, Object?>{
        'contract': StoryRuntimeCapabilities.contractId,
        'contractVersion': StoryRuntimeCapabilities.contractVersion,
        'runtimeId': capabilities.runtimeId,
        'runtimeVersion': capabilities.runtimeVersion,
        'features': capabilities.features
            .map(
              (capability) => <String, Object?>{
                'featureId': capability.featureId.value,
                'revision': capability.revision,
              },
            )
            .toList(growable: false),
        'extensions': capabilities.extensions
            .map(
              (capability) => <String, Object?>{
                'namespace': capability.namespace,
                'schemaVersion': capability.schemaVersion,
              },
            )
            .toList(growable: false),
      });

  StoryRuntimeCapabilities decode(String source) {
    final root = _decodeRoot(source);
    _allowOnly(root, const {
      'contract',
      'contractVersion',
      'runtimeId',
      'runtimeVersion',
      'features',
      'extensions',
    }, r'$');
    _expectContract(
      root,
      StoryRuntimeCapabilities.contractId,
      StoryRuntimeCapabilities.contractVersion,
    );
    try {
      return StoryRuntimeCapabilities(
        runtimeId: _string(root['runtimeId'], r'$.runtimeId'),
        runtimeVersion: _string(root['runtimeVersion'], r'$.runtimeVersion'),
        features: _list(root['features'], r'$.features').asMap().entries.map(
          (entry) => _decodeFeatureCapability(
            entry.value,
            r'$.features[${entry.key}]',
          ),
        ),
        extensions: _list(root['extensions'], r'$.extensions')
            .asMap()
            .entries
            .map(
              (entry) => _decodeExtensionCapability(
                entry.value,
                r'$.extensions[${entry.key}]',
              ),
            ),
      );
    } on StoryRuntimeCapabilityFormatException {
      rethrow;
    } on Object catch (error) {
      throw StoryRuntimeCapabilityFormatException(
        r'$',
        'Invalid runtime capability report.',
        cause: error,
      );
    }
  }
}

StoryRuntimeFeatureRequirement _decodeFeatureRequirement(
  Object? raw,
  String path,
) {
  final object = _object(raw, path);
  _allowOnly(object, const {
    'featureId',
    'minimumRevision',
    'maximumRevision',
  }, path);
  return StoryRuntimeFeatureRequirement(
    featureId: StoryRuntimeFeatureId(
      _string(object['featureId'], '$path.featureId'),
    ),
    minimumRevision: _integer(
      object['minimumRevision'],
      '$path.minimumRevision',
    ),
    maximumRevision: object.containsKey('maximumRevision')
        ? _integer(object['maximumRevision'], '$path.maximumRevision')
        : null,
  );
}

StoryExtensionSchemaRequirement _decodeExtensionRequirement(
  Object? raw,
  String path,
) {
  final object = _object(raw, path);
  _allowOnly(object, const {
    'namespace',
    'minimumSchemaVersion',
    'maximumSchemaVersion',
  }, path);
  return StoryExtensionSchemaRequirement(
    namespace: _string(object['namespace'], '$path.namespace'),
    minimumSchemaVersion: _integer(
      object['minimumSchemaVersion'],
      '$path.minimumSchemaVersion',
    ),
    maximumSchemaVersion: object.containsKey('maximumSchemaVersion')
        ? _integer(object['maximumSchemaVersion'], '$path.maximumSchemaVersion')
        : null,
  );
}

StoryRuntimeFeatureCapability _decodeFeatureCapability(
  Object? raw,
  String path,
) {
  final object = _object(raw, path);
  _allowOnly(object, const {'featureId', 'revision'}, path);
  return StoryRuntimeFeatureCapability(
    featureId: StoryRuntimeFeatureId(
      _string(object['featureId'], '$path.featureId'),
    ),
    revision: _integer(object['revision'], '$path.revision'),
  );
}

StoryRuntimeExtensionCapability _decodeExtensionCapability(
  Object? raw,
  String path,
) {
  final object = _object(raw, path);
  _allowOnly(object, const {'namespace', 'schemaVersion'}, path);
  return StoryRuntimeExtensionCapability(
    namespace: _string(object['namespace'], '$path.namespace'),
    schemaVersion: _integer(object['schemaVersion'], '$path.schemaVersion'),
  );
}

Map<String, Object?> _decodeRoot(String source) {
  try {
    return _object(jsonDecode(source), r'$');
  } on StoryRuntimeCapabilityFormatException {
    rethrow;
  } on Object catch (error) {
    throw StoryRuntimeCapabilityFormatException(
      r'$',
      'Document must be valid JSON.',
      cause: error,
    );
  }
}

void _expectContract(
  Map<String, Object?> root,
  String expectedId,
  int expectedVersion,
) {
  final contract = _string(root['contract'], r'$.contract');
  final version = _integer(root['contractVersion'], r'$.contractVersion');
  if (contract != expectedId) {
    throw StoryRuntimeCapabilityFormatException(
      r'$.contract',
      'Expected $expectedId, found $contract.',
    );
  }
  if (version != expectedVersion) {
    throw StoryRuntimeCapabilityFormatException(
      r'$.contractVersion',
      'Unsupported contract version $version; expected $expectedVersion.',
    );
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw StoryRuntimeCapabilityFormatException(path, 'Expected JSON object.');
  }
  return value;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List<Object?>) {
    throw StoryRuntimeCapabilityFormatException(path, 'Expected JSON array.');
  }
  return value;
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryRuntimeCapabilityFormatException(path, 'Expected string.');
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw StoryRuntimeCapabilityFormatException(path, 'Expected integer.');
  }
  return value;
}

void _allowOnly(Map<String, Object?> value, Set<String> allowed, String path) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw StoryRuntimeCapabilityFormatException(
        '$path.$key',
        'Unknown field.',
      );
    }
  }
  for (final key in allowed) {
    if (!value.containsKey(key) &&
        key != 'maximumRevision' &&
        key != 'maximumSchemaVersion') {
      throw StoryRuntimeCapabilityFormatException(
        '$path.$key',
        'Missing required field.',
      );
    }
  }
}

String _pretty(Object value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';
