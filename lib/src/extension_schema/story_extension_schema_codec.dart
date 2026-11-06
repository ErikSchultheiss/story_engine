import 'dart:convert';

import 'story_extension_schema.dart';

/// Strict deterministic JSON codec for Extension Schema contract version 1.
///
/// This codec parses declarative schema data only. It never registers or
/// executes host implementations.
final class StoryExtensionSchemaCodec {
  const StoryExtensionSchemaCodec();

  StoryExtensionSchema decodeJson(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw StoryExtensionSchemaFormatException(
        'Extension Schema JSON is malformed.',
        cause: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const StoryExtensionSchemaFormatException(
        'Extension Schema root must be a JSON object.',
      );
    }
    return _decodeSchema(decoded);
  }

  String encodeJson(StoryExtensionSchema schema) {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(_encodeSchema(schema))}\n';
  }
}

/// Malformed or unsupported Extension Schema representation.
final class StoryExtensionSchemaFormatException implements Exception {
  const StoryExtensionSchemaFormatException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'StoryExtensionSchemaFormatException: $message'
      : 'StoryExtensionSchemaFormatException: $message Cause: $cause';
}

StoryExtensionSchema _decodeSchema(Map<String, dynamic> json) {
  _requireKeys(
    json,
    required: const {
      'contract',
      'contractVersion',
      'namespace',
      'schemaVersion',
      'actions',
      'conditions',
      'enums',
      'referenceTypes',
    },
    optional: const {'metadata'},
    path: r'$',
  );

  final contract = _string(json, 'contract', r'$');
  if (contract != StoryExtensionSchema.contractId) {
    throw StoryExtensionSchemaFormatException(
      'Unsupported Extension Schema contract "$contract".',
    );
  }
  final contractVersion = _int(json, 'contractVersion', r'$');
  if (contractVersion != StoryExtensionSchema.contractVersion) {
    throw StoryExtensionSchemaFormatException(
      'Unsupported Extension Schema contractVersion $contractVersion.',
    );
  }

  try {
    return StoryExtensionSchema(
      namespace: _string(json, 'namespace', r'$'),
      schemaVersion: _int(json, 'schemaVersion', r'$'),
      actions: _objectList(
        json,
        'actions',
        r'$',
      ).map(_decodeAction).toList(growable: false),
      conditions: _objectList(
        json,
        'conditions',
        r'$',
      ).map(_decodeCondition).toList(growable: false),
      enums: _objectList(
        json,
        'enums',
        r'$',
      ).map(_decodeEnum).toList(growable: false),
      referenceTypes: _objectList(
        json,
        'referenceTypes',
        r'$',
      ).map(_decodeReferenceType).toList(growable: false),
      metadata: json.containsKey('metadata')
          ? _decodeMetadata(_object(json, 'metadata', r'$'), r'$.metadata')
          : null,
    );
  } on ArgumentError catch (error) {
    throw StoryExtensionSchemaFormatException(
      'Extension Schema violates the v1 data contract.',
      cause: error,
    );
  }
}

StoryExtensionActionDefinition _decodeAction(Map<String, dynamic> json) {
  const path = r'$.actions[]';
  _requireKeys(
    json,
    required: const {'id', 'parameters'},
    optional: const {'metadata'},
    path: path,
  );
  return StoryExtensionActionDefinition(
    id: _string(json, 'id', path),
    parameters: _objectList(
      json,
      'parameters',
      path,
    ).map(_decodeParameter).toList(growable: false),
    metadata: json.containsKey('metadata')
        ? _decodeMetadata(_object(json, 'metadata', path), '$path.metadata')
        : null,
  );
}

StoryExtensionConditionDefinition _decodeCondition(Map<String, dynamic> json) {
  const path = r'$.conditions[]';
  _requireKeys(
    json,
    required: const {'id', 'parameters'},
    optional: const {'metadata'},
    path: path,
  );
  return StoryExtensionConditionDefinition(
    id: _string(json, 'id', path),
    parameters: _objectList(
      json,
      'parameters',
      path,
    ).map(_decodeParameter).toList(growable: false),
    metadata: json.containsKey('metadata')
        ? _decodeMetadata(_object(json, 'metadata', path), '$path.metadata')
        : null,
  );
}

StoryExtensionParameterDefinition _decodeParameter(Map<String, dynamic> json) {
  const path = r'$.parameters[]';
  _requireKeys(
    json,
    required: const {'name', 'type', 'required'},
    optional: const {'default'},
    path: path,
  );
  return StoryExtensionParameterDefinition(
    name: _string(json, 'name', path),
    type: _decodeParameterType(_object(json, 'type', path)),
    isRequired: _bool(json, 'required', path),
    defaultValue: json.containsKey('default')
        ? _scalar(json['default'], '$path.default')
        : null,
  );
}

StoryExtensionParameterType _decodeParameterType(Map<String, dynamic> json) {
  const path = r'$.parameters[].type';
  final kind = _string(json, 'kind', path);
  switch (kind) {
    case 'boolean':
      _requireKeys(json, required: const {'kind'}, path: path);
      return const StoryExtensionParameterType.boolean();
    case 'integer':
      _requireKeys(json, required: const {'kind'}, path: path);
      return const StoryExtensionParameterType.integer();
    case 'number':
      _requireKeys(json, required: const {'kind'}, path: path);
      return const StoryExtensionParameterType.number();
    case 'string':
      _requireKeys(json, required: const {'kind'}, path: path);
      return const StoryExtensionParameterType.string();
    case 'enum':
      _requireKeys(json, required: const {'kind', 'enumId'}, path: path);
      return StoryExtensionParameterType.enumeration(
        _string(json, 'enumId', path),
      );
    case 'reference':
      _requireKeys(
        json,
        required: const {'kind', 'referenceTypeId'},
        path: path,
      );
      return StoryExtensionParameterType.reference(
        _string(json, 'referenceTypeId', path),
      );
    default:
      throw StoryExtensionSchemaFormatException(
        'Unknown parameter type kind "$kind" at $path.',
      );
  }
}

StoryExtensionEnumDefinition _decodeEnum(Map<String, dynamic> json) {
  const path = r'$.enums[]';
  _requireKeys(
    json,
    required: const {'id', 'values'},
    optional: const {'metadata'},
    path: path,
  );
  return StoryExtensionEnumDefinition(
    id: _string(json, 'id', path),
    values: _objectList(
      json,
      'values',
      path,
    ).map(_decodeEnumValue).toList(growable: false),
    metadata: json.containsKey('metadata')
        ? _decodeMetadata(_object(json, 'metadata', path), '$path.metadata')
        : null,
  );
}

StoryExtensionEnumValueDefinition _decodeEnumValue(Map<String, dynamic> json) {
  const path = r'$.enums[].values[]';
  _requireKeys(
    json,
    required: const {'id'},
    optional: const {'metadata'},
    path: path,
  );
  return StoryExtensionEnumValueDefinition(
    id: _string(json, 'id', path),
    metadata: json.containsKey('metadata')
        ? _decodeMetadata(_object(json, 'metadata', path), '$path.metadata')
        : null,
  );
}

StoryExtensionReferenceTypeDefinition _decodeReferenceType(
  Map<String, dynamic> json,
) {
  const path = r'$.referenceTypes[]';
  _requireKeys(
    json,
    required: const {'id'},
    optional: const {'metadata'},
    path: path,
  );
  return StoryExtensionReferenceTypeDefinition(
    id: _string(json, 'id', path),
    metadata: json.containsKey('metadata')
        ? _decodeMetadata(_object(json, 'metadata', path), '$path.metadata')
        : null,
  );
}

StoryExtensionSchemaMetadata _decodeMetadata(
  Map<String, dynamic> json,
  String path,
) {
  _requireKeys(
    json,
    required: const {},
    optional: const {'label', 'helpText', 'editor'},
    path: path,
  );
  return StoryExtensionSchemaMetadata(
    label: json.containsKey('label') ? _string(json, 'label', path) : null,
    helpText: json.containsKey('helpText')
        ? _string(json, 'helpText', path)
        : null,
    editor: json.containsKey('editor')
        ? _portableObject(_object(json, 'editor', path), '$path.editor')
        : const {},
  );
}

Map<String, Object?> _encodeSchema(StoryExtensionSchema schema) => {
  'contract': StoryExtensionSchema.contractId,
  'contractVersion': StoryExtensionSchema.contractVersion,
  'namespace': schema.namespace,
  'schemaVersion': schema.schemaVersion,
  if (schema.metadata != null) 'metadata': _encodeMetadata(schema.metadata!),
  'enums': [for (final definition in schema.enums) _encodeEnum(definition)],
  'referenceTypes': [
    for (final definition in schema.referenceTypes)
      _encodeReferenceType(definition),
  ],
  'actions': [
    for (final definition in schema.actions) _encodeAction(definition),
  ],
  'conditions': [
    for (final definition in schema.conditions) _encodeCondition(definition),
  ],
};

Map<String, Object?> _encodeAction(
  StoryExtensionActionDefinition definition,
) => {
  'id': definition.id,
  if (definition.metadata != null)
    'metadata': _encodeMetadata(definition.metadata!),
  'parameters': [
    for (final parameter in definition.parameters) _encodeParameter(parameter),
  ],
};

Map<String, Object?> _encodeCondition(
  StoryExtensionConditionDefinition definition,
) => {
  'id': definition.id,
  if (definition.metadata != null)
    'metadata': _encodeMetadata(definition.metadata!),
  'parameters': [
    for (final parameter in definition.parameters) _encodeParameter(parameter),
  ],
};

Map<String, Object?> _encodeParameter(
  StoryExtensionParameterDefinition definition,
) => {
  'name': definition.name,
  'type': _encodeParameterType(definition.type),
  'required': definition.isRequired,
  if (definition.defaultValue != null) 'default': definition.defaultValue,
};

Map<String, Object?> _encodeParameterType(StoryExtensionParameterType type) {
  return switch (type.kind) {
    StoryExtensionParameterTypeKind.boolean => {'kind': 'boolean'},
    StoryExtensionParameterTypeKind.integer => {'kind': 'integer'},
    StoryExtensionParameterTypeKind.number => {'kind': 'number'},
    StoryExtensionParameterTypeKind.string => {'kind': 'string'},
    StoryExtensionParameterTypeKind.enumeration => {
      'kind': 'enum',
      'enumId': type.enumId!,
    },
    StoryExtensionParameterTypeKind.reference => {
      'kind': 'reference',
      'referenceTypeId': type.referenceTypeId!,
    },
  };
}

Map<String, Object?> _encodeEnum(StoryExtensionEnumDefinition definition) => {
  'id': definition.id,
  if (definition.metadata != null)
    'metadata': _encodeMetadata(definition.metadata!),
  'values': [for (final value in definition.values) _encodeEnumValue(value)],
};

Map<String, Object?> _encodeEnumValue(
  StoryExtensionEnumValueDefinition definition,
) => {
  'id': definition.id,
  if (definition.metadata != null)
    'metadata': _encodeMetadata(definition.metadata!),
};

Map<String, Object?> _encodeReferenceType(
  StoryExtensionReferenceTypeDefinition definition,
) => {
  'id': definition.id,
  if (definition.metadata != null)
    'metadata': _encodeMetadata(definition.metadata!),
};

Map<String, Object?> _encodeMetadata(StoryExtensionSchemaMetadata metadata) => {
  if (metadata.label != null) 'label': metadata.label,
  if (metadata.helpText != null) 'helpText': metadata.helpText,
  if (metadata.editor.isNotEmpty) 'editor': metadata.editor,
};

void _requireKeys(
  Map<String, dynamic> json, {
  required Set<String> required,
  Set<String> optional = const {},
  required String path,
}) {
  for (final key in required) {
    if (!json.containsKey(key)) {
      throw StoryExtensionSchemaFormatException(
        'Missing required field "$key" at $path.',
      );
    }
  }
  final allowed = {...required, ...optional};
  for (final key in json.keys) {
    if (!allowed.contains(key)) {
      throw StoryExtensionSchemaFormatException(
        'Unknown field "$key" at $path.',
      );
    }
  }
}

String _string(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String) {
    throw StoryExtensionSchemaFormatException(
      'Field "$key" at $path must be a String.',
    );
  }
  return value;
}

int _int(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! int) {
    throw StoryExtensionSchemaFormatException(
      'Field "$key" at $path must be an Integer.',
    );
  }
  return value;
}

bool _bool(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! bool) {
    throw StoryExtensionSchemaFormatException(
      'Field "$key" at $path must be a Boolean.',
    );
  }
  return value;
}

Map<String, dynamic> _object(
  Map<String, dynamic> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw StoryExtensionSchemaFormatException(
      'Field "$key" at $path must be an object.',
    );
  }
  return value;
}

List<Map<String, dynamic>> _objectList(
  Map<String, dynamic> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value is! List<dynamic>) {
    throw StoryExtensionSchemaFormatException(
      'Field "$key" at $path must be an array.',
    );
  }
  return [
    for (var index = 0; index < value.length; index++)
      if (value[index] is Map<String, dynamic>)
        value[index] as Map<String, dynamic>
      else
        throw StoryExtensionSchemaFormatException(
          'Entry $index of "$key" at $path must be an object.',
        ),
  ];
}

Object _scalar(Object? value, String path) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value;
  }
  if (value is int) {
    return value;
  }
  if (value is double && value.isFinite) {
    return value;
  }

  throw StoryExtensionSchemaFormatException(
    'Value at $path must be Boolean, Integer, finite Number, or String.',
  );
}

Map<String, Object?> _portableObject(Map<String, dynamic> value, String path) {
  final keys = value.keys.toList()..sort();
  return {
    for (final key in keys) key: _portableValue(value[key], '$path.$key'),
  };
}

Object? _portableValue(Object? value, String path) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double && value.isFinite) {
    return value;
  }
  if (value is List<dynamic>) {
    return [
      for (var index = 0; index < value.length; index++)
        _portableValue(value[index], '$path[$index]'),
    ];
  }
  if (value is Map<String, dynamic>) {
    return _portableObject(value, path);
  }
  throw StoryExtensionSchemaFormatException(
    'Editor metadata at $path is not portable JSON-shaped data.',
  );
}
