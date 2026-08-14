import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeSnapshotValidator', () {
    const validator = StoryRuntimeSnapshotValidator();

    test('accepts a compatible awaiting-choice snapshot', () {
      final fixture = _interactiveFixture();

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: fixture.project,
        ),
        returnsNormally,
      );
    });

    test('project aliases do not affect runtime schema compatibility', () {
      final fixture = _interactiveFixture(variableAlias: StoryAlias('before'));
      final renamed = _interactiveFixture(variableAlias: StoryAlias('after'));

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: renamed.project,
        ),
        returnsNormally,
      );
    });

    test('state compatibility ignores authored variable ordering', () {
      final firstId = StoryVariableId('var_first');
      final secondId = StoryVariableId('var_second');
      final oldSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: firstId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(1),
          ),
          StoryVariableDefinition(
            id: secondId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(true),
          ),
        ],
      );
      final currentSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: secondId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
          StoryVariableDefinition(
            id: firstId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(99),
          ),
        ],
      );
      final eventId = StoryEventId('event_schema_order');
      final choiceId = StoryChoiceId('choice_schema_order_finish');
      final project = StoryProject(
        id: StoryProjectId('project_schema_order'),
        stateSchema: currentSchema,
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
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.fromValues(
          schema: oldSchema,
          values: {
            firstId: StoryIntegerValue(7),
            secondId: const StoryBooleanValue(true),
          },
        ),
        currentEventId: eventId,
        history: StoryRuntimeHistory(
          steps: [StoryEventEnteredStep(eventId: eventId)],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(
        () => validator.validate(snapshot: snapshot, project: project),
        returnsNormally,
      );
    });

    test('direct state compatibility still rejects removed set variables', () {
      final removedId = StoryVariableId('var_removed');
      final oldSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(id: removedId, type: StoryValueType.integer),
        ],
      );
      final eventId = StoryEventId('event_removed_state');
      final project = StoryProject(
        id: StoryProjectId('project_removed_state'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_removed_state_finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.fromValues(
          schema: oldSchema,
          values: {removedId: StoryIntegerValue(7)},
        ),
        currentEventId: eventId,
        history: StoryRuntimeHistory(
          steps: [StoryEventEnteredStep(eventId: eventId)],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(
        () => validator.validate(snapshot: snapshot, project: project),
        throwsA(
          _issue(StoryRuntimeSnapshotCompatibilityIssue.stateSchemaMismatch),
        ),
      );
    });

    test('rejects a missing persisted current event', () {
      final fixture = _interactiveFixture();
      final changedProject = StoryProject(
        id: fixture.project.id,
        stateSchema: fixture.project.stateSchema,
        entryEventId: StoryEventId('event_other'),
        events: [
          StoryEvent(
            id: StoryEventId('event_other'),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(
        () => validator.validate(
          snapshot: fixture.snapshot,
          project: changedProject,
        ),
        throwsA(_issue(StoryRuntimeSnapshotCompatibilityIssue.missingEvent)),
      );
    });

    test('rejects history actions that do not follow their entered event', () {
      final fixture = _interactiveFixture();
      final wrongEvent = StoryEventId('event_wrong');
      final malformed = StoryRuntimeSnapshot(
        projectId: fixture.snapshot.projectId,
        status: StoryEngineStatus.awaitingChoice,
        state: fixture.snapshot.state,
        currentEventId: fixture.snapshot.currentEventId,
        history: StoryRuntimeHistory(
          steps: [
            StoryEventEnteredStep(eventId: fixture.snapshot.currentEventId!),
            StoryChoiceSelectedStep(
              eventId: wrongEvent,
              choiceId: fixture.choiceId,
            ),
            StoryEventEnteredStep(eventId: fixture.snapshot.currentEventId!),
          ],
        ),
        randomState: fixture.snapshot.randomState,
        maxAutomaticTransitions: fixture.snapshot.maxAutomaticTransitions,
      );

      expect(
        () => validator.validate(snapshot: malformed, project: fixture.project),
        throwsA(
          _issue(StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence),
        ),
      );
    });

    test('non-terminated history cannot end immediately after an action', () {
      final fixture = _interactiveFixture();
      final malformed = StoryRuntimeSnapshot(
        projectId: fixture.snapshot.projectId,
        status: StoryEngineStatus.awaitingChoice,
        state: fixture.snapshot.state,
        currentEventId: fixture.snapshot.currentEventId,
        history: StoryRuntimeHistory(
          steps: [
            StoryEventEnteredStep(eventId: fixture.snapshot.currentEventId!),
            StoryChoiceSelectedStep(
              eventId: fixture.snapshot.currentEventId!,
              choiceId: fixture.choiceId,
            ),
          ],
        ),
        randomState: fixture.snapshot.randomState,
        maxAutomaticTransitions: fixture.snapshot.maxAutomaticTransitions,
      );

      expect(
        () => validator.validate(snapshot: malformed, project: fixture.project),
        throwsA(
          _issue(StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence),
        ),
      );
    });

    test(
      'rejects persisted choice identity no longer owned by source event',
      () {
        final fixture = _interactiveFixture(includeSelectedChoice: true);
        final changedChoiceId = StoryChoiceId('choice_changed');
        final changed = StoryProject(
          id: fixture.project.id,
          stateSchema: fixture.project.stateSchema,
          entryEventId: fixture.snapshot.currentEventId,
          events: [
            StoryEvent(
              id: fixture.snapshot.currentEventId!,
              choices: [
                StoryChoice(
                  id: changedChoiceId,
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        );

        expect(
          () =>
              validator.validate(snapshot: fixture.snapshot, project: changed),
          throwsA(_issue(StoryRuntimeSnapshotCompatibilityIssue.missingChoice)),
        );
      },
    );

    test(
      'awaitingContinue requires a continuation event in current project',
      () {
        final eventId = StoryEventId('event_pause');
        final project = StoryProject(
          id: StoryProjectId('project_pause'),
          entryEventId: eventId,
          events: [
            StoryEvent(
              id: eventId,
              choices: [
                StoryChoice(
                  id: StoryChoiceId('choice_finish'),
                  transition: const StoryTerminalTransition(),
                ),
              ],
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
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        );

        expect(
          () => validator.validate(snapshot: snapshot, project: project),
          throwsA(
            _issue(
              StoryRuntimeSnapshotCompatibilityIssue.statusEventModeMismatch,
            ),
          ),
        );
      },
    );

    test('history must begin at the supplied project entry event', () {
      final entryId = StoryEventId('event_entry');
      final otherId = StoryEventId('event_other');
      final choiceId = StoryChoiceId('choice_finish');
      final project = StoryProject(
        id: StoryProjectId('project_entry_history'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
          StoryEvent(
            id: otherId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_other_finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.initial(project.stateSchema),
        currentEventId: otherId,
        history: StoryRuntimeHistory(
          steps: [StoryEventEnteredStep(eventId: otherId)],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(
        () => validator.validate(snapshot: snapshot, project: project),
        throwsA(
          _issue(
            StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          ),
        ),
      );
    });

    test('history cannot jump to an event outside the selected transition', () {
      final entryId = StoryEventId('event_jump_entry');
      final expectedId = StoryEventId('event_expected');
      final forgedId = StoryEventId('event_forged');
      final choiceId = StoryChoiceId('choice_to_expected');
      final project = StoryProject(
        id: StoryProjectId('project_choice_jump'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryEventTransition(
                  destinationEventId: expectedId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: expectedId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: forgedId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_forged_finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.initial(project.stateSchema),
        currentEventId: forgedId,
        history: StoryRuntimeHistory(
          steps: [
            StoryEventEnteredStep(eventId: entryId),
            StoryChoiceSelectedStep(eventId: entryId, choiceId: choiceId),
            StoryEventEnteredStep(eventId: forgedId),
          ],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(
        () => validator.validate(snapshot: snapshot, project: project),
        throwsA(
          _issue(
            StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          ),
        ),
      );
    });

    test('automatic history cannot jump outside its authored transition', () {
      final entryId = StoryEventId('event_auto_entry');
      final expectedId = StoryEventId('event_auto_expected');
      final forgedId = StoryEventId('event_auto_forged');
      final project = StoryProject(
        id: StoryProjectId('project_auto_jump'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            automaticTransition: StoryEventTransition(
              destinationEventId: expectedId,
            ),
          ),
          StoryEvent(
            id: expectedId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: forgedId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_auto_forged_finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.initial(project.stateSchema),
        currentEventId: forgedId,
        history: StoryRuntimeHistory(
          steps: [
            StoryEventEnteredStep(eventId: entryId),
            StoryEventEnteredStep(eventId: forgedId),
          ],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(
        () => validator.validate(snapshot: snapshot, project: project),
        throwsA(
          _issue(
            StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          ),
        ),
      );
    });

    test(
      'terminated status requires a structurally terminal final transition',
      () {
        final entryId = StoryEventId('event_nonterminal_entry');
        final nextId = StoryEventId('event_nonterminal_next');
        final choiceId = StoryChoiceId('choice_nonterminal');
        final project = StoryProject(
          id: StoryProjectId('project_false_termination'),
          entryEventId: entryId,
          events: [
            StoryEvent(
              id: entryId,
              choices: [
                StoryChoice(
                  id: choiceId,
                  transition: StoryEventTransition(destinationEventId: nextId),
                ),
              ],
            ),
            StoryEvent(
              id: nextId,
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final snapshot = StoryRuntimeSnapshot(
          projectId: project.id,
          status: StoryEngineStatus.terminated,
          state: StoryState.initial(project.stateSchema),
          currentEventId: entryId,
          history: StoryRuntimeHistory(
            steps: [
              StoryEventEnteredStep(eventId: entryId),
              StoryChoiceSelectedStep(eventId: entryId, choiceId: choiceId),
            ],
          ),
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        );

        expect(
          () => validator.validate(snapshot: snapshot, project: project),
          throwsA(
            _issue(
              StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
            ),
          ),
        );
      },
    );

    test(
      'terminated interactive event without its terminal action is rejected',
      () {
        final fixture = _interactiveFixture();
        final snapshot = StoryRuntimeSnapshot(
          projectId: fixture.snapshot.projectId,
          status: StoryEngineStatus.terminated,
          state: fixture.snapshot.state,
          currentEventId: fixture.snapshot.currentEventId,
          history: fixture.snapshot.history,
          randomState: fixture.snapshot.randomState,
          maxAutomaticTransitions: fixture.snapshot.maxAutomaticTransitions,
        );

        expect(
          () =>
              validator.validate(snapshot: snapshot, project: fixture.project),
          throwsA(
            _issue(
              StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
            ),
          ),
        );
      },
    );

    test(
      'nested transition trees are validated conservatively, not replayed',
      () {
        final entryId = StoryEventId('event_weighted_entry');
        final nextId = StoryEventId('event_weighted_next');
        final flagId = StoryVariableId('var_weighted_flag');
        final schema = StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: flagId,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(true),
            ),
          ],
        );
        final project = StoryProject(
          id: StoryProjectId('project_weighted_history'),
          stateSchema: schema,
          entryEventId: entryId,
          events: [
            StoryEvent(
              id: entryId,
              automaticTransition: StoryWeightedTransition(
                options: [
                  StoryWeightedTransitionOption(
                    weight: 1,
                    transition: const StoryTerminalTransition(),
                  ),
                  StoryWeightedTransitionOption(
                    weight: 1,
                    transition: StoryConditionalTransition(
                      branches: [
                        StoryConditionalTransitionBranch(
                          condition: StoryVariableIsSetCondition(
                            variableId: flagId,
                          ),
                          transition: StoryEventTransition(
                            destinationEventId: nextId,
                          ),
                        ),
                      ],
                      fallback: const StoryTerminalTransition(),
                    ),
                  ),
                ],
              ),
            ),
            StoryEvent(
              id: nextId,
              choices: [
                StoryChoice(
                  id: StoryChoiceId('choice_weighted_finish'),
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        );

        final enteredNext = StoryRuntimeSnapshot(
          projectId: project.id,
          status: StoryEngineStatus.awaitingChoice,
          state: StoryState.initial(schema),
          currentEventId: nextId,
          history: StoryRuntimeHistory(
            steps: [
              StoryEventEnteredStep(eventId: entryId),
              StoryEventEnteredStep(eventId: nextId),
            ],
          ),
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        );
        final terminatedAtEntry = StoryRuntimeSnapshot(
          projectId: project.id,
          status: StoryEngineStatus.terminated,
          state: StoryState.initial(project.stateSchema),
          currentEventId: entryId,
          history: StoryRuntimeHistory(
            steps: [StoryEventEnteredStep(eventId: entryId)],
          ),
          randomState: _randomState(),
          maxAutomaticTransitions: 10,
        );

        expect(
          () => validator.validate(snapshot: enteredNext, project: project),
          returnsNormally,
        );
        expect(
          () =>
              validator.validate(snapshot: terminatedAtEntry, project: project),
          returnsNormally,
        );
      },
    );

    test('terminated snapshots do not require a host-visible event mode', () {
      final eventId = StoryEventId('event_auto_terminal');
      final project = StoryProject(
        id: StoryProjectId('project_terminated'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.terminated,
        state: StoryState.initial(project.stateSchema),
        currentEventId: eventId,
        history: StoryRuntimeHistory(
          steps: [StoryEventEnteredStep(eventId: eventId)],
        ),
        randomState: _randomState(),
        maxAutomaticTransitions: 10,
      );

      expect(
        () => validator.validate(snapshot: snapshot, project: project),
        returnsNormally,
      );
    });
  });
}

Matcher _issue(StoryRuntimeSnapshotCompatibilityIssue issue) =>
    isA<StoryRuntimeSnapshotCompatibilityException>().having(
      (error) => error.issue,
      'issue',
      issue,
    );

({StoryProject project, StoryRuntimeSnapshot snapshot, StoryChoiceId choiceId})
_interactiveFixture({
  StoryAlias? variableAlias,
  bool includeSelectedChoice = false,
}) {
  final variableId = StoryVariableId('var_score');
  final eventId = StoryEventId('event_choice');
  final choiceId = StoryChoiceId('choice_finish');
  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: variableId,
        alias: variableAlias,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(1),
      ),
    ],
  );
  final project = StoryProject(
    id: StoryProjectId('project_interactive_snapshot'),
    stateSchema: schema,
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
  final steps = <StoryRuntimeStep>[StoryEventEnteredStep(eventId: eventId)];
  if (includeSelectedChoice) {
    steps.add(StoryChoiceSelectedStep(eventId: eventId, choiceId: choiceId));
  }
  return (
    project: project,
    snapshot: StoryRuntimeSnapshot(
      projectId: project.id,
      status: includeSelectedChoice
          ? StoryEngineStatus.terminated
          : StoryEngineStatus.awaitingChoice,
      state: StoryState.initial(schema),
      currentEventId: eventId,
      history: StoryRuntimeHistory(steps: steps),
      randomState: _randomState(),
      maxAutomaticTransitions: 10,
    ),
    choiceId: choiceId,
  );
}

StoryRuntimeRandomState _randomState() => StoryRuntimeRandomState(
  algorithmId: 'story_engine.lcg32',
  algorithmVersion: 1,
  stateWords: const [17, 17],
);
