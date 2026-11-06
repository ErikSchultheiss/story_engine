import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 2D StoryEngine runtime inspection', () {
    test('start history records the committed entry event', () {
      final startId = StoryEventId('evt_start');
      final project = StoryProject(
        id: StoryProjectId('project_history_start'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 1);

      expect(engine.history.isEmpty, isTrue);

      engine.start();

      expect(engine.history.eventRoute, [startId]);
      expect(engine.history.visitedEventIds, [startId]);
      expect(engine.history.eventOccurrenceCount(startId), 1);
      expect(engine.history.selectedChoiceIds, isEmpty);
    });

    test('self-transitions and choices share one ordered trace', () {
      final startId = StoryEventId('evt_start');
      final loopId = StoryChoiceId('choice_loop');
      final finishId = StoryChoiceId('choice_finish');
      final project = StoryProject(
        id: StoryProjectId('project_history_loop'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: loopId,
                transition: StoryEventTransition(destinationEventId: startId),
              ),
              StoryChoice(
                id: finishId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 2)..start();
      final beforeLoop = engine.history;

      engine.choose(loopId);

      expect(beforeLoop.eventRoute, [startId]);
      expect(beforeLoop.selectedChoiceIds, isEmpty);
      expect(engine.history.eventRoute, [startId, startId]);
      expect(engine.history.visitedEventIds, [startId]);
      expect(engine.history.eventOccurrenceCount(startId), 2);
      expect(engine.history.selectedChoiceIds, [loopId]);
      expect(engine.history.steps, [
        StoryEventEnteredStep(eventId: startId),
        StoryChoiceSelectedStep(eventId: startId, choiceId: loopId),
        StoryEventEnteredStep(eventId: startId),
      ]);

      engine.choose(finishId);

      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.history.eventRoute, [startId, startId]);
      expect(engine.history.selectedChoiceIds, [loopId, finishId]);
    });

    test('automatic chains remain visible in history', () {
      final firstId = StoryEventId('evt_first');
      final secondId = StoryEventId('evt_second');
      final interactiveId = StoryEventId('evt_interactive');
      final finishId = StoryChoiceId('choice_finish');
      final project = StoryProject(
        id: StoryProjectId('project_history_auto'),
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            automaticTransition: StoryEventTransition(
              destinationEventId: secondId,
            ),
          ),
          StoryEvent(
            id: secondId,
            automaticTransition: StoryEventTransition(
              destinationEventId: interactiveId,
            ),
          ),
          StoryEvent(
            id: interactiveId,
            choices: [
              StoryChoice(
                id: finishId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 3)..start();

      expect(engine.currentEvent?.id, interactiveId);
      expect(engine.history.eventRoute, [firstId, secondId, interactiveId]);
      expect(engine.history.visitedEventIds, [
        firstId,
        secondId,
        interactiveId,
      ]);
      expect(engine.history.selectedChoiceIds, isEmpty);
    });

    test('failed start commits no history', () {
      final startId = StoryEventId('evt_start');
      final missingId = StoryEventId('evt_missing');
      final project = StoryProject(
        id: StoryProjectId('project_history_failed_start'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            automaticTransition: StoryEventTransition(
              destinationEventId: missingId,
            ),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 4);

      expect(engine.start, throwsA(isA<StoryEngineConfigurationException>()));

      expect(engine.status, StoryEngineStatus.notStarted);
      expect(engine.history.isEmpty, isTrue);
    });

    test('failed choose rolls back pending choice and event history', () {
      final startId = StoryEventId('evt_start');
      final missingId = StoryEventId('evt_missing');
      final choiceId = StoryChoiceId('choice_broken');
      final project = StoryProject(
        id: StoryProjectId('project_history_failed_choose'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryEventTransition(destinationEventId: missingId),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 5)..start();
      final before = engine.history;

      expect(
        () => engine.choose(choiceId),
        throwsA(isA<StoryEngineConfigurationException>()),
      );

      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(engine.currentEvent?.id, startId);
      expect(engine.history, before);
      expect(engine.history.selectedChoiceIds, isEmpty);
      expect(engine.history.eventRoute, [startId]);
    });
  });
}
