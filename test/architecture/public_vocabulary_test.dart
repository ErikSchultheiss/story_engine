import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('authored vocabulary remains exposed from the package root', () {
    final project = StoryProject(id: StoryProjectId('project_001'));
    final event = StoryEvent(id: StoryEventId('event_001'));
    final choice = StoryChoice(id: StoryChoiceId('choice_001'));

    expect(project, isA<StoryProject>());
    expect(event, isA<StoryEvent>());
    expect(choice, isA<StoryChoice>());
  });
}
