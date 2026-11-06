import 'dart:convert';

import '../identity/story_host_action_request_id.dart';
import 'story_host_action.dart';
import 'story_host_action_protocol.dart';

/// Strict JSON codec for [StoryHostActionProtocolSnapshot].
final class StoryHostActionProtocolSnapshotCodec {
  const StoryHostActionProtocolSnapshotCodec();

  static const String contract = 'open_story.host_action_protocol_snapshot';
  static const int contractVersion = 1;

  String encode(StoryHostActionProtocolSnapshot snapshot) =>
      jsonEncode(_encodeSnapshot(snapshot));

  StoryHostActionProtocolSnapshot decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw StoryHostActionProtocolSnapshotFormatException(
        message: 'Host-action protocol snapshot is not valid JSON.',
        cause: error,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const StoryHostActionProtocolSnapshotFormatException(
        message: 'Host-action protocol snapshot root must be an object.',
      );
    }
    return _decodeSnapshot(decoded);
  }

  Map<String, dynamic> _encodeSnapshot(
    StoryHostActionProtocolSnapshot snapshot,
  ) => <String, dynamic>{
    'contract': contract,
    'contractVersion': contractVersion,
    'scope': snapshot.scope,
    'nextRequestOrdinal': snapshot.nextRequestOrdinal,
    'pendingRequest': snapshot.pendingRequest == null
        ? null
        : _encodeRequest(snapshot.pendingRequest!),
  };

  StoryHostActionProtocolSnapshot _decodeSnapshot(Map<String, dynamic> json) {
    _requireKeys(json, const {
      'contract',
      'contractVersion',
      'scope',
      'nextRequestOrdinal',
      'pendingRequest',
    }, r'$');
    if (json['contract'] != contract) {
      throw const StoryHostActionProtocolSnapshotFormatException(
        message: 'Unsupported host-action protocol snapshot contract.',
      );
    }
    if (json['contractVersion'] != contractVersion) {
      throw const StoryHostActionProtocolSnapshotFormatException(
        message: 'Unsupported host-action protocol snapshot version.',
      );
    }
    final scope = _string(json['scope'], r'$.scope');
    final nextOrdinal = _integer(
      json['nextRequestOrdinal'],
      r'$.nextRequestOrdinal',
    );
    final pendingRaw = json['pendingRequest'];
    final pending = pendingRaw == null
        ? null
        : _decodeRequest(_object(pendingRaw, r'$.pendingRequest'));
    try {
      return StoryHostActionProtocolSnapshot(
        scope: scope,
        nextRequestOrdinal: nextOrdinal,
        pendingRequest: pending,
      );
    } on ArgumentError catch (error) {
      throw StoryHostActionProtocolSnapshotFormatException(
        message: 'Invalid host-action protocol snapshot value: $error',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _encodeRequest(StoryHostActionRequest request) =>
      <String, dynamic>{
        'id': request.id.value,
        'schemaNamespace': request.schemaNamespace,
        'actionId': request.actionId,
        'arguments': request.arguments,
        'resultType': request.resultType == null
            ? null
            : _encodeValueType(request.resultType!),
      };

  StoryHostActionRequest _decodeRequest(Map<String, dynamic> json) {
    _requireKeys(json, const {
      'id',
      'schemaNamespace',
      'actionId',
      'arguments',
      'resultType',
    }, r'$.pendingRequest');
    final argumentsRaw = _object(
      json['arguments'],
      r'$.pendingRequest.arguments',
    );
    final arguments = <String, Object>{};
    for (final entry in argumentsRaw.entries) {
      arguments[entry.key] = _scalar(
        entry.value,
        r'$.pendingRequest.arguments.' + entry.key,
      );
    }
    final resultTypeRaw = json['resultType'];
    try {
      return StoryHostActionRequest(
        id: StoryHostActionRequestId(
          _string(json['id'], r'$.pendingRequest.id'),
        ),
        schemaNamespace: _string(
          json['schemaNamespace'],
          r'$.pendingRequest.schemaNamespace',
        ),
        actionId: _string(json['actionId'], r'$.pendingRequest.actionId'),
        arguments: arguments,
        resultType: resultTypeRaw == null
            ? null
            : _decodeValueType(
                _object(resultTypeRaw, r'$.pendingRequest.resultType'),
              ),
      );
    } on ArgumentError catch (error) {
      throw StoryHostActionProtocolSnapshotFormatException(
        message: 'Invalid pending host-action request: $error',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _encodeValueType(
    StoryHostActionValueType type,
  ) => <String, dynamic>{
    'kind': switch (type.kind) {
      StoryHostActionValueKind.boolean => 'boolean',
      StoryHostActionValueKind.integer => 'integer',
      StoryHostActionValueKind.number => 'number',
      StoryHostActionValueKind.string => 'string',
      StoryHostActionValueKind.enumeration => 'enumeration',
      StoryHostActionValueKind.reference => 'reference',
    },
    if (type.enumId != null) 'enumId': type.enumId,
    if (type.referenceTypeId != null) 'referenceTypeId': type.referenceTypeId,
  };

  StoryHostActionValueType _decodeValueType(Map<String, dynamic> json) {
    final kind = _string(json['kind'], r'$.pendingRequest.resultType.kind');
    switch (kind) {
      case 'boolean':
        _requireKeys(json, const {'kind'}, r'$.pendingRequest.resultType');
        return const StoryHostActionValueType.boolean();
      case 'integer':
        _requireKeys(json, const {'kind'}, r'$.pendingRequest.resultType');
        return const StoryHostActionValueType.integer();
      case 'number':
        _requireKeys(json, const {'kind'}, r'$.pendingRequest.resultType');
        return const StoryHostActionValueType.number();
      case 'string':
        _requireKeys(json, const {'kind'}, r'$.pendingRequest.resultType');
        return const StoryHostActionValueType.string();
      case 'enumeration':
        _requireKeys(json, const {
          'kind',
          'enumId',
        }, r'$.pendingRequest.resultType');
        return StoryHostActionValueType.enumeration(
          _string(json['enumId'], r'$.pendingRequest.resultType.enumId'),
        );
      case 'reference':
        _requireKeys(json, const {
          'kind',
          'referenceTypeId',
        }, r'$.pendingRequest.resultType');
        return StoryHostActionValueType.reference(
          _string(
            json['referenceTypeId'],
            r'$.pendingRequest.resultType.referenceTypeId',
          ),
        );
      default:
        throw StoryHostActionProtocolSnapshotFormatException(
          message: 'Unknown host-action result type kind: $kind.',
        );
    }
  }
}

/// Reports malformed or unsupported host-action protocol snapshot JSON.
final class StoryHostActionProtocolSnapshotFormatException
    implements Exception {
  const StoryHostActionProtocolSnapshotFormatException({
    required this.message,
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StoryHostActionProtocolSnapshotFormatException: $message';
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw StoryHostActionProtocolSnapshotFormatException(
    message: 'Value at $path must be an object.',
  );
}

String _string(Object? value, String path) {
  if (value is String) {
    return value;
  }
  throw StoryHostActionProtocolSnapshotFormatException(
    message: 'Value at $path must be a string.',
  );
}

int _integer(Object? value, String path) {
  if (value is int) {
    return value;
  }
  throw StoryHostActionProtocolSnapshotFormatException(
    message: 'Value at $path must be an integer.',
  );
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
  throw StoryHostActionProtocolSnapshotFormatException(
    message:
        'Value at $path must be Boolean, Integer, finite Number, or String.',
  );
}

void _requireKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String path,
) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw StoryHostActionProtocolSnapshotFormatException(
      message: 'Object at $path must contain exactly ${expected.toList()}.',
    );
  }
}
