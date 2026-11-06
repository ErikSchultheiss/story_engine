import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Prepublication 1B resolution validation', () {
    test(
      'candidate identity errors precede invalid finalists and draw data',
      () {
        final a = _candidate('a');
        expect(
          () => StoryEntryPointResolutionExplanation(
            candidates: [a, a],
            selectionMethod: StoryEntryPointSelectionMethod.weightedDraw,
            finalists: [_finalist('unknown')],
          ),
          _argument(
            'Entry-point resolution candidates must have unique identities.',
          ),
        );
      },
    );

    test('missing host facts precede finalist and selection validation', () {
      final missing = StoryEntryPointExplanation(
        entryPointId: StoryEntryPointId('missing'),
        eventId: StoryEventId('missing_event'),
        isFallback: false,
        priority: 0,
        weight: 1,
        status: StoryEntryPointCandidateStatus.hostConditionMissing,
        authoredHostConditionCount: 1,
        evaluatedHostConditions: [
          StoryHostConditionExplanation(
            key: StoryHostConditionKey('gate_open'),
            schemaNamespace: 'com.example.stage1b',
            conditionId: 'gate_open',
            expected: true,
            actual: null,
          ),
        ],
      );
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [missing],
          selectionMethod: StoryEntryPointSelectionMethod.none,
          finalists: [_finalist('unknown')],
        ),
        _argument(
          'A complete entry-point resolution cannot contain a missing required '
          'host fact because authoritative resolution throws instead.',
        ),
      );
    });

    test('duplicate finalists precede no-selection metadata errors', () {
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [_candidate('a')],
          selectionMethod: StoryEntryPointSelectionMethod.none,
          finalists: [_finalist('a'), _finalist('a')],
          totalWeight: 2,
        ),
        _argument(
          'Entry-point resolution finalists must have unique identities.',
        ),
      );
    });

    test('unrecorded finalist precedes missing weighted-draw fields', () {
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [_candidate('a')],
          selectionMethod: StoryEntryPointSelectionMethod.weightedDraw,
          finalists: [_finalist('unknown')],
        ),
        _argument('Every finalist must refer to a recorded candidate.'),
      );
    });

    test('no-selection metadata is checked before candidate eligibility', () {
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [_candidate('a')],
          selectionMethod: StoryEntryPointSelectionMethod.none,
          totalWeight: 0,
        ),
        _argument(
          'A resolution with no selection cannot contain winner/draw data.',
        ),
      );
    });

    test('eligible candidates precede unevaluated fallback rejection', () {
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [_candidate('a'), _fallback()],
          selectionMethod: StoryEntryPointSelectionMethod.none,
        ),
        _argument(
          'A no-selection resolution cannot contain an eligible candidate.',
        ),
      );
    });

    test('no-selection requires the fallback evaluation to be complete', () {
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [_fallback()],
          selectionMethod: StoryEntryPointSelectionMethod.none,
        ),
        _argument(
          'When no regular entry is eligible the fallback tier is evaluated; '
          'a complete no-selection resolution cannot contain notEvaluated '
          'candidates.',
        ),
      );
    });

    test('empty no-selection remains valid', () {
      final result = StoryEntryPointResolutionExplanation(
        candidates: const [],
        selectionMethod: StoryEntryPointSelectionMethod.none,
      );
      expect(result.selectedEntryPointId, isNull);
      expect(result.finalists, isEmpty);
    });

    test('sole finalist rejects invented RNG data', () {
      expect(
        () => StoryEntryPointResolutionExplanation(
          candidates: [_candidate('a')],
          selectionMethod: StoryEntryPointSelectionMethod.soleFinalist,
          selectedEntryPointId: StoryEntryPointId('a'),
          winningFallbackTier: false,
          winningPriority: 0,
          finalists: [_finalist('a')],
          totalWeight: 1,
        ),
        _argument(
          'soleFinalist requires exactly one selected finalist and no RNG draw.',
        ),
      );
    });

    test('authored finalist order precedes total and sample validation', () {
      expect(
        () => _draw(
          candidates: [_candidate('a'), _candidate('b')],
          finalists: [_finalist('b'), _finalist('a')],
          total: 0,
          sample: -1,
        ),
        _argument('Finalists must match winning candidates in authored order.'),
      );
    });

    test('portable total overflow precedes malformed total and sample', () {
      final maximum = StoryIntegerValue.maxPortableValue;
      expect(
        () => _draw(
          candidates: [
            _candidate('a', weight: maximum),
            _candidate('b'),
          ],
          finalists: [
            _finalist('a', weight: maximum),
            _finalist('b'),
          ],
          total: 0,
          sample: -1,
        ),
        _argument(
          'Weighted finalist total exceeds the portable integer range.',
        ),
      );
    });

    for (final sample in [-1, 4]) {
      test('weighted sample $sample is outside the half-open draw range', () {
        expect(
          () => _draw(total: 4, sample: sample),
          _argument(
            'Weighted draw total/sample does not match the finalist weights.',
          ),
        );
      });
    }

    test('incorrect total precedes inconsistent winner', () {
      expect(
        () => _draw(total: 5, sample: 0, winner: 'b'),
        _argument(
          'Weighted draw total/sample does not match the finalist weights.',
        ),
      );
    });

    for (final sample in [0, 1, 2, 3]) {
      test(
        'weighted interval boundary $sample selects its authored finalist',
        () {
          final winner = sample < 2 ? 'a' : 'b';
          expect(
            () => _draw(total: 4, sample: sample, winner: winner),
            returnsNormally,
          );
          expect(
            () => _draw(
              total: 4,
              sample: sample,
              winner: winner == 'a' ? 'b' : 'a',
            ),
            _argument(
              'Weighted draw sample does not map to selectedEntryPointId.',
            ),
          );
        },
      );
    }
  });

  group('Prepublication 1B effect validation', () {
    test('set result validation precedes no-op consistency', () {
      expect(
        () => _effect(
          operation: StoryEffectOperation.set,
          operand: StoryIntegerValue(1),
          before: StoryIntegerValue(2),
          after: StoryIntegerValue(3),
          outcome: StoryEffectOutcome.noOp,
        ),
        _argument(
          'A successful set explanation must produce its operand as afterValue.',
        ),
      );
    });

    test('unset rejects a produced value before outcome checks', () {
      expect(
        () => _effect(
          operation: StoryEffectOperation.unset,
          before: StoryIntegerValue(1),
          after: StoryIntegerValue(1),
          outcome: StoryEffectOutcome.committed,
        ),
        _argument(
          'A successful unset explanation must leave the variable unset.',
        ),
      );
    });

    test('missing numeric values precede mixed-type validation', () {
      expect(
        () => _effect(
          operand: StoryIntegerValue(1),
          before: null,
          after: StoryNumberValue(2),
        ),
        _argument(
          'A successful numeric adjustment requires set before/after values.',
        ),
      );
    });

    test('numeric type mismatch precedes result arithmetic', () {
      expect(
        () => _effect(
          operand: StoryIntegerValue(1),
          before: StoryNumberValue(2),
          after: StoryNumberValue(9),
        ),
        _argument(
          'Numeric adjustment before/operand/after values must share one '
          'StoryValue type.',
        ),
      );
    });

    for (final operation in [
      StoryEffectOperation.increment,
      StoryEffectOperation.decrement,
    ]) {
      test('${operation.name} preserves the portable integer boundary', () {
        final boundary = operation == StoryEffectOperation.increment
            ? StoryIntegerValue.maxPortableValue
            : StoryIntegerValue.minPortableValue;
        final before = operation == StoryEffectOperation.increment
            ? boundary - 1
            : boundary + 1;
        expect(
          () => _effect(
            operation: operation,
            operand: StoryIntegerValue(1),
            before: StoryIntegerValue(before),
            after: StoryIntegerValue(boundary),
          ),
          returnsNormally,
        );
        expect(
          () => _effect(
            operation: operation,
            operand: StoryIntegerValue(1),
            before: StoryIntegerValue(boundary),
            after: StoryIntegerValue(boundary),
          ),
          _arithmeticError(),
        );
      });
    }

    test('finite number operands cannot explain an overflowing result', () {
      expect(
        () => _effect(
          operand: StoryNumberValue(1e308),
          before: StoryNumberValue(1e308),
          after: StoryNumberValue(1e308),
        ),
        _arithmeticError(),
      );
    });

    test('number arithmetic rejects a finite but incorrect result', () {
      expect(
        () => _effect(
          operand: StoryNumberValue(0.5),
          before: StoryNumberValue(2),
          after: StoryNumberValue(3),
        ),
        _arithmeticError(),
      );
    });

    test('rolled-back number decrement still requires truthful arithmetic', () {
      expect(
        () => _effect(
          operation: StoryEffectOperation.decrement,
          operand: StoryNumberValue(1),
          before: StoryNumberValue(3.5),
          after: StoryNumberValue(2.5),
        ),
        returnsNormally,
      );
    });

    test('rejected effects do not require successful adjustment values', () {
      expect(
        () => _effect(
          operand: StoryIntegerValue(1),
          before: null,
          after: null,
          outcome: StoryEffectOutcome.rejected,
        ),
        returnsNormally,
      );
    });
  });
}

Matcher _argument(String message) => throwsA(
  isA<ArgumentError>().having((error) => error.message, 'message', message),
);

Matcher _arithmeticError() => _argument(
  'Numeric adjustment afterValue must equal the authored operation '
  'applied to beforeValue.',
);

StoryEntryPointExplanation _candidate(String id, {int weight = 1}) =>
    StoryEntryPointExplanation(
      entryPointId: StoryEntryPointId(id),
      eventId: StoryEventId('event_$id'),
      isFallback: false,
      priority: 0,
      weight: weight,
      status: StoryEntryPointCandidateStatus.eligible,
      authoredHostConditionCount: 0,
    );

StoryEntryPointExplanation _fallback() => StoryEntryPointExplanation(
  entryPointId: StoryEntryPointId('fallback'),
  eventId: StoryEventId('event_fallback'),
  isFallback: true,
  priority: 0,
  weight: 1,
  status: StoryEntryPointCandidateStatus.notEvaluated,
  authoredHostConditionCount: 0,
);

StoryEntryPointFinalistExplanation _finalist(String id, {int weight = 1}) =>
    StoryEntryPointFinalistExplanation(
      entryPointId: StoryEntryPointId(id),
      weight: weight,
    );

StoryEntryPointResolutionExplanation _draw({
  List<StoryEntryPointExplanation>? candidates,
  List<StoryEntryPointFinalistExplanation>? finalists,
  required int total,
  required int sample,
  String winner = 'a',
}) => StoryEntryPointResolutionExplanation(
  candidates:
      candidates ?? [_candidate('a', weight: 2), _candidate('b', weight: 2)],
  selectionMethod: StoryEntryPointSelectionMethod.weightedDraw,
  selectedEntryPointId: StoryEntryPointId(winner),
  winningFallbackTier: false,
  winningPriority: 0,
  finalists:
      finalists ?? [_finalist('a', weight: 2), _finalist('b', weight: 2)],
  totalWeight: total,
  sampledWeightOffset: sample,
);

StoryEffectExplanation _effect({
  StoryEffectOperation operation = StoryEffectOperation.increment,
  StoryValue? operand,
  required StoryValue? before,
  required StoryValue? after,
  StoryEffectOutcome outcome = StoryEffectOutcome.rolledBack,
}) => StoryEffectExplanation(
  source: StoryEffectSource.eventEntry(eventId: StoryEventId('effect_event')),
  authoredIndex: 0,
  variableId: StoryVariableId('score'),
  operation: operation,
  operand: operand,
  beforeValue: before,
  afterValue: after,
  outcome: outcome,
);
