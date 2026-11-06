import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryEngine choice explanations', () {
    test(
      'explain every authored choice without hiding unavailable choices',
      () {
        final enabled = StoryVariableId('enabled');
        final eventId = StoryEventId('choice_explanation_event');
        final unconditionalId = StoryChoiceId('unconditional');
        final availableId = StoryChoiceId('available');
        final unavailableId = StoryChoiceId('unavailable');
        final project = StoryProject(
          id: StoryProjectId('choice_explanation_project'),
          entryEventId: eventId,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: enabled,
                type: StoryValueType.boolean,
                initialValue: const StoryBooleanValue(true),
              ),
            ],
          ),
          events: [
            StoryEvent(
              id: eventId,
              choices: [
                StoryChoice(
                  id: unconditionalId,
                  transition: const StoryTerminalTransition(),
                ),
                StoryChoice(
                  id: availableId,
                  availabilityCondition: StoryVariableComparisonCondition(
                    variableId: enabled,
                    operator: StoryComparisonOperator.equal,
                    value: const StoryBooleanValue(true),
                  ),
                  transition: const StoryTerminalTransition(),
                ),
                StoryChoice(
                  id: unavailableId,
                  availabilityCondition: StoryVariableComparisonCondition(
                    variableId: enabled,
                    operator: StoryComparisonOperator.equal,
                    value: const StoryBooleanValue(false),
                  ),
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        );
        final engine = StoryEngine(project: project)..start();
        final before = engine.createSnapshot();

        final explanations = engine.choiceExplanations;

        expect(explanations.map((explanation) => explanation.choiceId), [
          unconditionalId,
          availableId,
          unavailableId,
        ]);
        expect(explanations[0].available, isTrue);
        expect(explanations[0].condition, isNull);
        expect(explanations[1].available, isTrue);
        expect(explanations[1].condition?.result, isTrue);
        expect(explanations[2].available, isFalse);
        expect(explanations[2].condition?.result, isFalse);
        expect(engine.availableChoices.map((choice) => choice.id), [
          unconditionalId,
          availableId,
        ]);

        final after = engine.createSnapshot();
        expect(after.status, before.status);
        expect(after.state, before.state);
        expect(after.currentEventId, before.currentEventId);
        expect(after.history, before.history);
        expect(after.randomState, before.randomState);
      },
    );

    test('returns no explanations outside an awaiting-choice pause', () {
      final eventId = StoryEventId('continue_event');
      final engine = StoryEngine(
        project: StoryProject(
          id: StoryProjectId('choice_explanation_empty_project'),
          entryEventId: eventId,
          events: [
            StoryEvent(
              id: eventId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
      );

      expect(engine.choiceExplanations, isEmpty);
      engine.start();
      expect(engine.choiceExplanations, isEmpty);
      engine.continueStory();
      expect(engine.choiceExplanations, isEmpty);
    });
  });
}
