import 'story_identifier_rules.dart';

/// Stable machine identity for a `StoryChoice`.
///
/// A choice remains event-owned as an authored concept, but its machine
/// identity is not derived from its parent event. This allows future refactors
/// to move a choice without automatically destroying history/test identity.
final class StoryChoiceId {
  /// Creates a validated choice identifier.
  StoryChoiceId(String value) : value = validateStoryMachineId(value);

  /// The opaque machine token carried by this identifier.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryChoiceId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryChoiceId, value);

  @override
  String toString() => 'StoryChoiceId($value)';
}
