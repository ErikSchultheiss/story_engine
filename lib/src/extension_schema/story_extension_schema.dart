/// Language-neutral declaration of one host extension schema.
///
/// Extension schemas describe semantic capabilities that a trusted host may
/// implement. They contain data only: no Dart callbacks, source names, engine
/// objects, or executable code.
final class StoryExtensionSchema {
  factory StoryExtensionSchema({
    required String namespace,
    required int schemaVersion,
    Iterable<StoryExtensionActionDefinition> actions = const [],
    Iterable<StoryExtensionConditionDefinition> conditions = const [],
    Iterable<StoryExtensionEnumDefinition> enums = const [],
    Iterable<StoryExtensionReferenceTypeDefinition> referenceTypes = const [],
    StoryExtensionSchemaMetadata? metadata,
  }) {
    final validatedNamespace = _validateNamespace(namespace, 'namespace');
    final validatedVersion = _validatePortablePositiveInteger(
      schemaVersion,
      'schemaVersion',
    );
    final copiedActions = List<StoryExtensionActionDefinition>.unmodifiable(
      actions,
    );
    final copiedConditions =
        List<StoryExtensionConditionDefinition>.unmodifiable(conditions);
    final copiedEnums = List<StoryExtensionEnumDefinition>.unmodifiable(enums);
    final copiedReferenceTypes =
        List<StoryExtensionReferenceTypeDefinition>.unmodifiable(
          referenceTypes,
        );

    _validateUniqueIds(
      copiedActions.map((definition) => definition.id),
      'actions',
    );
    _validateUniqueIds(
      copiedConditions.map((definition) => definition.id),
      'conditions',
    );
    _validateUniqueIds(copiedEnums.map((definition) => definition.id), 'enums');
    _validateUniqueIds(
      copiedReferenceTypes.map((definition) => definition.id),
      'referenceTypes',
    );

    final enumsById = <String, StoryExtensionEnumDefinition>{
      for (final definition in copiedEnums) definition.id: definition,
    };
    final referenceTypeIds = <String>{
      for (final definition in copiedReferenceTypes) definition.id,
    };

    for (final action in copiedActions) {
      _validateParameters(
        action.parameters,
        enumsById: enumsById,
        referenceTypeIds: referenceTypeIds,
        owner: 'action ${action.id}',
      );
    }
    for (final condition in copiedConditions) {
      _validateParameters(
        condition.parameters,
        enumsById: enumsById,
        referenceTypeIds: referenceTypeIds,
        owner: 'condition ${condition.id}',
      );
    }

    return StoryExtensionSchema._(
      namespace: validatedNamespace,
      schemaVersion: validatedVersion,
      actions: copiedActions,
      conditions: copiedConditions,
      enums: copiedEnums,
      referenceTypes: copiedReferenceTypes,
      metadata: metadata,
    );
  }

  StoryExtensionSchema._({
    required this.namespace,
    required this.schemaVersion,
    required this.actions,
    required this.conditions,
    required this.enums,
    required this.referenceTypes,
    required this.metadata,
  });

  /// Wire-contract identity for Extension Schema v1 documents.
  static const String contractId = 'open_story.extension_schema';

  /// Current wire-contract version understood by this Dart model.
  static const int contractVersion = 1;

  /// Collision-resistant lower-case namespace owned by the extension producer.
  final String namespace;

  /// Producer-controlled positive revision of this named schema.
  ///
  /// This is independent from [contractVersion]. Compatibility-range
  /// negotiation is deliberately deferred to the later runtime-capability
  /// contract.
  final int schemaVersion;

  final List<StoryExtensionActionDefinition> actions;
  final List<StoryExtensionConditionDefinition> conditions;
  final List<StoryExtensionEnumDefinition> enums;
  final List<StoryExtensionReferenceTypeDefinition> referenceTypes;

  /// Optional authoring/editor metadata. It never changes runtime semantics.
  final StoryExtensionSchemaMetadata? metadata;

  @override
  String toString() =>
      'StoryExtensionSchema($namespace@$schemaVersion, '
      '${actions.length} actions, ${conditions.length} conditions)';
}

/// Optional human-facing metadata for a schema or schema member.
///
/// [editor] is deeply immutable JSON-shaped data for editor hints. Runtimes
/// must not use it to decide narrative behavior.
final class StoryExtensionSchemaMetadata {
  factory StoryExtensionSchemaMetadata({
    String? label,
    String? helpText,
    Map<String, Object?> editor = const {},
  }) {
    return StoryExtensionSchemaMetadata._(
      label: _validateOptionalText(label, 'label'),
      helpText: _validateOptionalText(helpText, 'helpText'),
      editor: _copyEditorObject(editor, r'$.editor'),
    );
  }

  StoryExtensionSchemaMetadata._({
    required this.label,
    required this.helpText,
    required this.editor,
  });

  final String? label;
  final String? helpText;
  final Map<String, Object?> editor;
}

/// One declarative custom host action.
///
/// Stage 8E defines only the action identity and typed arguments. Suspendable
/// completion/results belong to the later host-interaction protocol.
final class StoryExtensionActionDefinition {
  factory StoryExtensionActionDefinition({
    required String id,
    Iterable<StoryExtensionParameterDefinition> parameters = const [],
    StoryExtensionSchemaMetadata? metadata,
  }) {
    final copiedParameters = _copyParameters(parameters);
    return StoryExtensionActionDefinition._(
      id: _validateMemberId(id, 'id'),
      parameters: copiedParameters,
      metadata: metadata,
    );
  }

  StoryExtensionActionDefinition._({
    required this.id,
    required this.parameters,
    required this.metadata,
  });

  final String id;
  final List<StoryExtensionParameterDefinition> parameters;
  final StoryExtensionSchemaMetadata? metadata;
}

/// One declarative custom host condition.
///
/// A condition's semantic result is Boolean. The schema never stores or
/// executes the host implementation that computes that result.
final class StoryExtensionConditionDefinition {
  factory StoryExtensionConditionDefinition({
    required String id,
    Iterable<StoryExtensionParameterDefinition> parameters = const [],
    StoryExtensionSchemaMetadata? metadata,
  }) {
    final copiedParameters = _copyParameters(parameters);
    return StoryExtensionConditionDefinition._(
      id: _validateMemberId(id, 'id'),
      parameters: copiedParameters,
      metadata: metadata,
    );
  }

  StoryExtensionConditionDefinition._({
    required this.id,
    required this.parameters,
    required this.metadata,
  });

  final String id;
  final List<StoryExtensionParameterDefinition> parameters;
  final StoryExtensionSchemaMetadata? metadata;
}

/// One named enumeration usable by action/condition parameters.
final class StoryExtensionEnumDefinition {
  factory StoryExtensionEnumDefinition({
    required String id,
    required Iterable<StoryExtensionEnumValueDefinition> values,
    StoryExtensionSchemaMetadata? metadata,
  }) {
    final copiedValues = List<StoryExtensionEnumValueDefinition>.unmodifiable(
      values,
    );
    if (copiedValues.isEmpty) {
      throw ArgumentError.value(values, 'values', 'Enums must declare values.');
    }
    _validateUniqueIds(copiedValues.map((value) => value.id), 'values');
    return StoryExtensionEnumDefinition._(
      id: _validateMemberId(id, 'id'),
      values: copiedValues,
      metadata: metadata,
    );
  }

  StoryExtensionEnumDefinition._({
    required this.id,
    required this.values,
    required this.metadata,
  });

  final String id;
  final List<StoryExtensionEnumValueDefinition> values;
  final StoryExtensionSchemaMetadata? metadata;
}

/// Stable symbolic value inside a declared extension enum.
final class StoryExtensionEnumValueDefinition {
  StoryExtensionEnumValueDefinition({required String id, this.metadata})
    : id = _validateMemberId(id, 'id');

  final String id;
  final StoryExtensionSchemaMetadata? metadata;
}

/// One host-owned reference domain such as `enemy`, `quest`, or `location`.
///
/// The schema declares only the type identity. Actual catalogs and referenced
/// game objects remain host-owned and are not embedded in this contract.
final class StoryExtensionReferenceTypeDefinition {
  StoryExtensionReferenceTypeDefinition({required String id, this.metadata})
    : id = _validateMemberId(id, 'id');

  final String id;
  final StoryExtensionSchemaMetadata? metadata;
}

/// Kind of value accepted by one extension parameter.
enum StoryExtensionParameterTypeKind {
  boolean,
  integer,
  number,
  string,
  enumeration,
  reference,
}

/// Language-neutral parameter type descriptor.
final class StoryExtensionParameterType {
  const StoryExtensionParameterType.boolean()
    : kind = StoryExtensionParameterTypeKind.boolean,
      enumId = null,
      referenceTypeId = null;

  const StoryExtensionParameterType.integer()
    : kind = StoryExtensionParameterTypeKind.integer,
      enumId = null,
      referenceTypeId = null;

  const StoryExtensionParameterType.number()
    : kind = StoryExtensionParameterTypeKind.number,
      enumId = null,
      referenceTypeId = null;

  const StoryExtensionParameterType.string()
    : kind = StoryExtensionParameterTypeKind.string,
      enumId = null,
      referenceTypeId = null;

  StoryExtensionParameterType.enumeration(String enumId)
    : kind = StoryExtensionParameterTypeKind.enumeration,
      enumId = _validateMemberId(enumId, 'enumId'),
      referenceTypeId = null;

  StoryExtensionParameterType.reference(String referenceTypeId)
    : kind = StoryExtensionParameterTypeKind.reference,
      enumId = null,
      referenceTypeId = _validateMemberId(referenceTypeId, 'referenceTypeId');

  final StoryExtensionParameterTypeKind kind;
  final String? enumId;
  final String? referenceTypeId;
}

/// Typed argument declaration for one custom action or condition.
final class StoryExtensionParameterDefinition {
  factory StoryExtensionParameterDefinition({
    required String name,
    required StoryExtensionParameterType type,
    bool isRequired = true,
    Object? defaultValue,
  }) {
    if (isRequired && defaultValue != null) {
      throw ArgumentError.value(
        defaultValue,
        'defaultValue',
        'Required parameters cannot also declare a default value.',
      );
    }
    final copiedDefault = defaultValue == null
        ? null
        : _copyScalarDefault(defaultValue, r'$.default');
    return StoryExtensionParameterDefinition._(
      name: _validateMemberId(name, 'name'),
      type: type,
      isRequired: isRequired,
      defaultValue: copiedDefault,
    );
  }

  StoryExtensionParameterDefinition._({
    required this.name,
    required this.type,
    required this.isRequired,
    required this.defaultValue,
  });

  final String name;
  final StoryExtensionParameterType type;
  final bool isRequired;

  /// Optional scalar default for an optional parameter.
  ///
  /// `null` means no default; null itself is not an Extension Schema v1
  /// parameter value.
  final Object? defaultValue;
}

const int _maxPortableInteger = 9007199254740991;
final RegExp _namespaceComponentPattern = RegExp(r'^[a-z][a-z0-9_-]*$');
final RegExp _memberIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');

String _validateNamespace(String value, String argumentName) {
  final parts = value.split('.');
  if (parts.length < 2 ||
      parts.any((part) => !_namespaceComponentPattern.hasMatch(part))) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Extension namespaces must contain at least two lower-case ASCII '
      'dot-separated components.',
    );
  }
  return value;
}

String _validateMemberId(String value, String argumentName) {
  if (!_memberIdPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Extension member identifiers must start with a lower-case ASCII '
      'letter and then contain only lower-case letters, digits, or '
      'underscore.',
    );
  }
  return value;
}

int _validatePortablePositiveInteger(int value, String argumentName) {
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

String? _validateOptionalText(String? value, String argumentName) {
  if (value != null && value.isEmpty) {
    throw ArgumentError.value(value, argumentName, 'Text must not be empty.');
  }
  return value;
}

List<StoryExtensionParameterDefinition> _copyParameters(
  Iterable<StoryExtensionParameterDefinition> parameters,
) {
  final copiedParameters = List<StoryExtensionParameterDefinition>.unmodifiable(
    parameters,
  );
  _validateUniqueIds(
    copiedParameters.map((parameter) => parameter.name),
    'parameters',
  );
  return copiedParameters;
}

void _validateUniqueIds(Iterable<String> ids, String owner) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw ArgumentError.value(id, owner, 'Duplicate identifier: $id.');
    }
  }
}

void _validateParameters(
  List<StoryExtensionParameterDefinition> parameters, {
  required Map<String, StoryExtensionEnumDefinition> enumsById,
  required Set<String> referenceTypeIds,
  required String owner,
}) {
  for (final parameter in parameters) {
    final type = parameter.type;
    switch (type.kind) {
      case StoryExtensionParameterTypeKind.enumeration:
        final enumId = type.enumId!;
        final enumDefinition = enumsById[enumId];
        if (enumDefinition == null) {
          throw ArgumentError.value(
            enumId,
            owner,
            'Parameter ${parameter.name} references unknown enum $enumId.',
          );
        }
        final defaultValue = parameter.defaultValue;
        if (defaultValue != null &&
            !enumDefinition.values.any((value) => value.id == defaultValue)) {
          throw ArgumentError.value(
            defaultValue,
            owner,
            'Parameter ${parameter.name} has a default outside enum $enumId.',
          );
        }
      case StoryExtensionParameterTypeKind.reference:
        final referenceTypeId = type.referenceTypeId!;
        if (!referenceTypeIds.contains(referenceTypeId)) {
          throw ArgumentError.value(
            referenceTypeId,
            owner,
            'Parameter ${parameter.name} references unknown reference type '
            '$referenceTypeId.',
          );
        }
      case StoryExtensionParameterTypeKind.boolean:
      case StoryExtensionParameterTypeKind.integer:
      case StoryExtensionParameterTypeKind.number:
      case StoryExtensionParameterTypeKind.string:
        break;
    }

    final defaultValue = parameter.defaultValue;
    if (defaultValue != null && !_defaultMatchesType(defaultValue, type)) {
      throw ArgumentError.value(
        defaultValue,
        owner,
        'Default value for ${parameter.name} does not match ${type.kind.name}.',
      );
    }
  }
}

bool _defaultMatchesType(Object value, StoryExtensionParameterType type) {
  return switch (type.kind) {
    StoryExtensionParameterTypeKind.boolean => value is bool,
    StoryExtensionParameterTypeKind.integer => value is int,
    StoryExtensionParameterTypeKind.number => value is double,
    StoryExtensionParameterTypeKind.string => value is String,
    StoryExtensionParameterTypeKind.enumeration => value is String,
    StoryExtensionParameterTypeKind.reference =>
      value is String && value.isNotEmpty,
  };
}

Object _copyScalarDefault(Object value, String path) {
  if (value is bool || value is String) {
    return value;
  }
  if (value is int) {
    if (value < -_maxPortableInteger || value > _maxPortableInteger) {
      throw ArgumentError.value(
        value,
        path,
        'Integer defaults must remain within the portable exact-integer range.',
      );
    }
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, path, 'Number defaults must be finite.');
    }
    return value;
  }
  throw ArgumentError.value(
    value,
    path,
    'Extension defaults must be Boolean, Integer, finite Number, or String.',
  );
}

Map<String, Object?> _copyEditorObject(
  Map<String, Object?> value,
  String path,
) {
  final keys = value.keys.toList()..sort();
  return Map<String, Object?>.unmodifiable({
    for (final key in keys) key: _copyEditorValue(value[key], '$path.$key'),
  });
}

Object? _copyEditorValue(Object? value, String path) {
  if (value == null || value is bool || value is String) {
    return value;
  }
  if (value is int) {
    if (value < -_maxPortableInteger || value > _maxPortableInteger) {
      throw ArgumentError.value(
        value,
        path,
        'Editor metadata integers must remain portable.',
      );
    }
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, path, 'Editor metadata must be finite.');
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable([
      for (var index = 0; index < value.length; index++)
        _copyEditorValue(value[index], '$path[$index]'),
    ]);
  }
  if (value is Map<String, Object?>) {
    return _copyEditorObject(value, path);
  }
  throw ArgumentError.value(
    value,
    path,
    'Editor metadata must use only portable JSON-shaped values.',
  );
}
