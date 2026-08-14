import '../identity/story_alias.dart';
import '../identity/story_variable_id.dart';
import 'story_value.dart';
import 'story_value_type.dart';

/// Authored declaration of one scalar story-state variable.
///
/// A definition describes what may exist at runtime. It is distinct from the
/// mutable-in-time value held by a runtime StoryState snapshot.
final class StoryVariableDefinition {
  /// Creates a variable definition and validates any declared initial value.
  StoryVariableDefinition({
    required this.id,
    required this.type,
    this.alias,
    this.initialValue,
  }) {
    final initialValue = this.initialValue;
    if (initialValue != null && initialValue.type != type) {
      throw ArgumentError.value(
        initialValue,
        'initialValue',
        'Initial value type ${initialValue.type.name} does not match '
            'declared variable type ${type.name}.',
      );
    }
  }

  /// Stable machine identity for this variable.
  final StoryVariableId id;

  /// Optional readable handle; not durable machine identity.
  final StoryAlias? alias;

  /// Scalar value category accepted by this variable.
  final StoryValueType type;

  /// Optional initial runtime value.
  ///
  /// `null` means intentionally unset, not false/zero/empty-string.
  final StoryValue? initialValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableDefinition &&
          other.id == id &&
          other.alias == alias &&
          other.type == type &&
          other.initialValue == initialValue;

  @override
  int get hashCode => Object.hash(id, alias, type, initialValue);

  @override
  String toString() =>
      'StoryVariableDefinition(id: $id, alias: $alias, type: $type, '
      'initialValue: $initialValue)';
}
