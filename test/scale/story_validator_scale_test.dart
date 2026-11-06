import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';
import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 3I validation at scale', () {
    test(
      'Lantern Mystery has only deliberately accepted non-blocking findings',
      () {
        final report = StoryValidator.validate(
          LanternMysteryFixture.buildProject(),
        );
        final unexpected = report.diagnostics
            .where(
              (diagnostic) => !_lanternAcceptedCodes.contains(diagnostic.code),
            )
            .toList();

        expect(report.errors, isEmpty);
        expect(unexpected, isEmpty);
        expect(
          report.warnings.any(
            (diagnostic) =>
                diagnostic.code == StoryDiagnosticCode.stateReadMayBeUnset,
          ),
          isTrue,
        );
        expect(
          report.information.any(
            (diagnostic) =>
                diagnostic.code == StoryDiagnosticCode.graphInteractiveCycle,
          ),
          isTrue,
        );
      },
    );

    test(
      'structured small/medium/large profiles validate at declared scale',
      () {
        const expectations =
            <SyntheticStoryProfile, ({int events, int choices})>{
              SyntheticStoryProfile.small: (events: 100, choices: 389),
              SyntheticStoryProfile.medium: (events: 500, choices: 1949),
              SyntheticStoryProfile.large: (events: 1000, choices: 4876),
            };

        for (final entry in expectations.entries) {
          final fixture = SyntheticStoryProjectGenerator.structured(entry.key);
          final stopwatch = Stopwatch()..start();
          final report = StoryValidator.validate(fixture.project);
          stopwatch.stop();

          expect(fixture.metrics.eventCount, entry.value.events);
          expect(fixture.metrics.choiceCount, entry.value.choices);
          expect(report.errors, isEmpty, reason: entry.key.name);
          expect(
            _coreValidityDiagnostics(report),
            isEmpty,
            reason: entry.key.name,
          );

          // Stage 3I observes wall-clock cost but intentionally does not enforce
          // machine-specific millisecond thresholds. The output is diagnostic
          // only and can be inspected during local/CI runs.
          // ignore: avoid_print
          print(
            'Stage 3I validation observation: ${entry.key.name} '
            '${entry.value.events} events / ${entry.value.choices} choices -> '
            '${stopwatch.elapsedMicroseconds} us, '
            '${report.diagnostics.length} diagnostics',
          );
        }
      },
    );

    test(
      'large structured validation is deterministic across repeated runs',
      () {
        final fixture = SyntheticStoryProjectGenerator.structured(
          SyntheticStoryProfile.large,
        );

        final first = StoryValidator.validate(fixture.project);
        final second = StoryValidator.validate(fixture.project);

        expect(second.diagnostics, first.diagnostics);
      },
    );

    test('24 randomized valid fixtures have no core validity diagnostics', () {
      for (var seed = 0; seed < 24; seed++) {
        final fixture = SyntheticStoryProjectGenerator.randomized(seed: seed);
        final report = StoryValidator.validate(fixture.project);

        expect(
          report.errors,
          isEmpty,
          reason: 'Randomized valid seed $seed produced validation errors.',
        );
        expect(
          _coreValidityDiagnostics(report),
          isEmpty,
          reason:
              'Randomized valid seed $seed produced structural/reference/'
              'type diagnostics.',
        );
      }
    });

    test('24 default-scale malformed fixtures detect every injected fault', () {
      final observedFaults = <SyntheticStoryFault>{};

      for (var seed = 0; seed < 24; seed++) {
        final fixture = SyntheticStoryProjectGenerator.invalid(seed: seed);
        final metadata = fixture.faults.single;
        final report = StoryValidator.validate(fixture.project);

        observedFaults.add(metadata.fault);
        expect(
          report.diagnostics.any(
            (diagnostic) =>
                diagnostic.code == metadata.expectedDiagnosticCode &&
                diagnostic.severity == metadata.expectedSeverity &&
                diagnostic.location.pathString == metadata.targetPath,
          ),
          isTrue,
          reason:
              'Default-scale seed $seed injected ${metadata.fault.token}; '
              'expected ${metadata.expectedDiagnosticCode.value} at '
              '${metadata.targetPath}.',
        );
      }

      expect(observedFaults, SyntheticStoryFault.values.toSet());
    });
  });
}

final _lanternAcceptedCodes = <StoryDiagnosticCode>{
  StoryDiagnosticCode.stateReadMayBeUnset,
  StoryDiagnosticCode.graphInteractiveCycle,
  StoryDiagnosticCode.graphMixedCycle,
};

Iterable<StoryDiagnostic> _coreValidityDiagnostics(
  StoryValidationReport report,
) => report.diagnostics.where((diagnostic) {
  final value = diagnostic.code.value;
  return value.startsWith('structure.') ||
      value.startsWith('identity.') ||
      value.startsWith('reference.') ||
      value.startsWith('type.');
});
