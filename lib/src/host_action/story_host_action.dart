import '../identity/story_host_action_request_id.dart';
import '../state/story_value.dart';

/// Portable scalar categories accepted for successful host-action results.
enum StoryHostActionValueKind {
  boolean,
  integer,
  number,
  string,
  enumeration,
  reference,
}

/// Language-neutral type descriptor for one host-action result value.
///
/// Enumeration/reference values remain stable strings at the protocol layer;
/// their domain identity is carried explicitly rather than inferred from a host
/// programming-language type.
final class StoryHostActionValueType {
  const StoryHostActionValueType.boolean()
    : kind = StoryHostActionValueKind.boolean,
      enumId = null,
      referenceTypeId = null;

  const StoryHostActionValueType.integer()
    : kind = StoryHostActionValueKind.integer,
      enumId = null,
      referenceTypeId = null;

  const StoryHostActionValueType.number()
    : kind = StoryHostActionValueKind.number,
      enumId = null,
      referenceTypeId = null;

  const StoryHostActionValueType.string()
    : kind = StoryHostActionValueKind.string,
      enumId = null,
      referenceTypeId = null;

  StoryHostActionValueType.enumeration(String enumId)
    : kind = StoryHostActionValueKind.enumeration,
      enumId = _validateMemberId(enumId, 'enumId'),
      referenceTypeId = null;

  StoryHostActionValueType.reference(String referenceTypeId)
    : kind = StoryHostActionValueKind.reference,
      enumId = null,
      referenceTypeId = _validateMemberId(referenceTypeId, 'referenceTypeId');

  final StoryHostActionValueKind kind;
  final String? enumId;
  final String? referenceTypeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryHostActionValueType &&
          other.kind == kind &&
          other.enumId == enumId &&
          other.referenceTypeId == referenceTypeId;

  @override
  int get hashCode => Object.hash(kind, enumId, referenceTypeId);
}

/// Immutable portable request emitted when narrative execution awaits host work.
///
/// The request names one declared extension action using a language-neutral
/// namespace/member identity. [arguments] contain only portable scalar values;
/// executable callbacks, futures, engine objects, and platform handles are
/// deliberately excluded.
final class StoryHostActionRequest {
  StoryHostActionRequest({
    required this.id,
    required String schemaNamespace,
    required String actionId,
    Map<String, Object> arguments = const {},
    this.resultType,
  }) : schemaNamespace = _validateNamespace(schemaNamespace, 'schemaNamespace'),
       actionId = _validateMemberId(actionId, 'actionId'),
       arguments = _copyArguments(arguments);

  final StoryHostActionRequestId id;
  final String schemaNamespace;
  final String actionId;
  final Map<String, Object> arguments;

  /// Expected successful result type, or null when the action returns no value.
  final StoryHostActionValueType? resultType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryHostActionRequest &&
          other.id == id &&
          other.schemaNamespace == schemaNamespace &&
          other.actionId == actionId &&
          _mapsEqual(other.arguments, arguments) &&
          other.resultType == resultType;

  @override
  int get hashCode => Object.hash(
    id,
    schemaNamespace,
    actionId,
    Object.hashAll(
      arguments.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    resultType,
  );
}

/// Explicit host input that resolves one pending request.
sealed class StoryHostActionOutcome {
  const StoryHostActionOutcome({required this.requestId});

  final StoryHostActionRequestId requestId;
}

/// Successful completion of one host-action request.
final class StoryHostActionCompleted extends StoryHostActionOutcome {
  const StoryHostActionCompleted({
    required super.requestId,
    required this.value,
  });

  /// Typed result value, or null only when the request declares no result type.
  final Object? value;
}

/// Explicit host-reported failure of one host-action request.
final class StoryHostActionFailed extends StoryHostActionOutcome {
  StoryHostActionFailed({
    required super.requestId,
    required String code,
    required this.message,
  }) : code = _validateMachineToken(code, 'code');

  final String code;
  final String message;
}

/// Explicit host cancellation of one host-action request.
final class StoryHostActionCancelled extends StoryHostActionOutcome {
  StoryHostActionCancelled({
    required super.requestId,
    required String code,
    this.message,
  }) : code = _validateMachineToken(code, 'code');

  final String code;
  final String? message;
}

Map<String, Object> _copyArguments(Map<String, Object> source) {
  final keys = source.keys.toList()..sort();
  final result = <String, Object>{};
  for (final key in keys) {
    _validateMemberId(key, 'arguments key');
    result[key] = _copyPortableScalar(source[key]!, 'arguments.$key');
  }
  return Map<String, Object>.unmodifiable(result);
}

Object _copyPortableScalar(Object value, String path) {
  if (value is bool || value is String) {
    return value;
  }
  if (value is int) {
    if (value < StoryIntegerValue.minPortableValue ||
        value > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        value,
        path,
        'Integer host-action values must remain in the portable exact range.',
      );
    }
    return value;
  }
  if (value is double && value.isFinite) {
    return value;
  }
  throw ArgumentError.value(
    value,
    path,
    'Host-action values must be Boolean, Integer, finite Number, or String.',
  );
}

bool hostActionResultMatchesType(
  Object? value,
  StoryHostActionValueType? type,
) {
  if (type == null) {
    return value == null;
  }
  if (value == null) {
    return false;
  }
  return switch (type.kind) {
    StoryHostActionValueKind.boolean => value is bool,
    StoryHostActionValueKind.integer =>
      value is int &&
          value >= StoryIntegerValue.minPortableValue &&
          value <= StoryIntegerValue.maxPortableValue,
    StoryHostActionValueKind.number => value is double && value.isFinite,
    StoryHostActionValueKind.string => value is String,
    StoryHostActionValueKind.enumeration => value is String && value.isNotEmpty,
    StoryHostActionValueKind.reference => value is String && value.isNotEmpty,
  };
}

final RegExp _namespaceComponentPattern = RegExp(r'^[a-z][a-z0-9_-]*$');
final RegExp _memberIdPattern = RegExp(r'^[a-z][a-z0-9_]*$');
final RegExp _machineTokenPattern = RegExp(r'^[a-z][a-z0-9_.-]*$');

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
      'Member identifiers must start with a lower-case ASCII letter and then '
      'contain only lower-case letters, digits, or underscore.',
    );
  }
  return value;
}

String _validateMachineToken(String value, String argumentName) {
  if (!_machineTokenPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      argumentName,
      'Machine tokens must be stable lower-case ASCII identifiers.',
    );
  }
  return value;
}

bool _mapsEqual(Map<String, Object> left, Map<String, Object> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
