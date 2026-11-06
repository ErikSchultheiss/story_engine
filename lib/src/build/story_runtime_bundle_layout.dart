import '../identity/story_module_id.dart';

/// Canonical portable file layout for Runtime Bundle Contract Revision 1.
abstract final class StoryRuntimeBundleLayout {
  /// Canonical manifest path.
  static const String manifestPath = 'runtime-manifest.json';

  /// Opaque compiled/indexed project-index artifact path.
  static const String indexPath = 'index.runtime';

  /// Directory containing independently replaceable module artifacts.
  static const String modulesDirectory = 'modules';

  /// Returns the portable path for one compiled module artifact.
  static String modulePath(StoryModuleId moduleId) =>
      '$modulesDirectory/${_encodeBase32LowerNoPadding(moduleId.value)}.runtime';

  /// Whether [path] is a portable bundle-relative path.
  static bool isPortablePath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.endsWith('/') &&
      !path.contains('\\') &&
      path
          .split('/')
          .every(
            (segment) =>
                segment.isNotEmpty && segment != '.' && segment != '..',
          );
}

const _base32Alphabet = 'abcdefghijklmnopqrstuvwxyz234567';

String _encodeBase32LowerNoPadding(String value) {
  var buffer = 0;
  var bufferedBits = 0;
  final output = StringBuffer();

  for (final byte in value.codeUnits) {
    buffer = (buffer << 8) | byte;
    bufferedBits += 8;

    while (bufferedBits >= 5) {
      bufferedBits -= 5;
      output.write(_base32Alphabet[(buffer >> bufferedBits) & 0x1f]);
    }

    if (bufferedBits == 0) {
      buffer = 0;
    } else {
      buffer &= (1 << bufferedBits) - 1;
    }
  }

  if (bufferedBits > 0) {
    output.write(_base32Alphabet[(buffer << (5 - bufferedBits)) & 0x1f]);
  }

  return output.toString();
}
