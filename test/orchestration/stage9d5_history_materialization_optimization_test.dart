import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9D5 history materialization optimization', () {
    test(
      'long narrative execution preserves immutable public history snapshots',
      () {
        final fixture = _loopFixture();
        final session = fixture.runtime.startSession(fixture.entryPointId);

        for (var index = 0; index < 64; index++) {
          session.choose(
            index.isEven ? fixture.choiceForward : fixture.choiceBack,
          );
        }

        final before = session.history;
        final beforeSteps = List<StoryRuntimeStep>.of(before.steps);
        expect(before.steps, hasLength(129));

        session.choose(fixture.choiceForward);

        expect(before.steps, beforeSteps);
        expect(before.steps, hasLength(129));
        expect(session.history.steps, hasLength(131));
        expect(session.history.steps.last, isA<StoryEventEnteredStep>());
      },
    );

    test(
      'observer order still follows only the newly committed history suffix',
      () {
        final observer = _CollectingObserver();
        final fixture = _loopFixture(observer: observer);
        final session = fixture.runtime.startSession(fixture.entryPointId);

        observer.events.clear();
        session.choose(fixture.choiceForward);

        expect(observer.events, hasLength(3));
        expect(observer.events[0], isA<StoryNarrativeChoiceSelected>());
        expect(observer.events[1], isA<StoryNarrativeEventEntered>());
        expect(observer.events[2], isA<StoryNarrativeChoicePresented>());
        expect(
          observer.events.map((event) => event.sequence).toList(),
          orderedEquals([3, 4, 5]),
        );
      },
    );

    test('state-changing commits still propagate to active siblings', () {
      final mood = StoryVariableId('var_stage9d5_mood');
      final leftEvent = StoryEventId('evt_stage9d5_left');
      final rightEvent = StoryEventId('evt_stage9d5_right');
      final leftChoice = StoryChoiceId('choice_stage9d5_left');
      final rightChoice = StoryChoiceId('choice_stage9d5_right');
      final leftEntry = StoryEntryPointId('entry_stage9d5_left');
      final rightEntry = StoryEntryPointId('entry_stage9d5_right');
      final project = StoryProject(
        id: StoryProjectId('project_stage9d5_history_state'),
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
          StoryEvent(
            id: leftEvent,
            choices: [
              StoryChoice(
                id: leftChoice,
                effects: [
                  StorySetVariableEffect(
                    variableId: mood,
                    value: const StoryStringValue('left'),
                  ),
                ],
                transition: StoryEventTransition(destinationEventId: leftEvent),
              ),
            ],
          ),
          StoryEvent(
            id: rightEvent,
            choices: [
              StoryChoice(
                id: rightChoice,
                transition: StoryEventTransition(
                  destinationEventId: rightEvent,
                ),
              ),
            ],
          ),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(id: leftEntry, eventId: leftEvent),
          StoryEntryPoint(id: rightEntry, eventId: rightEvent),
        ],
      );
      final source = runtime.startSession(leftEntry);
      final sibling = runtime.startSession(rightEntry);

      source.choose(leftChoice);

      expect(runtime.persistentStateRevision, 1);
      expect(runtime.persistentState.rawValueOf(mood), 'left');
      expect(sibling.state.rawValueOf(mood), 'left');
      expect(source.history.steps, hasLength(3));
      expect(sibling.history.steps, hasLength(1));
    });
  });
}

({
  StoryNarrativeRuntime runtime,
  StoryEntryPointId entryPointId,
  StoryChoiceId choiceForward,
  StoryChoiceId choiceBack,
})
_loopFixture({StoryNarrativeObserver? observer}) {
  final eventA = StoryEventId('evt_stage9d5_history_a');
  final eventB = StoryEventId('evt_stage9d5_history_b');
  final choiceForward = StoryChoiceId('choice_stage9d5_history_forward');
  final choiceBack = StoryChoiceId('choice_stage9d5_history_back');
  final entryPointId = StoryEntryPointId('entry_stage9d5_history');
  final project = StoryProject(
    id: StoryProjectId('project_stage9d5_history_loop'),
    events: [
      StoryEvent(
        id: eventA,
        choices: [
          StoryChoice(
            id: choiceForward,
            transition: StoryEventTransition(destinationEventId: eventB),
          ),
        ],
      ),
      StoryEvent(
        id: eventB,
        choices: [
          StoryChoice(
            id: choiceBack,
            transition: StoryEventTransition(destinationEventId: eventA),
          ),
        ],
      ),
    ],
  );
  return (
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: [StoryEntryPoint(id: entryPointId, eventId: eventA)],
      observers: observer == null ? const [] : [observer],
    ),
    entryPointId: entryPointId,
    choiceForward: choiceForward,
    choiceBack: choiceBack,
  );
}

final class _CollectingObserver implements StoryNarrativeObserver {
  final List<StoryNarrativeObservation> events = <StoryNarrativeObservation>[];

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    events.add(observation);
  }
}
