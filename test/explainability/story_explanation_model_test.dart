import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9C1 explanation model', () {
    final trustId = StoryVariableId('trust');
    final keyId = StoryVariableId('has_key');

    StoryVariableComparisonConditionExplanation trustAtLeastFive({
      required bool result,
      int current = 7,
    }) => StoryVariableComparisonConditionExplanation(
      result: result,
      variableId: trustId,
      operator: StoryComparisonOperator.greaterThanOrEqual,
      expectedValue: StoryIntegerValue(5),
      currentValue: StoryIntegerValue(current),
    );

    StoryVariableComparisonConditionExplanation hasKey({
      required bool result,
      bool current = false,
    }) => StoryVariableComparisonConditionExplanation(
      result: result,
      variableId: keyId,
      operator: StoryComparisonOperator.equal,
      expectedValue: const StoryBooleanValue(true),
      currentValue: StoryBooleanValue(current),
    );

    test('ALL preserves actual short-circuit shape and owns child list', () {
      final source = <StoryConditionExplanation>[
        trustAtLeastFive(result: true),
        hasKey(result: false),
      ];
      final explanation = StoryAllConditionExplanation(
        result: false,
        authoredChildCount: 3,
        evaluatedChildren: source,
      );

      source.clear();

      expect(explanation.kind, StoryConditionExplanationKind.all);
      expect(explanation.result, isFalse);
      expect(explanation.authoredChildCount, 3);
      expect(explanation.evaluatedChildren, hasLength(2));
      expect(explanation.shortCircuited, isTrue);
      expect(
        () => explanation.evaluatedChildren.add(
          StoryVariableIsSetConditionExplanation(
            result: false,
            variableId: StoryVariableId('unused'),
            currentValue: null,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('composite constructor rejects invented post-short-circuit work', () {
      expect(
        () => StoryAllConditionExplanation(
          result: false,
          authoredChildCount: 3,
          evaluatedChildren: [
            hasKey(result: false),
            trustAtLeastFive(result: true),
          ],
        ),
        throwsArgumentError,
      );

      expect(
        () => StoryAnyConditionExplanation(
          result: true,
          authoredChildCount: 3,
          evaluatedChildren: [
            trustAtLeastFive(result: true),
            hasKey(result: false),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('variable and NOT explanation shapes remain internally coherent', () {
      final unset = StoryVariableIsUnsetConditionExplanation(
        result: true,
        variableId: keyId,
        currentValue: null,
      );
      final negated = StoryNotConditionExplanation(result: false, child: unset);

      expect(unset.kind, StoryConditionExplanationKind.variableIsUnset);
      expect(negated.kind, StoryConditionExplanationKind.not);
      expect(negated.child, same(unset));

      expect(
        () => StoryVariableIsSetConditionExplanation(
          result: true,
          variableId: keyId,
          currentValue: null,
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryVariableComparisonConditionExplanation(
          result: false,
          variableId: trustId,
          operator: StoryComparisonOperator.greaterThanOrEqual,
          expectedValue: StoryIntegerValue(5),
          currentValue: StoryIntegerValue(7),
        ),
        throwsArgumentError,
      );
    });

    test('choice explanation distinguishes unconditional and conditional', () {
      final eventId = StoryEventId('event_gate');
      final choiceId = StoryChoiceId('choice_enter');
      final condition = StoryAllConditionExplanation(
        result: false,
        authoredChildCount: 2,
        evaluatedChildren: [
          trustAtLeastFive(result: true),
          hasKey(result: false),
        ],
      );

      final unavailable = StoryChoiceExplanation(
        eventId: eventId,
        choiceId: choiceId,
        available: false,
        condition: condition,
      );
      final unconditional = StoryChoiceExplanation(
        eventId: eventId,
        choiceId: StoryChoiceId('choice_leave'),
        available: true,
      );

      expect(unavailable.condition, same(condition));
      expect(unavailable.available, isFalse);
      expect(unconditional.condition, isNull);

      expect(
        () => StoryChoiceExplanation(
          eventId: eventId,
          choiceId: choiceId,
          available: false,
        ),
        throwsArgumentError,
      );
    });

    test('host facts preserve matched mismatched and missing states', () {
      final arguments = <String, Object>{'minimum': 5};
      final matched = StoryHostConditionExplanation(
        key: StoryHostConditionKey('near_gate'),
        schemaNamespace: 'world.location',
        conditionId: 'near_landmark',
        arguments: arguments,
        expected: true,
        actual: true,
      );
      arguments['minimum'] = 99;

      final mismatched = StoryHostConditionExplanation(
        key: StoryHostConditionKey('is_night'),
        schemaNamespace: 'world.time',
        conditionId: 'is_night',
        expected: true,
        actual: false,
      );
      final missing = StoryHostConditionExplanation(
        key: StoryHostConditionKey('has_ticket'),
        schemaNamespace: 'world.inventory',
        conditionId: 'has_ticket',
        expected: true,
        actual: null,
      );

      expect(matched.status, StoryHostConditionExplanationStatus.matched);
      expect(matched.arguments['minimum'], 5);
      expect(() => matched.arguments['other'] = true, throwsUnsupportedError);
      expect(mismatched.status, StoryHostConditionExplanationStatus.mismatched);
      expect(missing.status, StoryHostConditionExplanationStatus.missing);
    });

    test('missing host fact is distinct and cannot complete resolution', () {
      final missingHost = StoryHostConditionExplanation(
        key: StoryHostConditionKey('has_ticket'),
        schemaNamespace: 'world.inventory',
        conditionId: 'has_ticket',
        expected: true,
        actual: null,
      );
      final candidate = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('entry_gate'),
        eventId: StoryEventId('event_gate'),
        isFallback: false,
        priority: 0,
        weight: 1,
        status: StoryEntryPointCandidateStatus.hostConditionMissing,
        authoredHostConditionCount: 1,
        evaluatedHostConditions: [missingHost],
      );

      expect(
        candidate.status,
        StoryEntryPointCandidateStatus.hostConditionMissing,
      );
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [candidate],
          selectionMethod: StoryEntryPointSelectionMethod.none,
        ),
        throwsArgumentError,
      );
    });

    test('entry resolution records non-evaluated fallback and actual draw', () {
      final regularA = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('entry_a'),
        eventId: StoryEventId('event_a'),
        isFallback: false,
        priority: 10,
        weight: 1,
        status: StoryEntryPointCandidateStatus.eligible,
        authoredHostConditionCount: 0,
      );
      final regularB = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('entry_b'),
        eventId: StoryEventId('event_b'),
        isFallback: false,
        priority: 10,
        weight: 3,
        status: StoryEntryPointCandidateStatus.eligible,
        authoredHostConditionCount: 0,
      );
      final fallback = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('entry_fallback'),
        eventId: StoryEventId('event_fallback'),
        isFallback: true,
        priority: 100,
        weight: 1,
        status: StoryEntryPointCandidateStatus.notEvaluated,
        authoredHostConditionCount: 0,
      );

      final resolution = StoryEntryPointResolutionExplanation(
        candidates: [regularA, regularB, fallback],
        selectionMethod: StoryEntryPointSelectionMethod.weightedDraw,
        selectedEntryPointId: regularB.entryPointId,
        winningFallbackTier: false,
        winningPriority: 10,
        finalists: [
          StoryEntryPointFinalistExplanation(
            entryPointId: regularA.entryPointId,
            weight: 1,
          ),
          StoryEntryPointFinalistExplanation(
            entryPointId: regularB.entryPointId,
            weight: 3,
          ),
        ],
        totalWeight: 4,
        sampledWeightOffset: 2,
      );

      expect(
        resolution.selectionMethod,
        StoryEntryPointSelectionMethod.weightedDraw,
      );
      expect(resolution.selectedEntryPointId, regularB.entryPointId);
      expect(resolution.sampledWeightOffset, 2);
      expect(
        resolution.candidates.last.status,
        StoryEntryPointCandidateStatus.notEvaluated,
      );
      expect(() => resolution.candidates.clear(), throwsUnsupportedError);
    });

    test('weighted resolution rejects a sample inconsistent with winner', () {
      final a = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('entry_a'),
        eventId: StoryEventId('event_a'),
        isFallback: false,
        priority: 0,
        weight: 1,
        status: StoryEntryPointCandidateStatus.eligible,
        authoredHostConditionCount: 0,
      );
      final b = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('entry_b'),
        eventId: StoryEventId('event_b'),
        isFallback: false,
        priority: 0,
        weight: 1,
        status: StoryEntryPointCandidateStatus.eligible,
        authoredHostConditionCount: 0,
      );

      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [a, b],
          selectionMethod: StoryEntryPointSelectionMethod.weightedDraw,
          selectedEntryPointId: b.entryPointId,
          winningFallbackTier: false,
          winningPriority: 0,
          finalists: [
            StoryEntryPointFinalistExplanation(
              entryPointId: a.entryPointId,
              weight: 1,
            ),
            StoryEntryPointFinalistExplanation(
              entryPointId: b.entryPointId,
              weight: 1,
            ),
          ],
          totalWeight: 2,
          sampledWeightOffset: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'effect explanation attributes authored source and transaction truth',
      () {
        final source = StoryEffectSource.choice(
          eventId: StoryEventId('event_gate'),
          choiceId: StoryChoiceId('choice_enter'),
        );
        final effect = StoryEffectExplanation(
          source: source,
          authoredIndex: 1,
          variableId: trustId,
          operation: StoryEffectOperation.increment,
          operand: StoryIntegerValue(2),
          beforeValue: StoryIntegerValue(7),
          afterValue: StoryIntegerValue(9),
          outcome: StoryEffectOutcome.committed,
        );
        final rolledBack = StoryEffectExplanation(
          source: source,
          authoredIndex: 1,
          variableId: trustId,
          operation: StoryEffectOperation.increment,
          operand: StoryIntegerValue(2),
          beforeValue: StoryIntegerValue(7),
          afterValue: StoryIntegerValue(9),
          outcome: StoryEffectOutcome.rolledBack,
        );

        expect(source.kind, StoryEffectOwnerKind.choice);
        expect(effect.outcome, StoryEffectOutcome.committed);
        expect(rolledBack.afterValue, StoryIntegerValue(9));

        expect(
          () => StoryEffectExplanation(
            source: source,
            authoredIndex: 2,
            variableId: trustId,
            operation: StoryEffectOperation.unset,
            operand: StoryIntegerValue(1),
            beforeValue: StoryIntegerValue(7),
            afterValue: null,
            outcome: StoryEffectOutcome.committed,
          ),
          throwsArgumentError,
        );
        expect(
          () => StoryEffectExplanation(
            source: source,
            authoredIndex: 2,
            variableId: trustId,
            operation: StoryEffectOperation.increment,
            operand: StoryIntegerValue(2),
            beforeValue: StoryIntegerValue(7),
            afterValue: StoryIntegerValue(10),
            outcome: StoryEffectOutcome.committed,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
