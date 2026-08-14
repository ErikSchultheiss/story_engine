import 'dart:io';

import 'package:story_engine/story_engine.dart';

/// Loads one committed Story Format fixture directory as a logical bundle.
StoryFormatBundle loadStoryFormatFixture(String name) {
  final root = Directory('test/fixtures/story_format_v1/$name');
  if (!root.existsSync()) {
    throw ArgumentError.value(name, 'name', 'Unknown Story Format fixture.');
  }

  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  final entries = <String, String>{};
  for (final file in files) {
    final relativePath = file.path
        .substring(root.path.length + 1)
        .replaceAll('\\', '/');
    entries[relativePath] = file.readAsStringSync();
  }
  return StoryFormatBundle(files: entries);
}
