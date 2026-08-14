import '../identity/story_identifier_rules.dart';

/// Stable machine identity for one Story Format authoring group.
///
/// A group is organization metadata only. Its ID has no runtime-flow meaning
/// and must not be derived from a mutable group label or physical path.
final class StoryFormatGroupId {
  StoryFormatGroupId(String value) : value = validateStoryMachineId(value);

  /// Opaque stable machine token.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatGroupId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryFormatGroupId, value);

  @override
  String toString() => 'StoryFormatGroupId($value)';
}
