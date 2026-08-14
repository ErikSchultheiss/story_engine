import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 3H deterministic malformed-project generation', () {
    test('fault metadata tokens stay stable and representable-only', () {
      expect(
        SyntheticStoryFault.values.map((fault) => fault.token).toList(),
        [
          'missing_destination',
          'duplicate_event_id',
          'duplicate_choice_id',
          'undeclared_variable_reference',
          'wrong_condition_value_type',
          'wrong_effect_value_type',
          'missing_entry_event',
          'ambiguous_event_flow',
          'incomplete_choice',
          'automatic_cycle',
          'unreachable_event',
          'potentially_uninitialized_variable',
        ],
      );
    });

    test('randomized base fixtures remain validator-error free', () {
      for (final seed in [0, 1, 7, 17, 42, 255]) {
        final base = SyntheticStoryProjectGenerator.randomized(
          seed: seed,
          eventCount: 64,
          variableCount: 16,
        );

        expect(
          StoryValidator.validate(base.project).errors,
          isEmpty,
          reason: 'Seed $seed must be valid before Stage 3H fault injection.',
        );
      }
    });

    test('48 deterministic seeds detect every injected default fault', () {
      final observedFaults = <SyntheticStoryFault>{};

      for (var seed = 0; seed < 48; seed++) {
        final fixture = SyntheticStoryProjectGenerator.invalid(
          seed: seed,
          eventCount: 64,
          variableCount: 16,
        );
        final expectedFault = SyntheticStoryFault.values[
          seed % SyntheticStoryFault.values.length
        ];
        final metadata = fixture.faults.single;
        final report = StoryValidator.validate(fixture.project);
        final matching = report.diagnostics
            .where(
              (diagnostic) =>
                  diagnostic.code == metadata.expectedDiagnosticCode &&
                  diagnostic.severity == metadata.expectedSeverity &&
                  diagnostic.location.pathString == metadata.targetPath,
            )
            .toList();

        observedFaults.add(metadata.fault);
        expect(metadata.fault, expectedFault, reason: 'Generator seed $seed');
        expect(metadata.targetPath, isNotEmpty, reason: 'Generator seed $seed');
        expect(metadata.description, isNotEmpty, reason: 'Generator seed $seed');
        expect(
          matching,
          isNotEmpty,
          reason: 'Seed $seed injected ${metadata.fault.token}; expected '
              '${metadata.expectedDiagnosticCode.value} '
              '(${metadata.expectedSeverity.name}).',
        );
      }

      expect(observedFaults, SyntheticStoryFault.values.toSet());
    });

    test('same seed and explicit fault set reproduce byte-for-byte signature', () {
      const faults = [
        SyntheticStoryFault.missingDestination,
        SyntheticStoryFault.wrongEffectValueType,
        SyntheticStoryFault.incompleteChoice,
        SyntheticStoryFault.potentiallyUninitializedVariable,
      ];
      final first = SyntheticStoryProjectGenerator.invalid(
        seed: 42,
        faults: faults,
        eventCount: 64,
        variableCount: 16,
      );
      final second = SyntheticStoryProjectGenerator.invalid(
        seed: 42,
        faults: faults.reversed,
        eventCount: 64,
        variableCount: 16,
      );

      expect(first.baseSignature, second.baseSignature);
      expect(first.signature, second.signature);
      expect(first.faults, second.faults);
      expect(
        first.faults.map((metadata) => metadata.fault).toList(),
        [
          SyntheticStoryFault.missingDestination,
          SyntheticStoryFault.wrongEffectValueType,
          SyntheticStoryFault.incompleteChoice,
          SyntheticStoryFault.potentiallyUninitializedVariable,
        ],
      );

      final report = StoryValidator.validate(first.project);
      for (final metadata in first.faults) {
        expect(
          report.diagnostics.any(
            (diagnostic) =>
                diagnostic.code == metadata.expectedDiagnosticCode &&
                diagnostic.severity == metadata.expectedSeverity &&
                diagnostic.location.pathString == metadata.targetPath,
          ),
          isTrue,
          reason: 'Missing expected multi-fault diagnostic '
              '${metadata.expectedDiagnosticCode.value}.',
        );
      }
    });

    test('fault injection changes the valid base signature', () {
      for (final fault in SyntheticStoryFault.values) {
        final fixture = SyntheticStoryProjectGenerator.invalid(
          seed: 9,
          faults: [fault],
          eventCount: 64,
          variableCount: 16,
        );

        expect(
          fixture.signature,
          isNot(equals(fixture.baseSignature)),
          reason: 'Fault ${fault.token} must structurally change the fixture.',
        );
      }
    });

    test('continuation transitions participate in structural signatures', () {
      final firstId = StoryEventId('event_signature_first');
      final secondId = StoryEventId('event_signature_second');
      final terminalProject = StoryProject(
        id: StoryProjectId('project_signature_continuation'),
        entryEventId: firstId,
        events: [
          StoryEvent(
            id: firstId,
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: secondId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final destinationProject = StoryProject(
        id: StoryProjectId('project_signature_continuation'),
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
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(
        syntheticProjectSignature(terminalProject),
        isNot(equals(syntheticProjectSignature(destinationProject))),
      );
    });

    test('empty, duplicate, and diagnostic-suppressing fault sets are rejected', () {
      expect(
        () => SyntheticStoryProjectGenerator.invalid(seed: 1, faults: const []),
        throwsArgumentError,
      );
      expect(
        () => SyntheticStoryProjectGenerator.invalid(
          seed: 1,
          faults: const [
            SyntheticStoryFault.missingDestination,
            SyntheticStoryFault.missingDestination,
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SyntheticStoryProjectGenerator.invalid(
          seed: 1,
          faults: const [
            SyntheticStoryFault.missingEntryEvent,
            SyntheticStoryFault.automaticCycle,
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SyntheticStoryProjectGenerator.invalid(
          seed: 1,
          faults: const [
            SyntheticStoryFault.duplicateEventId,
            SyntheticStoryFault.unreachableEvent,
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
