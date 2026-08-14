import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('domain model stays free of embedded JSON serialization methods', () {
    final violations = <String>[];
    for (final directory in const [
      'lib/src/model',
      'lib/src/state',
      'lib/src/condition',
      'lib/src/effect',
      'lib/src/transition',
      'lib/src/identity',
      'lib/src/presentation',
    ]) {
      for (final entity in Directory(directory).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (RegExp(r'\b(?:toJson|fromJson)\s*\(').hasMatch(source)) {
          violations.add(entity.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Serialization adapters must stay outside domain objects.\n'
          '${violations.join('\n')}',
    );
  });

  test('internal draft codec is not part of public story_engine barrel', () {
    final barrel = File('lib/story_engine.dart').readAsStringSync();

    expect(barrel, isNot(contains('serialization/')));
    expect(barrel, isNot(contains('StoryProjectDraftCodec')));
    expect(barrel, isNot(contains('StoryDraftSerializationException')));
  });
}
