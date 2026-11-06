import '../condition/story_condition.dart';
import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../state/story_value.dart';

/// Stable key for one explicit host-computed Boolean fact used by entry-point
/// resolution.
///
/// The host owns the computation. The narrative runtime receives only the
/// explicit result, so orchestration never performs hidden reads of world
/// state, clocks, engine globals, or platform services.
final class StoryHostConditionKey {
  StoryHostConditionKey(String value) : value = _validateToken(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryHostConditionKey && other.value == value;

  @override
  int get hashCode => Object.hash(StoryHostConditionKey, value);

  @override
  String toString() => 'StoryHostConditionKey($value)';
}

/// Declarative request for one host-owned condition result.
///
/// [schemaNamespace], [conditionId], and [arguments] identify a condition that
/// may be declared by Extension Schema v1. This object does not contain or
/// invoke host code. The host evaluates the condition through its trusted
/// integration layer and supplies the Boolean result through [StoryHostContext].
final class StoryHostConditionRequirement {
  factory StoryHostConditionRequirement({
    required StoryHostConditionKey key,
    required String schemaNamespace,
    required String conditionId,
    Map<String, Object> arguments = const {},
    bool expected = true,
  }) => StoryHostConditionRequirement._(
    key: key,
    schemaNamespace: _validateNamespace(schemaNamespace),
    conditionId: _validateToken(conditionId, 'conditionId'),
    arguments: _copyArguments(arguments),
    expected: expected,
  );

  const StoryHostConditionRequirement._({
    required this.key,
    required this.schemaNamespace,
    required this.conditionId,
    required this.arguments,
    required this.expected,
  });

  final StoryHostConditionKey key;
  final String schemaNamespace;
  final String conditionId;
  final Map<String, Object> arguments;

  /// Required Boolean result. Set to false to express a negative requirement
  /// without asking the runtime to reinterpret the host condition itself.
  final bool expected;
}

/// Explicit host-world facts supplied for one orchestration operation.
///
/// Missing required facts are errors, not implicit false values. That keeps
/// unknown/unsupported host semantics from silently changing narrative routes.
final class StoryHostContext {
  factory StoryHostContext({
    Map<StoryHostConditionKey, bool> conditionResults = const {},
  }) => StoryHostContext._(
    Map<StoryHostConditionKey, bool>.unmodifiable(conditionResults),
  );

  const StoryHostContext._(this.conditionResults);

  static final StoryHostContext empty = StoryHostContext();

  final Map<StoryHostConditionKey, bool> conditionResults;

  bool? resultFor(StoryHostConditionKey key) => conditionResults[key];
}

/// One host-addressable way to begin a local narrative session.
///
/// Entry points are orchestration metadata above Story Format v1. Stage 8G
/// intentionally does not add them to the frozen authored format or define a
/// wire representation for them yet.
final class StoryEntryPoint {
  factory StoryEntryPoint({
    required StoryEntryPointId id,
    required StoryEventId eventId,
    StoryCondition? eligibilityCondition,
    Iterable<StoryHostConditionRequirement> hostConditions = const [],
    int priority = 0,
    int weight = 1,
    bool isFallback = false,
  }) {
    if (priority < StoryIntegerValue.minPortableValue ||
        priority > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        priority,
        'priority',
        'Entry-point priority must be a portable Story Integer.',
      );
    }
    if (weight <= 0 || weight > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Entry-point weight must be within 1..${StoryIntegerValue.maxPortableValue}.',
      );
    }

    final copiedHostConditions =
        List<StoryHostConditionRequirement>.unmodifiable(hostConditions);
    final seenHostKeys = <StoryHostConditionKey>{};
    for (final requirement in copiedHostConditions) {
      if (!seenHostKeys.add(requirement.key)) {
        throw ArgumentError.value(
          hostConditions,
          'hostConditions',
          'Entry point $id contains duplicate host-condition key '
              '${requirement.key}.',
        );
      }
    }

    return StoryEntryPoint._(
      id: id,
      eventId: eventId,
      eligibilityCondition: eligibilityCondition,
      hostConditions: copiedHostConditions,
      priority: priority,
      weight: weight,
      isFallback: isFallback,
    );
  }

  const StoryEntryPoint._({
    required this.id,
    required this.eventId,
    required this.eligibilityCondition,
    required this.hostConditions,
    required this.priority,
    required this.weight,
    required this.isFallback,
  });

  final StoryEntryPointId id;
  final StoryEventId eventId;

  /// Optional core state condition evaluated against persistent narrative
  /// state before a session starts.
  final StoryCondition? eligibilityCondition;

  /// Explicit host-world requirements, evaluated in declaration order after
  /// [eligibilityCondition] succeeds.
  final List<StoryHostConditionRequirement> hostConditions;

  /// Higher values outrank lower values after eligibility/fallback filtering.
  final int priority;

  /// Positive authored-order weight used only when multiple eligible entry
  /// points share the winning fallback tier and priority.
  final int weight;

  /// Fallback entries are considered only when no non-fallback entry is
  /// eligible. Fallback never competes with a regular eligible entry.
  final bool isFallback;
}

Map<String, Object> _copyArguments(Map<String, Object> arguments) {
  final result = <String, Object>{};
  for (final entry in arguments.entries) {
    final name = _validateToken(entry.key, 'argument name');
    final value = entry.value;
    if (value is bool || value is String) {
      result[name] = value;
      continue;
    }
    if (value is int) {
      StoryIntegerValue(value);
      result[name] = value;
      continue;
    }
    if (value is double && value.isFinite) {
      result[name] = value;
      continue;
    }
    throw ArgumentError.value(
      value,
      'arguments[$name]',
      'Host-condition arguments must be Boolean, portable Integer, finite '
          'Number, or String.',
    );
  }
  return Map<String, Object>.unmodifiable(result);
}

String _validateNamespace(String value) {
  if (!_namespacePattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'schemaNamespace',
      'Extension namespace must use at least two lower-case ASCII '
          'dot-separated components.',
    );
  }
  return value;
}

String _validateToken(String value, String name) {
  if (!_tokenPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      name,
      'Value must start with a lower-case ASCII letter and contain only '
      'lower-case ASCII letters, digits, and underscores.',
    );
  }
  return value;
}

final _namespacePattern = RegExp(r'^[a-z][a-z0-9_-]*(\.[a-z][a-z0-9_-]*)+$');
final _tokenPattern = RegExp(r'^[a-z][a-z0-9_]*$');
