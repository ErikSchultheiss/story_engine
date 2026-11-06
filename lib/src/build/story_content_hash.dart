import 'package:crypto/crypto.dart' as crypto;

import 'story_bundle_bytes.dart';

/// SHA-256 content identity used by deterministic runtime-bundle artifacts.
///
/// The wire representation is `sha256:<64 lower-case hexadecimal digits>`.
/// Hashes identify exact bytes; they do not imply narrative compatibility.
final class StoryContentHash {
  StoryContentHash._(this.hex);

  /// Computes a SHA-256 digest over [bytes].
  ///
  /// Throws [ArgumentError] if any value is outside the byte range 0–255.
  factory StoryContentHash.fromBytes(Iterable<int> bytes) {
    final snapshot = List<int>.of(bytes, growable: false);
    validateStoryBundleBytes(snapshot);
    return StoryContentHash._(crypto.sha256.convert(snapshot).toString());
  }

  /// Parses the canonical tagged wire representation.
  factory StoryContentHash.parse(String value) {
    const prefix = 'sha256:';
    if (!value.startsWith(prefix)) {
      throw FormatException('Content hash must use the sha256: prefix.');
    }
    final hex = value.substring(prefix.length);
    if (!_sha256HexPattern.hasMatch(hex)) {
      throw FormatException(
        'SHA-256 content hashes must contain exactly 64 lower-case '
        'hexadecimal digits.',
      );
    }
    return StoryContentHash._(hex);
  }

  /// Hash algorithm frozen by Runtime Bundle Contract Revision 1.
  static const String algorithm = 'sha256';

  /// Raw lower-case hexadecimal SHA-256 digest.
  final String hex;

  /// Canonical tagged wire value.
  String get value => '$algorithm:$hex';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryContentHash && other.hex == hex;

  @override
  int get hashCode => Object.hash(StoryContentHash, hex);

  @override
  String toString() => value;
}

final _sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');
