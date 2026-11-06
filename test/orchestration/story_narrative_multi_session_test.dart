import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 8J multi-session execution', () {
    test(
      'multiple active sessions share committed persistent state in order',
      () {
        final mood = StoryVariableId('var_mood');
        final eventA = StoryEventId('evt_a');
        final eventB = StoryEventId('evt_b');
        final choiceA = StoryChoiceId('choice_a');
        final choiceB = StoryChoiceId('choice_b');
        final entryA = StoryEntryPointId('entry_a');
        final entryB = StoryEntryPointId('entry_b');
        final project = StoryProject(
          id: StoryProjectId('project_multi_session_conflict'),
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: mood,
                type: StoryValueType.string,
                initialValue: const StoryStringValue('neutral'),
              ),
            ],
          ),
          events: [
            _singleChoiceEvent(
              eventA,
              choiceA,
              effects: [
                StorySetVariableEffect(
                  variableId: mood,
                  value: const StoryStringValue('angry'),
                ),
              ],
            ),
            _singleChoiceEvent(
              eventB,
              choiceB,
              effects: [
                StorySetVariableEffect(
                  variableId: mood,
                  value: const StoryStringValue('calm'),
                ),
              ],
            ),
          ],
        );
        final runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: [
            StoryEntryPoint(id: entryA, eventId: eventA),
            StoryEntryPoint(id: entryB, eventId: eventB),
          ],
        );

        final first = runtime.startSession(entryA);
        final second = runtime.startSession(entryB);

        expect(runtime.activeSessions, [first, second]);
        expect(runtime.persistentStateRevision, 0);

        first.choose(choiceA);
        expect(runtime.persistentState.rawValueOf(mood), 'angry');
        expect(second.state.rawValueOf(mood), 'angry');
        expect(runtime.persistentStateRevision, 1);
        expect(runtime.activeSessions, [second]);

        second.choose(choiceB);
        expect(runtime.persistentState.rawValueOf(mood), 'calm');
        expect(runtime.persistentStateRevision, 2);
        expect(runtime.activeSessions, isEmpty);
        expect(runtime.activeSession, isNull);

        // Session-local histories remain separate even though persistent state is
        // shared and committed in authority order.
        expect(first.history.eventRoute, [eventA]);
        expect(second.history.eventRoute, [eventB]);
        expect(runtime.history.eventRoute, [eventA, eventB]);
      },
    );

    test(
      'authority input objects drive sessions without a local UI contract',
      () {
        final eventId = StoryEventId('evt_server_driven');
        final choiceId = StoryChoiceId('choice_server_driven');
        final entryId = StoryEntryPointId('entry_server_driven');
        final runtime = StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('project_server_driven'),
            events: [_singleChoiceEvent(eventId, choiceId)],
          ),
          entryPoints: [StoryEntryPoint(id: entryId, eventId: eventId)],
        );
        final session = runtime.startSession(entryId);

        runtime.applyInput(
          StoryNarrativeChoiceInput(
            sessionIndex: session.index,
            choiceId: choiceId,
          ),
        );

        expect(session.isTerminated, isTrue);
      },
    );

    test('awaiting-host session does not block another active session', () {
      final waitingEvent = StoryEventId('evt_waiting');
      final otherEvent = StoryEventId('evt_other');
      final otherChoice = StoryChoiceId('choice_other');
      final waitingEntry = StoryEntryPointId('entry_waiting');
      final otherEntry = StoryEntryPointId('entry_other');
      final project = StoryProject(
        id: StoryProjectId('project_parallel_host_wait'),
        events: [
          StoryEvent(
            id: waitingEvent,
            continuationTransition: const StoryTerminalTransition(),
          ),
          _singleChoiceEvent(otherEvent, otherChoice),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(id: waitingEntry, eventId: waitingEvent),
          StoryEntryPoint(id: otherEntry, eventId: otherEvent),
        ],
      );
      final waiting = runtime.startSession(waitingEntry);
      final request = waiting.requestHostAction(
        schemaNamespace: 'com.example.world',
        actionId: 'load_area',
      );
      final other = runtime.startSession(otherEntry);

      expect(waiting.sessionStatus, StoryNarrativeSessionStatus.awaitingHost);
      expect(runtime.activeSessions, [waiting, other]);

      other.choose(otherChoice);
      expect(other.isTerminated, isTrue);
      expect(runtime.activeSessions, [waiting]);

      runtime.applyInput(
        StoryNarrativeHostActionCompletedInput(
          sessionIndex: waiting.index,
          requestId: request.id,
        ),
      );
      waiting.continueStory();
      expect(runtime.activeSessions, isEmpty);
    });

    test(
      'explicit host facts remain required for time-like world conditions',
      () {
        final eventId = StoryEventId('evt_night_only');
        final entryId = StoryEntryPointId('entry_night_only');
        final isNight = StoryHostConditionKey('is_night');
        final runtime = StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('project_explicit_time'),
            events: [
              StoryEvent(
                id: eventId,
                continuationTransition: const StoryTerminalTransition(),
              ),
            ],
          ),
          entryPoints: [
            StoryEntryPoint(
              id: entryId,
              eventId: eventId,
              hostConditions: [
                StoryHostConditionRequirement(
                  key: isNight,
                  schemaNamespace: 'com.example.world',
                  conditionId: 'is_night',
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
            hostContext: StoryHostContext(conditionResults: {isNight: false}),
          ),
          isNull,
        );
        expect(
          runtime.resolveAndStartSession(
            hostContext: StoryHostContext(conditionResults: {isNight: true}),
          ),
          isNotNull,
        );
      },
    );

    test('independent runtimes remain deterministic and isolated', () {
      final eventId = StoryEventId('evt_independent');
      final choiceId = StoryChoiceId('choice_independent');
      final entryId = StoryEntryPointId('entry_independent');
      final project = StoryProject(
        id: StoryProjectId('project_independent_workers'),
        events: [_singleChoiceEvent(eventId, choiceId)],
      );

      StoryNarrativeRuntime buildRuntime() => StoryNarrativeRuntime(
        project: project,
        entryPoints: [StoryEntryPoint(id: entryId, eventId: eventId)],
        randomSeed: 42,
      );

      final first = buildRuntime();
      final second = buildRuntime();
      final firstSession = first.startSession(entryId);
      final secondSession = second.startSession(entryId);

      firstSession.choose(choiceId);
      secondSession.choose(choiceId);

      expect(first.history.eventRoute, second.history.eventRoute);
      expect(first.persistentState, second.persistentState);
      expect(firstSession.randomSeed, secondSession.randomSeed);
    });
  });
}

StoryEvent _singleChoiceEvent(
  StoryEventId eventId,
  StoryChoiceId choiceId, {
  List<StoryEffect> effects = const [],
}) => StoryEvent(
  id: eventId,
  choices: [
    StoryChoice(
      id: choiceId,
      effects: effects,
      transition: const StoryTerminalTransition(),
    ),
  ],
);
