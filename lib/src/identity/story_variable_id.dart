import 'story_identifier_rules.dart';

/// Stable machine identity for an authored story variable.
///
/// Variable references use this typed opaque token rather than an alias,
/// visible label, list position, or editor grouping. Renaming/reorganizing a
/// variable therefore does not change its durable identity.
final class StoryVariableId {
  /// Creates a validated variable identifier.
  StoryVariableId(String value) : value = validateStoryMachineId(value);

  /// The opaque machine token carried by this identifier.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryVariableId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryVariableId, value);

  @override
  String toString() => 'StoryVariableId($value)';
}
