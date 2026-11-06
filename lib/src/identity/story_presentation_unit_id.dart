import 'story_identifier_rules.dart';

/// Stable machine identity for one translatable or voice-production presentation unit.
///
/// The identity is independent from visible wording and from the event/choice slot
/// in which the unit currently appears. Rewriting or moving the source unit must
/// therefore preserve this ID unless the author intentionally creates a new unit.
final class StoryPresentationUnitId {
  /// Creates a validated presentation-unit identifier.
  StoryPresentationUnitId(String value) : value = validateStoryMachineId(value);

  /// Opaque portable machine token.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryPresentationUnitId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryPresentationUnitId, value);

  @override
  String toString() => 'StoryPresentationUnitId($value)';
}
