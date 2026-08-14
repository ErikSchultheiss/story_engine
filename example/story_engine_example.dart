import 'package:story_engine/story_engine.dart';

final _lanternLitId = StoryVariableId('lantern_lit');
final _gateId = StoryEventId('forest_gate');
final _tunnelId = StoryEventId('old_tunnel');
final _lightLanternId = StoryChoiceId('light_lantern');

/// Runs the complete Pure-Dart public-API walkthrough.
///
/// [log] exists so the example can be exercised by the package test suite
/// without changing the normal `dart run` output.
void runExample({void Function(Object?)? log}) {
  final void Function(Object?) write = log ?? print;

  final authoredProject = buildExampleProject();

  // Story Format is storage-neutral. A real host can map these logical files to
  // a directory, archive, database, network payload, or another storage layer.
  const storyFormat = StoryFormatCodec();
  final bundle = storyFormat.encodeProject(authoredProject);
  final project = storyFormat.decodeProject(bundle);

  write('Story Format: ${bundle.files.length} logical files loaded.');

  final validation = StoryValidator.validate(project);
  write('Validation: ${validation.summary}');
  if (validation.hasErrors) {
    write(validation.format());
    return;
  }

  final engine = StoryEngine(project: project)..start();
  _showCurrentEvent(engine, write);

  final lightLantern = engine.availableChoices.singleWhere(
    (choice) => choice.id == _lightLanternId,
  );
  write('Selecting: ${_choiceText(lightLantern)}');
  engine.choose(lightLantern.id);

  write('lantern_lit = ${engine.state?.rawValueOf(_lanternLitId)}');
  _showCurrentEvent(engine, write);

  final snapshotCodec = StoryRuntimeSnapshotCodec();
  final saveJson = snapshotCodec.encodeJson(engine.createSnapshot());
  write('Saved runtime snapshot: ${saveJson.length} JSON characters.');

  final decodedSnapshot = snapshotCodec.decodeJson(
    saveJson,
    project: project,
  );
  final restored = StoryEngine.restore(
    project: project,
    snapshot: decodedSnapshot,
  );
  write('Restored status: ${restored.status.name}');

  restored.continueStory();
  write('Finished status: ${restored.status.name}');
}

/// Builds the tiny authored project used by the Pure-Dart example.
StoryProject buildExampleProject() {
  final leaveId = StoryChoiceId('leave');

  return StoryProject(
    id: StoryProjectId('pure_dart_example'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: _lanternLitId,
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(false),
        ),
      ],
    ),
    entryEventId: _gateId,
    events: [
      StoryEvent(
        id: _gateId,
        presentation: StoryEventPresentation(
          title: const StoryText('Forest Gate'),
          body: const StoryText(
            'A narrow tunnel disappears beneath the old watchtower.',
          ),
        ),
        choices: [
          StoryChoice(
            id: _lightLanternId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Light the lantern and enter'),
            ),
            effects: [
              StorySetVariableEffect(
                variableId: _lanternLitId,
                value: const StoryBooleanValue(true),
              ),
            ],
            transition: StoryEventTransition(destinationEventId: _tunnelId),
          ),
          StoryChoice(
            id: leaveId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Turn back'),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
      StoryEvent(
        id: _tunnelId,
        presentation: StoryEventPresentation(
          title: const StoryText('Old Tunnel'),
          body: const StoryText(
            'The lantern catches fresh footprints in the dust.',
          ),
        ),
        availabilityCondition: StoryVariableComparisonCondition(
          variableId: _lanternLitId,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(true),
        ),
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
}

void _showCurrentEvent(
  StoryEngine engine,
  void Function(Object?) write,
) {
  final event = engine.currentEvent;
  if (event == null) {
    write('No current event.');
    return;
  }

  final presentation = event.presentation;
  final title = presentation?.title?.value;
  final body = presentation?.body?.value;

  if (title != null) {
    write('\n$title');
  }
  if (body != null) {
    write(body);
  }

  if (engine.status == StoryEngineStatus.awaitingChoice) {
    for (final choice in engine.availableChoices) {
      write('- ${choice.id.value}: ${_choiceText(choice)}');
    }
  } else if (engine.status == StoryEngineStatus.awaitingContinue) {
    write('[continue]');
  }
}

String _choiceText(StoryChoice choice) =>
    choice.presentation?.text.value ?? choice.id.value;

void main() => runExample();
