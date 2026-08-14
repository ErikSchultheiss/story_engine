import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryEngine lifecycle', () {
    test('starts at the project entry event and exposes available choices', () {
      final startId = StoryEventId('evt_start');
      final choiceId = StoryChoiceId('choice_continue');
      final project = StoryProject(
        id: StoryProjectId('project_runtime'),
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

      final engine = StoryEngine(project: project, randomSeed: 7);

      expect(engine.status, StoryEngineStatus.notStarted);
      expect(engine.state, isNull);
      expect(engine.currentEvent, isNull);
      expect(engine.availableChoices, isEmpty);

      engine.start();

      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(engine.currentEvent?.id, startId);
      expect(engine.availableChoices.map((choice) => choice.id), [choiceId]);
      expect(engine.state, StoryState.initial(project.stateSchema));
    });

    test('cannot start twice or choose outside awaiting-choice state', () {
      final startId = StoryEventId('evt_start');
      final choiceId = StoryChoiceId('choice_end');
      final project = StoryProject(
        id: StoryProjectId('project_lifecycle'),
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
      final engine = StoryEngine(project: project, randomSeed: 1);

      expect(
        () => engine.choose(choiceId),
        throwsA(isA<StoryEngineOperationException>()),
      );

      engine.start();
      expect(
        engine.start,
        throwsA(isA<StoryEngineOperationException>()),
      );

      engine.choose(choiceId);
      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.availableChoices, isEmpty);
      expect(
        () => engine.choose(choiceId),
        throwsA(isA<StoryEngineOperationException>()),
      );
    });

    test('accepts a caller-supplied immutable initial state with same schema', () {
      final goldId = StoryVariableId('var_gold');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: goldId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(10),
          ),
        ],
      );
      final startId = StoryEventId('evt_start');
      final project = StoryProject(
        id: StoryProjectId('project_initial_state'),
        stateSchema: schema,
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final supplied = StoryState.fromValues(
        schema: schema,
        values: {goldId: StoryIntegerValue(99)},
      );
      final engine = StoryEngine(project: project, randomSeed: 4);

      engine.start(initialState: supplied);

      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.state?.valueOf(goldId), StoryIntegerValue(99));
      expect(supplied.valueOf(goldId), StoryIntegerValue(99));
    });

    test('rejects an initial state governed by a different schema', () {
      final startId = StoryEventId('evt_start');
      final project = StoryProject(
        id: StoryProjectId('project_schema'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final otherSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: StoryVariableId('var_other'),
            type: StoryValueType.boolean,
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 1);

      expect(
        () => engine.start(initialState: StoryState.initial(otherSchema)),
        throwsA(isA<StoryEngineOperationException>()),
      );
      expect(engine.status, StoryEngineStatus.notStarted);
      expect(engine.state, isNull);
    });
  });

  group('Stage 1H execution ordering', () {
    test('event availability is checked before event entry effects', () {
      final openId = StoryVariableId('var_open');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: openId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
        ],
      );
      final eventId = StoryEventId('evt_guarded');
      final project = StoryProject(
        id: StoryProjectId('project_event_order'),
        stateSchema: schema,
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: openId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(false),
            ),
            entryEffects: [
              StorySetVariableEffect(
                variableId: openId,
                value: const StoryBooleanValue(true),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 2);

      engine.start();

      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.state?.valueOf(openId), const StoryBooleanValue(true));
    });

    test('entry effects run before choice availability is evaluated', () {
      final keyId = StoryVariableId('var_key');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: keyId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
        ],
      );
      final eventId = StoryEventId('evt_room');
      final choiceId = StoryChoiceId('choice_unlock');
      final project = StoryProject(
        id: StoryProjectId('project_entry_choice_order'),
        stateSchema: schema,
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            entryEffects: [
              StorySetVariableEffect(
                variableId: keyId,
                value: const StoryBooleanValue(true),
              ),
            ],
            choices: [
              StoryChoice(
                id: choiceId,
                availabilityCondition: StoryVariableComparisonCondition(
                  variableId: keyId,
                  operator: StoryComparisonOperator.equal,
                  value: const StoryBooleanValue(true),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 3)..start();

      expect(engine.availableChoices.single.id, choiceId);
    });

    test('choice effects run before conditional transition resolution', () {
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
      final choiceId = StoryChoiceId('choice_help');
      final project = StoryProject(
        id: StoryProjectId('project_choice_order'),
        stateSchema: schema,
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: choiceId,
                effects: [
                  StoryIncrementVariableEffect(
                    variableId: trustId,
                    amount: StoryIntegerValue(15),
                  ),
                ],
                transition: StoryConditionalTransition(
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
                  fallback: StoryEventTransition(
                    destinationEventId: fallbackId,
                  ),
                ),
              ),
            ],
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
      final engine = StoryEngine(project: project, randomSeed: 5)..start();

      engine.choose(choiceId);

      expect(engine.currentEvent?.id, trustedId);
      expect(engine.state?.valueOf(trustId), StoryIntegerValue(65));
      expect(engine.status, StoryEngineStatus.terminated);
    });

    test('automatic event entry effects run before its transition resolution', () {
      final flagId = StoryVariableId('var_flag');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: flagId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
        ],
      );
      final autoId = StoryEventId('evt_auto');
      final trueId = StoryEventId('evt_true');
      final falseId = StoryEventId('evt_false');
      final project = StoryProject(
        id: StoryProjectId('project_auto_order'),
        stateSchema: schema,
        entryEventId: autoId,
        events: [
          StoryEvent(
            id: autoId,
            entryEffects: [
              StorySetVariableEffect(
                variableId: flagId,
                value: const StoryBooleanValue(true),
              ),
            ],
            automaticTransition: StoryConditionalTransition(
              branches: [
                StoryConditionalTransitionBranch(
                  condition: StoryVariableComparisonCondition(
                    variableId: flagId,
                    operator: StoryComparisonOperator.equal,
                    value: const StoryBooleanValue(true),
                  ),
                  transition: StoryEventTransition(
                    destinationEventId: trueId,
                  ),
                ),
              ],
              fallback: StoryEventTransition(destinationEventId: falseId),
            ),
          ),
          StoryEvent(
            id: trueId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: falseId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 6);

      engine.start();

      expect(engine.currentEvent?.id, trueId);
      expect(engine.status, StoryEngineStatus.terminated);
    });
  });

  group('Choice availability and selection', () {
    test('unavailable choices are hidden and cannot be selected', () {
      final flagId = StoryVariableId('var_flag');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: flagId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
        ],
      );
      final eventId = StoryEventId('evt_start');
      final hiddenChoiceId = StoryChoiceId('choice_hidden');
      final visibleChoiceId = StoryChoiceId('choice_visible');
      final project = StoryProject(
        id: StoryProjectId('project_choices'),
        stateSchema: schema,
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: hiddenChoiceId,
                availabilityCondition: StoryVariableComparisonCondition(
                  variableId: flagId,
                  operator: StoryComparisonOperator.equal,
                  value: const StoryBooleanValue(true),
                ),
                transition: const StoryTerminalTransition(),
              ),
              StoryChoice(
                id: visibleChoiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 8)..start();

      expect(
        engine.availableChoices.map((choice) => choice.id),
        [visibleChoiceId],
      );
      expect(
        () => engine.choose(hiddenChoiceId),
        throwsA(isA<StoryEngineOperationException>()),
      );
      expect(engine.status, StoryEngineStatus.awaitingChoice);
    });

    test('availableChoices is immutable', () {
      final eventId = StoryEventId('evt_start');
      final project = StoryProject(
        id: StoryProjectId('project_choice_list'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_end'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 9)..start();
      final choices = engine.availableChoices;

      expect(
        () => choices.add(
          StoryChoice(
            id: StoryChoiceId('choice_illegal'),
            transition: const StoryTerminalTransition(),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('Automatic flow and deterministic randomness', () {
    test('start resolves automatic chains until interactive content is reached', () {
      final firstId = StoryEventId('evt_first');
      final secondId = StoryEventId('evt_second');
      final thirdId = StoryEventId('evt_third');
      final choiceId = StoryChoiceId('choice_end');
      final project = StoryProject(
        id: StoryProjectId('project_auto_chain'),
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
              destinationEventId: thirdId,
            ),
          ),
          StoryEvent(
            id: thirdId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 10)..start();

      expect(engine.currentEvent?.id, thirdId);
      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(engine.availableChoices.single.id, choiceId);
    });

    test('same seed and authored weighted flow produce the same route', () {
      final startId = StoryEventId('evt_start');
      final aId = StoryEventId('evt_a');
      final bId = StoryEventId('evt_b');
      final choiceId = StoryChoiceId('choice_random');
      final project = StoryProject(
        id: StoryProjectId('project_seed'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryWeightedTransition(
                  options: [
                    StoryWeightedTransitionOption(
                      weight: 1,
                      transition: StoryEventTransition(destinationEventId: aId),
                    ),
                    StoryWeightedTransitionOption(
                      weight: 1,
                      transition: StoryEventTransition(destinationEventId: bId),
                    ),
                  ],
                ),
              ),
            ],
          ),
          StoryEvent(
            id: aId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: bId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final first = StoryEngine(project: project, randomSeed: 123456)..start();
      final second = StoryEngine(project: project, randomSeed: 123456)..start();

      first.choose(choiceId);
      second.choose(choiceId);

      expect(first.currentEvent?.id, second.currentEvent?.id);
      expect(first.status, second.status);
    });

    test('automatic cycle is guarded instead of hanging', () {
      final aId = StoryEventId('evt_a');
      final bId = StoryEventId('evt_b');
      final project = StoryProject(
        id: StoryProjectId('project_cycle'),
        entryEventId: aId,
        events: [
          StoryEvent(
            id: aId,
            automaticTransition: StoryEventTransition(destinationEventId: bId),
          ),
          StoryEvent(
            id: bId,
            automaticTransition: StoryEventTransition(destinationEventId: aId),
          ),
        ],
      );
      final engine = StoryEngine(
        project: project,
        randomSeed: 11,
        maxAutomaticTransitions: 4,
      );

      expect(
        engine.start,
        throwsA(isA<StoryEngineExecutionException>()),
      );
      expect(engine.status, StoryEngineStatus.notStarted);
      expect(engine.state, isNull);
      expect(engine.currentEvent, isNull);
    });
  });

  group('Runtime structural errors and transactional behavior', () {
    test('duplicate event IDs are rejected when preparing StoryEngine', () {
      final id = StoryEventId('evt_duplicate');
      final project = StoryProject(
        id: StoryProjectId('project_duplicate_event'),
        entryEventId: id,
        events: [
          StoryEvent(
            id: id,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: id,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(
        () => StoryEngine(project: project, randomSeed: 1),
        throwsA(isA<StoryEngineConfigurationException>()),
      );
    });

    test('choice IDs remain unique across the whole project', () {
      final duplicateChoiceId = StoryChoiceId('choice_duplicate');
      final aId = StoryEventId('evt_a');
      final bId = StoryEventId('evt_b');
      final project = StoryProject(
        id: StoryProjectId('project_duplicate_choice'),
        entryEventId: aId,
        events: [
          StoryEvent(
            id: aId,
            choices: [
              StoryChoice(
                id: duplicateChoiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
          StoryEvent(
            id: bId,
            choices: [
              StoryChoice(
                id: duplicateChoiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      expect(
        () => StoryEngine(project: project, randomSeed: 1),
        throwsA(isA<StoryEngineConfigurationException>()),
      );
    });

    test('missing entry point is an explicit start configuration error', () {
      final engine = StoryEngine(
        project: StoryProject(id: StoryProjectId('project_no_entry')),
        randomSeed: 1,
      );

      expect(
        engine.start,
        throwsA(isA<StoryEngineConfigurationException>()),
      );
      expect(engine.status, StoryEngineStatus.notStarted);
    });

    test('ambiguous and incomplete events are rejected when entered', () {
      final ambiguousId = StoryEventId('evt_ambiguous');
      final ambiguousProject = StoryProject(
        id: StoryProjectId('project_ambiguous'),
        entryEventId: ambiguousId,
        events: [
          StoryEvent(
            id: ambiguousId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_end'),
                transition: const StoryTerminalTransition(),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final incompleteId = StoryEventId('evt_incomplete');
      final incompleteProject = StoryProject(
        id: StoryProjectId('project_incomplete'),
        entryEventId: incompleteId,
        events: [StoryEvent(id: incompleteId)],
      );

      expect(
        () => StoryEngine(project: ambiguousProject, randomSeed: 1).start(),
        throwsA(isA<StoryEngineConfigurationException>()),
      );
      expect(
        () => StoryEngine(project: incompleteProject, randomSeed: 1).start(),
        throwsA(isA<StoryEngineConfigurationException>()),
      );
    });

    test('failed choice traversal does not commit scalar effects', () {
      final goldId = StoryVariableId('var_gold');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: goldId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(10),
          ),
        ],
      );
      final startId = StoryEventId('evt_start');
      final missingId = StoryEventId('evt_missing');
      final choiceId = StoryChoiceId('choice_broken');
      final project = StoryProject(
        id: StoryProjectId('project_transaction'),
        stateSchema: schema,
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: choiceId,
                effects: [
                  StoryIncrementVariableEffect(
                    variableId: goldId,
                    amount: StoryIntegerValue(5),
                  ),
                ],
                transition: StoryEventTransition(
                  destinationEventId: missingId,
                ),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 12)..start();
      final before = engine.state;

      expect(
        () => engine.choose(choiceId),
        throwsA(isA<StoryEngineConfigurationException>()),
      );

      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(engine.currentEvent?.id, startId);
      expect(engine.state, same(before));
      expect(engine.state?.valueOf(goldId), StoryIntegerValue(10));
    });

    test('event availability failure rolls back the whole choose operation', () {
      final flagId = StoryVariableId('var_flag');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: flagId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
        ],
      );
      final startId = StoryEventId('evt_start');
      final guardedId = StoryEventId('evt_guarded');
      final choiceId = StoryChoiceId('choice_enter');
      final project = StoryProject(
        id: StoryProjectId('project_event_guard'),
        stateSchema: schema,
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: choiceId,
                effects: [
                  StorySetVariableEffect(
                    variableId: flagId,
                    value: const StoryBooleanValue(true),
                  ),
                ],
                transition: StoryEventTransition(
                  destinationEventId: guardedId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: guardedId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: flagId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(false),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 13)..start();

      expect(
        () => engine.choose(choiceId),
        throwsA(isA<StoryEngineExecutionException>()),
      );
      expect(
        engine.state?.valueOf(flagId),
        const StoryBooleanValue(false),
      );
      expect(engine.currentEvent?.id, startId);
      expect(engine.status, StoryEngineStatus.awaitingChoice);
    });
  });

  group('Authored runtime model immutability', () {
    test('project events, event choices/effects, and choice effects are copied', () {
      final choiceEffects = <StoryEffect>[];
      final choices = <StoryChoice>[
        StoryChoice(
          id: StoryChoiceId('choice_end'),
          effects: choiceEffects,
          transition: const StoryTerminalTransition(),
        ),
      ];
      final entryEffects = <StoryEffect>[];
      final event = StoryEvent(
        id: StoryEventId('evt_start'),
        entryEffects: entryEffects,
        choices: choices,
      );
      final events = <StoryEvent>[event];
      final project = StoryProject(
        id: StoryProjectId('project_immutable'),
        events: events,
        entryEventId: event.id,
      );

      choices.clear();
      entryEffects.add(
        StorySetVariableEffect(
          variableId: StoryVariableId('var_unused'),
          value: const StoryBooleanValue(true),
        ),
      );
      choiceEffects.add(
        StoryUnsetVariableEffect(variableId: StoryVariableId('var_unused')),
      );
      events.clear();

      expect(project.events, [event]);
      expect(event.choices, hasLength(1));
      expect(event.entryEffects, isEmpty);
      expect(event.choices.single.effects, isEmpty);
      expect(() => event.choices.clear(), throwsUnsupportedError);
      expect(() => project.events.clear(), throwsUnsupportedError);
    });
  });

  test('random seed is constrained to one explicit 32-bit seed', () {
    final project = StoryProject(id: StoryProjectId('project_seed_bounds'));

    expect(
      () => StoryEngine(project: project, randomSeed: -1),
      throwsArgumentError,
    );
    expect(
      () => StoryEngine(project: project, randomSeed: 4294967296),
      throwsArgumentError,
    );
    expect(
      StoryEngine(project: project, randomSeed: 4294967295).randomSeed,
      4294967295,
    );
  });
}
