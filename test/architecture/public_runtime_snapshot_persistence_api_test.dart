import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('runtime snapshot persistence contract is public through the barrel', () {
    final eventId = StoryEventId('event_public_persistence');
    final project = StoryProject(
      id: StoryProjectId('project_public_persistence'),
      entryEventId: eventId,
      events: [
        StoryEvent(
          id: eventId,
          continuationTransition: const StoryTerminalTransition(),
        ),
      ],
    );
    final snapshot = StoryRuntimeSnapshot(
      projectId: project.id,
      status: StoryEngineStatus.awaitingContinue,
      state: StoryState.initial(project.stateSchema),
      currentEventId: eventId,
      history: StoryRuntimeHistory(
        steps: [StoryEventEnteredStep(eventId: eventId)],
      ),
      randomState: StoryRuntimeRandomState(
        algorithmId: 'story_engine.lcg32',
        algorithmVersion: 1,
        stateWords: const [5, 5],
      ),
      maxAutomaticTransitions: StoryEngine.defaultMaxAutomaticTransitions,
    );

    final codec = StoryRuntimeSnapshotCodec();
    final restored = codec.decode(codec.encode(snapshot), project: project);
    const StoryRuntimeSnapshotValidator().validate(
      snapshot: restored,
      project: project,
    );

    expect(restored, snapshot);
  });
}
