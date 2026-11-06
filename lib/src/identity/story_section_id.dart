import 'story_identifier_rules.dart';

/// Stable machine identity for a `StorySection`.
///
/// Section identity is independent from ordering, nesting, visible names, and
/// filesystem placement. Reorganizing authored content must not require a new
/// section ID merely because its presentation changes.
final class StorySectionId {
  /// Creates a validated section identifier.
  StorySectionId(String value) : value = validateStoryMachineId(value);

  /// The opaque machine token carried by this identifier.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StorySectionId && other.value == value;

  @override
  int get hashCode => Object.hash(StorySectionId, value);

  @override
  String toString() => 'StorySectionId($value)';
}
