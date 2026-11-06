import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/orchestration/story_narrative_runtime.dart'
    as internal_runtime;
import 'package:story_engine/src/runtime/story_engine.dart' as internal_engine;
import 'package:test/test.dart';

void main() {
  group('Stage 9D5 rollback behavior', () {
    test(
      'lazy mutation checkpoint reconstructs exact pre-operation snapshot',
      () {
        final scoreId = StoryVariableId('stage9d5_checkpoint_score');
        final startId = StoryEventId('stage9d5_checkpoint_start');
        final choiceId = StoryChoiceId('stage9d5_checkpoint_choice');
        final project = StoryProject(
          id: StoryProjectId('stage9d5_checkpoint_project'),
          stateSchema: StoryStateSchema(
            variables: <StoryVariableDefinition>[
              StoryVariableDefinition(
                id: scoreId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(0),
              ),
            ],
          ),
          events: <StoryEvent>[
            StoryEvent(
              id: startId,
              choices: <StoryChoice>[
                StoryChoice(
                  id: choiceId,
                  effects: <StoryEffect>[
                    StoryIncrementVariableEffect(
                      variableId: scoreId,
                      amount: StoryIntegerValue(1),
                    ),
                  ],
                  transition: StoryWeightedTransition(
                    options: <StoryWeightedTransitionOption>[
                      StoryWeightedTransitionOption(
                        weight: 1,
                        transition: const StoryTerminalTransition(),
                      ),
                      StoryWeightedTransitionOption(
                        weight: 3,
                        transition: const StoryTerminalTransition(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          entryEventId: startId,
        );
        final engine = StoryEngine(project: project, randomSeed: 0x9d5a)
          ..start();
        final before = engine.createSnapshot();
        final checkpoint = internal_engine.captureStoryEngineMutationCheckpoint(
          engine,
        );

        engine.choose(choiceId);
        final committed = engine.createSnapshot();
        expect(committed, isNot(before));
        expect(committed.state!.rawValueOf(scoreId), 1);
        expect(committed.status, StoryEngineStatus.terminated);

        final reconstructed = internal_engine
            .materializeStoryEngineMutationCheckpoint(engine, checkpoint);
        expect(reconstructed, before);

        final restored = StoryEngine.restore(
          project: project,
          snapshot: reconstructed,
        )..choose(choiceId);
        expect(
          restored.createSnapshot(),
          committed,
          reason:
              'Checkpoint reconstruction must preserve the exact RNG state '
              'needed for deterministic continuation.',
        );
      },
    );

    test(
      'failed core mutation leaves a previously captured checkpoint valid',
      () {
        final eventId = StoryEventId('stage9d5_failed_checkpoint_event');
        final choiceId = StoryChoiceId('stage9d5_failed_checkpoint_choice');
        final project = StoryProject(
          id: StoryProjectId('stage9d5_failed_checkpoint_project'),
          events: <StoryEvent>[
            StoryEvent(
              id: eventId,
              choices: <StoryChoice>[
                StoryChoice(
                  id: choiceId,
                  transition: StoryEventTransition(destinationEventId: eventId),
                ),
              ],
            ),
          ],
          entryEventId: eventId,
        );
        final engine = StoryEngine(project: project)..start();
        final before = engine.createSnapshot();
        final checkpoint = internal_engine.captureStoryEngineMutationCheckpoint(
          engine,
        );

        expect(
          () => engine.choose(StoryChoiceId('stage9d5_missing_choice')),
          throwsA(isA<StoryEngineOperationException>()),
        );
        expect(engine.createSnapshot(), before);
        expect(
          internal_engine.materializeStoryEngineMutationCheckpoint(
            engine,
            checkpoint,
          ),
          before,
        );
      },
    );

    test(
      'failed sibling propagation restores source and leaves authority atomic',
      () {
        final valueId = StoryVariableId('stage9d5_rollback_value');
        final eventId = StoryEventId('stage9d5_rollback_event');
        final mutateChoiceId = StoryChoiceId('stage9d5_rollback_mutate');
        final loopChoiceId = StoryChoiceId('stage9d5_rollback_loop');
        final entryPointId = StoryEntryPointId('stage9d5_rollback_entry');
        final project = StoryProject(
          id: StoryProjectId('stage9d5_rollback_project'),
          stateSchema: StoryStateSchema(
            variables: <StoryVariableDefinition>[
              StoryVariableDefinition(
                id: valueId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(0),
              ),
            ],
          ),
          events: <StoryEvent>[
            StoryEvent(
              id: eventId,
              choices: <StoryChoice>[
                StoryChoice(
                  id: mutateChoiceId,
                  effects: <StoryEffect>[
                    StoryIncrementVariableEffect(
                      variableId: valueId,
                      amount: StoryIntegerValue(1),
                    ),
                  ],
                  transition: StoryEventTransition(destinationEventId: eventId),
                ),
                StoryChoice(
                  id: loopChoiceId,
                  transition: StoryEventTransition(destinationEventId: eventId),
                ),
              ],
            ),
          ],
        );
        final entryPoint = StoryEntryPoint(id: entryPointId, eventId: eventId);
        final runtime = internal_runtime
            .createStoryNarrativeRuntimeForStage9d5Benchmark(
              project: project,
              entryPoints: <StoryEntryPoint>[entryPoint],
              historyStrategy: internal_runtime
                  .StoryNarrativeRuntimeHistoryStrategy
                  .lazyIndexed,
            );
        final source = runtime.startSession(entryPointId);
        runtime.startSession(entryPointId);
        source.choose(loopChoiceId);
        final before = runtime.createSnapshot();

        internal_runtime
            .installMismatchedProjectPreparationForStage9d5RollbackTest(
              runtime,
              StoryProject(id: StoryProjectId('stage9d5_other_project')),
            );

        expect(() => source.choose(mutateChoiceId), throwsArgumentError);
        expect(runtime.persistentStateRevision, 0);
        expect(runtime.persistentState.rawValueOf(valueId), 0);
        final snapshotCodec = StoryNarrativeRuntimeSnapshotCodec();
        expect(
          snapshotCodec.encodeJson(runtime.createSnapshot()),
          snapshotCodec.encodeJson(before),
          reason:
              'A failed sibling preparation must restore the source and '
              'leave every sibling plus shared authority unchanged.',
        );
      },
    );

    test(
      'production selective rollback restores exact runtime after a later sibling preparation failure',
      () {
        final fixture = _stage9d6bFixture();
        final runtime = StoryNarrativeRuntime(
          project: fixture.project,
          entryPoints: <StoryEntryPoint>[fixture.entryPoint],
          randomSeed: 0x9d6b,
        );
        final source = runtime.startSession(fixture.entryPoint.id);
        final siblingA = runtime.startSession(fixture.entryPoint.id);
        final siblingB = runtime.startSession(fixture.entryPoint.id);

        _primeStage9d6bSessions(
          source: source,
          siblingA: siblingA,
          siblingB: siblingB,
          loopChoiceId: fixture.loopChoiceId,
        );

        final beforeAggregate = runtime.createSnapshot();
        final beforeSource = source.createSnapshot().runtimeSnapshot;
        final beforeSiblingA = siblingA.createSnapshot().runtimeSnapshot;
        final beforeSiblingB = siblingB.createSnapshot().runtimeSnapshot;
        final activeOrderBefore = runtime.activeSessions
            .map((session) => session.index)
            .toList(growable: false);

        final probe = internal_runtime.installStage9d6RollbackTestProbe(
          runtime: runtime,
          failAfterPreparedSiblingCount: 1,
        );

        expect(
          () => source.choose(fixture.mutateChoiceId),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('Injected Stage 9D6B sibling preparation failure'),
            ),
          ),
        );

        expect(probe.selectiveRollbackMaterializationCount, 1);
        expect(probe.preparedSiblingReplacementCount, 1);
        expect(probe.rollbackRestoreAttemptCount, 1);
        expect(probe.events, <String>[
          'selectiveRollbackMaterialized',
          'siblingReplacementPrepared',
          'rollbackRestoreAttempt',
        ]);

        final afterSource = source.createSnapshot().runtimeSnapshot;
        expect(afterSource, beforeSource);
        expect(afterSource.state, beforeSource.state);
        expect(afterSource.history, beforeSource.history);
        expect(afterSource.randomState, beforeSource.randomState);
        expect(afterSource.currentEventId, beforeSource.currentEventId);
        expect(afterSource.status, beforeSource.status);
        expect(siblingA.createSnapshot().runtimeSnapshot, beforeSiblingA);
        expect(siblingB.createSnapshot().runtimeSnapshot, beforeSiblingB);
        expect(
          runtime.persistentStateRevision,
          beforeAggregate.persistentStateRevision,
        );
        expect(runtime.persistentState, beforeAggregate.persistentState);
        expect(
          runtime.activeSessions.map((session) => session.index).toList(),
          activeOrderBefore,
        );

        final snapshotCodec = StoryNarrativeRuntimeSnapshotCodec();
        expect(
          snapshotCodec.encodeJson(runtime.createSnapshot()),
          snapshotCodec.encodeJson(beforeAggregate),
          reason:
              'The production selective path must roll back source, '
              'siblings, persistent authority, RNG, history, lifecycle, and '
              'active-session ordering atomically.',
        );
      },
    );

    test(
      'production rollback still traverses validated StoryEngine.restore',
      () {
        final fixture = _stage9d6bFixture();
        final runtime = StoryNarrativeRuntime(
          project: fixture.project,
          entryPoints: <StoryEntryPoint>[fixture.entryPoint],
          randomSeed: 0x9d6c,
        );
        final source = runtime.startSession(fixture.entryPoint.id);
        final siblingA = runtime.startSession(fixture.entryPoint.id);
        final siblingB = runtime.startSession(fixture.entryPoint.id);
        _primeStage9d6bSessions(
          source: source,
          siblingA: siblingA,
          siblingB: siblingB,
          loopChoiceId: fixture.loopChoiceId,
        );

        final probe = internal_runtime.installStage9d6RollbackTestProbe(
          runtime: runtime,
          failAfterPreparedSiblingCount: 1,
          rollbackSnapshotTransform: (snapshot) => StoryRuntimeSnapshot(
            metadata: snapshot.metadata,
            projectId: StoryProjectId('stage9d6b_invalid_rollback_project'),
            status: snapshot.status,
            state: snapshot.state,
            currentEventId: snapshot.currentEventId,
            history: snapshot.history,
            randomState: snapshot.randomState,
            maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
          ),
        );

        expect(
          () => source.choose(fixture.mutateChoiceId),
          throwsA(
            isA<StoryRuntimeSnapshotCompatibilityException>().having(
              (error) => error.issue,
              'issue',
              StoryRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
            ),
          ),
        );
        expect(probe.selectiveRollbackMaterializationCount, 1);
        expect(probe.preparedSiblingReplacementCount, 1);
        expect(probe.rollbackRestoreAttemptCount, 1);
        expect(probe.events, <String>[
          'selectiveRollbackMaterialized',
          'siblingReplacementPrepared',
          'rollbackRestoreAttempt',
        ]);
      },
    );

    test(
      'retained diagnostic strategies preserve successful commit semantics',
      () {
        final fixture = _stage9d6bFixture();
        String? expectedSnapshotJson;

        for (final strategy
            in internal_runtime.StoryNarrativeRuntimeHistoryStrategy.values) {
          final runtime = internal_runtime
              .createStoryNarrativeRuntimeForStage9d5Benchmark(
                project: fixture.project,
                entryPoints: <StoryEntryPoint>[fixture.entryPoint],
                historyStrategy: strategy,
                randomSeed: 0x9d6d,
              );
          final source = runtime.startSession(fixture.entryPoint.id);
          final siblingA = runtime.startSession(fixture.entryPoint.id);
          final siblingB = runtime.startSession(fixture.entryPoint.id);
          _primeStage9d6bSessions(
            source: source,
            siblingA: siblingA,
            siblingB: siblingB,
            loopChoiceId: fixture.loopChoiceId,
          );

          source.choose(fixture.mutateChoiceId);
          final encoded = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
            runtime.createSnapshot(),
          );
          expectedSnapshotJson ??= encoded;
          expect(
            encoded,
            expectedSnapshotJson,
            reason:
                '${strategy.name} must remain a diagnostic performance '
                'variant only; it must not alter committed narrative semantics.',
          );
        }
      },
    );

    test('retained diagnostic strategies preserve rollback semantics', () {
      final fixture = _stage9d6bFixture();

      for (final strategy
          in internal_runtime.StoryNarrativeRuntimeHistoryStrategy.values) {
        final runtime = internal_runtime
            .createStoryNarrativeRuntimeForStage9d5Benchmark(
              project: fixture.project,
              entryPoints: <StoryEntryPoint>[fixture.entryPoint],
              historyStrategy: strategy,
              randomSeed: 0x9d6e,
            );
        final source = runtime.startSession(fixture.entryPoint.id);
        final siblingA = runtime.startSession(fixture.entryPoint.id);
        final siblingB = runtime.startSession(fixture.entryPoint.id);
        _primeStage9d6bSessions(
          source: source,
          siblingA: siblingA,
          siblingB: siblingB,
          loopChoiceId: fixture.loopChoiceId,
        );
        final before = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
          runtime.createSnapshot(),
        );
        final probe = internal_runtime.installStage9d6RollbackTestProbe(
          runtime: runtime,
          failAfterPreparedSiblingCount: 1,
        );

        expect(
          () => source.choose(fixture.mutateChoiceId),
          throwsA(isA<StateError>()),
          reason: strategy.name,
        );
        expect(probe.preparedSiblingReplacementCount, 1, reason: strategy.name);
        expect(probe.rollbackRestoreAttemptCount, 1, reason: strategy.name);
        expect(
          StoryNarrativeRuntimeSnapshotCodec().encodeJson(
            runtime.createSnapshot(),
          ),
          before,
          reason:
              '${strategy.name} must restore the same aggregate boundary '
              'after a prepared-sibling propagation failure.',
        );
      }
    });
  });
}

final class _Stage9d6bFixture {
  const _Stage9d6bFixture({
    required this.project,
    required this.entryPoint,
    required this.loopChoiceId,
    required this.mutateChoiceId,
  });

  final StoryProject project;
  final StoryEntryPoint entryPoint;
  final StoryChoiceId loopChoiceId;
  final StoryChoiceId mutateChoiceId;
}

_Stage9d6bFixture _stage9d6bFixture() {
  final valueId = StoryVariableId('stage9d6b_rollback_value');
  final eventId = StoryEventId('stage9d6b_rollback_event');
  final loopChoiceId = StoryChoiceId('stage9d6b_rollback_loop');
  final mutateChoiceId = StoryChoiceId('stage9d6b_rollback_mutate');
  final entryPointId = StoryEntryPointId('stage9d6b_rollback_entry');
  final loopTransition = StoryWeightedTransition(
    options: <StoryWeightedTransitionOption>[
      StoryWeightedTransitionOption(
        weight: 1,
        transition: StoryEventTransition(destinationEventId: eventId),
      ),
      StoryWeightedTransitionOption(
        weight: 3,
        transition: StoryEventTransition(destinationEventId: eventId),
      ),
    ],
  );
  final project = StoryProject(
    id: StoryProjectId('stage9d6b_rollback_project'),
    stateSchema: StoryStateSchema(
      variables: <StoryVariableDefinition>[
        StoryVariableDefinition(
          id: valueId,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
      ],
    ),
    events: <StoryEvent>[
      StoryEvent(
        id: eventId,
        choices: <StoryChoice>[
          StoryChoice(id: loopChoiceId, transition: loopTransition),
          StoryChoice(
            id: mutateChoiceId,
            effects: <StoryEffect>[
              StoryIncrementVariableEffect(
                variableId: valueId,
                amount: StoryIntegerValue(1),
              ),
            ],
            transition: loopTransition,
          ),
        ],
      ),
    ],
  );
  return _Stage9d6bFixture(
    project: project,
    entryPoint: StoryEntryPoint(id: entryPointId, eventId: eventId),
    loopChoiceId: loopChoiceId,
    mutateChoiceId: mutateChoiceId,
  );
}

void _primeStage9d6bSessions({
  required StoryNarrativeSession source,
  required StoryNarrativeSession siblingA,
  required StoryNarrativeSession siblingB,
  required StoryChoiceId loopChoiceId,
}) {
  source.choose(loopChoiceId);
  source.choose(loopChoiceId);
  siblingA.choose(loopChoiceId);
  siblingB.choose(loopChoiceId);
  siblingB.choose(loopChoiceId);
  siblingB.choose(loopChoiceId);
}
