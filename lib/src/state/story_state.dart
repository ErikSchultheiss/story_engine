import '../identity/story_variable_id.dart';
import 'story_state_schema.dart';
import 'story_value.dart';

/// Immutable snapshot of author-controlled scalar narrative state.
///
/// Runtime bookkeeping such as the current event, visited events, choice
/// history, occurrence counts, and RNG state does not belong here. Those live
/// in the broader `StoryRuntimeSnapshot` runtime-persistence contract.
///
/// Public callers can inspect state but cannot mutate it in place. Future
/// engine effects will use the package-internal [StoryStateMutation] mechanism
/// to produce a new [StoryState].
final class StoryState {
  /// Builds the initial state from all definitions that declare initial values.
  factory StoryState.initial(StoryStateSchema schema) {
    final values = <StoryVariableId, StoryValue>{};
    for (final definition in schema.variables) {
      final initialValue = definition.initialValue;
      if (initialValue != null) {
        values[definition.id] = initialValue;
      }
    }
    return StoryState._validated(schema, values);
  }

  /// Builds an immutable state snapshot from explicit values.
  ///
  /// This is useful for deterministic tests, playtest setup, and later
  /// snapshot restoration. Every supplied ID must be declared by [schema], and
  /// each value must exactly match its declared scalar type. Omitted declared
  /// variables remain unset.
  factory StoryState.fromValues({
    required StoryStateSchema schema,
    required Map<StoryVariableId, StoryValue> values,
  }) => StoryState._validated(schema, values);

  /// Builds an immutable state snapshot from ordinary Dart scalar values.
  ///
  /// This convenience constructor accepts the same portable scalar domain as
  /// [StoryValue.fromRaw] and is useful when host application state starts as
  /// JSON-like Dart values. Declared-but-omitted variables remain unset.
  factory StoryState.fromRawValues({
    required StoryStateSchema schema,
    required Map<StoryVariableId, Object> values,
  }) => StoryState._validated(
    schema,
    <StoryVariableId, StoryValue>{
      for (final entry in values.entries)
        entry.key: StoryValue.fromRaw(entry.value),
    },
  );

  factory StoryState._validated(
    StoryStateSchema schema,
    Map<StoryVariableId, StoryValue> values,
  ) {
    _validateValuesAgainstSchema(schema, values);
    return StoryState._(
      schema,
      Map<StoryVariableId, StoryValue>.unmodifiable(values),
    );
  }

  StoryState._(this.schema, this._values);

  /// The authored schema governing this state snapshot.
  final StoryStateSchema schema;

  final Map<StoryVariableId, StoryValue> _values;

  /// Read-only view of all currently set values.
  Map<StoryVariableId, StoryValue> get values => _values;

  /// Whether the declared variable [id] currently has a value.
  ///
  /// Throws if [id] is not declared by this state's schema, so an undeclared ID
  /// is never confused with a declared-but-unset variable.
  bool isSet(StoryVariableId id) {
    _requireDeclared(id);
    return _values.containsKey(id);
  }

  /// Returns the current value for declared [id], or `null` when it is unset.
  ///
  /// Throws if [id] is not declared by this state's schema.
  StoryValue? valueOf(StoryVariableId id) {
    _requireDeclared(id);
    return _values[id];
  }

  /// Returns the underlying Dart scalar for declared [id], or `null` when
  /// the variable is unset.
  ///
  /// This is a convenience view over [valueOf]; it preserves schema checking
  /// and never exposes mutable story state.
  Object? rawValueOf(StoryVariableId id) => valueOf(id)?.rawValue;

  void _requireDeclared(StoryVariableId id) {
    if (!schema.contains(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'Story variable is not declared by this state schema.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryState &&
          other.schema == schema &&
          _mapValuesEqual(_values, other._values);

  @override
  int get hashCode {
    var hash = schema.hashCode;
    for (final definition in schema.variables) {
      final value = _values[definition.id];
      if (value != null) {
        hash = Object.hash(hash, definition.id, value);
      }
    }
    return hash;
  }

  @override
  String toString() => 'StoryState(${_values.length} set values)';
}

/// Package-internal state evolution mechanism.
///
/// This type is intentionally not exported from `package:story_engine/`
/// even though engine implementation files under `lib/src/` may import it.
/// Future effects should evolve story state through this boundary rather than
/// exposing mutable maps or setters on [StoryState].
final class StoryStateMutation {
  const StoryStateMutation._();

  /// Returns a new snapshot with [id] set to [value].
  static StoryState set(
    StoryState state,
    StoryVariableId id,
    StoryValue value,
  ) {
    final values = Map<StoryVariableId, StoryValue>.of(state._values);
    values[id] = value;
    return StoryState._validated(state.schema, values);
  }

  /// Returns a new snapshot with declared [id] unset.
  static StoryState unset(StoryState state, StoryVariableId id) {
    state._requireDeclared(id);
    final values = Map<StoryVariableId, StoryValue>.of(state._values);
    values.remove(id);
    return StoryState._validated(state.schema, values);
  }
}

void _validateValuesAgainstSchema(
  StoryStateSchema schema,
  Map<StoryVariableId, StoryValue> values,
) {
  for (final entry in values.entries) {
    final definition = schema.definitionFor(entry.key);
    if (definition == null) {
      throw ArgumentError.value(
        entry.key,
        'values',
        'Story state contains an undeclared variable ID.',
      );
    }
    if (entry.value.type != definition.type) {
      throw ArgumentError.value(
        entry.value,
        'values',
        'Value type ${entry.value.type.name} does not match declared variable '
            'type ${definition.type.name} for ${entry.key}.',
      );
    }
  }
}

bool _mapValuesEqual(
  Map<StoryVariableId, StoryValue> left,
  Map<StoryVariableId, StoryValue> right,
) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
