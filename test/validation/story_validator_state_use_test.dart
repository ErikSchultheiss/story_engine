import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  group('Stage 3E initialization and state-use analysis', () {
    test('engine-owned Stage 3E diagnostic code tokens stay stable', () {
      expect(
        [
          StoryDiagnosticCode.stateReadMayBeUnset.value,
          StoryDiagnosticCode.stateNumericEffectTargetUnset.value,
          StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset.value,
          StoryDiagnosticCode.stateVariableNeverReferenced.value,
          StoryDiagnosticCode.stateVariableWrittenNeverRead.value,
          StoryDiagnosticCode.stateVariableReadWithoutInitialization.value,
        ],
        [
          'state.read_may_be_unset',
          'state.numeric_effect_target_unset',
          'state.numeric_effect_target_may_be_unset',
          'state.variable_never_referenced',
          'state.variable_written_never_read',
          'state.variable_read_without_initialization',
        ],
      );
    });

    test('comparison against initially unset variable reports a warning', () {
      final variableId = StoryVariableId('variable_unset_read');
      final eventId = StoryEventId('event_unset_read');
      final project = StoryProject(
        id: StoryProjectId('project_unset_read'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: variableId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.warnings.singleWhere(
        (item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset,
      );

      expect(
        diagnostic.location.pathString,
        'events[0].availabilityCondition.variableId',
      );
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.variable(variableId)],
      );
      expect(
        diagnostic.relatedLocations.single.pathString,
        'stateSchema.variables[0]',
      );
    });

    test('explicit is-set and is-unset predicates are safe presence reads', () {
      final variableId = StoryVariableId('variable_presence_only');
      final eventId = StoryEventId('event_presence_only');
      final project = StoryProject(
        id: StoryProjectId('project_presence_only'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryAnyCondition([
              StoryVariableIsSetCondition(variableId: variableId),
              StoryVariableIsUnsetCondition(variableId: variableId),
            ]),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset,
        ),
        isEmpty,
      );
    });

    test('ALL is-set guard proves a later scalar comparison is safe', () {
      final variableId = StoryVariableId('variable_all_guard');
      final eventId = StoryEventId('event_all_guard');
      final project = StoryProject(
        id: StoryProjectId('project_all_guard'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryAllCondition([
              StoryVariableIsSetCondition(variableId: variableId),
              StoryVariableComparisonCondition(
                variableId: variableId,
                operator: StoryComparisonOperator.greaterThan,
                value: StoryIntegerValue(0),
              ),
            ]),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset,
        ),
        isEmpty,
      );
    });

    test('ANY is-unset guard proves its later scalar comparison is safe', () {
      final variableId = StoryVariableId('variable_any_guard');
      final eventId = StoryEventId('event_any_guard');
      final project = StoryProject(
        id: StoryProjectId('project_any_guard'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryAnyCondition([
              StoryVariableIsUnsetCondition(variableId: variableId),
              StoryVariableComparisonCondition(
                variableId: variableId,
                operator: StoryComparisonOperator.equal,
                value: const StoryBooleanValue(true),
              ),
            ]),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset,
        ),
        isEmpty,
      );
    });

    test('is-set choice guard makes a numeric adjustment safe', () {
      final variableId = StoryVariableId('variable_guarded_number');
      final eventId = StoryEventId('event_guarded_number');
      final project = StoryProject(
        id: StoryProjectId('project_guarded_number'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_initialize_guarded_number'),
                availabilityCondition: StoryVariableIsUnsetCondition(
                  variableId: variableId,
                ),
                effects: [
                  StorySetVariableEffect(
                    variableId: variableId,
                    value: StoryIntegerValue(0),
                  ),
                ],
                transition: StoryEventTransition(destinationEventId: eventId),
              ),
              StoryChoice(
                id: StoryChoiceId('choice_increment_guarded_number'),
                availabilityCondition: StoryVariableIsSetCondition(
                  variableId: variableId,
                ),
                effects: [
                  StoryIncrementVariableEffect(
                    variableId: variableId,
                    amount: StoryIntegerValue(1),
                  ),
                ],
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) =>
              item.code == StoryDiagnosticCode.stateNumericEffectTargetUnset ||
              item.code ==
                  StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset,
        ),
        isEmpty,
      );
    });

    test('prior assignment propagated through a transition prevents warning', () {
      final variableId = StoryVariableId('variable_prior_assignment');
      final sourceId = StoryEventId('event_assignment_source');
      final destinationId = StoryEventId('event_assignment_destination');
      final project = StoryProject(
        id: StoryProjectId('project_prior_assignment'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
            ),
          ],
        ),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
            entryEffects: [
              StorySetVariableEffect(
                variableId: variableId,
                value: const StoryBooleanValue(true),
              ),
            ],
            automaticTransition: StoryEventTransition(
              destinationEventId: destinationId,
            ),
          ),
          StoryEvent(
            id: destinationId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: variableId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset,
        ),
        isEmpty,
      );
    });

    test('merged paths report a variable that may still be unset', () {
      final variableId = StoryVariableId('variable_path_dependent');
      final sourceId = StoryEventId('event_path_source');
      final destinationId = StoryEventId('event_path_destination');
      final project = StoryProject(
        id: StoryProjectId('project_path_dependent'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
            ),
          ],
        ),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_sets_variable'),
                effects: [
                  StorySetVariableEffect(
                    variableId: variableId,
                    value: const StoryBooleanValue(true),
                  ),
                ],
                transition: StoryEventTransition(
                  destinationEventId: destinationId,
                ),
              ),
              StoryChoice(
                id: StoryChoiceId('choice_leaves_unset'),
                transition: StoryEventTransition(
                  destinationEventId: destinationId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: destinationId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: variableId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final warning = report.warnings.singleWhere(
        (item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset,
      );

      expect(
        warning.location.pathString,
        'events[1].availabilityCondition.variableId',
      );
    });

    test('numeric adjustment of definitely unset variable is an error', () {
      final variableId = StoryVariableId('variable_definitely_unset_number');
      final eventId = StoryEventId('event_definitely_unset_number');
      final project = StoryProject(
        id: StoryProjectId('project_definitely_unset_number'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: variableId,
                amount: StoryIntegerValue(1),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final error = report.errors.singleWhere(
        (item) => item.code == StoryDiagnosticCode.stateNumericEffectTargetUnset,
      );

      expect(error.location.pathString, 'events[0].entryEffects[0].variableId');
    });

    test('numeric adjustment after merged paths reports path-dependent warning', () {
      final variableId = StoryVariableId('variable_maybe_unset_number');
      final sourceId = StoryEventId('event_maybe_unset_source');
      final destinationId = StoryEventId('event_maybe_unset_destination');
      final project = StoryProject(
        id: StoryProjectId('project_maybe_unset_number'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
            ),
          ],
        ),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_initializes_number'),
                effects: [
                  StorySetVariableEffect(
                    variableId: variableId,
                    value: StoryIntegerValue(0),
                  ),
                ],
                transition: StoryEventTransition(
                  destinationEventId: destinationId,
                ),
              ),
              StoryChoice(
                id: StoryChoiceId('choice_skips_number'),
                transition: StoryEventTransition(
                  destinationEventId: destinationId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: destinationId,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: variableId,
                amount: StoryIntegerValue(1),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final warning = report.warnings.singleWhere(
        (item) =>
            item.code == StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset,
      );

      expect(warning.location.pathString, 'events[1].entryEffects[0].variableId');
    });

    test('usage diagnostics distinguish unused, write-only, and uninitialized read', () {
      final unusedId = StoryVariableId('variable_unused');
      final writeOnlyId = StoryVariableId('variable_write_only');
      final readOnlyUnsetId = StoryVariableId('variable_read_only_unset');
      final eventId = StoryEventId('event_usage_quality');
      final project = StoryProject(
        id: StoryProjectId('project_usage_quality'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: unusedId,
              type: StoryValueType.boolean,
            ),
            StoryVariableDefinition(
              id: writeOnlyId,
              type: StoryValueType.boolean,
            ),
            StoryVariableDefinition(
              id: readOnlyUnsetId,
              type: StoryValueType.boolean,
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryVariableIsUnsetCondition(
              variableId: readOnlyUnsetId,
            ),
            entryEffects: [
              StorySetVariableEffect(
                variableId: writeOnlyId,
                value: const StoryBooleanValue(true),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.information.singleWhere(
          (item) => item.code == StoryDiagnosticCode.stateVariableNeverReferenced,
        ).references,
        [StoryDiagnosticReference.variable(unusedId)],
      );
      expect(
        report.information.singleWhere(
          (item) => item.code == StoryDiagnosticCode.stateVariableWrittenNeverRead,
        ).references,
        [StoryDiagnosticReference.variable(writeOnlyId)],
      );
      expect(
        report.warnings.singleWhere(
          (item) =>
              item.code ==
              StoryDiagnosticCode.stateVariableReadWithoutInitialization,
        ).references,
        [StoryDiagnosticReference.variable(readOnlyUnsetId)],
      );
    });

    test('Lantern Mystery surfaces unset-capable alarm reads without errors', () {
      final report = StoryValidator.validate(LanternMysteryFixture.buildProject());

      expect(report.errors, isEmpty);
      final stateWarnings = report.warnings
          .where((item) => item.code == StoryDiagnosticCode.stateReadMayBeUnset)
          .toList();
      expect(stateWarnings, isNotEmpty);
      expect(
        stateWarnings.every(
          (item) =>
              item.references.contains(
                StoryDiagnosticReference.variable(
                  LanternMysteryFixture.alarmTriggeredId,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('Stage 3E diagnostics remain deterministic across repeated validation', () {
      final project = LanternMysteryFixture.buildProject();

      final first = StoryValidator.validate(project);
      final second = StoryValidator.validate(project);

      expect(second.diagnostics, first.diagnostics);
    });
  });
}
