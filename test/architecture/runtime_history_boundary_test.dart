import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('runtime history is public structural observation data', () {
    final eventId = StoryEventId('evt_public_history');
    final choiceId = StoryChoiceId('choice_public_history');
    final history = StoryRuntimeHistory(
      steps: [
        StoryEventEnteredStep(eventId: eventId),
        StoryChoiceSelectedStep(eventId: eventId, choiceId: choiceId),
        StoryEventContinuedStep(eventId: eventId),
      ],
    );

    expect(history.eventRoute, [eventId]);
    expect(history.selectedChoiceIds, [choiceId]);
    expect(history.continuedEventIds, [eventId]);
  });

  test('history value object stays independent of state and presentation data', () {
    final source = File(
      'lib/src/runtime/story_runtime_history.dart',
    ).readAsStringSync();

    for (final forbidden in const [
      '../state/',
      '../presentation/',
      '../serialization/',
      'DateTime',
      'StoryState',
      'StoryText',
    ]) {
      expect(
        source,
        isNot(contains(forbidden)),
        reason: 'History must stay structural: $forbidden',
      );
    }
  });
}
