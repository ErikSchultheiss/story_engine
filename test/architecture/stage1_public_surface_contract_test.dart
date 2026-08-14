import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('public barrel exports only the deliberately approved library files', () {
    final barrel = File('lib/story_engine.dart').readAsStringSync();
    final actual = _exportPattern
        .allMatches(barrel)
        .map((match) => match.group(1)!)
        .toList()
      ..sort();
    final expected = [..._approvedPublicLibraryFiles]..sort();

    expect(
      actual,
      expected,
      reason: 'Changing the public barrel is allowed, but it must be an '
          'intentional architecture decision accompanied by an update to this '
          'public-surface contract test.',
    );
  });

  test('public Stage 1 layers interoperate through story_engine.dart only', () {
    final trustId = StoryVariableId('var_trust');
    final hasKeyId = StoryVariableId('var_has_key');
    final startId = StoryEventId('evt_start');
    final trustedId = StoryEventId('evt_trusted');
    final helpId = StoryChoiceId('choice_help');

    final schema = StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: trustId,
          alias: StoryAlias('trust'),
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(50),
        ),
        StoryVariableDefinition(
          id: hasKeyId,
          alias: StoryAlias('has_key'),
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(false),
        ),
      ],
    );

    final project = StoryProject(
      id: StoryProjectId('project_stage1_contract'),
      alias: StoryAlias('stage1_contract'),
      stateSchema: schema,
      entryEventId: startId,
      events: [
        StoryEvent(
          id: startId,
          alias: StoryAlias('start'),
          choices: [
            StoryChoice(
              id: helpId,
              alias: StoryAlias('help'),
              availabilityCondition: StoryVariableComparisonCondition(
                variableId: hasKeyId,
                operator: StoryComparisonOperator.equal,
                value: const StoryBooleanValue(false),
              ),
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
                fallback: const StoryTerminalTransition(),
              ),
            ),
          ],
        ),
        StoryEvent(
          id: trustedId,
          alias: StoryAlias('trusted'),
          entryEffects: [
            StorySetVariableEffect(
              variableId: hasKeyId,
              value: const StoryBooleanValue(true),
            ),
          ],
          automaticTransition: const StoryTerminalTransition(),
        ),
      ],
    );

    final engine = StoryEngine(project: project, randomSeed: 123)..start();

    expect(engine.status, StoryEngineStatus.awaitingChoice);
    expect(engine.availableChoices.single.id, helpId);

    engine.choose(helpId);

    expect(engine.status, StoryEngineStatus.terminated);
    expect(engine.currentEvent?.id, trustedId);
    expect(engine.state?.valueOf(trustId), StoryIntegerValue(65));
    expect(engine.state?.valueOf(hasKeyId), const StoryBooleanValue(true));
  });
}

final _exportPattern = RegExp(r'''export\s+['"]([^'"]+)['"]''');

const _approvedPublicLibraryFiles = <String>[
  'src/condition/story_condition.dart',
  'src/condition/story_condition_context.dart',
  'src/condition/story_condition_evaluator.dart',
  'src/effect/story_effect.dart',
  'src/format/story_format_bundle.dart',
  'src/format/story_format_bundle_layout.dart',
  'src/format/codec/story_format_codec.dart',
  'src/format/story_format_compatibility.dart',
  'src/format/story_format_document.dart',
  'src/format/story_format_extension_attachment.dart',
  'src/format/story_format_extension_namespace.dart',
  'src/format/story_format_extension_payload.dart',
  'src/format/story_format_extension_target.dart',
  'src/format/story_format_group.dart',
  'src/format/story_format_group_id.dart',
  'src/format/story_format_metadata.dart',
  'src/format/story_format_organization.dart',
  'src/format/story_format_tag.dart',
  'src/format/story_format_tag_id.dart',
  'src/identity/story_alias.dart',
  'src/identity/story_choice_id.dart',
  'src/identity/story_event_id.dart',
  'src/identity/story_project_id.dart',
  'src/identity/story_variable_id.dart',
  'src/model/story_choice.dart',
  'src/model/story_event.dart',
  'src/model/story_project.dart',
  'src/presentation/story_choice_presentation.dart',
  'src/presentation/story_event_presentation.dart',
  'src/presentation/story_text.dart',
  'src/persistence/story_runtime_snapshot_codec.dart',
  'src/runtime/story_engine.dart',
  'src/runtime/story_engine_status.dart',
  'src/runtime/story_runtime_history.dart',
  'src/runtime/story_runtime_snapshot.dart',
  'src/runtime/story_runtime_snapshot_validator.dart',
  'src/state/story_state.dart',
  'src/state/story_state_schema.dart',
  'src/state/story_value.dart',
  'src/state/story_value_type.dart',
  'src/state/story_variable_definition.dart',
  'src/transition/story_transition.dart',
  'src/validation/story_diagnostic.dart',
  'src/validation/story_diagnostic_code.dart',
  'src/validation/story_diagnostic_location.dart',
  'src/validation/story_diagnostic_reference.dart',
  'src/validation/story_diagnostic_severity.dart',
  'src/validation/story_validation_report.dart',
  'src/validation/story_validator.dart',
];
