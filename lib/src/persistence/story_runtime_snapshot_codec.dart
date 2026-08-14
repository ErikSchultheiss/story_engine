import 'dart:convert';

import '../identity/story_choice_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../identity/story_variable_id.dart';
import '../model/story_project.dart';
import '../runtime/story_engine_status.dart';
import '../runtime/story_runtime_history.dart';
import '../runtime/story_runtime_snapshot.dart';
import '../runtime/story_runtime_snapshot_validator.dart';
import '../state/story_state.dart';
import '../state/story_value.dart';
import 'story_runtime_snapshot_migrations.dart';

/// Structured malformed-data failure from [StoryRuntimeSnapshotCodec].
///
/// Compatibility failures for otherwise well-formed snapshots use
/// [StoryRuntimeSnapshotCompatibilityException] instead.
final class StoryRuntimeSnapshotFormatException implements Exception {
  const StoryRuntimeSnapshotFormatException(
    this.path,
    this.message, {
    this.cause,
  });

  final String path;
  final String message;
  final Object? cause;

  /// Machine-oriented location alias shared with other public data failures.
  String get location => path;

  /// Generic recovery guidance for malformed persisted snapshot data.
  String get suggestion => 'Inspect the persisted snapshot at $path and '
      'correct or discard the malformed value before restoring it.';

  @override
  String toString() {
    final causeText = cause == null ? '' : ' Cause: $cause';
    return 'StoryRuntimeSnapshotFormatException at $path: '
        '$message$causeText';
  }
}

/// Deterministic pure-Dart adapter for the versioned runtime-snapshot document.
///
/// The encoded document is deliberately separate from authored-project
/// serialization. It stores only runtime state and requires the corresponding
/// [StoryProject] when decoding so authored schema/event definitions are not
/// duplicated inside the save file.
final class StoryRuntimeSnapshotCodec {
  StoryRuntimeSnapshotCodec()
    : _migrations = StoryRuntimeSnapshotMigrationPipeline.builtIn();

  static const String documentType = 'story_engine_runtime_snapshot';

  final StoryRuntimeSnapshotMigrationPipeline _migrations;

  /// Encodes [snapshot] into the current deterministic JSON-compatible shape.
  ///
  /// Only current-version in-memory snapshots are emitted. Old encoded formats
  /// are upgraded while decoding rather than being re-emitted from old domain
  /// values.
  Map<String, Object?> encode(StoryRuntimeSnapshot snapshot) {
    if (snapshot.metadata.formatVersion !=
        StoryRuntimeSnapshotMetadata.currentFormatVersion) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion,
        path: r'$.formatVersion',
        message: 'The current codec emits only snapshot format version '
            '${StoryRuntimeSnapshotMetadata.currentFormatVersion}.',
      );
    }
    if (snapshot.metadata.runtimeContractVersion !=
        StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue
            .unsupportedRuntimeContractVersion,
        path: r'$.runtimeContractVersion',
        message: 'The current codec emits only runtime contract version '
            '${StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion}.',
      );
    }
    return <String, Object?>{
      'documentType': documentType,
      'formatVersion': snapshot.metadata.formatVersion,
      'runtimeContractVersion': snapshot.metadata.runtimeContractVersion,
      'projectId': snapshot.projectId.value,
      'status': _encodeStatus(snapshot.status),
      'state': _encodeState(snapshot.state),
      'currentEventId': snapshot.currentEventId?.value,
      'history': _encodeHistory(snapshot.history),
      'randomState': _encodeRandomState(snapshot.randomState),
      'maxAutomaticTransitions': snapshot.maxAutomaticTransitions,
    };
  }

  /// Encodes [snapshot] as compact deterministic JSON.
  String encodeJson(StoryRuntimeSnapshot snapshot) => jsonEncode(encode(snapshot));

  /// Decodes one runtime-snapshot data tree against [project].
  ///
  /// Malformed representation failures use [StoryRuntimeSnapshotFormatException].
  /// Well-formed but incompatible snapshots use
  /// [StoryRuntimeSnapshotCompatibilityException].
  StoryRuntimeSnapshot decode(
    Object? encoded, {
    required StoryProject project,
  }) {
    try {
      final source = _map(encoded, r'$');
      final document = _migrateToCurrent(source);
      final snapshot = _decodeCurrent(document, project: project);
      const StoryRuntimeSnapshotValidator().validate(
        snapshot: snapshot,
        project: project,
      );
      return snapshot;
    } on StoryRuntimeSnapshotFormatException {
      rethrow;
    } on StoryRuntimeSnapshotCompatibilityException {
      rethrow;
    } catch (error) {
      throw StoryRuntimeSnapshotFormatException(
        r'$',
        'Invalid runtime snapshot data.',
        cause: error,
      );
    }
  }

  /// Decodes compact or pretty-printed runtime-snapshot JSON against [project].
  StoryRuntimeSnapshot decodeJson(
    String source, {
    required StoryProject project,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (error) {
      throw StoryRuntimeSnapshotFormatException(
        r'$',
        'Input is not valid JSON.',
        cause: error,
      );
    }
    return decode(decoded, project: project);
  }

  Map<String, Object?> _migrateToCurrent(Map<String, Object?> source) {
    final type = _string(
      _required(source, 'documentType', r'$'),
      r'$.documentType',
    );
    if (type != documentType) {
      throw StoryRuntimeSnapshotFormatException(
        r'$.documentType',
        'Expected "$documentType", got "$type".',
      );
    }

    final version = _positiveInteger(
      _required(source, 'formatVersion', r'$'),
      r'$.formatVersion',
    );
    final current = StoryRuntimeSnapshotMetadata.currentFormatVersion;
    if (version > current) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion,
        path: r'$.formatVersion',
        message: 'Snapshot format version $version is newer than supported '
            'version $current.',
      );
    }
    if (version == current) {
      return source;
    }
    if (!_migrations.canMigrate(fromVersion: version, toVersion: current)) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion,
        path: r'$.formatVersion',
        message: 'No migration path exists from snapshot format version '
            '$version to $current.',
      );
    }
    try {
      return _migrations.migrate(
        document: source,
        fromVersion: version,
        toVersion: current,
      );
    } catch (error) {
      throw StoryRuntimeSnapshotFormatException(
        r'$',
        'Runtime snapshot migration failed.',
        cause: error,
      );
    }
  }

  StoryRuntimeSnapshot _decodeCurrent(
    Map<String, Object?> root, {
    required StoryProject project,
  }) {
    _allowOnly(
      root,
      const {
        'documentType',
        'formatVersion',
        'runtimeContractVersion',
        'projectId',
        'status',
        'state',
        'currentEventId',
        'history',
        'randomState',
        'maxAutomaticTransitions',
      },
      r'$',
    );

    final type = _string(_required(root, 'documentType', r'$'), r'$.documentType');
    if (type != documentType) {
      throw StoryRuntimeSnapshotFormatException(
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
        StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue
            .unsupportedRuntimeContractVersion,
        path: r'$.runtimeContractVersion',
        message: 'Snapshot runtime contract version $runtimeContractVersion '
            'is not supported by this engine runtime.',
      );
    }

    final projectId = _projectId(
      _required(root, 'projectId', r'$'),
      r'$.projectId',
    );
    if (projectId != project.id) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
        path: r'$.projectId',
        message: 'Snapshot belongs to ${projectId.value}, but the supplied '
            'project is ${project.id.value}.',
      );
    }

    final status = _decodeStatus(
      _required(root, 'status', r'$'),
      r'$.status',
    );

    final stateEncoded = _required(root, 'state', r'$');
    final state = stateEncoded == null
        ? null
        : _decodeState(stateEncoded, r'$.state', project: project);
    final currentEventEncoded = _required(root, 'currentEventId', r'$');
    final currentEventId = currentEventEncoded == null
        ? null
        : _eventId(currentEventEncoded, r'$.currentEventId');

    try {
      return StoryRuntimeSnapshot(
        metadata: StoryRuntimeSnapshotMetadata(
          formatVersion: formatVersion,
          runtimeContractVersion: runtimeContractVersion,
        ),
        projectId: projectId,
        status: status,
        state: state,
        currentEventId: currentEventId,
        history: _decodeHistory(
          _required(root, 'history', r'$'),
          r'$.history',
        ),
        randomState: _decodeRandomState(
          _required(root, 'randomState', r'$'),
          r'$.randomState',
        ),
        maxAutomaticTransitions: _positiveInteger(
          _required(root, 'maxAutomaticTransitions', r'$'),
          r'$.maxAutomaticTransitions',
        ),
      );
    } on ArgumentError catch (error) {
      throw StoryRuntimeSnapshotFormatException(
        r'$',
        'Snapshot violates the committed runtime-state shape.',
        cause: error,
      );
    }
  }
}

Map<String, Object?>? _encodeState(StoryState? state) {
  if (state == null) {
    return null;
  }
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
      throw StoryRuntimeSnapshotFormatException(
        '$entryPath.variableId',
        'State contains duplicate variable ID ${variableId.value}.',
      );
    }
    final definition = project.stateSchema.definitionFor(variableId);
    if (definition == null) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.stateSchemaMismatch,
        path: '$entryPath.variableId',
        message: 'Snapshot state references undeclared variable '
            '${variableId.value}.',
      );
    }
    final value = _decodeValue(
      _required(entry, 'value', entryPath),
      '$entryPath.value',
    );
    if (value.type != definition.type) {
      throw StoryRuntimeSnapshotCompatibilityException(
        issue: StoryRuntimeSnapshotCompatibilityIssue.stateSchemaMismatch,
        path: '$entryPath.value',
        message: 'Snapshot value for ${variableId.value} has type '
            '${value.type.name}, but the project declares '
            '${definition.type.name}.',
      );
    }
    values[variableId] = value;
  }

  try {
    return StoryState.fromValues(schema: project.stateSchema, values: values);
  } on ArgumentError catch (error) {
    throw StoryRuntimeSnapshotFormatException(
      path,
      'Snapshot state values are invalid.',
      cause: error,
    );
  }
}

Map<String, Object?> _encodeHistory(StoryRuntimeHistory history) =>
    <String, Object?>{
      'steps': history.steps.map(_encodeHistoryStep).toList(growable: false),
    };

Map<String, Object?> _encodeHistoryStep(StoryRuntimeStep step) => switch (step) {
  StoryEventEnteredStep(:final eventId) => <String, Object?>{
    'type': 'event_entered',
    'eventId': eventId.value,
  },
  StoryChoiceSelectedStep(:final eventId, :final choiceId) => <String, Object?>{
    'type': 'choice_selected',
    'eventId': eventId.value,
    'choiceId': choiceId.value,
  },
  StoryEventContinuedStep(:final eventId) => <String, Object?>{
    'type': 'event_continued',
    'eventId': eventId.value,
  },
};

StoryRuntimeHistory _decodeHistory(Object? encoded, String path) {
  final map = _map(encoded, path);
  _allowOnly(map, const {'steps'}, path);
  final encodedSteps = _list(_required(map, 'steps', path), '$path.steps');
  final steps = <StoryRuntimeStep>[];
  for (var index = 0; index < encodedSteps.length; index++) {
    steps.add(_decodeHistoryStep(encodedSteps[index], '$path.steps[$index]'));
  }
  return StoryRuntimeHistory(steps: steps);
}

StoryRuntimeStep _decodeHistoryStep(Object? encoded, String path) {
  final map = _map(encoded, path);
  final type = _string(_required(map, 'type', path), '$path.type');
  switch (type) {
    case 'event_entered':
      _allowOnly(map, const {'type', 'eventId'}, path);
      return StoryEventEnteredStep(
        eventId: _eventId(_required(map, 'eventId', path), '$path.eventId'),
      );
    case 'choice_selected':
      _allowOnly(map, const {'type', 'eventId', 'choiceId'}, path);
      return StoryChoiceSelectedStep(
        eventId: _eventId(_required(map, 'eventId', path), '$path.eventId'),
        choiceId: _choiceId(_required(map, 'choiceId', path), '$path.choiceId'),
      );
    case 'event_continued':
      _allowOnly(map, const {'type', 'eventId'}, path);
      return StoryEventContinuedStep(
        eventId: _eventId(_required(map, 'eventId', path), '$path.eventId'),
      );
    default:
      throw StoryRuntimeSnapshotFormatException(
        '$path.type',
        'Unknown runtime history step type "$type".',
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
  _allowOnly(
    map,
    const {'algorithmId', 'algorithmVersion', 'stateWords'},
    path,
  );
  final words = _list(
    _required(map, 'stateWords', path),
    '$path.stateWords',
  ).indexed.map((entry) {
    final value = _integer(entry.$2, '$path.stateWords[${entry.$1}]');
    if (value < 0 || value > StoryIntegerValue.maxPortableValue) {
      throw StoryRuntimeSnapshotFormatException(
        '$path.stateWords[${entry.$1}]',
        'Random state word must be within the portable exact integer range.',
      );
    }
    return value;
  }).toList(growable: false);

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
    throw StoryRuntimeSnapshotFormatException(
      path,
      'Random state metadata/payload is invalid.',
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
      _ => throw StoryRuntimeSnapshotFormatException(
        '$path.type',
        'Unknown story value type "$type".',
      ),
    };
  } on StoryRuntimeSnapshotFormatException {
    rethrow;
  } on ArgumentError catch (error) {
    throw StoryRuntimeSnapshotFormatException(
      path,
      'Story value is outside the portable runtime range.',
      cause: error,
    );
  }
}

String _encodeStatus(StoryEngineStatus status) => switch (status) {
  StoryEngineStatus.notStarted => 'notStarted',
  StoryEngineStatus.awaitingChoice => 'awaitingChoice',
  StoryEngineStatus.awaitingContinue => 'awaitingContinue',
  StoryEngineStatus.terminated => 'terminated',
};

StoryEngineStatus _decodeStatus(Object? encoded, String path) {
  final token = _string(encoded, path);
  return switch (token) {
    'notStarted' => StoryEngineStatus.notStarted,
    'awaitingChoice' => StoryEngineStatus.awaitingChoice,
    'awaitingContinue' => StoryEngineStatus.awaitingContinue,
    'terminated' => StoryEngineStatus.terminated,
    _ => throw StoryRuntimeSnapshotFormatException(
      path,
      'Unknown story engine status "$token".',
    ),
  };
}

StoryProjectId _projectId(Object? value, String path) =>
    _typedId(value, path, StoryProjectId.new, 'project');

StoryEventId _eventId(Object? value, String path) =>
    _typedId(value, path, StoryEventId.new, 'event');

StoryChoiceId _choiceId(Object? value, String path) =>
    _typedId(value, path, StoryChoiceId.new, 'choice');

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
    throw StoryRuntimeSnapshotFormatException(
      path,
      'Malformed $kind ID "$value".',
      cause: error,
    );
  }
}

Object? _required(Map<String, Object?> map, String key, String path) {
  if (!map.containsKey(key)) {
    throw StoryRuntimeSnapshotFormatException(
      '$path.$key',
      'Required field is missing.',
    );
  }
  return map[key];
}

Map<String, Object?> _map(Object? value, String path) {
  if (value is! Map) {
    throw StoryRuntimeSnapshotFormatException(path, 'Expected an object/map.');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw StoryRuntimeSnapshotFormatException(
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
    throw StoryRuntimeSnapshotFormatException(path, 'Expected a list.');
  }
  return List<Object?>.of(value, growable: false);
}

String _string(Object? value, String path) {
  if (value is! String) {
    throw StoryRuntimeSnapshotFormatException(path, 'Expected a string.');
  }
  return value;
}

bool _boolean(Object? value, String path) {
  if (value is! bool) {
    throw StoryRuntimeSnapshotFormatException(path, 'Expected a boolean.');
  }
  return value;
}

int _integer(Object? value, String path) {
  if (value is! int) {
    throw StoryRuntimeSnapshotFormatException(path, 'Expected an integer.');
  }
  return value;
}

int _positiveInteger(Object? value, String path) {
  final result = _integer(value, path);
  if (result <= 0) {
    throw StoryRuntimeSnapshotFormatException(
      path,
      'Expected an integer greater than zero.',
    );
  }
  return result;
}

double _number(Object? value, String path) {
  if (value is! num) {
    throw StoryRuntimeSnapshotFormatException(path, 'Expected a number.');
  }
  final result = value.toDouble();
  if (!result.isFinite) {
    throw StoryRuntimeSnapshotFormatException(path, 'Expected a finite number.');
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
      throw StoryRuntimeSnapshotFormatException(
        '$path.$key',
        'Unknown field. Newer snapshot data is never silently discarded.',
      );
    }
  }
}
