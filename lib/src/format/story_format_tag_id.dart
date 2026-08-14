import '../identity/story_identifier_rules.dart';

/// Stable machine identity for one Story Format authoring tag.
///
/// Tags are authoring classification only and never participate in runtime
/// control flow or persistence state.
final class StoryFormatTagId {
  StoryFormatTagId(String value) : value = validateStoryMachineId(value);

  /// Opaque stable machine token.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatTagId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryFormatTagId, value);

  @override
  String toString() => 'StoryFormatTagId($value)';
}
