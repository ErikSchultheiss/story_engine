// Both bundle contracts use logical paths that can be represented by
// ordinary file and directory names on Windows as well as POSIX hosts.
bool isPortableStoryBundlePath(String path) =>
    path.split('/').every(_isPortableSegment);

bool _isPortableSegment(String segment) =>
    segment.isNotEmpty &&
    !_invalidCharacters.hasMatch(segment) &&
    !segment.startsWith(' ') &&
    !segment.endsWith('.') &&
    !segment.endsWith(' ') &&
    !_windowsDeviceName.hasMatch(segment);

final _invalidCharacters = RegExp(r'[<>:"\\|?*\x00-\x1f]');
final _windowsDeviceName = RegExp(
  r'^(?:CON|PRN|AUX|NUL|CONIN\$|CONOUT\$|(?:COM|LPT)[1-9¹²³]) *(?:\.|$)',
  caseSensitive: false,
);
