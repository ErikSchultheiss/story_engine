/// Immutable logical Story Format bundle containing UTF-8 JSON text files.
///
/// Paths are bundle-relative portable paths using `/` separators. This value
/// deliberately performs no filesystem I/O; applications may map the files to
/// a directory, archive, database, network payload, or another storage layer.
final class StoryFormatBundle {
  factory StoryFormatBundle({required Map<String, String> files}) {
    final copied = <String, String>{};
    for (final entry in files.entries) {
      _validatePath(entry.key);
      copied[entry.key] = entry.value;
    }
    return StoryFormatBundle._(Map<String, String>.unmodifiable(copied));
  }

  StoryFormatBundle._(this.files);

  /// Bundle-relative file path to UTF-8 JSON text.
  final Map<String, String> files;

  /// Returns one file's text, or `null` when [path] is absent.
  String? file(String path) => files[path];

  /// Whether [path] exists in this logical bundle.
  bool contains(String path) => files.containsKey(path);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! StoryFormatBundle || other.files.length != files.length) {
      return false;
    }
    for (final entry in files.entries) {
      if (!other.files.containsKey(entry.key) ||
          other.files[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final paths = files.keys.toList()..sort();
    return Object.hashAll([
      StoryFormatBundle,
      for (final path in paths) Object.hash(path, files[path]),
    ]);
  }

  @override
  String toString() => 'StoryFormatBundle(${files.length} files)';
}

void _validatePath(String path) {
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.endsWith('/') ||
      path.contains('\\') ||
      path.split('/').any((segment) => segment.isEmpty || segment == '.' || segment == '..')) {
    throw ArgumentError.value(
      path,
      'files',
      'Story Format bundle paths must be non-empty portable relative file '
          'paths using forward slashes and no dot segments.',
    );
  }
}
