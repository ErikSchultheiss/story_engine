import 'story_identifier_rules.dart';

/// Stable machine identity for a `StoryEvent`.
///
/// Event references must use this identity rather than a title, alias, section
/// position, graph position, or other author-facing metadata.
final class StoryEventId {
  /// Creates a validated event identifier.
  StoryEventId(String value) : value = validateStoryMachineId(value);

  /// The opaque machine token carried by this identifier.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryEventId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryEventId, value);

  @override
  String toString() => 'StoryEventId($value)';
}
