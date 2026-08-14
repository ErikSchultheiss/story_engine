/// Version identity for the current in-memory Story Format contract.
///
/// Story Format versioning is independent from package semver, internal draft
/// serialization revisions, runtime-snapshot format versions, runtime-contract
/// versions, and RNG algorithm versions.
final class StoryFormatMetadata {
  /// Creates metadata for the only Story Format version this package currently
  /// understands as a public authored-format document.
  const StoryFormatMetadata.current()
      : formatId = currentFormatId,
        formatVersion = currentFormatVersion;

  /// Stable authored-format identity.
  static const String currentFormatId = 'story_engine.story_format';

  /// Current public Story Format version.
  static const int currentFormatVersion = 1;

  /// Stable authored-format identity carried by this document.
  final String formatId;

  /// Integer Story Format version carried by this document.
  final int formatVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatMetadata &&
          other.formatId == formatId &&
          other.formatVersion == formatVersion;

  @override
  int get hashCode => Object.hash(formatId, formatVersion);

  @override
  String toString() =>
      'StoryFormatMetadata(formatId: $formatId, version: $formatVersion)';
}
