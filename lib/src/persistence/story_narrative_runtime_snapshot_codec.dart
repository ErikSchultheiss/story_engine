import 'dart:convert';

import '../host_action/story_host_action_protocol.dart';
import '../host_action/story_host_action_protocol_snapshot_codec.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_project_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_project.dart';
import 'story_runtime_snapshot_codec.dart';
import '../runtime/story_runtime_snapshot.dart';
import '../runtime/story_runtime_snapshot_validator.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';
import '../orchestration/story_entry_point.dart';
import '../orchestration/story_narrative_runtime_snapshot.dart';
import 'story_narrative_runtime_snapshot_migrations.dart';
import '../orchestration/story_narrative_runtime_snapshot_validator.dart';

/// Structured malformed-data failure from
/// [StoryNarrativeRuntimeSnapshotCodec].
///
/// Well-formed but semantically incompatible aggregate checkpoints use
/// [StoryNarrativeRuntimeSnapshotCompatibilityException] instead.
final class StoryNarrativeRuntimeSnapshotFormatException implements Exception {
  const StoryNarrativeRuntimeSnapshotFormatException(
    this.path,
    this.message, {
    this.cause,
  });

  final String path;
  final String message;
  final Object? cause;

  /// Machine-oriented location alias shared with the other public persistence
  /// failures.
  String get location => path;

  /// Generic recovery guidance for malformed aggregate save data.
  String get suggestion =>
      'Inspect the aggregate narrative snapshot at $path '
      'and correct or discard the malformed value before restoring it.';

  @override
  String toString() {
    final causeText = cause == null ? '' : ' Cause: $cause';
    return 'StoryNarrativeRuntimeSnapshotFormatException at $path: '
        '$message$causeText';
  }
}

/// Deterministic versioned codec for complete narrative-runtime checkpoints.
///
/// The aggregate representation wraps the existing core runtime snapshot and
/// host-action protocol snapshot contracts instead of reinterpreting them. A
/// compatible [StoryProject] and complete entry-point configuration are
/// required while decoding so aggregate validation completes before a restored
/// runtime can become observable.
final class StoryNarrativeRuntimeSnapshotCodec {
  StoryNarrativeRuntimeSnapshotCodec()
    : _migrations = StoryNarrativeRuntimeSnapshotMigrationPipeline.builtIn(),
      _coreCodec = StoryRuntimeSnapshotCodec(),
      _hostActionCodec = const StoryHostActionProtocolSnapshotCodec();

  static const String documentType = 'story_engine_narrative_runtime_snapshot';

  final StoryNarrativeRuntimeSnapshotMigrationPipeline _migrations;
  final StoryRuntimeSnapshotCodec _coreCodec;
  final StoryHostActionProtocolSnapshotCodec _hostActionCodec;

  /// Encodes [snapshot] into the current deterministic JSON-compatible shape.
  ///
  /// Only current aggregate format/runtime-contract versions are emitted. Old
  /// encoded formats are upgraded on decode through package-owned migrations.
  Map<String, Object?> encode(StoryNarrativeRuntimeSnapshot snapshot) {
    if (snapshot.metadata.formatVersion !=
        StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedFormatVersion,
        path: r'$.formatVersion',
        message:
            'The current aggregate codec emits only snapshot format '
            'version '
            '${StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion}.',
      );
    }
    if (snapshot.metadata.runtimeContractVersion !=
        StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedRuntimeContractVersion,
        path: r'$.runtimeContractVersion',
        message:
            'The current aggregate codec emits only runtime contract '
            'version '
            '${StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion}.',
      );
    }

    return <String, Object?>{
      'documentType': documentType,
      'formatVersion': snapshot.metadata.formatVersion,
      'runtimeContractVersion': snapshot.metadata.runtimeContractVersion,
      'projectId': snapshot.projectId.value,
      'persistentState': _encodeState(snapshot.persistentState),
      'persistentStateRevision': snapshot.persistentStateRevision,
      'orchestrationRandomState': _encodeRandomState(
        snapshot.orchestrationRandomState,
      ),
      'maxAutomaticTransitions': snapshot.maxAutomaticTransitions,
      'nextSessionIndex': snapshot.nextSessionIndex,
      'nextObservationSequence': snapshot.nextObservationSequence,
      'sessions': snapshot.sessions.map(_encodeSession).toList(growable: false),
    };
  }

  /// Encodes [snapshot] as compact deterministic JSON.
  String encodeJson(StoryNarrativeRuntimeSnapshot snapshot) =>
      jsonEncode(encode(snapshot));

  /// Decodes one aggregate checkpoint and validates it against host-supplied
  /// authored configuration.
  StoryNarrativeRuntimeSnapshot decode(
    Object? encoded, {
    required StoryProject project,
    required Iterable<StoryEntryPoint> entryPoints,
  }) {
    try {
      final source = _map(encoded, r'$');
      final document = _migrateToCurrent(source);
      final snapshot = _decodeCurrent(document, project: project);
      StoryNarrativeRuntimeSnapshotValidator().validate(
        snapshot: snapshot,
        project: project,
        entryPoints: entryPoints,
      );
      return snapshot;
    } on StoryNarrativeRuntimeSnapshotFormatException {
      rethrow;
    } on StoryNarrativeRuntimeSnapshotCompatibilityException {
      rethrow;
    } catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        r'$',
        'Invalid aggregate narrative-runtime snapshot data.',
        cause: error,
      );
    }
  }

  /// Decodes compact or pretty-printed aggregate snapshot JSON.
  StoryNarrativeRuntimeSnapshot decodeJson(
    String source, {
    required StoryProject project,
    required Iterable<StoryEntryPoint> entryPoints,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        r'$',
        'Input is not valid JSON.',
        cause: error,
      );
    }
    return decode(decoded, project: project, entryPoints: entryPoints);
  }

  Map<String, Object?> _migrateToCurrent(Map<String, Object?> source) {
    final type = _string(
      _required(source, 'documentType', r'$'),
      r'$.documentType',
    );
    if (type != documentType) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        r'$.documentType',
        'Expected "$documentType", got "$type".',
      );
    }

    final version = _positiveInteger(
      _required(source, 'formatVersion', r'$'),
      r'$.formatVersion',
    );
    final current = StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion;
    if (version > current) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedFormatVersion,
        path: r'$.formatVersion',
        message:
            'Aggregate snapshot format version $version is newer than '
            'supported version $current.',
      );
    }
    if (version == current) {
      return source;
    }
    if (!_migrations.canMigrate(fromVersion: version, toVersion: current)) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedFormatVersion,
        path: r'$.formatVersion',
        message:
            'No aggregate snapshot migration path exists from format '
            'version $version to $current.',
      );
    }
    try {
      return _migrations.migrate(
        document: source,
        fromVersion: version,
        toVersion: current,
      );
    } catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        r'$',
        'Aggregate narrative-runtime snapshot migration failed.',
        cause: error,
      );
    }
  }

  StoryNarrativeRuntimeSnapshot _decodeCurrent(
    Map<String, Object?> root, {
    required StoryProject project,
  }) {
    _allowOnly(root, const {
      'documentType',
      'formatVersion',
      'runtimeContractVersion',
      'projectId',
      'persistentState',
      'persistentStateRevision',
      'orchestrationRandomState',
      'maxAutomaticTransitions',
      'nextSessionIndex',
      'nextObservationSequence',
      'sessions',
    }, r'$');

    final type = _string(
      _required(root, 'documentType', r'$'),
      r'$.documentType',
    );
    if (type != documentType) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        r'$.documentType',
        'Expected "$documentType", got "$type".',
      );
    }

    final formatVersion = _positiveInteger(
      _required(root, 'formatVersion', r'$'),
      r'$.formatVersion',
    );
    final runtimeContractVersion = _positiveInteger(
      _required(root, 'runtimeContractVersion', r'$'),
      r'$.runtimeContractVersion',
    );
    if (runtimeContractVersion !=
        StoryNarrativeRuntimeSnapshotMetadata.currentRuntimeContractVersion) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .unsupportedRuntimeContractVersion,
        path: r'$.runtimeContractVersion',
        message:
            'Aggregate snapshot runtime contract version '
            '$runtimeContractVersion is not supported by this narrative '
            'runtime.',
      );
    }

    final projectId = _projectId(
      _required(root, 'projectId', r'$'),
      r'$.projectId',
    );
    if (projectId != project.id) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue:
            StoryNarrativeRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
        path: r'$.projectId',
        message:
            'Aggregate snapshot belongs to ${projectId.value}, but the '
            'supplied project is ${project.id.value}.',
      );
    }

    final persistentState = _decodeState(
      _required(root, 'persistentState', r'$'),
      r'$.persistentState',
      project: project,
    );
    final persistentStateRevision = _portableNonNegativeInteger(
      _required(root, 'persistentStateRevision', r'$'),
      r'$.persistentStateRevision',
    );
    final orchestrationRandomState = _decodeRandomState(
      _required(root, 'orchestrationRandomState', r'$'),
      r'$.orchestrationRandomState',
    );
    final maxAutomaticTransitions = _positiveInteger(
      _required(root, 'maxAutomaticTransitions', r'$'),
      r'$.maxAutomaticTransitions',
    );
    final nextSessionIndex = _portableNonNegativeInteger(
      _required(root, 'nextSessionIndex', r'$'),
      r'$.nextSessionIndex',
    );
    final nextObservationSequence = _portableNonNegativeInteger(
      _required(root, 'nextObservationSequence', r'$'),
      r'$.nextObservationSequence',
    );
    final sessionsRaw = _list(_required(root, 'sessions', r'$'), r'$.sessions');
    final sessions = <StoryNarrativeSessionSnapshot>[];
    for (var index = 0; index < sessionsRaw.length; index++) {
      sessions.add(
        _decodeSession(
          sessionsRaw[index],
          '\$.sessions[$index]',
          project: project,
        ),
      );
    }

    try {
      return StoryNarrativeRuntimeSnapshot(
        metadata: StoryNarrativeRuntimeSnapshotMetadata(
          formatVersion: formatVersion,
          runtimeContractVersion: runtimeContractVersion,
        ),
        projectId: projectId,
        persistentState: persistentState,
        persistentStateRevision: persistentStateRevision,
        orchestrationRandomState: orchestrationRandomState,
        maxAutomaticTransitions: maxAutomaticTransitions,
        nextSessionIndex: nextSessionIndex,
        nextObservationSequence: nextObservationSequence,
        sessions: sessions,
      );
    } on ArgumentError catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        r'$',
        'Aggregate snapshot violates its local committed-data shape.',
        cause: error,
      );
    }
  }

  Map<String, Object?> _encodeSession(StoryNarrativeSessionSnapshot session) {
    final hostActionEncoded = jsonDecode(
      _hostActionCodec.encode(session.hostActionSnapshot),
    );
    return <String, Object?>{
      'sessionIndex': session.sessionIndex,
      'entryPointId': session.entryPointId.value,
      'runtimeSnapshot': _coreCodec.encode(session.runtimeSnapshot),
      'hostActionSnapshot': hostActionEncoded,
    };
  }

  StoryNarrativeSessionSnapshot _decodeSession(
    Object? encoded,
    String path, {
    required StoryProject project,
  }) {
    final map = _map(encoded, path);
    _allowOnly(map, const {
      'sessionIndex',
      'entryPointId',
      'runtimeSnapshot',
      'hostActionSnapshot',
    }, path);

    final sessionIndex = _portableNonNegativeInteger(
      _required(map, 'sessionIndex', path),
      '$path.sessionIndex',
    );
    final entryPointId = _entryPointId(
      _required(map, 'entryPointId', path),
      '$path.entryPointId',
    );

    final runtimePath = '$path.runtimeSnapshot';
    StoryRuntimeSnapshot runtimeSnapshot;
    try {
      runtimeSnapshot = _coreCodec.decode(
        _required(map, 'runtimeSnapshot', path),
        project: project,
      );
    } on StoryRuntimeSnapshotFormatException catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        '$runtimePath${_nestedPathSuffix(error.path)}',
        'Malformed retained core runtime snapshot: ${error.message}',
        cause: error,
      );
    } on StoryRuntimeSnapshotCompatibilityException catch (error) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .sessionRuntimeSnapshotIncompatible,
        path: '$runtimePath${_nestedPathSuffix(error.path)}',
        message:
            'Retained session contains an incompatible core runtime '
            'snapshot: ${error.message}',
        cause: error,
      );
    }

    final hostPath = '$path.hostActionSnapshot';
    final hostRaw = _required(map, 'hostActionSnapshot', path);
    StoryHostActionProtocolSnapshot hostActionSnapshot;
    try {
      hostActionSnapshot = _hostActionCodec.decode(jsonEncode(hostRaw));
    } on StoryHostActionProtocolSnapshotFormatException catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        hostPath,
        'Malformed retained host-action protocol snapshot: ${error.message}',
        cause: error,
      );
    } catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        hostPath,
        'Retained host-action protocol snapshot is not JSON-compatible.',
        cause: error,
      );
    }

    try {
      return StoryNarrativeSessionSnapshot(
        sessionIndex: sessionIndex,
        entryPointId: entryPointId,
        runtimeSnapshot: runtimeSnapshot,
        hostActionSnapshot: hostActionSnapshot,
      );
    } on ArgumentError catch (error) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        path,
        'Retained session checkpoint contains an invalid local value.',
        cause: error,
      );
    }
  }
}

Map<String, Object?> _encodeState(StoryState state) {
  final values = <Object?>[];
  for (final definition in state.schema.variables) {
    final value = state.values[definition.id];
    if (value != null) {
      values.add(<String, Object?>{
        'variableId': definition.id.value,
        'value': _encodeValue(value),
      });
    }
  }
  return <String, Object?>{'values': values};
}

StoryState _decodeState(
  Object? encoded,
  String path, {
  required StoryProject project,
}) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'values'}, path);
  final entries = _list(_required(map, 'values', path), '$path.values');
  final values = <StoryVariableId, StoryValue>{};

  for (var index = 0; index < entries.length; index++) {
    final entryPath = '$path.values[$index]';
    final entry = _map(entries[index], entryPath);
    _allowOnly(entry, const {'variableId', 'value'}, entryPath);
    final variableId = _variableId(
      _required(entry, 'variableId', entryPath),
      '$entryPath.variableId',
    );
    if (values.containsKey(variableId)) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        '$entryPath.variableId',
        'Persistent state contains duplicate variable ID ${variableId.value}.',
      );
    }
    final definition = project.stateSchema.definitionFor(variableId);
    if (definition == null) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .persistentStateSchemaMismatch,
        path: '$entryPath.variableId',
        message:
            'Aggregate persistent state references undeclared variable '
            '${variableId.value}.',
      );
    }
    final value = _decodeValue(
      _required(entry, 'value', entryPath),
      '$entryPath.value',
    );
    if (value.type != definition.type) {
      throw StoryNarrativeRuntimeSnapshotCompatibilityException(
        issue: StoryNarrativeRuntimeSnapshotCompatibilityIssue
            .persistentStateSchemaMismatch,
        path: '$entryPath.value',
        message:
            'Aggregate persistent-state value for ${variableId.value} '
            'has type ${value.type.name}, but the project declares '
            '${definition.type.name}.',
      );
    }
    values[variableId] = value;
  }

  try {
    return StoryState.fromValues(schema: project.stateSchema, values: values);
  } on ArgumentError catch (error) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Aggregate persistent state values are invalid.',
      cause: error,
    );
  }
}

Map<String, Object?> _encodeRandomState(StoryRuntimeRandomState state) =>
    <String, Object?>{
      'algorithmId': state.algorithmId,
      'algorithmVersion': state.algorithmVersion,
      'stateWords': List<int>.of(state.stateWords, growable: false),
    };

StoryRuntimeRandomState _decodeRandomState(Object? encoded, String path) {
  final map = _map(encoded, path);
  _allowOnly(map, const {
    'algorithmId',
    'algorithmVersion',
    'stateWords',
  }, path);
  final words = _list(_required(map, 'stateWords', path), '$path.stateWords')
      .indexed
      .map((entry) {
        final value = _integer(entry.$2, '$path.stateWords[${entry.$1}]');
        if (value < 0 || value > StoryIntegerValue.maxPortableValue) {
          throw StoryNarrativeRuntimeSnapshotFormatException(
            '$path.stateWords[${entry.$1}]',
            'Random state word must be within the portable exact integer range.',
          );
        }
        return value;
      })
      .toList(growable: false);

  try {
    return StoryRuntimeRandomState(
      algorithmId: _string(
        _required(map, 'algorithmId', path),
        '$path.algorithmId',
      ),
      algorithmVersion: _positiveInteger(
        _required(map, 'algorithmVersion', path),
        '$path.algorithmVersion',
      ),
      stateWords: words,
    );
  } on ArgumentError catch (error) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Aggregate random state metadata/payload is invalid.',
      cause: error,
    );
  }
}

Map<String, Object?> _encodeValue(StoryValue value) => switch (value) {
  StoryBooleanValue(:final value) => <String, Object?>{
    'type': 'boolean',
    'value': value,
  },
  StoryIntegerValue(:final value) => <String, Object?>{
    'type': 'integer',
    'value': value,
  },
  StoryNumberValue(:final value) => <String, Object?>{
    'type': 'number',
    'value': value,
  },
  StoryStringValue(:final value) => <String, Object?>{
    'type': 'string',
    'value': value,
  },
};

StoryValue _decodeValue(Object? encoded, String path) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'type', 'value'}, path);
  final type = _string(_required(map, 'type', path), '$path.type');
  try {
    return switch (type) {
      'boolean' => StoryBooleanValue(
        _boolean(_required(map, 'value', path), '$path.value'),
      ),
      'integer' => StoryIntegerValue(
        _integer(_required(map, 'value', path), '$path.value'),
      ),
      'number' => StoryNumberValue(
        _number(_required(map, 'value', path), '$path.value'),
      ),
      'string' => StoryStringValue(
        _string(_required(map, 'value', path), '$path.value'),
      ),
      _ => throw StoryNarrativeRuntimeSnapshotFormatException(
        '$path.type',
        'Unknown story value type "$type".',
      ),
    };
  } on StoryNarrativeRuntimeSnapshotFormatException {
    rethrow;
  } on ArgumentError catch (error) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Story value is outside the portable runtime range.',
      cause: error,
    );
  }
}

StoryProjectId _projectId(Object? value, String path) =>
    _typedId(value, path, StoryProjectId.new, 'project');

StoryEntryPointId _entryPointId(Object? value, String path) =>
    _typedId(value, path, StoryEntryPointId.new, 'entry point');

StoryVariableId _variableId(Object? value, String path) =>
    _typedId(value, path, StoryVariableId.new, 'variable');

T _typedId<T>(
  Object? encoded,
  String path,
  T Function(String) create,
  String kind,
) {
  final value = _string(encoded, path);
  try {
    return create(value);
  } on ArgumentError catch (error) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Malformed $kind ID "$value".',
      cause: error,
    );
  }
}

Object? _required(Map<String, Object?> map, String key, String path) {
  if (!map.containsKey(key)) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      '$path.$key',
      'Required field is missing.',
    );
  }
  return map[key];
}

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected an object/map.',
    );
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        path,
        'Object keys must be strings.',
      );
    }
    result[key] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected a list.',
    );
  }
  return List<Object?>.of(value, growable: false);
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected a string.',
    );
  }
  return value;
}

bool _boolean(Object? value, String path) {
  if (value is! bool) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected a boolean.',
    );
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected an integer.',
    );
  }
  return value;
}

int _positiveInteger(Object? value, String path) {
  final result = _integer(value, path);
  if (result <= 0) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected an integer greater than zero.',
    );
  }
  return result;
}

int _portableNonNegativeInteger(Object? value, String path) {
  final result = _integer(value, path);
  if (result < 0 || result > StoryIntegerValue.maxPortableValue) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected a non-negative integer within the portable exact range.',
    );
  }
  return result;
}

double _number(Object? value, String path) {
  if (value is! num) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected a number.',
    );
  }
  final result = value.toDouble();
  if (!result.isFinite) {
    throw StoryNarrativeRuntimeSnapshotFormatException(
      path,
      'Expected a finite number.',
    );
  }
  return result;
}

void _allowOnly(
  Map<String, Object?> map,
  Set<String> allowedKeys,
  String path,
) {
  for (final key in map.keys) {
    if (!allowedKeys.contains(key)) {
      throw StoryNarrativeRuntimeSnapshotFormatException(
        '$path.$key',
        'Unknown field. Newer aggregate snapshot data is never silently '
            'discarded.',
      );
    }
  }
}

String _nestedPathSuffix(String path) {
  if (path == r'$') {
    return '';
  }
  if (path.startsWith(r'$.')) {
    return path.substring(1);
  }
  return '.$path';
}
