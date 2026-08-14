import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';
import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 3J validation architecture review', () {
    test(
      'engine-owned diagnostic tokens remain stable, unique, and normalized',
      () {
        expect(
          _engineOwnedCodes.map((code) => code.value).toList(),
          _expectedCodeValues,
        );
        expect(_engineOwnedCodes.toSet(), hasLength(_engineOwnedCodes.length));

        final tokenPattern = RegExp(
          r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$',
        );
        for (final code in _engineOwnedCodes) {
          expect(code.value, matches(tokenPattern), reason: code.value);
        }
      },
    );

    test('canonical diagnostics remain deterministic and navigation-ready', () {
      final project = LanternMysteryFixture.buildProject();
      final first = StoryValidator.validate(project);
      final second = StoryValidator.validate(project);

      expect(second.diagnostics, first.diagnostics);
      expect(first.errors, isEmpty);
      expect(first.diagnostics, isNotEmpty);

      for (final diagnostic in first.diagnostics) {
        expect(diagnostic.location.projectId, project.id);
        expect(
          diagnostic.location.path,
          isNotEmpty,
          reason: '${diagnostic.code.value} must identify authored structure.',
        );
        expect(diagnostic.message.trim(), isNotEmpty);
      }
    });

    test(
      'representable malformed projects remain reportable without runtime',
      () {
        for (final fault in SyntheticStoryFault.values) {
          final fixture = SyntheticStoryProjectGenerator.invalid(
            seed: 73,
            faults: [fault],
            eventCount: 64,
            variableCount: 16,
          );

          final report = StoryValidator.validate(fixture.project);
          final expected = fixture.faults.single;

          expect(
            report.diagnostics.any(
              (diagnostic) =>
                  diagnostic.code == expected.expectedDiagnosticCode &&
                  diagnostic.severity == expected.expectedSeverity &&
                  diagnostic.location.pathString == expected.targetPath,
            ),
            isTrue,
            reason: 'Stage 3J review lost ${fault.token}.',
          );

          for (final diagnostic in report.diagnostics) {
            expect(diagnostic.location.projectId, fixture.project.id);
            expect(
              diagnostic.location.path,
              isNotEmpty,
              reason: '${diagnostic.code.value} must be locatable by Studio.',
            );
          }
        }
      },
    );
  });
}

final _engineOwnedCodes = <StoryDiagnosticCode>[
  StoryDiagnosticCode.structureMissingEntryEvent,
  StoryDiagnosticCode.structureEntryEventNotFound,
  StoryDiagnosticCode.identityDuplicateEventId,
  StoryDiagnosticCode.identityDuplicateChoiceId,
  StoryDiagnosticCode.structureChoiceMissingTransition,
  StoryDiagnosticCode.structureEventMissingFlow,
  StoryDiagnosticCode.structureEventAmbiguousFlow,
  StoryDiagnosticCode.referenceMissingTransitionDestination,
  StoryDiagnosticCode.referenceUndeclaredConditionVariable,
  StoryDiagnosticCode.referenceUndeclaredEffectVariable,
  StoryDiagnosticCode.typeConditionOperandMismatch,
  StoryDiagnosticCode.typeConditionOperatorNotSupported,
  StoryDiagnosticCode.typeEffectValueMismatch,
  StoryDiagnosticCode.typeNumericEffectTargetNotNumeric,
  StoryDiagnosticCode.typeNumericEffectAmountMismatch,
  StoryDiagnosticCode.stateReadMayBeUnset,
  StoryDiagnosticCode.stateNumericEffectTargetUnset,
  StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset,
  StoryDiagnosticCode.stateVariableNeverReferenced,
  StoryDiagnosticCode.stateVariableWrittenNeverRead,
  StoryDiagnosticCode.stateVariableReadWithoutInitialization,
  StoryDiagnosticCode.graphUnreachableEvent,
  StoryDiagnosticCode.graphInteractiveCycle,
  StoryDiagnosticCode.graphContinuationCycle,
  StoryDiagnosticCode.graphAutomaticCycle,
  StoryDiagnosticCode.graphMixedCycle,
  StoryDiagnosticCode.graphEventCannotReachTermination,
  StoryDiagnosticCode.presentationChoiceMissingText,
  StoryDiagnosticCode.presentationEventEmptyText,
  StoryDiagnosticCode.presentationContinuationWithoutMeaningfulPresentation,
  StoryDiagnosticCode.presentationAutomaticEventPresentationNotHostVisible,
];

const _expectedCodeValues = <String>[
  'structure.missing_entry_event',
  'structure.entry_event_not_found',
  'identity.duplicate_event_id',
  'identity.duplicate_choice_id',
  'structure.choice_missing_transition',
  'structure.event_missing_flow',
  'structure.event_ambiguous_flow',
  'reference.missing_transition_destination',
  'reference.undeclared_condition_variable',
  'reference.undeclared_effect_variable',
  'type.condition_operand_mismatch',
  'type.condition_operator_not_supported',
  'type.effect_value_mismatch',
  'type.numeric_effect_target_not_numeric',
  'type.numeric_effect_amount_mismatch',
  'state.read_may_be_unset',
  'state.numeric_effect_target_unset',
  'state.numeric_effect_target_may_be_unset',
  'state.variable_never_referenced',
  'state.variable_written_never_read',
  'state.variable_read_without_initialization',
  'graph.unreachable_event',
  'graph.interactive_cycle',
  'graph.continuation_cycle',
  'graph.automatic_cycle',
  'graph.mixed_cycle',
  'graph.event_cannot_reach_termination',
  'presentation.choice_missing_text',
  'presentation.event_empty_text',
  'presentation.continuation_without_meaningful_presentation',
  'presentation.automatic_event_presentation_not_host_visible',
];
