import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  group('Stage 3D type and semantic validation', () {
    test('engine-owned Stage 3D diagnostic code tokens stay stable', () {
      expect(
        [
          StoryDiagnosticCode.typeConditionOperandMismatch.value,
          StoryDiagnosticCode.typeConditionOperatorNotSupported.value,
          StoryDiagnosticCode.typeEffectValueMismatch.value,
          StoryDiagnosticCode.typeNumericEffectTargetNotNumeric.value,
          StoryDiagnosticCode.typeNumericEffectAmountMismatch.value,
        ],
        [
          'type.condition_operand_mismatch',
          'type.condition_operator_not_supported',
          'type.effect_value_mismatch',
          'type.numeric_effect_target_not_numeric',
          'type.numeric_effect_amount_mismatch',
        ],
      );
    });

    test('comparison literal must match the declared variable type', () {
      final variableId = StoryVariableId('variable_condition_type');
      final eventId = StoryEventId('event_condition_type');
      final project = StoryProject(
        id: StoryProjectId('project_condition_type'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(false),
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
              value: StoryIntegerValue(1),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.typeConditionOperandMismatch,
      );
      expect(
        diagnostic.location.pathString,
        'events[0].availabilityCondition.value',
      );
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.variable(variableId)],
      );
      expect(diagnostic.relatedLocations, hasLength(1));
      expect(
        diagnostic.relatedLocations.single.pathString,
        'stateSchema.variables[0].type',
      );
      expect(
        diagnostic.relatedLocations.single.kind,
        StoryDiagnosticLocationKind.variable,
      );
    });

    test('ordering operator is rejected for a non-numeric declared type', () {
      final variableId = StoryVariableId('variable_ordering_type');
      final eventId = StoryEventId('event_ordering_type');
      final project = StoryProject(
        id: StoryProjectId('project_ordering_type'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.string,
              initialValue: const StoryStringValue('alpha'),
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: variableId,
              operator: StoryComparisonOperator.lessThan,
              value: StoryIntegerValue(10),
            ),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final typeErrors = report.errors
          .where(
            (diagnostic) =>
                diagnostic.code ==
                    StoryDiagnosticCode.typeConditionOperandMismatch ||
                diagnostic.code ==
                    StoryDiagnosticCode.typeConditionOperatorNotSupported,
          )
          .toList();

      expect(typeErrors, hasLength(2));
      expect(
        typeErrors.map((diagnostic) => diagnostic.code).toSet(),
        {
          StoryDiagnosticCode.typeConditionOperandMismatch,
          StoryDiagnosticCode.typeConditionOperatorNotSupported,
        },
      );
      final operatorError = typeErrors.singleWhere(
        (diagnostic) =>
            diagnostic.code ==
            StoryDiagnosticCode.typeConditionOperatorNotSupported,
      );
      expect(
        operatorError.location.pathString,
        'events[0].availabilityCondition.operator',
      );
    });

    test('set effect value must match the declared variable type', () {
      final variableId = StoryVariableId('variable_set_type');
      final eventId = StoryEventId('event_set_type');
      final project = StoryProject(
        id: StoryProjectId('project_set_type'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(0),
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            entryEffects: [
              StorySetVariableEffect(
                variableId: variableId,
                value: StoryNumberValue(1.5),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(diagnostic.code, StoryDiagnosticCode.typeEffectValueMismatch);
      expect(diagnostic.location.pathString, 'events[0].entryEffects[0].value');
      expect(diagnostic.location.kind, StoryDiagnosticLocationKind.effect);
    });

    test('increment and decrement require a numeric declared target', () {
      final variableId = StoryVariableId('variable_non_numeric_target');
      final eventId = StoryEventId('event_non_numeric_target');
      final choiceId = StoryChoiceId('choice_non_numeric_target');
      final project = StoryProject(
        id: StoryProjectId('project_non_numeric_target'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(false),
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
            choices: [
              StoryChoice(
                id: choiceId,
                effects: [
                  StoryDecrementVariableEffect(
                    variableId: variableId,
                    amount: StoryNumberValue(1.0),
                  ),
                ],
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final targetErrors = report.errors
          .where(
            (diagnostic) =>
                diagnostic.code ==
                StoryDiagnosticCode.typeNumericEffectTargetNotNumeric,
          )
          .toList();

      expect(targetErrors, hasLength(2));
      expect(
        targetErrors.map((diagnostic) => diagnostic.location.pathString),
        [
          'events[0].choices[0].effects[0].variableId',
          'events[0].entryEffects[0].variableId',
        ],
      );
      expect(
        targetErrors.every(
          (diagnostic) =>
              diagnostic.relatedLocations.single.pathString ==
              'stateSchema.variables[0].type',
        ),
        isTrue,
      );
    });

    test('numeric effect amount must match the numeric target type', () {
      final integerId = StoryVariableId('variable_integer_target');
      final numberId = StoryVariableId('variable_number_target');
      final eventId = StoryEventId('event_numeric_amounts');
      final project = StoryProject(
        id: StoryProjectId('project_numeric_amounts'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: integerId,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(0),
            ),
            StoryVariableDefinition(
              id: numberId,
              type: StoryValueType.number,
              initialValue: StoryNumberValue(0.0),
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            entryEffects: [
              StoryIncrementVariableEffect(
                variableId: integerId,
                amount: StoryNumberValue(1.0),
              ),
              StoryDecrementVariableEffect(
                variableId: numberId,
                amount: StoryIntegerValue(1),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final amountErrors = report.errors
          .where(
            (diagnostic) =>
                diagnostic.code ==
                StoryDiagnosticCode.typeNumericEffectAmountMismatch,
          )
          .toList();

      expect(amountErrors, hasLength(2));
      expect(
        amountErrors.map((diagnostic) => diagnostic.location.pathString),
        [
          'events[0].entryEffects[0].amount',
          'events[0].entryEffects[1].amount',
        ],
      );
    });

    test('semantic validation traverses nested transition conditions', () {
      final variableId = StoryVariableId('variable_nested_type');
      final eventId = StoryEventId('event_nested_type');
      final choiceId = StoryChoiceId('choice_nested_type');
      final project = StoryProject(
        id: StoryProjectId('project_nested_type'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(0),
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryWeightedTransition(
                  options: [
                    StoryWeightedTransitionOption(
                      weight: 1,
                      transition: StoryConditionalTransition(
                        branches: [
                          StoryConditionalTransitionBranch(
                            condition: StoryNotCondition(
                              StoryVariableComparisonCondition(
                                variableId: variableId,
                                operator: StoryComparisonOperator.equal,
                                value: StoryNumberValue(2.0),
                              ),
                            ),
                            transition: const StoryTerminalTransition(),
                          ),
                        ],
                        fallback: const StoryTerminalTransition(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.errors.single;

      expect(
        diagnostic.code,
        StoryDiagnosticCode.typeConditionOperandMismatch,
      );
      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].transition.options[0].transition.branches[0].'
        'condition.condition.value',
      );
      expect(diagnostic.location.eventId, eventId);
      expect(diagnostic.location.choiceId, choiceId);
    });

    test('undeclared references do not receive speculative type errors', () {
      final missingId = StoryVariableId('variable_missing_semantic');
      final eventId = StoryEventId('event_missing_semantic');
      final project = StoryProject(
        id: StoryProjectId('project_missing_semantic'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryVariableComparisonCondition(
              variableId: missingId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            entryEffects: [
              StorySetVariableEffect(
                variableId: missingId,
                value: const StoryStringValue('unknown'),
              ),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(2));
      expect(
        report.errors.map((diagnostic) => diagnostic.code).toSet(),
        {
          StoryDiagnosticCode.referenceUndeclaredConditionVariable,
          StoryDiagnosticCode.referenceUndeclaredEffectVariable,
        },
      );
    });

    test('valid scalar condition/effect semantics pass Stage 3D', () {
      final flagId = StoryVariableId('variable_valid_flag');
      final countId = StoryVariableId('variable_valid_count');
      final scoreId = StoryVariableId('variable_valid_score');
      final labelId = StoryVariableId('variable_valid_label');
      final eventId = StoryEventId('event_valid_semantics');
      final project = StoryProject(
        id: StoryProjectId('project_valid_semantics'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: flagId,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(false),
            ),
            StoryVariableDefinition(
              id: countId,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(1),
            ),
            StoryVariableDefinition(
              id: scoreId,
              type: StoryValueType.number,
              initialValue: StoryNumberValue(2.5),
            ),
            StoryVariableDefinition(
              id: labelId,
              type: StoryValueType.string,
              initialValue: const StoryStringValue('start'),
            ),
          ],
        ),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryAllCondition([
              StoryVariableComparisonCondition(
                variableId: flagId,
                operator: StoryComparisonOperator.equal,
                value: const StoryBooleanValue(false),
              ),
              StoryVariableComparisonCondition(
                variableId: countId,
                operator: StoryComparisonOperator.greaterThanOrEqual,
                value: StoryIntegerValue(1),
              ),
              StoryVariableComparisonCondition(
                variableId: labelId,
                operator: StoryComparisonOperator.notEqual,
                value: const StoryStringValue('done'),
              ),
            ]),
            entryEffects: [
              StorySetVariableEffect(
                variableId: flagId,
                value: const StoryBooleanValue(true),
              ),
              StoryIncrementVariableEffect(
                variableId: countId,
                amount: StoryIntegerValue(1),
              ),
              StoryDecrementVariableEffect(
                variableId: scoreId,
                amount: StoryNumberValue(0.5),
              ),
              StoryUnsetVariableEffect(variableId: labelId),
            ],
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, isEmpty);
      expect(report.isValid, isTrue);
    });

    test('Lantern Mystery has no Stage 3D type/semantic errors', () {
      final report = StoryValidator.validate(LanternMysteryFixture.buildProject());

      expect(report.errors, isEmpty);
    });

    test('constructor-owned semantic invariants remain constructor-owned', () {
      final variableId = StoryVariableId('variable_constructor_boundary');

      expect(
        () => StoryVariableDefinition(
          id: variableId,
          type: StoryValueType.boolean,
          initialValue: StoryIntegerValue(1),
        ),
        throwsArgumentError,
      );
      expect(() => StoryAllCondition(const []), throwsArgumentError);
      expect(
        () => StoryIncrementVariableEffect(
          variableId: variableId,
          amount: const StoryBooleanValue(true),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryWeightedTransitionOption(
          weight: 0,
          transition: const StoryTerminalTransition(),
        ),
        throwsArgumentError,
      );
      expect(() => StoryNumberValue(double.nan), throwsArgumentError);
    });
  });
}
