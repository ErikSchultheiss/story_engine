import 'story_identifier_rules.dart';

/// Stable machine identity for a `StoryProject`.
///
/// The string value is deliberately opaque. Consumers must not infer project
/// semantics, hierarchy, titles, or filesystem locations from it.
final class StoryProjectId {
  /// Creates a validated project identifier.
  StoryProjectId(String value) : value = validateStoryMachineId(value);

  /// The opaque machine token carried by this identifier.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryProjectId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryProjectId, value);

  @override
  String toString() => 'StoryProjectId($value)';
}
