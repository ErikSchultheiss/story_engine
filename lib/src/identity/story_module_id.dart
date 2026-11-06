import 'story_identifier_rules.dart';

/// Stable machine identity for one independently loadable narrative module.
///
/// Module identity is organizational/runtime-loading identity. Event IDs remain
/// globally stable within the logical project and do not change when an event
/// is moved from one module to another.
final class StoryModuleId {
  /// Creates a validated module identifier.
  StoryModuleId(String value) : value = validateStoryMachineId(value);

  /// The opaque machine token carried by this identifier.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryModuleId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryModuleId, value);

  @override
  String toString() => 'StoryModuleId($value)';
}
