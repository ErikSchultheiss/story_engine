/// Machine-readable reason a Story Format document cannot be interpreted by
/// the current public format contract.
enum StoryFormatCompatibilityIssue {
  /// The bundle identifies a different authored format family.
  unsupportedFormatIdentity,

  /// The bundle uses a Story Format version this package does not understand.
  unsupportedFormatVersion,
}

/// Structured incompatibility encountered before current-version Story Format
/// decoding can safely interpret authored semantics.
///
/// This is deliberately separate from `StoryFormatCodecException`: malformed
/// data that claims to be current Story Format v1 is a codec/data error, while
/// a different format identity or unsupported version is a compatibility
/// boundary that a host may route through a future migration path.
final class StoryFormatCompatibilityException implements Exception {
  const StoryFormatCompatibilityException({
    required this.issue,
    required this.bundlePath,
    required this.jsonPath,
    required this.message,
    this.foundFormatId,
    this.foundFormatVersion,
  });

  /// Stable machine-readable incompatibility classification.
  final StoryFormatCompatibilityIssue issue;

  /// Bundle-relative file where incompatibility was detected.
  final String bundlePath;

  /// JSONPath-like location inside [bundlePath].
  final String jsonPath;

  /// Human-readable explanation.
  final String message;

  /// Parsed authored-format identity when one was available.
  final String? foundFormatId;

  /// Parsed authored-format version when one was available.
  final int? foundFormatVersion;

  /// Compact bundle + JSON location for developer logs.
  String get location => '$bundlePath:$jsonPath';

  /// Actionable compatibility guidance independent from [message].
  String get suggestion => switch (issue) {
    StoryFormatCompatibilityIssue.unsupportedFormatIdentity =>
      'Use a reader/importer for ${foundFormatId ?? 'the detected format'} '
          'before decoding it as Story Format.',
    StoryFormatCompatibilityIssue.unsupportedFormatVersion =>
      'Use a story_engine version that supports Story Format version '
          '${foundFormatVersion ?? 'the detected version'}, or migrate the '
          'bundle to a supported version.',
  };

  @override
  String toString() =>
      'StoryFormatCompatibilityException(${issue.name}) at '
      '$bundlePath:$jsonPath: $message';
}
