/// Stable machine identity for one published narrative-content release.
///
/// Release identity is an opaque label. Runtime compatibility is determined by
/// exact module revisions and explicit migration metadata, never by sorting or
/// comparing release IDs.
final class StoryContentReleaseId {
  StoryContentReleaseId(String value) : value = _validateVersionToken(value);

  /// Opaque portable release token.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryContentReleaseId && other.value == value;

  @override
  int get hashCode => Object.hash(StoryContentReleaseId, value);

  @override
  String toString() => 'StoryContentReleaseId($value)';
}

String _validateVersionToken(String value) {
  if (!_versionTokenPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'value',
      'Content release IDs must be 1-128 portable ASCII characters.',
    );
  }
  return value;
}

final _versionTokenPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+-]{0,127}$');
