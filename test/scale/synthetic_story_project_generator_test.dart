import 'package:test/test.dart';

import '../support/synthetic_story_project_generator.dart';

void main() {
  group('Stage 2F structured synthetic profiles', () {
    test('small profile stays compact but structurally mixed', () {
      final fixture = SyntheticStoryProjectGenerator.structured(
        SyntheticStoryProfile.small,
      );
      final metrics = fixture.metrics;

      expect(metrics.eventCount, 100);
      expect(metrics.variableCount, 25);
      expect(metrics.choiceCount, greaterThanOrEqualTo(380));
      _expectStructuredMix(metrics);
    });

    test('medium profile supplies the primary Stage 2F scale fixture', () {
      final fixture = SyntheticStoryProjectGenerator.structured(
        SyntheticStoryProfile.medium,
      );
      final metrics = fixture.metrics;

      expect(metrics.eventCount, 500);
      expect(metrics.variableCount, 100);
      expect(
        metrics.choiceCount,
        allOf(greaterThanOrEqualTo(1900), lessThanOrEqualTo(2000)),
      );
      expect(metrics.automaticEventCount, greaterThan(10));
      expect(metrics.backwardDestinationCount, greaterThan(0));
      _expectStructuredMix(metrics);
    });

    test('large profile reaches roughly five thousand choices', () {
      final fixture = SyntheticStoryProjectGenerator.structured(
        SyntheticStoryProfile.large,
      );
      final metrics = fixture.metrics;

      expect(metrics.eventCount, 1000);
      expect(metrics.variableCount, 250);
      expect(
        metrics.choiceCount,
        allOf(greaterThanOrEqualTo(4800), lessThanOrEqualTo(4950)),
      );
      expect(metrics.automaticEventCount, greaterThan(20));
      expect(metrics.backwardDestinationCount, greaterThan(0));
      _expectStructuredMix(metrics);
    });

    test('stable structured profiles have stable public-model signatures', () {
      for (final profile in SyntheticStoryProfile.values) {
        final first = SyntheticStoryProjectGenerator.structured(profile);
        final second = SyntheticStoryProjectGenerator.structured(profile);

        expect(second.signature, first.signature, reason: profile.name);
        expect(second.metrics.eventCount, first.metrics.eventCount);
        expect(second.metrics.choiceCount, first.metrics.choiceCount);
      }
    });
  });
}

void _expectStructuredMix(SyntheticStoryMetrics metrics) {
  expect(metrics.directTransitionCount, greaterThan(0));
  expect(metrics.conditionalTransitionCount, greaterThan(0));
  expect(metrics.weightedTransitionCount, greaterThan(0));
  expect(metrics.terminalTransitionCount, greaterThan(0));
  expect(metrics.conditionNodeCount, greaterThan(0));
  expect(metrics.maxConditionDepth, greaterThanOrEqualTo(3));
  expect(metrics.effectCount, greaterThan(0));
  expect(metrics.missingDestinationCount, 0);
  expect(metrics.invalidVariableReferenceCount, 0);
}
