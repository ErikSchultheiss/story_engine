import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('StoryEngine choice flow is available through the public package barrel', () {
    final startId = StoryEventId('evt_start');
    final choiceId = StoryChoiceId('choice_end');
    final project = StoryProject(
      id: StoryProjectId('project_public_runtime'),
      entryEventId: startId,
      events: [
        StoryEvent(
          id: startId,
          choices: [
            StoryChoice(
              id: choiceId,
              transition: const StoryTerminalTransition(),
            ),
          ],
        ),
      ],
    );

    final engine = StoryEngine(project: project)..start();

    expect(engine.randomSeed, StoryEngine.defaultRandomSeed);
    expect(engine.status, StoryEngineStatus.awaitingChoice);
    expect(engine.currentEvent?.id, startId);
    expect(engine.availableChoices.single.id, choiceId);
    expect(engine.history.eventRoute, [startId]);
    expect(engine.history.visitedEventIds, [startId]);
    expect(engine.history.selectedChoiceIds, isEmpty);
  });

  test('StoryEngine continuation flow is available through the public barrel', () {
    final startId = StoryEventId('evt_continue');
    final project = StoryProject(
      id: StoryProjectId('project_public_continue'),
      entryEventId: startId,
      events: [
        StoryEvent(
          id: startId,
          continuationTransition: const StoryTerminalTransition(),
        ),
      ],
    );

    final engine = StoryEngine(project: project, randomSeed: 124)..start();

    expect(engine.status, StoryEngineStatus.awaitingContinue);
    expect(engine.currentEvent?.id, startId);
    expect(engine.availableChoices, isEmpty);

    engine.continueStory();

    expect(engine.status, StoryEngineStatus.terminated);
    expect(engine.history.continuedEventIds, [startId]);
  });

  test(
    'StoryEngine snapshot capture/restore is public through the package barrel',
    () {
      final eventId = StoryEventId('evt_public_snapshot_restore');
      final choiceId = StoryChoiceId('choice_public_snapshot_restore');
      final project = StoryProject(
        id: StoryProjectId('project_public_snapshot_restore'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final running = StoryEngine(project: project, randomSeed: 125)..start();

      final snapshot = running.createSnapshot();
      final restored = StoryEngine.restore(
        project: project,
        snapshot: snapshot,
      );

      expect(restored.status, StoryEngineStatus.awaitingChoice);
      expect(restored.currentEvent?.id, eventId);
      expect(restored.history, running.history);
      expect(restored.availableChoices.single.id, choiceId);
      expect(restored.createSnapshot(), snapshot);
    },
  );
}
