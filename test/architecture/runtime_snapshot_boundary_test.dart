import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('runtime snapshot model contains no authored serialization knowledge', () {
    final source = File(
      'lib/src/runtime/story_runtime_snapshot.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('serialization/')));
    expect(source, isNot(contains('StoryProjectDraftCodec')));
    expect(source, isNot(contains('dart:convert')));
    expect(RegExp(r'\bjson(?:Encode|Decode)\s*\(').hasMatch(source), isFalse);
  });

  test('authored draft codec contains no runtime snapshot knowledge', () {
    final source = File(
      'lib/src/serialization/story_project_draft_codec.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('StoryRuntimeSnapshot')));
    expect(source, isNot(contains('story_runtime_snapshot.dart')));
  });

  test('snapshot persists canonical runtime history rather than parallel views', () {
    final source = File(
      'lib/src/runtime/story_runtime_snapshot.dart',
    ).readAsStringSync();

    expect(source, contains('final StoryRuntimeHistory history;'));
    expect(
      RegExp(r'final\s+List<StoryEventId>\s+visited').hasMatch(source),
      isFalse,
    );
    expect(
      RegExp(r'final\s+List<StoryChoiceId>\s+selected').hasMatch(source),
      isFalse,
    );
    expect(
      RegExp(r'final\s+Map<StoryEventId,\s*int>').hasMatch(source),
      isFalse,
    );
  });

  test('snapshot contract exposes no in-progress transaction machinery', () {
    final source = File(
      'lib/src/runtime/story_runtime_snapshot.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_RuntimeTransaction')));
    expect(source, isNot(contains('pendingHistorySteps')));
    expect(source, isNot(contains('automaticTransitions')));
  });

  test('runtime snapshot production code is pure Dart and Studio independent', () {
    final source = File(
      'lib/src/runtime/story_runtime_snapshot.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('package:flutter/')));
    expect(source, isNot(contains('package:cyoa_studio/')));
    expect(source.toLowerCase(), isNot(contains('timetwirlers')));
    expect(source.toLowerCase(), isNot(contains('time_twirlers')));
  });
}
