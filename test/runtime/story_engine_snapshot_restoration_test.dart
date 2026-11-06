import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryEngine runtime snapshot capture/restoration', () {
    test(
      'captures and restores notStarted without consuming runtime state',
      () {
        final eventId = StoryEventId('event_before_start');
        final choiceId = StoryChoiceId('choice_finish');
        final project = StoryProject(
          id: StoryProjectId('project_before_start_restore'),
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
        final engine = StoryEngine(
          project: project,
          randomSeed: 17,
          maxAutomaticTransitions: 23,
        );

        final snapshot = engine.createSnapshot();
        final restored = StoryEngine.restore(
          project: project,
          snapshot: snapshot,
        );

        expect(restored.status, StoryEngineStatus.notStarted);
        expect(restored.state, isNull);
        expect(restored.currentEvent, isNull);
        expect(restored.history.isEmpty, isTrue);
        expect(restored.randomSeed, 17);
        expect(restored.maxAutomaticTransitions, 23);
        expect(restored.createSnapshot(), snapshot);

        restored.start();
        expect(restored.status, StoryEngineStatus.awaitingChoice);
        expect(restored.currentEvent?.id, eventId);
        expect(restored.availableChoices.single.id, choiceId);
      },
    );

    test('restores awaitingChoice state, history, and available choices', () {
      final scoreId = StoryVariableId('var_restore_score');
      final eventId = StoryEventId('event_restore_choice');
      final choiceId = StoryChoiceId('choice_restore_finish');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: scoreId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(1),
          ),
        ],
      );
      final project = StoryProject(
        id: StoryProjectId('project_awaiting_choice_restore'),
        stateSchema: schema,
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: scoreId,
                amount: StoryIntegerValue(1),
              ),
            ],
            choices: [
              StoryChoice(
                id: choiceId,
                availabilityCondition: StoryVariableComparisonCondition(
                  variableId: scoreId,
                  operator: StoryComparisonOperator.equal,
                  value: StoryIntegerValue(2),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 29)..start();

      final snapshot = engine.createSnapshot();
      final encoded = StoryRuntimeSnapshotCodec().encode(snapshot);
      final decoded = StoryRuntimeSnapshotCodec().decode(
        encoded,
        project: project,
      );
      final restored = StoryEngine.restore(project: project, snapshot: decoded);

      expect(restored.status, StoryEngineStatus.awaitingChoice);
      expect(restored.currentEvent?.id, eventId);
      expect(restored.state?.valueOf(scoreId), StoryIntegerValue(2));
      expect(restored.history, engine.history);
      expect(restored.availableChoices.single.id, choiceId);

      // Entry effects must not be replayed during restore.
      expect(restored.state?.valueOf(scoreId), isNot(StoryIntegerValue(3)));

      restored.choose(choiceId);
      expect(restored.status, StoryEngineStatus.terminated);
      expect(restored.state?.valueOf(scoreId), StoryIntegerValue(2));
    });

    test('awaitingContinue restore remains paused until continueStory', () {
      final pauseId = StoryEventId('event_restore_pause');
      final nextId = StoryEventId('event_restore_after_pause');
      final finishId = StoryChoiceId('choice_after_restore_continue');
      final project = StoryProject(
        id: StoryProjectId('project_awaiting_continue_restore'),
        entryEventId: pauseId,
        events: [
          StoryEvent(
            id: pauseId,
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
      final engine = StoryEngine(project: project, randomSeed: 31)..start();
      final snapshot = engine.createSnapshot();

      final restored = StoryEngine.restore(
        project: project,
        snapshot: snapshot,
      );

      expect(restored.status, StoryEngineStatus.awaitingContinue);
      expect(restored.currentEvent?.id, pauseId);
      expect(restored.availableChoices, isEmpty);
      expect(restored.history.steps, [StoryEventEnteredStep(eventId: pauseId)]);

      // Restore itself must not traverse the continuation.
      expect(restored.currentEvent?.id, isNot(nextId));

      restored.continueStory();
      expect(restored.status, StoryEngineStatus.awaitingChoice);
      expect(restored.currentEvent?.id, nextId);
      expect(restored.availableChoices.single.id, finishId);
      expect(restored.history.steps, [
        StoryEventEnteredStep(eventId: pauseId),
        StoryEventContinuedStep(eventId: pauseId),
        StoryEventEnteredStep(eventId: nextId),
      ]);
    });

    test(
      'restores repeated self-loop history without deriving parallel state',
      () {
        final loopId = StoryEventId('event_restore_loop');
        final loopChoiceId = StoryChoiceId('choice_restore_loop');
        final finishChoiceId = StoryChoiceId('choice_restore_loop_finish');
        final project = StoryProject(
          id: StoryProjectId('project_loop_restore'),
          entryEventId: loopId,
          events: [
            StoryEvent(
              id: loopId,
              choices: [
                StoryChoice(
                  id: loopChoiceId,
                  transition: StoryEventTransition(destinationEventId: loopId),
                ),
                StoryChoice(
                  id: finishChoiceId,
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        );
        final engine = StoryEngine(project: project, randomSeed: 37)..start();
        engine
          ..choose(loopChoiceId)
          ..choose(loopChoiceId);

        final snapshot = engine.createSnapshot();
        final restored = StoryEngine.restore(
          project: project,
          snapshot: snapshot,
        );

        expect(restored.currentEvent?.id, loopId);
        expect(restored.history.eventRoute, [loopId, loopId, loopId]);
        expect(restored.history.eventOccurrenceCount(loopId), 3);
        expect(restored.history.selectedChoiceIds, [
          loopChoiceId,
          loopChoiceId,
        ]);
        expect(restored.createSnapshot(), snapshot);

        restored.choose(finishChoiceId);
        expect(restored.status, StoryEngineStatus.terminated);
      },
    );

    test('restores state after automatic traversal without replaying it', () {
      final countId = StoryVariableId('var_restore_auto_count');
      final firstId = StoryEventId('event_restore_auto_first');
      final secondId = StoryEventId('event_restore_auto_second');
      final pauseId = StoryEventId('event_restore_auto_pause');
      final finishId = StoryChoiceId('choice_restore_auto_finish');
      final schema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: countId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(0),
          ),
        ],
      );
      StoryIncrementVariableEffect increment() => StoryIncrementVariableEffect(
        variableId: countId,
        amount: StoryIntegerValue(1),
      );
      final project = StoryProject(
        id: StoryProjectId('project_automatic_restore'),
        stateSchema: schema,
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            entryEffects: [increment()],
            automaticTransition: StoryEventTransition(
              destinationEventId: secondId,
            ),
          ),
          StoryEvent(
            id: secondId,
            entryEffects: [increment()],
            automaticTransition: StoryEventTransition(
              destinationEventId: pauseId,
            ),
          ),
          StoryEvent(
            id: pauseId,
            entryEffects: [increment()],
            choices: [
              StoryChoice(
                id: finishId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project, randomSeed: 41)..start();
      final snapshot = engine.createSnapshot();

      final restored = StoryEngine.restore(
        project: project,
        snapshot: snapshot,
      );

      expect(restored.status, StoryEngineStatus.awaitingChoice);
      expect(restored.currentEvent?.id, pauseId);
      expect(restored.history.eventRoute, [firstId, secondId, pauseId]);
      expect(restored.state?.valueOf(countId), StoryIntegerValue(3));

      // Replaying automatic traversal during restore would increment again.
      expect(restored.state?.valueOf(countId), isNot(StoryIntegerValue(6)));
    });

    test(
      'terminated restore stays terminated with exact committed history',
      () {
        final eventId = StoryEventId('event_restore_terminated');
        final choiceId = StoryChoiceId('choice_restore_terminated');
        final project = StoryProject(
          id: StoryProjectId('project_terminated_restore'),
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
        final engine = StoryEngine(project: project, randomSeed: 43)..start();
        engine.choose(choiceId);
        final snapshot = engine.createSnapshot();

        final restored = StoryEngine.restore(
          project: project,
          snapshot: snapshot,
        );

        expect(restored.status, StoryEngineStatus.terminated);
        expect(restored.currentEvent?.id, eventId);
        expect(restored.history, engine.history);
        expect(restored.createSnapshot(), snapshot);
        expect(
          () => restored.choose(choiceId),
          throwsA(isA<StoryEngineOperationException>()),
        );
        expect(
          restored.continueStory,
          throwsA(isA<StoryEngineOperationException>()),
        );
      },
    );

    test(
      'snapshot capture exposes only committed state after failed operation',
      () {
        final eventId = StoryEventId('event_restore_transaction');
        final missingId = StoryEventId('event_restore_missing');
        final choiceId = StoryChoiceId('choice_restore_failed');
        final project = StoryProject(
          id: StoryProjectId('project_snapshot_transaction_boundary'),
          entryEventId: eventId,
          events: [
            StoryEvent(
              id: eventId,
              choices: [
                StoryChoice(
                  id: choiceId,
                  transition: StoryEventTransition(
                    destinationEventId: missingId,
                  ),
                ),
              ],
            ),
          ],
        );
        final engine = StoryEngine(project: project, randomSeed: 47)..start();
        final before = engine.createSnapshot();

        expect(
          () => engine.choose(choiceId),
          throwsA(isA<StoryEngineConfigurationException>()),
        );

        expect(engine.createSnapshot(), before);
      },
    );

    test(
      'restore rebinds compatible state values to the supplied project schema',
      () {
        final variableId = StoryVariableId('var_restore_alias_rebind');
        final eventId = StoryEventId('event_restore_alias_rebind');
        final choiceId = StoryChoiceId('choice_restore_alias_rebind');
        StoryProject buildProject(StoryAlias alias) {
          final schema = StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: variableId,
                alias: alias,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(4),
              ),
            ],
          );
          return StoryProject(
            id: StoryProjectId('project_restore_alias_rebind'),
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
        }

        final original = buildProject(StoryAlias('old_alias'));
        final renamed = buildProject(StoryAlias('new_alias'));
        final snapshot = (StoryEngine(
          project: original,
          randomSeed: 51,
        )..start()).createSnapshot();

        final restored = StoryEngine.restore(
          project: renamed,
          snapshot: snapshot,
        );

        expect(restored.state?.schema, renamed.stateSchema);
        expect(restored.state?.valueOf(variableId), StoryIntegerValue(4));
        expect(restored.currentEvent, same(renamed.events.single));
      },
    );

    test('restore rejects unsupported and malformed RNG envelopes', () {
      final eventId = StoryEventId('event_restore_rng_contract');
      final project = StoryProject(
        id: StoryProjectId('project_restore_rng_contract'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final valid = StoryEngine(
        project: project,
        randomSeed: 53,
      ).createSnapshot();

      expect(
        () => StoryEngine.restore(
          project: project,
          snapshot: _withRandomState(
            valid,
            StoryRuntimeRandomState(
              algorithmId: 'story_engine.other_rng',
              algorithmVersion: 1,
              stateWords: const [53, 53],
            ),
          ),
        ),
        throwsA(
          _compatibilityIssue(
            StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithm,
          ),
        ),
      );

      expect(
        () => StoryEngine.restore(
          project: project,
          snapshot: _withRandomState(
            valid,
            StoryRuntimeRandomState(
              algorithmId: valid.randomState.algorithmId,
              algorithmVersion: 999,
              stateWords: const [53, 53],
            ),
          ),
        ),
        throwsA(
          _compatibilityIssue(
            StoryRuntimeSnapshotCompatibilityIssue
                .unsupportedRandomAlgorithmVersion,
          ),
        ),
      );

      expect(
        () => StoryEngine.restore(
          project: project,
          snapshot: _withRandomState(
            valid,
            StoryRuntimeRandomState(
              algorithmId: valid.randomState.algorithmId,
              algorithmVersion: valid.randomState.algorithmVersion,
              stateWords: const [53],
            ),
          ),
        ),
        throwsA(
          _compatibilityIssue(
            StoryRuntimeSnapshotCompatibilityIssue.invalidRandomState,
          ),
        ),
      );
    });
  });
}

StoryRuntimeSnapshot _withRandomState(
  StoryRuntimeSnapshot snapshot,
  StoryRuntimeRandomState randomState,
) => StoryRuntimeSnapshot(
  metadata: snapshot.metadata,
  projectId: snapshot.projectId,
  status: snapshot.status,
  state: snapshot.state,
  currentEventId: snapshot.currentEventId,
  history: snapshot.history,
  randomState: randomState,
  maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
);

Matcher _compatibilityIssue(StoryRuntimeSnapshotCompatibilityIssue issue) =>
    isA<StoryRuntimeSnapshotCompatibilityException>().having(
      (error) => error.issue,
      'issue',
      issue,
    );
