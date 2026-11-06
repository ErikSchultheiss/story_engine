import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 3C reference validation', () {
    test('engine-owned Stage 3C diagnostic code tokens stay stable', () {
      expect(
        [
          StoryDiagnosticCode.referenceMissingTransitionDestination.value,
          StoryDiagnosticCode.referenceUndeclaredConditionVariable.value,
          StoryDiagnosticCode.referenceUndeclaredEffectVariable.value,
        ],
        [
          'reference.missing_transition_destination',
          'reference.undeclared_condition_variable',
          'reference.undeclared_effect_variable',
        ],
      );
    });

    test('direct transition to a missing event is an error', () {
      final sourceId = StoryEventId('event_source');
      final missingId = StoryEventId('event_missing');
      final choiceId = StoryChoiceId('choice_missing_destination');
      final project = StoryProject(
        id: StoryProjectId('project_missing_destination'),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryEventTransition(destinationEventId: missingId),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.referenceMissingTransitionDestination,
      );
      expect(diagnostic.location.kind, StoryDiagnosticLocationKind.transition);
      expect(diagnostic.location.eventId, sourceId);
      expect(diagnostic.location.choiceId, choiceId);
      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].transition.destinationEventId',
      );
      expect(diagnostic.references, [
        StoryDiagnosticReference.event(missingId),
      ]);
    });

    test('conditions are traversed recursively at arbitrary Boolean depth', () {
      final eventId = StoryEventId('event_nested_condition');
      final missingVariableId = StoryVariableId('variable_missing');
      final project = StoryProject(
        id: StoryProjectId('project_nested_condition_reference'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            availabilityCondition: StoryAllCondition([
              StoryNotCondition(
                StoryAnyCondition([
                  StoryVariableIsSetCondition(variableId: missingVariableId),
                ]),
              ),
            ]),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.referenceUndeclaredConditionVariable,
      );
      expect(diagnostic.location.kind, StoryDiagnosticLocationKind.condition);
      expect(
        diagnostic.location.pathString,
        'events[0].availabilityCondition.conditions[0].condition.'
        'conditions[0].variableId',
      );
      expect(diagnostic.references, [
        StoryDiagnosticReference.variable(missingVariableId),
      ]);
    });

    test('choice availability carries the enclosing choice location', () {
      final eventId = StoryEventId('event_choice_condition');
      final choiceId = StoryChoiceId('choice_condition');
      final missingVariableId = StoryVariableId('variable_choice_missing');
      final project = StoryProject(
        id: StoryProjectId('project_choice_condition_reference'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: choiceId,
                availabilityCondition: StoryVariableIsUnsetCondition(
                  variableId: missingVariableId,
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.referenceUndeclaredConditionVariable,
      );
      expect(diagnostic.location.choiceId, choiceId);
      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].availabilityCondition.variableId',
      );
    });

    test('event and choice effects validate every variable reference', () {
      final eventId = StoryEventId('event_effects');
      final choiceId = StoryChoiceId('choice_effects');
      final missingSet = StoryVariableId('variable_missing_set');
      final missingUnset = StoryVariableId('variable_missing_unset');
      final missingIncrement = StoryVariableId('variable_missing_increment');
      final missingDecrement = StoryVariableId('variable_missing_decrement');
      final project = StoryProject(
        id: StoryProjectId('project_effect_references'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            entryEffects: [
              StorySetVariableEffect(
                variableId: missingSet,
                value: const StoryBooleanValue(true),
              ),
              StoryUnsetVariableEffect(variableId: missingUnset),
            ],
            choices: [
              StoryChoice(
                id: choiceId,
                effects: [
                  StoryIncrementVariableEffect(
                    variableId: missingIncrement,
                    amount: StoryIntegerValue(1),
                  ),
                  StoryDecrementVariableEffect(
                    variableId: missingDecrement,
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
      final referenceErrors = report.errors
          .where(
            (diagnostic) =>
                diagnostic.code ==
                StoryDiagnosticCode.referenceUndeclaredEffectVariable,
          )
          .toList();

      expect(referenceErrors, hasLength(4));
      expect(
        referenceErrors.map((diagnostic) => diagnostic.location.pathString),
        [
          'events[0].choices[0].effects[0].variableId',
          'events[0].choices[0].effects[1].variableId',
          'events[0].entryEffects[0].variableId',
          'events[0].entryEffects[1].variableId',
        ],
      );
      expect(
        referenceErrors[0].location.kind,
        StoryDiagnosticLocationKind.effect,
      );
      expect(referenceErrors[0].location.choiceId, choiceId);
    });

    test('conditional and weighted transition trees are fully recursive', () {
      final sourceId = StoryEventId('event_nested_transition_source');
      final existingId = StoryEventId('event_existing_destination');
      final missingId = StoryEventId('event_deep_missing');
      final missingVariableId = StoryVariableId('variable_deep_missing');
      final choiceId = StoryChoiceId('choice_nested_transition');
      final project = StoryProject(
        id: StoryProjectId('project_nested_transition_references'),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
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
                            condition: StoryVariableComparisonCondition(
                              variableId: missingVariableId,
                              operator: StoryComparisonOperator.equal,
                              value: const StoryBooleanValue(true),
                            ),
                            transition: StoryWeightedTransition(
                              options: [
                                StoryWeightedTransitionOption(
                                  weight: 1,
                                  transition: StoryEventTransition(
                                    destinationEventId: missingId,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        fallback: StoryEventTransition(
                          destinationEventId: existingId,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          StoryEvent(
            id: existingId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(2));
      final conditionError = report.errors.singleWhere(
        (diagnostic) =>
            diagnostic.code ==
            StoryDiagnosticCode.referenceUndeclaredConditionVariable,
      );
      final destinationError = report.errors.singleWhere(
        (diagnostic) =>
            diagnostic.code ==
            StoryDiagnosticCode.referenceMissingTransitionDestination,
      );

      expect(
        conditionError.location.pathString,
        'events[0].choices[0].transition.options[0].transition.branches[0].'
        'condition.variableId',
      );
      expect(
        destinationError.location.pathString,
        'events[0].choices[0].transition.options[0].transition.branches[0].'
        'transition.options[0].transition.destinationEventId',
      );
    });

    test('conditional fallback transition is inspected', () {
      final flagId = StoryVariableId('variable_fallback_flag');
      final sourceId = StoryEventId('event_fallback_source');
      final missingId = StoryEventId('event_fallback_missing');
      final project = StoryProject(
        id: StoryProjectId('project_fallback_reference'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: flagId,
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(true),
            ),
          ],
        ),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_fallback_reference'),
                transition: StoryConditionalTransition(
                  branches: [
                    StoryConditionalTransitionBranch(
                      condition: StoryVariableIsSetCondition(
                        variableId: flagId,
                      ),
                      transition: const StoryTerminalTransition(),
                    ),
                  ],
                  fallback: StoryEventTransition(destinationEventId: missingId),
                ),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      final diagnostic = report.errors.single;
      expect(
        diagnostic.code,
        StoryDiagnosticCode.referenceMissingTransitionDestination,
      );
      expect(
        diagnostic.location.pathString,
        'events[0].choices[0].transition.fallback.destinationEventId',
      );
    });

    test('continuation and automatic transitions are both inspected', () {
      final continuationId = StoryEventId('event_continuation_reference');
      final automaticId = StoryEventId('event_automatic_reference');
      final missingContinuationId = StoryEventId('event_missing_continuation');
      final missingAutomaticId = StoryEventId('event_missing_automatic');
      final project = StoryProject(
        id: StoryProjectId('project_event_transition_references'),
        entryEventId: continuationId,
        events: [
          StoryEvent(
            id: continuationId,
            continuationTransition: StoryEventTransition(
              destinationEventId: missingContinuationId,
            ),
          ),
          StoryEvent(
            id: automaticId,
            automaticTransition: StoryEventTransition(
              destinationEventId: missingAutomaticId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final missingDestinations = report.errors
          .where(
            (diagnostic) =>
                diagnostic.code ==
                StoryDiagnosticCode.referenceMissingTransitionDestination,
          )
          .toList();

      expect(missingDestinations, hasLength(2));
      expect(
        missingDestinations.map((diagnostic) => diagnostic.location.pathString),
        [
          'events[0].continuationTransition.destinationEventId',
          'events[1].automaticTransition.destinationEventId',
        ],
      );
    });

    test('declared references across all authored contexts pass Stage 3C', () {
      final flagId = StoryVariableId('variable_flag');
      final countId = StoryVariableId('variable_count');
      final sourceId = StoryEventId('event_valid_source');
      final destinationId = StoryEventId('event_valid_destination');
      final project = StoryProject(
        id: StoryProjectId('project_valid_references'),
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
              initialValue: StoryIntegerValue(0),
            ),
          ],
        ),
        entryEventId: sourceId,
        events: [
          StoryEvent(
            id: sourceId,
            availabilityCondition: StoryVariableIsSetCondition(
              variableId: flagId,
            ),
            entryEffects: [
              StorySetVariableEffect(
                variableId: flagId,
                value: const StoryBooleanValue(true),
              ),
            ],
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_valid_references'),
                availabilityCondition: StoryVariableComparisonCondition(
                  variableId: countId,
                  operator: StoryComparisonOperator.equal,
                  value: StoryIntegerValue(0),
                ),
                effects: [
                  StoryIncrementVariableEffect(
                    variableId: countId,
                    amount: StoryIntegerValue(1),
                  ),
                ],
                transition: StoryConditionalTransition(
                  branches: [
                    StoryConditionalTransitionBranch(
                      condition: StoryVariableIsSetCondition(
                        variableId: flagId,
                      ),
                      transition: StoryWeightedTransition(
                        options: [
                          StoryWeightedTransitionOption(
                            weight: 1,
                            transition: StoryEventTransition(
                              destinationEventId: destinationId,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  fallback: StoryEventTransition(
                    destinationEventId: destinationId,
                  ),
                ),
              ),
            ],
          ),
          StoryEvent(
            id: destinationId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (diagnostic) => diagnostic.code.value.startsWith('reference.'),
        ),
        isEmpty,
      );
      expect(report.isValid, isTrue);
    });

    test('entry-event reference remains the single Stage 3B diagnostic', () {
      final existingId = StoryEventId('event_existing');
      final missingEntryId = StoryEventId('event_missing_entry');
      final project = StoryProject(
        id: StoryProjectId('project_bad_entry_only'),
        entryEventId: missingEntryId,
        events: [
          StoryEvent(
            id: existingId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(report.errors, hasLength(1));
      expect(
        report.errors.single.code,
        StoryDiagnosticCode.structureEntryEventNotFound,
      );
    });
  });
}
