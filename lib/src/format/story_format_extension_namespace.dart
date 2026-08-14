/// Collision-resistant namespace for one opaque Story Format extension.
///
/// V1 uses lower-case ASCII dot-separated components such as
/// `com.example.editor_notes`. Extension namespaces identify preserved opaque
/// data only; they do not grant executable behavior to the core engine.
final class StoryFormatExtensionNamespace {
  StoryFormatExtensionNamespace(String value) : value = _validate(value);

  /// Validated dot-separated namespace token.
  final String value;

  static String _validate(String value) {
    final parts = value.split('.');
    if (parts.length < 2 ||
        parts.any((part) => !_componentPattern.hasMatch(part))) {
      throw ArgumentError.value(
        value,
        'value',
        'Story Format extension namespaces must contain at least two '
            'lower-case ASCII dot-separated components. Each component must '
            'start with a letter and then contain only letters, digits, '
            'underscore, or hyphen.',
      );
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatExtensionNamespace && other.value == value;

  @override
  int get hashCode => Object.hash(StoryFormatExtensionNamespace, value);

  @override
  String toString() => 'StoryFormatExtensionNamespace($value)';
}

final _componentPattern = RegExp(r'^[a-z][a-z0-9_-]*$');
