import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 2G continuation flow', () {
    test('presented no-choice event pauses until continueStory', () {
      final startId = StoryEventId('evt_start');
      final nextId = StoryEventId('evt_next');
      final finishId = StoryChoiceId('choice_finish');
      final project = StoryProject(
        id: StoryProjectId('project_continue_pause'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            presentation: StoryEventPresentation(
              title: const StoryText('Pause here'),
            ),
            continuationTransition: StoryEventTransition(
              destinationEventId: nextId,
            ),
          ),
          StoryEvent(
            id: nextId,
            choices: [
              StoryChoice(
                id: finishId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 1)..start();

      expect(engine.status, StoryEngineStatus.awaitingContinue);
      expect(engine.currentEvent?.id, startId);
      expect(engine.availableChoices, isEmpty);

      engine.continueStory();

      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(engine.currentEvent?.id, nextId);
      expect(engine.availableChoices.single.id, finishId);
      expect(engine.history.continuedEventIds, [startId]);
    });

    test('entry effects run before the continuation pause', () {
      final countId = StoryVariableId('var_count');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: countId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(1),
          ),
        ],
      );
      final startId = StoryEventId('evt_start');
      final project = StoryProject(
        id: StoryProjectId('project_continue_entry_effect'),
        stateSchema: schema,
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: countId,
                amount: StoryIntegerValue(2),
              ),
            ],
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 2)..start();

      expect(engine.status, StoryEngineStatus.awaitingContinue);
      expect(engine.state?.valueOf(countId), StoryIntegerValue(3));

      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);
    });

    test('continuation transition observes state after entry effects', () {
      final trustId = StoryVariableId('var_trust');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: trustId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(50),
          ),
        ],
      );
      final startId = StoryEventId('evt_start');
      final trustedId = StoryEventId('evt_trusted');
      final fallbackId = StoryEventId('evt_fallback');
      final project = StoryProject(
        id: StoryProjectId('project_continue_post_entry_state'),
        stateSchema: schema,
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: trustId,
                amount: StoryIntegerValue(15),
              ),
            ],
            continuationTransition: StoryConditionalTransition(
              branches: [
                StoryConditionalTransitionBranch(
                  condition: StoryVariableComparisonCondition(
                    variableId: trustId,
                    operator: StoryComparisonOperator.greaterThanOrEqual,
                    value: StoryIntegerValue(60),
                  ),
                  transition: StoryEventTransition(
                    destinationEventId: trustedId,
                  ),
                ),
              ],
              fallback: StoryEventTransition(destinationEventId: fallbackId),
            ),
          ),
          StoryEvent(
            id: trustedId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: fallbackId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 3)..start();

      expect(engine.state?.valueOf(trustId), StoryIntegerValue(65));
      engine.continueStory();

      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.currentEvent?.id, trustedId);
    });

    test('choose and continueStory reject the wrong pause mode', () {
      final choiceEventId = StoryEventId('evt_choice');
      final continueEventId = StoryEventId('evt_continue');
      final choiceId = StoryChoiceId('choice_to_continue');
      final project = StoryProject(
        id: StoryProjectId('project_continue_operations'),
        entryEventId: choiceEventId,
        events: [
          StoryEvent(
            id: choiceEventId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryEventTransition(
                  destinationEventId: continueEventId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: continueEventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 4)..start();

      expect(
        engine.continueStory,
        throwsA(isA<StoryEngineOperationException>()),
      );

      engine.choose(choiceId);
      expect(engine.status, StoryEngineStatus.awaitingContinue);
      expect(
        () => engine.choose(choiceId),
        throwsA(isA<StoryEngineOperationException>()),
      );

      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);
      expect(
        engine.continueStory,
        throwsA(isA<StoryEngineOperationException>()),
      );
    });

    test('failed continue rolls back continue and destination history', () {
      final startId = StoryEventId('evt_start');
      final missingId = StoryEventId('evt_missing');
      final project = StoryProject(
        id: StoryProjectId('project_continue_rollback'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            continuationTransition: StoryEventTransition(
              destinationEventId: missingId,
            ),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 5)..start();
      final before = engine.history;

      expect(
        engine.continueStory,
        throwsA(isA<StoryEngineConfigurationException>()),
      );

      expect(engine.status, StoryEngineStatus.awaitingContinue);
      expect(engine.currentEvent?.id, startId);
      expect(engine.history, before);
      expect(engine.history.continuedEventIds, isEmpty);
    });

    test('runtime rejects events with more than one flow mode', () {
      final startId = StoryEventId('evt_start');
      final choiceId = StoryChoiceId('choice_end');
      final project = StoryProject(
        id: StoryProjectId('project_continue_ambiguous'),
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
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 6);

      expect(engine.start, throwsA(isA<StoryEngineConfigurationException>()));
      expect(engine.status, StoryEngineStatus.notStarted);
    });
  });
}
