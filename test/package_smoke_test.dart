import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('public package facade can run a minimal story', () {
    final eventId = StoryEventId('smoke_start');
    final project = StoryProject(
      id: StoryProjectId('smoke_project'),
      entryEventId: eventId,
      events: [
        StoryEvent(
          id: eventId,
          automaticTransition: const StoryTerminalTransition(),
        ),
      ],
    );
    final engine = StoryEngine(project: project)..start();

    expect(engine.status, StoryEngineStatus.terminated);
    expect(engine.currentEvent?.id, eventId);
  });
}
