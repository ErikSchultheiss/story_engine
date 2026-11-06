import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryText', () {
    test(
      'preserves authored text exactly, including empty/whitespace text',
      () {
        const empty = StoryText('');
        const whitespace = StoryText('  line one\nline two  ');

        expect(empty.value, '');
        expect(whitespace.value, '  line one\nline two  ');
        expect(const StoryText('Foyer'), const StoryText('Foyer'));
      },
    );
  });

  group('StoryEventPresentation', () {
    test(
      'supports title-only, body-only, and title-plus-body presentation',
      () {
        final titleOnly = StoryEventPresentation(
          title: const StoryText('Foyer'),
        );
        final bodyOnly = StoryEventPresentation(
          body: const StoryText('You enter the station.'),
        );
        final complete = StoryEventPresentation(
          title: const StoryText('Foyer'),
          body: const StoryText('You enter the station.'),
        );

        expect(titleOnly.title, const StoryText('Foyer'));
        expect(titleOnly.body, isNull);
        expect(bodyOnly.title, isNull);
        expect(bodyOnly.body, const StoryText('You enter the station.'));
        expect(
          complete,
          StoryEventPresentation(
            title: const StoryText('Foyer'),
            body: const StoryText('You enter the station.'),
          ),
        );
      },
    );

    test('rejects an empty presentation object', () {
      expect(() => StoryEventPresentation(), throwsArgumentError);
    });
  });

  group('model attachment', () {
    test('event and choice presentation is optional authored data', () {
      final event = StoryEvent(
        id: StoryEventId('evt_foyer'),
        presentation: StoryEventPresentation(
          title: const StoryText('Foyer'),
          body: const StoryText('A corridor leads deeper into the station.'),
        ),
        choices: [
          StoryChoice(
            id: StoryChoiceId('choice_corridor'),
            presentation: const StoryChoicePresentation(
              text: StoryText('Enter the corridor'),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(event.presentation?.title, const StoryText('Foyer'));
      expect(
        event.choices.single.presentation?.text,
        const StoryText('Enter the corridor'),
      );

      final logicOnly = StoryEvent(
        id: StoryEventId('evt_logic_only'),
        automaticTransition: const StoryTerminalTransition(),
      );
      expect(logicOnly.presentation, isNull);
    });

    test('presentation does not participate in runtime flow semantics', () {
      final choiceId = StoryChoiceId('choice_finish');
      final project = StoryProject(
        id: StoryProjectId('project_presentation_runtime'),
        entryEventId: StoryEventId('evt_start'),
        events: [
          StoryEvent(
            id: StoryEventId('evt_start'),
            presentation: StoryEventPresentation(
              title: const StoryText('Start'),
              body: const StoryText('Visible content.'),
            ),
            choices: [
              StoryChoice(
                id: choiceId,
                presentation: const StoryChoicePresentation(
                  text: StoryText('Finish'),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final engine = StoryEngine(project: project, randomSeed: 1)..start();

      expect(
        engine.currentEvent?.presentation?.title,
        const StoryText('Start'),
      );
      expect(
        engine.availableChoices.single.presentation?.text,
        const StoryText('Finish'),
      );

      engine.choose(choiceId);
      expect(engine.status, StoryEngineStatus.terminated);
    });
  });
}
