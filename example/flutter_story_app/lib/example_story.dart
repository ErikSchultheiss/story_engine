import 'package:story_engine/story_engine.dart';

/// Stable IDs exposed to the UI so host code can inspect selected state without
/// depending on visible text.
final lanternLitId = StoryVariableId('lantern_lit');
final forestGateId = StoryEventId('forest_gate');
final oldTunnelId = StoryEventId('old_tunnel');
final lightLanternId = StoryChoiceId('light_lantern');

/// Builds the tiny authored project used by the Flutter consumer example.
///
/// This file deliberately contains no Flutter import. The authored story can be
/// validated, serialized, or executed in any Dart host; `main.dart` supplies
/// only the Flutter presentation/input/persistence policy around it.
StoryProject buildFlutterExampleProject() {
  final leaveId = StoryChoiceId('leave');

  return StoryProject(
    id: StoryProjectId('flutter_example'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: lanternLitId,
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(false),
        ),
      ],
    ),
    entryEventId: forestGateId,
    events: [
      StoryEvent(
        id: forestGateId,
        presentation: StoryEventPresentation(
          title: const StoryText('Forest Gate'),
          body: const StoryText(
            'A narrow tunnel disappears beneath the old watchtower.',
          ),
        ),
        choices: [
          StoryChoice(
            id: lightLanternId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Light the lantern and enter'),
            ),
            effects: [
              StorySetVariableEffect(
                variableId: lanternLitId,
                value: const StoryBooleanValue(true),
              ),
            ],
            transition: StoryEventTransition(destinationEventId: oldTunnelId),
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
        id: oldTunnelId,
        presentation: StoryEventPresentation(
          title: const StoryText('Old Tunnel'),
          body: const StoryText(
            'The lantern catches fresh footprints in the dust.',
          ),
        ),
        availabilityCondition: StoryVariableComparisonCondition(
          variableId: lanternLitId,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(true),
        ),
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
}
