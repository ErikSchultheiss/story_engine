import 'package:story_engine/story_engine.dart';

final _gateOpenId = StoryVariableId('gate_open');
final _gatekeeperEventId = StoryEventId('gatekeeper_conversation');
final _travelerEventId = StoryEventId('traveler_conversation');
final _gatekeeperEntryId = StoryEntryPointId('gatekeeper');
final _travelerEntryId = StoryEntryPointId('traveler');
final _openGateChoiceId = StoryChoiceId('open_gate');
final _enterCityChoiceId = StoryChoiceId('enter_city');
final _waitChoiceId = StoryChoiceId('wait');

/// Runs the minimal multi-session shared-state orchestration walkthrough.
///
/// [log] exists so the example can be exercised by the package test suite
/// without changing the normal `dart run` output.
void runSharedStateExample({void Function(Object?)? log}) {
  final void Function(Object?) write = log ?? print;
  final project = buildSharedStateExampleProject();
  final entryPoints = buildSharedStateExampleEntryPoints();

  final validation = StoryValidator.validate(
    project,
    additionalEntryEventIds: entryPoints.map((entry) => entry.eventId),
  );
  write('Validation: ${validation.summary}');
  if (validation.hasErrors) {
    write(validation.format());
    return;
  }

  final runtime = StoryNarrativeRuntime(
    project: project,
    entryPoints: entryPoints,
  );
  final gatekeeper = runtime.startSession(_gatekeeperEntryId);
  final traveler = runtime.startSession(_travelerEntryId);

  write('Active sessions: ${_activeSessionIndexes(runtime)}');
  write('Persistent revision: ${runtime.persistentStateRevision}');
  write('Traveler sees gate_open = ${traveler.state.rawValueOf(_gateOpenId)}');
  write('Traveler choices before gate opens: ${_choiceIds(traveler)}');

  runtime.applyInput(
    StoryNarrativeChoiceInput(
      sessionIndex: gatekeeper.index,
      choiceId: _openGateChoiceId,
    ),
  );

  write('After authority input: open_gate');
  write(
    'Persistent gate_open = ${runtime.persistentState.rawValueOf(_gateOpenId)}',
  );
  write('Persistent revision: ${runtime.persistentStateRevision}');
  write('Traveler sees gate_open = ${traveler.state.rawValueOf(_gateOpenId)}');
  write('Traveler choices after gate opens: ${_choiceIds(traveler)}');
  write('Active sessions: ${_activeSessionIndexes(runtime)}');

  runtime.applyInput(
    StoryNarrativeChoiceInput(
      sessionIndex: traveler.index,
      choiceId: _enterCityChoiceId,
    ),
  );

  write('Traveler entered the city.');
  write('Active sessions: ${_activeSessionIndexes(runtime)}');
}

/// Builds the tiny shared-state project used by the orchestration example.
StoryProject buildSharedStateExampleProject() {
  return StoryProject(
    id: StoryProjectId('shared_state_conversations_example'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: _gateOpenId,
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(false),
        ),
      ],
    ),
    entryEventId: _gatekeeperEventId,
    events: [
      StoryEvent(
        id: _gatekeeperEventId,
        presentation: StoryEventPresentation(
          title: const StoryText('Gatekeeper'),
          body: const StoryText('The city gate is still closed.'),
        ),
        choices: [
          StoryChoice(
            id: _openGateChoiceId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Open the city gate'),
            ),
            effects: [
              StorySetVariableEffect(
                variableId: _gateOpenId,
                value: const StoryBooleanValue(true),
              ),
            ],
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
      StoryEvent(
        id: _travelerEventId,
        presentation: StoryEventPresentation(
          title: const StoryText('Traveler'),
          body: const StoryText('A traveler waits outside the city.'),
        ),
        choices: [
          StoryChoice(
            id: _enterCityChoiceId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Enter the city'),
            ),
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: _gateOpenId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            transition: const StoryTerminalTransition(),
          ),
          StoryChoice(
            id: _waitChoiceId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Keep waiting'),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
    ],
  );
}

/// Entry points for the two independent local conversations.
List<StoryEntryPoint> buildSharedStateExampleEntryPoints() => [
  StoryEntryPoint(id: _gatekeeperEntryId, eventId: _gatekeeperEventId),
  StoryEntryPoint(id: _travelerEntryId, eventId: _travelerEventId),
];

String _choiceIds(StoryNarrativeSession session) =>
    session.availableChoices.map((choice) => choice.id.value).join(', ');

String _activeSessionIndexes(StoryNarrativeRuntime runtime) =>
    runtime.activeSessions.map((session) => session.index).join(', ');

void main() => runSharedStateExample();
