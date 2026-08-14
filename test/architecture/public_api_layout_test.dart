import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('story_engine.dart is the only top-level Dart library in lib', () {
    final topLevelDartFiles = Directory('lib')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.uri.pathSegments.last)
        .toList()
      ..sort();

    expect(topLevelDartFiles, <String>['story_engine.dart']);
  });
}
