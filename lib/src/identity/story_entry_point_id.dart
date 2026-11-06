import 'story_identifier_rules.dart';

/// Stable machine identity for one host-addressable narrative entry point.
///
/// Entry-point identity is distinct from event identity:
/// multiple entry points may intentionally target the same event while
/// carrying different orchestration eligibility/priority metadata.
final class StoryEntryPointId {
  StoryEntryPointId(String value) : value = validateStoryMachineId(value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEntryPointId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryEntryPointId, value);

  @override
  String toString() => 'StoryEntryPointId($value)';
}
