import '../identity/story_event_id.dart';
import 'story_format_document.dart';

/// Canonical logical file layout for one Story Format v1 authored bundle.
///
/// Paths are portable bundle-relative paths that always use `/` separators.
/// This type does not perform filesystem I/O. Stage 5D separately defines the
/// deterministic JSON representation inside each logical file.
///
/// The v1 core layout is intentionally small:
///
/// ```text
/// project.json
/// events/<portable-event-id>.json
/// organization.json             // omitted when organization is empty
/// extensions.json               // omitted when there are no extensions
/// ```
///
/// Event storage is derived only from stable [StoryEventId] identity. Mutable
/// aliases, presentation text, and group membership never participate in the
/// path, so ordinary authoring edits do not move event files.
abstract final class StoryFormatBundleLayout {
  /// Mandatory root manifest/document index.
  static const String projectPath = 'project.json';

  /// Directory containing one semantic event document per unique event ID.
  static const String eventsDirectory = 'events';

  /// Optional runtime-neutral organization document.
  static const String organizationPath = 'organization.json';

  /// Optional opaque extension-attachment document.
  static const String extensionsPath = 'extensions.json';

  /// Returns the canonical portable storage token for [eventId].
  ///
  /// Story machine IDs are ASCII but deliberately permit characters that are
  /// unsafe or collision-prone as filenames on common filesystems (for
  /// example `:`, `.`, and case distinctions). V1 therefore encodes the exact
  /// ID bytes using RFC 4648 Base32, lower-case and without `=` padding.
  ///
  /// The mapping is reversible and one-to-one. A maximum-length 128-byte
  /// machine ID produces a 205-character token, keeping the resulting filename
  /// below common 255-character filename-component limits.
  static String eventFileToken(StoryEventId eventId) =>
      _encodeBase32LowerNoPadding(eventId.value);

  /// Returns the canonical bundle-relative JSON path for [eventId].
  static String eventPath(StoryEventId eventId) =>
      '$eventsDirectory/${eventFileToken(eventId)}.json';

  /// Returns every canonical file path required by [document].
  ///
  /// `project.json` is always present. Organization/extensions files are
  /// omitted when empty. Event files are enumerated by canonical path order,
  /// not authored event order; authored event order belongs in the project
  /// manifest/index and therefore never depends on directory enumeration.
  ///
  /// A document containing duplicate event IDs cannot be materialized into
  /// this one-file-per-stable-ID layout and is rejected here. Stage 5E freezes
  /// this as an intentional format-boundary failure rather than inventing
  /// unstable storage identities.
  static List<String> canonicalFilePaths(StoryFormatDocument document) {
    final eventPaths = <String>[];
    final seen = <String>{};

    for (final event in document.project.events) {
      final path = eventPath(event.id);
      if (!seen.add(path)) {
        throw ArgumentError.value(
          event.id,
          'document',
          'Story Format v1 requires unique event IDs when materializing a '
              'bundle because each stable event identity owns exactly one '
              'event file.',
        );
      }
      eventPaths.add(path);
    }
    eventPaths.sort();

    return List<String>.unmodifiable([
      projectPath,
      if (!document.organization.isEmpty) organizationPath,
      if (document.extensions.isNotEmpty) extensionsPath,
      ...eventPaths,
    ]);
  }
}

const _base32Alphabet = 'abcdefghijklmnopqrstuvwxyz234567';

String _encodeBase32LowerNoPadding(String value) {
  var buffer = 0;
  var bufferedBits = 0;
  final output = StringBuffer();

  for (final byte in value.codeUnits) {
    // Story machine IDs are validated as ASCII by the identity layer.
    buffer = (buffer << 8) | byte;
    bufferedBits += 8;

    while (bufferedBits >= 5) {
      bufferedBits -= 5;
      final index = (buffer >> bufferedBits) & 0x1f;
      output.write(_base32Alphabet[index]);
    }

    if (bufferedBits == 0) {
      buffer = 0;
    } else {
      buffer &= (1 << bufferedBits) - 1;
    }
  }

  if (bufferedBits > 0) {
    final index = (buffer << (5 - bufferedBits)) & 0x1f;
    output.write(_base32Alphabet[index]);
  }

  return output.toString();
}
