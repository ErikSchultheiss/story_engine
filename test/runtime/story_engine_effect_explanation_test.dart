import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryEngine effect explanations', () {
    test(
      'start records committed and no-op entry effects in authored order',
      () {
        final counterId = StoryVariableId('counter');
        final optionalId = StoryVariableId('optional');
        final eventId = StoryEventId('entry');
        final project = StoryProject(
          id: StoryProjectId('effect_start_project'),
          entryEventId: eventId,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: counterId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(1),
              ),
              StoryVariableDefinition(
                id: optionalId,
                type: StoryValueType.string,
              ),
            ],
          ),
          events: [
            StoryEvent(
              id: eventId,
              entryEffects: [
                StoryIncrementVariableEffect(
                  variableId: counterId,
                  amount: StoryIntegerValue(2),
                ),
                StoryUnsetVariableEffect(variableId: optionalId),
              ],
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final engine = StoryEngine(project: project);

        final explanations = engine.startWithEffectExplanations();

        expect(explanations, hasLength(2));
        expect(explanations, same(engine.lastEffectExplanations));
        expect(explanations[0].source.kind, StoryEffectOwnerKind.eventEntry);
        expect(explanations[0].source.eventId, eventId);
        expect(explanations[0].authoredIndex, 0);
        expect(explanations[0].beforeValue, StoryIntegerValue(1));
        expect(explanations[0].afterValue, StoryIntegerValue(3));
        expect(explanations[0].outcome, StoryEffectOutcome.committed);
        expect(explanations[1].authoredIndex, 1);
        expect(explanations[1].beforeValue, isNull);
        expect(explanations[1].afterValue, isNull);
        expect(explanations[1].outcome, StoryEffectOutcome.noOp);
        expect(engine.state?.valueOf(counterId), StoryIntegerValue(3));
      },
    );

    test(
      'choice and destination entry effects keep exact authored sources',
      () {
        final scoreId = StoryVariableId('score');
        final startId = StoryEventId('start');
        final destinationId = StoryEventId('destination');
        final choiceId = StoryChoiceId('advance');
        final project = StoryProject(
          id: StoryProjectId('effect_choice_project'),
          entryEventId: startId,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: scoreId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(10),
              ),
            ],
          ),
          events: [
            StoryEvent(
              id: startId,
              choices: [
                StoryChoice(
                  id: choiceId,
                  effects: [
                    StoryIncrementVariableEffect(
                      variableId: scoreId,
                      amount: StoryIntegerValue(5),
                    ),
                  ],
                  transition: StoryEventTransition(
                    destinationEventId: destinationId,
                  ),
                ),
              ],
            ),
            StoryEvent(
              id: destinationId,
              entryEffects: [
                StoryIncrementVariableEffect(
                  variableId: scoreId,
                  amount: StoryIntegerValue(2),
                ),
              ],
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final engine = StoryEngine(project: project)..start();

        final explanations = engine.chooseWithEffectExplanations(choiceId);

        expect(explanations, hasLength(2));
        expect(explanations[0].source.kind, StoryEffectOwnerKind.choice);
        expect(explanations[0].source.eventId, startId);
        expect(explanations[0].source.choiceId, choiceId);
        expect(explanations[0].authoredIndex, 0);
        expect(explanations[0].beforeValue, StoryIntegerValue(10));
        expect(explanations[0].afterValue, StoryIntegerValue(15));
        expect(explanations[0].outcome, StoryEffectOutcome.committed);
        expect(explanations[1].source.kind, StoryEffectOwnerKind.eventEntry);
        expect(explanations[1].source.eventId, destinationId);
        expect(explanations[1].source.choiceId, isNull);
        expect(explanations[1].beforeValue, StoryIntegerValue(15));
        expect(explanations[1].afterValue, StoryIntegerValue(17));
        expect(explanations[1].outcome, StoryEffectOutcome.committed);
        expect(engine.state?.valueOf(scoreId), StoryIntegerValue(17));
        expect(engine.status, StoryEngineStatus.terminated);
      },
    );

    test(
      'later runtime failure exposes rolled-back effects without commit',
      () {
        final scoreId = StoryVariableId('score');
        final gateId = StoryVariableId('gate');
        final startId = StoryEventId('start');
        final blockedId = StoryEventId('blocked');
        final choiceId = StoryChoiceId('blocked_choice');
        final project = StoryProject(
          id: StoryProjectId('effect_rollback_project'),
          entryEventId: startId,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: scoreId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(10),
              ),
              StoryVariableDefinition(
                id: gateId,
                type: StoryValueType.boolean,
                initialValue: const StoryBooleanValue(false),
              ),
            ],
          ),
          events: [
            StoryEvent(
              id: startId,
              choices: [
                StoryChoice(
                  id: choiceId,
                  effects: [
                    StoryIncrementVariableEffect(
                      variableId: scoreId,
                      amount: StoryIntegerValue(5),
                    ),
                  ],
                  transition: StoryEventTransition(
                    destinationEventId: blockedId,
                  ),
                ),
              ],
            ),
            StoryEvent(
              id: blockedId,
              availabilityCondition: StoryVariableComparisonCondition(
                variableId: gateId,
                operator: StoryComparisonOperator.equal,
                value: const StoryBooleanValue(true),
              ),
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final engine = StoryEngine(project: project)..start();
        final before = engine.createSnapshot();

        expect(
          () => engine.chooseWithEffectExplanations(choiceId),
          throwsA(isA<StoryEngineExecutionException>()),
        );

        expect(engine.lastEffectExplanations, hasLength(1));
        expect(
          engine.lastEffectExplanations.single.outcome,
          StoryEffectOutcome.rolledBack,
        );
        expect(
          engine.lastEffectExplanations.single.afterValue,
          StoryIntegerValue(15),
        );
        final after = engine.createSnapshot();
        expect(after.state, before.state);
        expect(after.currentEventId, before.currentEventId);
        expect(after.history, before.history);
        expect(after.randomState, before.randomState);
      },
    );

    test('effect execution failure is rejected and leaves state unchanged', () {
      final unsetId = StoryVariableId('unset_counter');
      final startId = StoryEventId('start');
      final choiceId = StoryChoiceId('invalid_effect');
      final project = StoryProject(
        id: StoryProjectId('effect_rejected_project'),
        entryEventId: startId,
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(id: unsetId, type: StoryValueType.integer),
          ],
        ),
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: choiceId,
                effects: [
                  StoryIncrementVariableEffect(
                    variableId: unsetId,
                    amount: StoryIntegerValue(1),
                  ),
                ],
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project)..start();
      final before = engine.createSnapshot();

      expect(
        () => engine.chooseWithEffectExplanations(choiceId),
        throwsA(isA<StoryEngineExecutionException>()),
      );

      expect(engine.lastEffectExplanations, hasLength(1));
      final rejected = engine.lastEffectExplanations.single;
      expect(rejected.outcome, StoryEffectOutcome.rejected);
      expect(rejected.variableId, unsetId);
      expect(rejected.beforeValue, isNull);
      expect(rejected.afterValue, isNull);
      expect(engine.createSnapshot().state, before.state);
      expect(engine.createSnapshot().history, before.history);
    });

    test(
      'diagnostics-on execution has the same committed runtime snapshot',
      () {
        final scoreId = StoryVariableId('score');
        final startId = StoryEventId('start');
        final leftId = StoryEventId('left');
        final rightId = StoryEventId('right');
        final choiceId = StoryChoiceId('weighted');
        final project = StoryProject(
          id: StoryProjectId('effect_parity_project'),
          entryEventId: startId,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: scoreId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(0),
              ),
            ],
          ),
          events: [
            StoryEvent(
              id: startId,
              choices: [
                StoryChoice(
                  id: choiceId,
                  effects: [
                    StoryIncrementVariableEffect(
                      variableId: scoreId,
                      amount: StoryIntegerValue(1),
                    ),
                  ],
                  transition: StoryWeightedTransition(
                    options: [
                      StoryWeightedTransitionOption(
                        weight: 1,
                        transition: StoryEventTransition(
                          destinationEventId: leftId,
                        ),
                      ),
                      StoryWeightedTransitionOption(
                        weight: 1,
                        transition: StoryEventTransition(
                          destinationEventId: rightId,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            StoryEvent(
              id: leftId,
              automaticTransition: const StoryTerminalTransition(),
            ),
            StoryEvent(
              id: rightId,
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final ordinary = StoryEngine(project: project, randomSeed: 42)..start();
        final explained = StoryEngine(project: project, randomSeed: 42)
          ..start();

        ordinary.choose(choiceId);
        explained.chooseWithEffectExplanations(choiceId);

        expect(explained.createSnapshot(), ordinary.createSnapshot());
        expect(explained.lastEffectExplanations, hasLength(1));
        expect(
          explained.lastEffectExplanations.single.outcome,
          StoryEffectOutcome.committed,
        );
      },
    );

    test(
      'ordinary operations remain diagnostics-off and clear prior trace',
      () {
        final flagId = StoryVariableId('flag');
        final startId = StoryEventId('start');
        final endId = StoryEventId('end');
        final choiceId = StoryChoiceId('advance');
        final project = StoryProject(
          id: StoryProjectId('effect_off_project'),
          entryEventId: startId,
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: flagId,
                type: StoryValueType.boolean,
                initialValue: const StoryBooleanValue(false),
              ),
            ],
          ),
          events: [
            StoryEvent(
              id: startId,
              entryEffects: [
                StorySetVariableEffect(
                  variableId: flagId,
                  value: const StoryBooleanValue(true),
                ),
              ],
              choices: [
                StoryChoice(
                  id: choiceId,
                  transition: StoryEventTransition(destinationEventId: endId),
                ),
              ],
            ),
            StoryEvent(
              id: endId,
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final engine = StoryEngine(project: project);

        expect(engine.startWithEffectExplanations(), hasLength(1));
        engine.choose(choiceId);

        expect(engine.lastEffectExplanations, isEmpty);
      },
    );
  });
}
