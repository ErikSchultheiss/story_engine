const int _maxPortableInteger = 9007199254740991;
final RegExp _featureIdPattern = RegExp(r'^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$');
final RegExp _namespaceComponentPattern = RegExp(r'^[a-z][a-z0-9_-]*$');
final RegExp _portableTokenPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$',
);

/// Stable language-neutral identity for one independently versioned runtime feature.
final class StoryRuntimeFeatureId {
  factory StoryRuntimeFeatureId(String value) {
    return StoryRuntimeFeatureId._(_validateFeatureId(value));
  }

  const StoryRuntimeFeatureId._(this.value);

  /// Runtime Semantics Core Revision 1.
  static const runtimeCore = StoryRuntimeFeatureId._('runtime_core');

  /// Cross-runtime deterministic-random profile revision 1.
  static const deterministicRandom = StoryRuntimeFeatureId._(
    'deterministic_random',
  );

  /// Suspendable host-action protocol revision 1.
  static const hostActions = StoryRuntimeFeatureId._('host_actions');

  /// Host-driven/multi-session narrative execution contracts revision 1.
  static const narrativeSessions = StoryRuntimeFeatureId._(
    'narrative_sessions',
  );

  /// Modular/indexed project-loading contract revision 1.
  static const modularLoading = StoryRuntimeFeatureId._('modular_loading');

  /// Deterministic runtime-bundle build contract revision 1.
  static const runtimeBundles = StoryRuntimeFeatureId._('runtime_bundles');

  /// Content release/patch/save-compatibility contract revision 1.
  static const contentVersioning = StoryRuntimeFeatureId._(
    'content_versioning',
  );

  /// Structured non-authoritative runtime observability contract revision 1.
  static const runtimeObservability = StoryRuntimeFeatureId._(
    'runtime_observability',
  );

  /// Portable feature token, for example `host_actions` or `modular_loading`.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryRuntimeFeatureId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryRuntimeFeatureId, value);

  @override
  String toString() => 'StoryRuntimeFeatureId($value)';
}

/// Project-side requirement for one runtime feature revision.
final class StoryRuntimeFeatureRequirement {
  StoryRuntimeFeatureRequirement({
    required this.featureId,
    required int minimumRevision,
    int? maximumRevision,
  }) : minimumRevision = _validatePositivePortableInteger(
         minimumRevision,
         'minimumRevision',
       ),
       maximumRevision = _validateOptionalMaximum(
         maximumRevision,
         minimumRevision,
         'maximumRevision',
       );

  final StoryRuntimeFeatureId featureId;
  final int minimumRevision;
  final int? maximumRevision;
}

/// Project-side acceptable version range for one Extension Schema namespace.
final class StoryExtensionSchemaRequirement {
  StoryExtensionSchemaRequirement({
    required String namespace,
    required int minimumSchemaVersion,
    int? maximumSchemaVersion,
  }) : namespace = _validateNamespace(namespace),
       minimumSchemaVersion = _validatePositivePortableInteger(
         minimumSchemaVersion,
         'minimumSchemaVersion',
       ),
       maximumSchemaVersion = _validateOptionalMaximum(
         maximumSchemaVersion,
         minimumSchemaVersion,
         'maximumSchemaVersion',
       );

  final String namespace;
  final int minimumSchemaVersion;
  final int? maximumSchemaVersion;
}

/// Portable project/export requirements evaluated before a target runtime is used.
///
/// A profile is a declarative set of required feature revisions and extension
/// schema version ranges. It never contains fallback semantics or executable
/// compatibility code.
final class StoryRuntimeCapabilityProfile {
  StoryRuntimeCapabilityProfile({
    required String profileId,
    required int profileVersion,
    Iterable<StoryRuntimeFeatureRequirement> requiredFeatures = const [],
    Iterable<StoryExtensionSchemaRequirement> requiredExtensions = const [],
  }) : profileId = _validatePortableToken(profileId, 'profileId'),
       profileVersion = _validatePositivePortableInteger(
         profileVersion,
         'profileVersion',
       ),
       requiredFeatures = _copyFeatureRequirements(requiredFeatures),
       requiredExtensions = _copyExtensionRequirements(requiredExtensions);

  /// Wire-contract identity for Stage 8M project capability profiles.
  static const String contractId = 'open_story.runtime_capability_profile';

  /// Current capability-profile wire-contract version.
  static const int contractVersion = 1;

  /// Opaque identity of this reusable project/export profile.
  final String profileId;

  /// Producer-controlled positive revision of [profileId].
  final int profileVersion;

  /// Required runtime feature revisions in canonical feature-ID order.
  final List<StoryRuntimeFeatureRequirement> requiredFeatures;

  /// Required extension namespaces in canonical namespace order.
  final List<StoryExtensionSchemaRequirement> requiredExtensions;
}

/// Runtime-side implementation report for one semantic feature revision.
final class StoryRuntimeFeatureCapability {
  StoryRuntimeFeatureCapability({
    required this.featureId,
    required int revision,
  }) : revision = _validatePositivePortableInteger(revision, 'revision');

  final StoryRuntimeFeatureId featureId;
  final int revision;
}

/// Runtime-side exact implemented Extension Schema version for one namespace.
final class StoryRuntimeExtensionCapability {
  StoryRuntimeExtensionCapability({
    required String namespace,
    required int schemaVersion,
  }) : namespace = _validateNamespace(namespace),
       schemaVersion = _validatePositivePortableInteger(
         schemaVersion,
         'schemaVersion',
       );

  final String namespace;
  final int schemaVersion;
}

/// Portable report of the semantic features/extensions implemented by a runtime.
final class StoryRuntimeCapabilities {
  /// Reports the semantic Stage 8 capabilities implemented by this Dart
  /// reference package. Host-provided extension implementations remain
  /// explicit through [extensions].
  factory StoryRuntimeCapabilities.storyEngineReference({
    required String runtimeVersion,
    Iterable<StoryRuntimeExtensionCapability> extensions = const [],
  }) {
    return StoryRuntimeCapabilities(
      runtimeId: 'story_engine',
      runtimeVersion: runtimeVersion,
      features: [
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.runtimeCore,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.deterministicRandom,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.hostActions,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.narrativeSessions,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.modularLoading,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.runtimeBundles,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.contentVersioning,
          revision: 1,
        ),
        StoryRuntimeFeatureCapability(
          featureId: StoryRuntimeFeatureId.runtimeObservability,
          revision: 1,
        ),
      ],
      extensions: extensions,
    );
  }

  StoryRuntimeCapabilities({
    required String runtimeId,
    required String runtimeVersion,
    Iterable<StoryRuntimeFeatureCapability> features = const [],
    Iterable<StoryRuntimeExtensionCapability> extensions = const [],
  }) : runtimeId = _validatePortableToken(runtimeId, 'runtimeId'),
       runtimeVersion = _validatePortableToken(
         runtimeVersion,
         'runtimeVersion',
       ),
       features = _copyFeatureCapabilities(features),
       extensions = _copyExtensionCapabilities(extensions);

  /// Wire-contract identity for runtime capability reports.
  static const String contractId = 'open_story.runtime_capabilities';

  /// Current runtime-capability wire-contract version.
  static const int contractVersion = 1;

  /// Stable implementation identity such as `story_engine` or `example_csharp`.
  final String runtimeId;

  /// Opaque implementation/package version reported for diagnostics.
  final String runtimeVersion;

  /// Implemented feature revisions in canonical feature-ID order.
  final List<StoryRuntimeFeatureCapability> features;

  /// Implemented extension schema versions in canonical namespace order.
  final List<StoryRuntimeExtensionCapability> extensions;
}

List<StoryRuntimeFeatureRequirement> _copyFeatureRequirements(
  Iterable<StoryRuntimeFeatureRequirement> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.featureId.value.compareTo(b.featureId.value));
  _rejectDuplicates(
    result.map((entry) => entry.featureId.value),
    'requiredFeatures',
  );
  return List<StoryRuntimeFeatureRequirement>.unmodifiable(result);
}

List<StoryExtensionSchemaRequirement> _copyExtensionRequirements(
  Iterable<StoryExtensionSchemaRequirement> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.namespace.compareTo(b.namespace));
  _rejectDuplicates(
    result.map((entry) => entry.namespace),
    'requiredExtensions',
  );
  return List<StoryExtensionSchemaRequirement>.unmodifiable(result);
}

List<StoryRuntimeFeatureCapability> _copyFeatureCapabilities(
  Iterable<StoryRuntimeFeatureCapability> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.featureId.value.compareTo(b.featureId.value));
  _rejectDuplicates(result.map((entry) => entry.featureId.value), 'features');
  return List<StoryRuntimeFeatureCapability>.unmodifiable(result);
}

List<StoryRuntimeExtensionCapability> _copyExtensionCapabilities(
  Iterable<StoryRuntimeExtensionCapability> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.namespace.compareTo(b.namespace));
  _rejectDuplicates(result.map((entry) => entry.namespace), 'extensions');
  return List<StoryRuntimeExtensionCapability>.unmodifiable(result);
}

String _validateFeatureId(String value) {
  if (value.length > 128 || !_featureIdPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'value',
      'Runtime feature IDs must be 1-128 lower-case portable ASCII characters.',
    );
  }
  return value;
}

String _validateNamespace(String value) {
  final parts = value.split('.');
  if (parts.length < 2 ||
      parts.any((part) => !_namespaceComponentPattern.hasMatch(part))) {
    throw ArgumentError.value(
      value,
      'namespace',
      'Extension namespaces must contain at least two lower-case ASCII '
          'dot-separated components.',
    );
  }
  return value;
}

String _validatePortableToken(String value, String argumentName) {
  if (!_portableTokenPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Value must be a 1-128 character portable ASCII token.',
    );
  }
  return value;
}

int _validatePositivePortableInteger(int value, String argumentName) {
  if (value < 1 || value > _maxPortableInteger) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Value must be a positive portable integer no greater than '
      '$_maxPortableInteger.',
    );
  }
  return value;
}

int? _validateOptionalMaximum(int? value, int minimum, String argumentName) {
  if (value == null) {
    return null;
  }
  final validated = _validatePositivePortableInteger(value, argumentName);
  if (validated < minimum) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Maximum version/revision must not be lower than the minimum.',
    );
  }
  return validated;
}

void _rejectDuplicates(Iterable<String> values, String argumentName) {
  final seen = <String>{};
  for (final value in values) {
    if (!seen.add(value)) {
      throw ArgumentError.value(
        value,
        argumentName,
        'Duplicate capability identity: $value.',
      );
    }
  }
}
