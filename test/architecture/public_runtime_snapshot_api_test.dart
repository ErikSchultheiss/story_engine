import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('runtime snapshot value contract is available through public barrel', () {
    final eventId = StoryEventId('event_public_snapshot');
    final snapshot = StoryRuntimeSnapshot(
      projectId: StoryProjectId('project_public_snapshot'),
      status: StoryEngineStatus.awaitingContinue,
      state: StoryState.initial(StoryStateSchema.empty()),
      currentEventId: eventId,
      history: StoryRuntimeHistory(
        steps: [StoryEventEnteredStep(eventId: eventId)],
      ),
      randomState: StoryRuntimeRandomState(
        algorithmId: 'story_engine.public_test',
        algorithmVersion: 1,
        stateWords: const [42],
      ),
      maxAutomaticTransitions: StoryEngine.defaultMaxAutomaticTransitions,
    );

    expect(
      snapshot.metadata,
      const StoryRuntimeSnapshotMetadata(),
    );
    expect(snapshot.projectId.value, 'project_public_snapshot');
    expect(snapshot.status, StoryEngineStatus.awaitingContinue);
    expect(snapshot.currentEventId, eventId);
  });
}
