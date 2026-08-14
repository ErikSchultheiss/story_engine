import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeHistory value object', () {
    final foyerId = StoryEventId('evt_foyer');
    final cellarId = StoryEventId('evt_cellar');
    final inspectId = StoryChoiceId('choice_inspect');
    final descendId = StoryChoiceId('choice_descend');

    test('derives route, first visits, choices, and occurrence counts', () {
      final history = StoryRuntimeHistory(
        steps: [
          StoryEventEnteredStep(eventId: foyerId),
          StoryChoiceSelectedStep(eventId: foyerId, choiceId: inspectId),
          StoryEventEnteredStep(eventId: foyerId),
          StoryChoiceSelectedStep(eventId: foyerId, choiceId: descendId),
          StoryEventEnteredStep(eventId: cellarId),
        ],
      );

      expect(history.eventRoute, [foyerId, foyerId, cellarId]);
      expect(history.visitedEventIds, [foyerId, cellarId]);
      expect(history.selectedChoiceIds, [inspectId, descendId]);
      expect(history.eventOccurrenceCount(foyerId), 2);
      expect(history.eventOccurrenceCount(cellarId), 1);
      expect(history.hasVisitedEvent(cellarId), isTrue);
      expect(history.hasSelectedChoice(inspectId), isTrue);
      expect(history.isEmpty, isFalse);
    });

    test('defensively copies steps and exposes immutable derived lists', () {
      final source = <StoryRuntimeStep>[
        StoryEventEnteredStep(eventId: foyerId),
      ];
      final history = StoryRuntimeHistory(steps: source);

      source.add(StoryEventEnteredStep(eventId: cellarId));

      expect(history.eventRoute, [foyerId]);
      expect(
        () => history.steps.add(StoryEventEnteredStep(eventId: cellarId)),
        throwsUnsupportedError,
      );
      expect(
        () => history.eventRoute.add(cellarId),
        throwsUnsupportedError,
      );
      expect(
        () => history.visitedEventIds.add(cellarId),
        throwsUnsupportedError,
      );
      expect(
        () => history.selectedChoiceIds.add(descendId),
        throwsUnsupportedError,
      );
      expect(
        () => history.continuedEventIds.add(cellarId),
        throwsUnsupportedError,
      );
    });

    test('records explicit continue actions separately from choices', () {
      final history = StoryRuntimeHistory(
        steps: [
          StoryEventEnteredStep(eventId: foyerId),
          StoryEventContinuedStep(eventId: foyerId),
          StoryEventEnteredStep(eventId: cellarId),
        ],
      );

      expect(history.eventRoute, [foyerId, cellarId]);
      expect(history.selectedChoiceIds, isEmpty);
      expect(history.continuedEventIds, [foyerId]);
      expect(history.hasContinuedEvent(foyerId), isTrue);
      expect(history.hasContinuedEvent(cellarId), isFalse);
    });

    test('uses deterministic value equality', () {
      final left = StoryRuntimeHistory(
        steps: [
          StoryEventEnteredStep(eventId: foyerId),
          StoryChoiceSelectedStep(eventId: foyerId, choiceId: inspectId),
        ],
      );
      final right = StoryRuntimeHistory(
        steps: [
          StoryEventEnteredStep(eventId: foyerId),
          StoryChoiceSelectedStep(eventId: foyerId, choiceId: inspectId),
        ],
      );
      final different = StoryRuntimeHistory(
        steps: [StoryEventEnteredStep(eventId: foyerId)],
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(left, isNot(different));
      final sameId = StoryEventId('evt_same');
      expect(
        StoryEventEnteredStep(eventId: sameId),
        StoryEventEnteredStep(eventId: StoryEventId('evt_same')),
      );
    });
  });
}
