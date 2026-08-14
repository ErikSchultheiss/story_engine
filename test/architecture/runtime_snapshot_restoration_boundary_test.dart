import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('StoryEngine snapshot capture/restore stays encoding agnostic', () {
    final source = File('lib/src/runtime/story_engine.dart').readAsStringSync();

    expect(source, isNot(contains('../persistence/')));
    expect(source, isNot(contains('StoryRuntimeSnapshotCodec')));
    expect(source, isNot(contains('dart:convert')));
    expect(source, isNot(contains('jsonEncode')));
    expect(source, isNot(contains('jsonDecode')));
  });

  test('restore does not reconstruct parallel history-derived collections', () {
    final source = File('lib/src/runtime/story_engine.dart').readAsStringSync();

    expect(source, contains('_historySteps.addAll(snapshot.history.steps);'));
    expect(source, isNot(contains('snapshot.history.visitedEventIds')));
    expect(source, isNot(contains('snapshot.history.selectedChoiceIds')));
    expect(source, isNot(contains('snapshot.history.continuedEventIds')));
  });

  test('snapshot capture cannot expose transaction-local pending history', () {
    final source = File('lib/src/runtime/story_engine.dart').readAsStringSync();
    final start = source.indexOf('StoryRuntimeSnapshot createSnapshot()');
    final end = source.indexOf('List<StoryChoice> get availableChoices');

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final captureSource = source.substring(start, end);

    expect(captureSource, isNot(contains('pendingHistorySteps')));
    expect(captureSource, isNot(contains('_RuntimeTransaction')));
    expect(captureSource, contains('history: history'));
  });
}
