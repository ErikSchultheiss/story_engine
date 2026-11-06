/// Opaque version token for one revision of a stable narrative module.
///
/// Version strings are labels only. `story_engine` never infers save
/// compatibility from semantic-version ordering or lexical comparison.
final class StoryModuleVersion {
  StoryModuleVersion(String value) : value = _validateVersionToken(value);

  /// Portable module-version token.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryModuleVersion && other.value == value;

  @override
  int get hashCode => Object.hash(StoryModuleVersion, value);

  @override
  String toString() => 'StoryModuleVersion($value)';
}

String _validateVersionToken(String value) {
  if (!_versionTokenPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'value',
      'Module versions must be 1-128 portable ASCII characters.',
    );
  }
  return value;
}

final _versionTokenPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$');
