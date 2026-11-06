import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 6G end-to-end scale regression', () {
    test(
      '1,000-event public workflow validates, round-trips, runs, and restores',
      () {
        final fixture = SyntheticStoryProjectGenerator.structured(
          SyntheticStoryProfile.large,
        );
        const formatCodec = StoryFormatCodec();
        final snapshotCodec = StoryRuntimeSnapshotCodec();

        expect(fixture.metrics.eventCount, 1000);
        expect(fixture.metrics.choiceCount, 4876);
        expect(fixture.metrics.variableCount, 250);

        final report = StoryValidator.validate(fixture.project);
        expect(report.errors, isEmpty);

        final bundle = formatCodec.encodeProject(fixture.project);
        final decodedProject = formatCodec.decodeProject(bundle);
        expect(formatCodec.encodeProject(decodedProject), bundle);
        expect(bundle.files, hasLength(1001));

        var engine = StoryEngine(project: decodedProject, randomSeed: 0x6a17)
          ..start();

        const checkpoints = <int>[200, 500, 800];
        var nextCheckpoint = 0;
        var selectedChoices = 0;

        while (engine.status != StoryEngineStatus.terminated) {
          switch (engine.status) {
            case StoryEngineStatus.awaitingChoice:
              final choices = engine.availableChoices;
              expect(choices, isNotEmpty);
              engine.choose(choices.first.id);
              selectedChoices++;

              if (nextCheckpoint < checkpoints.length &&
                  selectedChoices >= checkpoints[nextCheckpoint]) {
                final restored = _roundTrip(
                  project: decodedProject,
                  engine: engine,
                  codec: snapshotCodec,
                );
                _expectCommittedRuntimeParity(restored, engine);
                engine = restored;
                nextCheckpoint++;
              }
              break;

            case StoryEngineStatus.awaitingContinue:
              engine.continueStory();
              break;

            case StoryEngineStatus.notStarted:
              throw StateError(
                'Started scale run unexpectedly returned to notStarted.',
              );

            case StoryEngineStatus.terminated:
              break;
          }
        }

        expect(nextCheckpoint, checkpoints.length);
        expect(selectedChoices, greaterThan(800));
        expect(engine.history.eventRoute.length, lessThanOrEqualTo(1000));

        final terminalRestore = _roundTrip(
          project: decodedProject,
          engine: engine,
          codec: snapshotCodec,
        );
        _expectCommittedRuntimeParity(terminalRestore, engine);
        expect(terminalRestore.status, StoryEngineStatus.terminated);
      },
    );

    test(
      '16 seeded 250-event projects survive the complete public workflow',
      () {
        const formatCodec = StoryFormatCodec();
        final snapshotCodec = StoryRuntimeSnapshotCodec();

        for (var seed = 0; seed < 16; seed++) {
          final fixture = SyntheticStoryProjectGenerator.randomized(
            seed: seed,
            eventCount: 250,
            variableCount: 80,
          );
          final report = StoryValidator.validate(fixture.project);
          expect(report.errors, isEmpty, reason: 'generator seed $seed');

          final bundle = formatCodec.encodeProject(fixture.project);
          final decodedProject = formatCodec.decodeProject(bundle);
          expect(
            formatCodec.encodeProject(decodedProject),
            bundle,
            reason: 'generator seed $seed',
          );

          var engine = StoryEngine(
            project: decodedProject,
            randomSeed: (seed * 7919 + 17) & 0xffffffff,
          )..start();
          var selectedChoices = 0;
          var restoredOnce = false;

          while (engine.status != StoryEngineStatus.terminated) {
            switch (engine.status) {
              case StoryEngineStatus.awaitingChoice:
                final choices = engine.availableChoices;
                expect(choices, isNotEmpty, reason: 'generator seed $seed');
                engine.choose(choices.first.id);
                selectedChoices++;

                if (!restoredOnce && selectedChoices >= 75) {
                  final restored = _roundTrip(
                    project: decodedProject,
                    engine: engine,
                    codec: snapshotCodec,
                  );
                  _expectCommittedRuntimeParity(
                    restored,
                    engine,
                    reason: 'generator seed $seed',
                  );
                  engine = restored;
                  restoredOnce = true;
                }
                break;

              case StoryEngineStatus.awaitingContinue:
                engine.continueStory();
                break;

              case StoryEngineStatus.notStarted:
                throw StateError(
                  'Seed $seed unexpectedly returned to notStarted.',
                );

              case StoryEngineStatus.terminated:
                break;
            }
          }

          expect(restoredOnce, isTrue, reason: 'generator seed $seed');
          expect(engine.history.eventRoute, isNotEmpty, reason: 'seed $seed');
        }
      },
    );

    test('every representable fault remains detectable at 500-event scale', () {
      for (var index = 0; index < SyntheticStoryFault.values.length; index++) {
        final fault = SyntheticStoryFault.values[index];
        final fixture = SyntheticStoryProjectGenerator.invalid(
          seed: 0x6000 + index,
          faults: [fault],
          eventCount: 500,
          variableCount: 120,
        );
        final metadata = fixture.faults.single;
        final report = StoryValidator.validate(fixture.project);

        expect(
          report.diagnostics.any(
            (diagnostic) =>
                diagnostic.code == metadata.expectedDiagnosticCode &&
                diagnostic.severity == metadata.expectedSeverity &&
                diagnostic.location.pathString == metadata.targetPath,
          ),
          isTrue,
          reason:
              '500-event ${fault.token} fixture should preserve its '
              'expected diagnostic identity/location.',
        );
      }
    });
  });

  group('Stage 6G performance-baseline contract', () {
    test(
      'benchmark runner stays opt-in and free of hard timing assertions',
      () {
        final source = File(
          'benchmark/performance_baseline.dart',
        ).readAsStringSync();

        expect(source, contains('Stopwatch'));
        expect(source, contains('--samples='));
        expect(source, contains('--stress-events='));
        expect(source, contains('StoryValidator.validate'));
        expect(source, contains('encodeProject'));
        expect(source, contains('decodeProject'));
        expect(source, contains('StoryRuntimeSnapshotCodec'));
        expect(source, isNot(contains('package:test/test.dart')));
        expect(source, isNot(contains('expect(')));
      },
    );

    test('documented structural baseline remains fixed', () {
      const expected =
          <SyntheticStoryProfile, ({int events, int choices, int variables})>{
            SyntheticStoryProfile.small: (
              events: 100,
              choices: 389,
              variables: 25,
            ),
            SyntheticStoryProfile.medium: (
              events: 500,
              choices: 1949,
              variables: 100,
            ),
            SyntheticStoryProfile.large: (
              events: 1000,
              choices: 4876,
              variables: 250,
            ),
          };

      for (final entry in expected.entries) {
        final fixture = SyntheticStoryProjectGenerator.structured(entry.key);
        expect(fixture.metrics.eventCount, entry.value.events);
        expect(fixture.metrics.choiceCount, entry.value.choices);
        expect(fixture.metrics.variableCount, entry.value.variables);
      }
    });
  });
}

StoryEngine _roundTrip({
  required StoryProject project,
  required StoryEngine engine,
  required StoryRuntimeSnapshotCodec codec,
}) {
  final json = codec.encodeJson(engine.createSnapshot());
  final decoded = codec.decodeJson(json, project: project);
  return StoryEngine.restore(project: project, snapshot: decoded);
}

void _expectCommittedRuntimeParity(
  StoryEngine actual,
  StoryEngine expected, {
  String? reason,
}) {
  expect(actual.status, expected.status, reason: reason);
  expect(actual.state, expected.state, reason: reason);
  expect(actual.currentEvent?.id, expected.currentEvent?.id, reason: reason);
  expect(actual.history, expected.history, reason: reason);
  expect(actual.randomSeed, expected.randomSeed, reason: reason);
  expect(
    actual.maxAutomaticTransitions,
    expected.maxAutomaticTransitions,
    reason: reason,
  );
}
