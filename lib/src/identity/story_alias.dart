import 'story_identifier_rules.dart';

/// Optional human/developer-friendly alias for an authored entity.
///
/// An alias is deliberately not machine identity. It can later support readable
/// developer integrations, search, diagnostics, and authoring workflows, but
/// durable references must use the corresponding typed machine ID.
///
/// Aliases use lower-case ASCII snake_case so they are predictable in source
/// control, tooling, logs, and developer-facing configuration.
final class StoryAlias {
  /// Creates a validated alias such as `forest_gate` or `mara_trust`.
  StoryAlias(String value) : value = validateStoryAlias(value);

  /// The developer-friendly alias token.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryAlias && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'StoryAlias($value)';
}
