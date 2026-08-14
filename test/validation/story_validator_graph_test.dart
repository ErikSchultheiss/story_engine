import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  group('Stage 3F graph and reachability validation', () {
    test('engine-owned Stage 3F diagnostic code tokens stay stable', () {
      expect(
        [
          StoryDiagnosticCode.graphUnreachableEvent.value,
          StoryDiagnosticCode.graphInteractiveCycle.value,
          StoryDiagnosticCode.graphContinuationCycle.value,
          StoryDiagnosticCode.graphAutomaticCycle.value,
          StoryDiagnosticCode.graphMixedCycle.value,
          StoryDiagnosticCode.graphEventCannotReachTermination.value,
        ],
        [
          'graph.unreachable_event',
          'graph.interactive_cycle',
          'graph.continuation_cycle',
          'graph.automatic_cycle',
          'graph.mixed_cycle',
          'graph.event_cannot_reach_termination',
        ],
      );
    });

    test('event with no structural path from entry is a warning', () {
      final entryId = StoryEventId('event_entry');
      final orphanId = StoryEventId('event_orphan');
      final project = StoryProject(
        id: StoryProjectId('project_unreachable'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: orphanId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.warnings.singleWhere(
        (item) => item.code == StoryDiagnosticCode.graphUnreachableEvent,
      );

      expect(diagnostic.location.pathString, 'events[1]');
      expect(diagnostic.location.eventId, orphanId);
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.event(orphanId)],
      );
    });

    test('nested conditional and weighted branches all count as reachable', () {
      final entryId = StoryEventId('event_nested_entry');
      final branchId = StoryEventId('event_nested_branch');
      final weightedId = StoryEventId('event_nested_weighted');
      final project = StoryProject(
        id: StoryProjectId('project_nested_reachability'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: StoryVariableId('variable_nested_reachability'),
              type: StoryValueType.boolean,
              initialValue: const StoryBooleanValue(true),
            ),
          ],
        ),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            automaticTransition: StoryConditionalTransition(
              branches: [
                StoryConditionalTransitionBranch(
                  condition: StoryVariableComparisonCondition(
                    variableId: StoryVariableId(
                      'variable_nested_reachability',
                    ),
                    operator: StoryComparisonOperator.equal,
                    value: const StoryBooleanValue(true),
                  ),
                  transition: StoryEventTransition(
                    destinationEventId: branchId,
                  ),
                ),
              ],
              fallback: StoryWeightedTransition(
                options: [
                  StoryWeightedTransitionOption(
                    weight: 1,
                    transition: StoryEventTransition(
                      destinationEventId: weightedId,
                    ),
                  ),
                  StoryWeightedTransitionOption(
                    weight: 1,
                    transition: const StoryTerminalTransition(),
                  ),
                ],
              ),
            ),
          ),
          StoryEvent(
            id: branchId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: weightedId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.diagnostics.where(
          (item) => item.code == StoryDiagnosticCode.graphUnreachableEvent,
        ),
        isEmpty,
      );
    });

    test('ambiguous event still contributes authored edges to reachability', () {
      final entryId = StoryEventId('event_ambiguous_graph_entry');
      final choiceDestinationId = StoryEventId('event_choice_destination');
      final automaticDestinationId = StoryEventId('event_auto_destination');
      final project = StoryProject(
        id: StoryProjectId('project_ambiguous_graph_reachability'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_ambiguous_graph'),
                transition: StoryEventTransition(
                  destinationEventId: choiceDestinationId,
                ),
              ),
            ],
            automaticTransition: StoryEventTransition(
              destinationEventId: automaticDestinationId,
            ),
          ),
          StoryEvent(
            id: choiceDestinationId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: automaticDestinationId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.errors.singleWhere(
          (item) => item.code == StoryDiagnosticCode.structureEventAmbiguousFlow,
        ),
        isNotNull,
      );
      expect(
        report.diagnostics.where(
          (item) => item.code == StoryDiagnosticCode.graphUnreachableEvent,
        ),
        isEmpty,
      );
    });

    test('reachable automatic self-cycle is an error', () {
      final eventId = StoryEventId('event_automatic_self_cycle');
      final project = StoryProject(
        id: StoryProjectId('project_automatic_self_cycle'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            automaticTransition: StoryEventTransition(
              destinationEventId: eventId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.errors.singleWhere(
        (item) => item.code == StoryDiagnosticCode.graphAutomaticCycle,
      );

      expect(diagnostic.location.pathString, 'events[0]');
      expect(
        diagnostic.references,
        [StoryDiagnosticReference.event(eventId)],
      );
      expect(
        report.diagnostics.where(
          (item) =>
              item.code == StoryDiagnosticCode.graphEventCannotReachTermination,
        ),
        isEmpty,
      );
    });

    test('reachable multi-event automatic cycle reports one SCC error', () {
      final firstId = StoryEventId('event_auto_cycle_first');
      final secondId = StoryEventId('event_auto_cycle_second');
      final project = StoryProject(
        id: StoryProjectId('project_auto_cycle_multi'),
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            automaticTransition: StoryEventTransition(
              destinationEventId: secondId,
            ),
          ),
          StoryEvent(
            id: secondId,
            automaticTransition: StoryEventTransition(
              destinationEventId: firstId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final diagnostic = report.errors.singleWhere(
        (item) => item.code == StoryDiagnosticCode.graphAutomaticCycle,
      );

      expect(diagnostic.location.pathString, 'events[0]');
      expect(
        diagnostic.references,
        [
          StoryDiagnosticReference.event(firstId),
          StoryDiagnosticReference.event(secondId),
        ],
      );
      expect(diagnostic.relatedLocations, hasLength(1));
      expect(diagnostic.relatedLocations.single.pathString, 'events[1]');
    });

    test('continuation cycle is warning rather than automatic error', () {
      final firstId = StoryEventId('event_continue_cycle_first');
      final secondId = StoryEventId('event_continue_cycle_second');
      final project = StoryProject(
        id: StoryProjectId('project_continue_cycle'),
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            continuationTransition: StoryEventTransition(
              destinationEventId: secondId,
            ),
          ),
          StoryEvent(
            id: secondId,
            continuationTransition: StoryEventTransition(
              destinationEventId: firstId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.warnings.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphContinuationCycle,
        ).location.pathString,
        'events[0]',
      );
      expect(
        report.errors.where(
          (item) => item.code == StoryDiagnosticCode.graphAutomaticCycle,
        ),
        isEmpty,
      );
    });

    test('interactive cycle is information and can still have terminal exit', () {
      final firstId = StoryEventId('event_interactive_cycle_first');
      final secondId = StoryEventId('event_interactive_cycle_second');
      final project = StoryProject(
        id: StoryProjectId('project_interactive_cycle'),
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_interactive_loop_forward'),
                transition: StoryEventTransition(
                  destinationEventId: secondId,
                ),
              ),
              StoryChoice(
                id: StoryChoiceId('choice_interactive_finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
          StoryEvent(
            id: secondId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_interactive_loop_back'),
                transition: StoryEventTransition(
                  destinationEventId: firstId,
                ),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.information.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphInteractiveCycle,
        ).location.pathString,
        'events[0]',
      );
      expect(
        report.diagnostics.where(
          (item) =>
              item.code == StoryDiagnosticCode.graphEventCannotReachTermination,
        ),
        isEmpty,
      );
    });

    test('mixed automatic and continuation cycle is non-blocking information', () {
      final automaticId = StoryEventId('event_mixed_automatic');
      final continuationId = StoryEventId('event_mixed_continuation');
      final project = StoryProject(
        id: StoryProjectId('project_mixed_cycle'),
        entryEventId: automaticId,
        events: [
          StoryEvent(
            id: automaticId,
            automaticTransition: StoryEventTransition(
              destinationEventId: continuationId,
            ),
          ),
          StoryEvent(
            id: continuationId,
            continuationTransition: StoryEventTransition(
              destinationEventId: automaticId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.information.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphMixedCycle,
        ).location.pathString,
        'events[0]',
      );
      expect(
        report.errors.where(
          (item) => item.code == StoryDiagnosticCode.graphAutomaticCycle,
        ),
        isEmpty,
      );
    });

    test('automatic subcycle inside a mixed SCC remains an error', () {
      final automaticId = StoryEventId('event_mixed_with_auto_subcycle');
      final continuationId = StoryEventId('event_mixed_with_auto_pause');
      final project = StoryProject(
        id: StoryProjectId('project_mixed_with_auto_subcycle'),
        entryEventId: automaticId,
        events: [
          StoryEvent(
            id: automaticId,
            automaticTransition: StoryWeightedTransition(
              options: [
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: StoryEventTransition(
                    destinationEventId: automaticId,
                  ),
                ),
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: StoryEventTransition(
                    destinationEventId: continuationId,
                  ),
                ),
              ],
            ),
          ),
          StoryEvent(
            id: continuationId,
            continuationTransition: StoryEventTransition(
              destinationEventId: automaticId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.errors.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphAutomaticCycle,
        ).references,
        [StoryDiagnosticReference.event(automaticId)],
      );
      expect(
        report.information.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphMixedCycle,
        ).references,
        [
          StoryDiagnosticReference.event(continuationId),
          StoryDiagnosticReference.event(automaticId),
        ],
      );
    });

    test('acyclic predecessors of closed loop cannot reach termination', () {
      final firstId = StoryEventId('event_nonterm_first');
      final secondId = StoryEventId('event_nonterm_second');
      final loopId = StoryEventId('event_nonterm_loop');
      final project = StoryProject(
        id: StoryProjectId('project_nonterm_predecessors'),
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            automaticTransition: StoryEventTransition(
              destinationEventId: secondId,
            ),
          ),
          StoryEvent(
            id: secondId,
            automaticTransition: StoryEventTransition(
              destinationEventId: loopId,
            ),
          ),
          StoryEvent(
            id: loopId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_nonterm_loop'),
                transition: StoryEventTransition(destinationEventId: loopId),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      final noTermination = report.warnings
          .where(
            (item) =>
                item.code ==
                StoryDiagnosticCode.graphEventCannotReachTermination,
          )
          .toList();

      expect(noTermination, hasLength(3));
      expect(
        noTermination.map((item) => item.location.pathString),
        ['events[0]', 'events[1]', 'events[2]'],
      );
      expect(
        report.information.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphInteractiveCycle,
        ).location.pathString,
        'events[2]',
      );
    });

    test('unreachable automatic cycle is not reported as runtime-cycle error', () {
      final entryId = StoryEventId('event_reachable_terminal');
      final cycleId = StoryEventId('event_unreachable_auto_cycle');
      final project = StoryProject(
        id: StoryProjectId('project_unreachable_auto_cycle'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: cycleId,
            automaticTransition: StoryEventTransition(
              destinationEventId: cycleId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.warnings.singleWhere(
          (item) => item.code == StoryDiagnosticCode.graphUnreachableEvent,
        ).location.pathString,
        'events[1]',
      );
      expect(
        report.errors.where(
          (item) => item.code == StoryDiagnosticCode.graphAutomaticCycle,
        ),
        isEmpty,
      );
    });

    test('missing destination remains Stage 3C-owned nontermination boundary', () {
      final entryId = StoryEventId('event_missing_destination_entry');
      final missingId = StoryEventId('event_missing_destination_target');
      final project = StoryProject(
        id: StoryProjectId('project_missing_destination_boundary'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            automaticTransition: StoryEventTransition(
              destinationEventId: missingId,
            ),
          ),
        ],
      );

      final report = StoryValidator.validate(project);

      expect(
        report.errors.singleWhere(
          (item) =>
              item.code ==
              StoryDiagnosticCode.referenceMissingTransitionDestination,
        ),
        isNotNull,
      );
      expect(
        report.diagnostics.where(
          (item) =>
              item.code == StoryDiagnosticCode.graphEventCannotReachTermination,
        ),
        isEmpty,
      );
    });

    test('unresolved entry and duplicate event IDs suppress graph claims', () {
      final duplicateId = StoryEventId('event_graph_duplicate');
      final duplicateProject = StoryProject(
        id: StoryProjectId('project_graph_duplicate'),
        entryEventId: duplicateId,
        events: [
          StoryEvent(
            id: duplicateId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: duplicateId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final unresolvedProject = StoryProject(
        id: StoryProjectId('project_graph_missing_entry'),
        entryEventId: StoryEventId('event_graph_missing_entry'),
        events: [
          StoryEvent(
            id: StoryEventId('event_graph_other'),
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      for (final report in [
        StoryValidator.validate(duplicateProject),
        StoryValidator.validate(unresolvedProject),
      ]) {
        expect(
          report.diagnostics.where((item) => item.code.value.startsWith('graph.')),
          isEmpty,
        );
      }
    });

    test('Lantern Mystery has no graph errors or graph warnings', () {
      final report = StoryValidator.validate(LanternMysteryFixture.buildProject());

      expect(
        report.errors.where((item) => item.code.value.startsWith('graph.')),
        isEmpty,
      );
      expect(
        report.warnings.where((item) => item.code.value.startsWith('graph.')),
        isEmpty,
      );
      expect(
        report.information.where(
          (item) => item.code == StoryDiagnosticCode.graphInteractiveCycle,
        ),
        isNotEmpty,
      );
    });

    test('Stage 3F diagnostics remain deterministic across repeated validation', () {
      final project = LanternMysteryFixture.buildProject();

      final first = StoryValidator.validate(project);
      final second = StoryValidator.validate(project);

      expect(second.diagnostics, first.diagnostics);
    });
  });
}
