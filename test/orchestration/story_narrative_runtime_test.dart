import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryEngine host-selected activation', () {
    test(
      'startAt begins an unrelated event without changing project entry',
      () {
        final defaultId = StoryEventId('evt_default');
        final npcId = StoryEventId('evt_npc');
        final project = StoryProject(
          id: StoryProjectId('project_start_at'),
          events: [
            StoryEvent(
              id: defaultId,
              continuationTransition: const StoryTerminalTransition(),
            ),
            StoryEvent(
              id: npcId,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        );

        final engine = StoryEngine(project: project)..startAt(npcId);

        expect(project.entryEventId, isNull);
        expect(engine.currentEvent?.id, npcId);
        expect(engine.history.eventRoute, [npcId]);
      },
    );

    test('start keeps once-only precedence after a host-selected startAt', () {
      final npcId = StoryEventId('evt_host_started');
      final engine = StoryEngine(
        project: StoryProject(
          id: StoryProjectId('project_start_precedence'),
          events: [_continuationEvent(npcId)],
        ),
      )..startAt(npcId);

      expect(
        () => engine.start(),
        throwsA(
          isA<StoryEngineOperationException>().having(
            (error) => error.operation,
            'operation',
            'start',
          ),
        ),
      );
    });
  });

  group('StoryNarrativeRuntime', () {
    test('persists scalar state across independent sessions', () {
      final visits = StoryVariableId('var_visits');
      final firstEvent = StoryEventId('evt_first_npc');
      final secondEvent = StoryEventId('evt_second_npc');
      final firstEntry = StoryEntryPointId('entry_first_npc');
      final secondEntry = StoryEntryPointId('entry_second_npc');
      final project = StoryProject(
        id: StoryProjectId('project_session_state'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: visits,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(0),
            ),
          ],
        ),
        events: [
          StoryEvent(
            id: firstEvent,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: visits,
                amount: StoryIntegerValue(1),
              ),
            ],
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: secondEvent,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: visits,
                amount: StoryIntegerValue(10),
              ),
            ],
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(id: firstEntry, eventId: firstEvent),
          StoryEntryPoint(id: secondEntry, eventId: secondEvent),
        ],
        randomSeed: 17,
      );

      final first = runtime.startSession(firstEntry);
      expect(runtime.persistentState.valueOf(visits), StoryIntegerValue(1));
      first.continueStory();
      expect(runtime.activeSession, isNull);

      final second = runtime.startSession(secondEntry);
      expect(runtime.persistentState.valueOf(visits), StoryIntegerValue(11));
      second.continueStory();

      expect(runtime.history.sessions, hasLength(2));
      expect(runtime.history.sessions[0].entryPointId, firstEntry);
      expect(runtime.history.sessions[1].entryPointId, secondEntry);
      expect(runtime.history.eventRoute, [firstEvent, secondEvent]);
    });

    test('priority outranks weight and fallback is a separate tier', () {
      final primaryLow = StoryEntryPointId('entry_primary_low');
      final primaryHigh = StoryEntryPointId('entry_primary_high');
      final fallback = StoryEntryPointId('entry_fallback');
      final lowEvent = StoryEventId('evt_low');
      final highEvent = StoryEventId('evt_high');
      final fallbackEvent = StoryEventId('evt_fallback');
      final enabled = StoryVariableId('var_enabled');
      final project = StoryProject(
        id: StoryProjectId('project_priority'),
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
          _continuationEvent(lowEvent),
          _continuationEvent(highEvent),
          _continuationEvent(fallbackEvent),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(
            id: primaryLow,
            eventId: lowEvent,
            priority: 1,
            weight: 1000,
          ),
          StoryEntryPoint(
            id: primaryHigh,
            eventId: highEvent,
            priority: 10,
            weight: 1,
          ),
          StoryEntryPoint(
            id: fallback,
            eventId: fallbackEvent,
            priority: 999,
            isFallback: true,
          ),
        ],
      );

      final session = runtime.resolveAndStartSession();
      expect(session?.entryPoint.id, primaryHigh);
    });

    test('fallback activates only when no regular entry is eligible', () {
      final available = StoryVariableId('var_available');
      final regularEvent = StoryEventId('evt_regular');
      final fallbackEvent = StoryEventId('evt_fallback_only');
      final regularEntry = StoryEntryPointId('entry_regular');
      final fallbackEntry = StoryEntryPointId('entry_fallback_only');
      final project = StoryProject(
        id: StoryProjectId('project_fallback'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: available,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(false),
            ),
          ],
        ),
        events: [
          _continuationEvent(regularEvent),
          _continuationEvent(fallbackEvent),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(
            id: regularEntry,
            eventId: regularEvent,
            eligibilityCondition: StoryVariableComparisonCondition(
              variableId: available,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
          ),
          StoryEntryPoint(
            id: fallbackEntry,
            eventId: fallbackEvent,
            isFallback: true,
          ),
        ],
      );

      expect(runtime.resolveAndStartSession()?.entryPoint.id, fallbackEntry);
    });

    test('one host-condition key cannot identify conflicting requests', () {
      final firstEvent = StoryEventId('evt_host_key_first');
      final secondEvent = StoryEventId('evt_host_key_second');
      final sharedKey = StoryHostConditionKey('shared_fact');

      expect(
        () => StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('project_conflicting_host_key'),
            events: [
              _continuationEvent(firstEvent),
              _continuationEvent(secondEvent),
            ],
          ),
          entryPoints: [
            StoryEntryPoint(
              id: StoryEntryPointId('entry_host_key_first'),
              eventId: firstEvent,
              hostConditions: [
                StoryHostConditionRequirement(
                  key: sharedKey,
                  schemaNamespace: 'com.example.world',
                  conditionId: 'quest_completed',
                  arguments: const {'quest': 'dragon_hunt'},
                ),
              ],
            ),
            StoryEntryPoint(
              id: StoryEntryPointId('entry_host_key_second'),
              eventId: secondEvent,
              hostConditions: [
                StoryHostConditionRequirement(
                  key: sharedKey,
                  schemaNamespace: 'com.example.world',
                  conditionId: 'quest_completed',
                  arguments: const {'quest': 'lost_crown'},
                ),
              ],
            ),
          ],
        ),
        throwsA(isA<StoryNarrativeConfigurationException>()),
      );
    });

    test('host-world condition results are explicit required inputs', () {
      final eventId = StoryEventId('evt_after_quest');
      final entryId = StoryEntryPointId('entry_after_quest');
      final questDone = StoryHostConditionKey('quest_done');
      final project = StoryProject(
        id: StoryProjectId('project_host_fact'),
        events: [_continuationEvent(eventId)],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(
            id: entryId,
            eventId: eventId,
            hostConditions: [
              StoryHostConditionRequirement(
                key: questDone,
                schemaNamespace: 'com.example-rpg.world',
                conditionId: 'quest_completed',
                arguments: const {'quest': 'dragon_hunt'},
              ),
            ],
          ),
        ],
      );

      expect(
        () => runtime.resolveAndStartSession(),
        throwsA(isA<StoryNarrativeResolutionException>()),
      );
      expect(
        runtime.resolveAndStartSession(
          hostContext: StoryHostContext(conditionResults: {questDone: false}),
        ),
        isNull,
      );
      expect(
        runtime
            .resolveAndStartSession(
              hostContext: StoryHostContext(
                conditionResults: {questDone: true},
              ),
            )
            ?.entryPoint
            .id,
        entryId,
      );
    });

    test(
      'weighted ties and allocated session seeds are exactly deterministic',
      () {
        final firstId = StoryEntryPointId('entry_weight_a');
        final secondId = StoryEntryPointId('entry_weight_b');
        final firstEvent = StoryEventId('evt_weight_a');
        final secondEvent = StoryEventId('evt_weight_b');
        final project = StoryProject(
          id: StoryProjectId('project_weighted_entry'),
          events: [
            _continuationEvent(firstEvent),
            _continuationEvent(secondEvent),
          ],
        );

        StoryNarrativeRuntime build(int seed) => StoryNarrativeRuntime(
          project: project,
          randomSeed: seed,
          entryPoints: [
            StoryEntryPoint(id: firstId, eventId: firstEvent, weight: 1),
            StoryEntryPoint(id: secondId, eventId: secondEvent, weight: 3),
          ],
        );

        final seed0 = build(0).resolveAndStartSession()!;
        final seed1 = build(1).resolveAndStartSession()!;
        final seed2 = build(2).resolveAndStartSession()!;

        expect(seed0.entryPoint.id, secondId); // sampled 2 in [0, 4)
        expect(seed0.randomSeed, 2868466484);
        expect(seed1.entryPoint.id, secondId); // sampled 3 in [0, 4)
        expect(seed1.randomSeed, 3027450565);
        expect(seed2.entryPoint.id, firstId); // sampled 0 in [0, 4)
        expect(seed2.randomSeed, 3186434646);
      },
    );

    test(
      'randomness inside one session cannot perturb later entry resolution',
      () {
        final randomEvent = StoryEventId('evt_random_session');
        final randomA = StoryEventId('evt_random_a');
        final randomB = StoryEventId('evt_random_b');
        final deterministicEvent = StoryEventId('evt_deterministic_session');
        final nextA = StoryEventId('evt_next_a');
        final nextB = StoryEventId('evt_next_b');
        final randomEntry = StoryEntryPointId('entry_random_session');
        final deterministicEntry = StoryEntryPointId(
          'entry_deterministic_session',
        );
        final nextEntryA = StoryEntryPointId('entry_next_a');
        final nextEntryB = StoryEntryPointId('entry_next_b');
        final project = StoryProject(
          id: StoryProjectId('project_rng_scope'),
          events: [
            StoryEvent(
              id: randomEvent,
              automaticTransition: StoryWeightedTransition(
                options: [
                  StoryWeightedTransitionOption(
                    weight: 1,
                    transition: StoryEventTransition(
                      destinationEventId: randomA,
                    ),
                  ),
                  StoryWeightedTransitionOption(
                    weight: 1,
                    transition: StoryEventTransition(
                      destinationEventId: randomB,
                    ),
                  ),
                ],
              ),
            ),
            _continuationEvent(randomA),
            _continuationEvent(randomB),
            _continuationEvent(deterministicEvent),
            _continuationEvent(nextA),
            _continuationEvent(nextB),
          ],
        );

        StoryNarrativeRuntime build() => StoryNarrativeRuntime(
          project: project,
          randomSeed: 77,
          entryPoints: [
            StoryEntryPoint(
              id: randomEntry,
              eventId: randomEvent,
              isFallback: true,
            ),
            StoryEntryPoint(
              id: deterministicEntry,
              eventId: deterministicEvent,
              isFallback: true,
            ),
            StoryEntryPoint(id: nextEntryA, eventId: nextA, weight: 1),
            StoryEntryPoint(id: nextEntryB, eventId: nextB, weight: 1),
          ],
        );

        final randomRuntime = build();
        final randomSession = randomRuntime.startSession(randomEntry);
        randomSession.continueStory();
        final nextAfterRandom = randomRuntime.resolveAndStartSession()!;

        final deterministicRuntime = build();
        final deterministicSession = deterministicRuntime.startSession(
          deterministicEntry,
        );
        deterministicSession.continueStory();
        final nextAfterDeterministic = deterministicRuntime
            .resolveAndStartSession()!;

        expect(
          nextAfterRandom.entryPoint.id,
          nextAfterDeterministic.entryPoint.id,
        );
        expect(nextAfterRandom.randomSeed, nextAfterDeterministic.randomSeed);
      },
    );

    test('failed activation does not commit orchestration RNG state', () {
      final allowed = StoryVariableId('var_allowed');
      final blockedEvent = StoryEventId('evt_blocked_start');
      final validEvent = StoryEventId('evt_valid_start');
      final blockedEntry = StoryEntryPointId('entry_blocked_start');
      final validEntry = StoryEntryPointId('entry_valid_start');
      final project = StoryProject(
        id: StoryProjectId('project_failed_activation_rng'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: allowed,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(false),
            ),
          ],
        ),
        events: [
          StoryEvent(
            id: blockedEvent,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: allowed,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            continuationTransition: const StoryTerminalTransition(),
          ),
          _continuationEvent(validEvent),
        ],
      );
      final entryPoints = [
        StoryEntryPoint(id: blockedEntry, eventId: blockedEvent),
        StoryEntryPoint(id: validEntry, eventId: validEvent),
      ];

      final afterFailure = StoryNarrativeRuntime(
        project: project,
        entryPoints: entryPoints,
        randomSeed: 31,
      );
      expect(
        () => afterFailure.startSession(blockedEntry),
        throwsA(isA<StoryNarrativeExecutionException>()),
      );
      final afterFailureSession = afterFailure.startSession(validEntry);

      final fresh = StoryNarrativeRuntime(
        project: project,
        entryPoints: entryPoints,
        randomSeed: 31,
      );
      final freshSession = fresh.startSession(validEntry);

      expect(afterFailureSession.randomSeed, freshSession.randomSeed);
    });

    test('synthetic open world handles many unrelated NPC entry points', () {
      const count = 40;
      final events = <StoryEvent>[];
      final entryPoints = <StoryEntryPoint>[];
      for (var index = 0; index < count; index++) {
        final suffix = index.toString().padLeft(2, '0');
        final eventId = StoryEventId('evt_npc_$suffix');
        final entryId = StoryEntryPointId('entry_npc_$suffix');
        events.add(_continuationEvent(eventId));
        entryPoints.add(
          StoryEntryPoint(id: entryId, eventId: eventId, priority: index),
        );
      }
      final project = StoryProject(
        id: StoryProjectId('project_open_world_40_npcs'),
        entryEventId: events.first.id,
        events: events,
      );
      final report = StoryValidator.validate(
        project,
        additionalEntryEventIds: entryPoints.map(
          (entryPoint) => entryPoint.eventId,
        ),
      );
      expect(
        report.diagnostics.where(
          (diagnostic) =>
              diagnostic.code == StoryDiagnosticCode.graphUnreachableEvent,
        ),
        isEmpty,
      );

      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: entryPoints,
        randomSeed: 1234,
      );

      final session = runtime.resolveAndStartSession();
      expect(session?.entryPoint.id, StoryEntryPointId('entry_npc_39'));
      expect(session?.currentEvent?.id, StoryEventId('evt_npc_39'));
      expect(project.entryEventId, StoryEventId('evt_npc_00'));
    });

    test('multiple sessions may be active at Stage 8J', () {
      final eventId = StoryEventId('evt_multi_active');
      final entryId = StoryEntryPointId('entry_multi_active');
      final runtime = StoryNarrativeRuntime(
        project: StoryProject(
          id: StoryProjectId('project_multi_active'),
          events: [_continuationEvent(eventId)],
        ),
        entryPoints: [StoryEntryPoint(id: entryId, eventId: eventId)],
      );

      final first = runtime.startSession(entryId);
      final second = runtime.startSession(entryId);

      expect(first.index, 0);
      expect(second.index, 1);
      expect(runtime.activeSessions, [first, second]);
      expect(runtime.activeSession, same(second));
    });
  });
}

StoryEvent _continuationEvent(StoryEventId id) =>
    StoryEvent(id: id, continuationTransition: const StoryTerminalTransition());
