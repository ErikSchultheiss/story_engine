import 'package:story_engine/src/effect/story_effect_executor.dart';
import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  const executor = StoryEffectExecutor();

  late StoryVariableId goldId;
  late StoryVariableId ratioId;
  late StoryVariableId flagId;
  late StoryVariableId nameId;
  late StoryVariableId unsetCounterId;
  late StoryState state;

  setUp(() {
    goldId = StoryVariableId('var_gold');
    ratioId = StoryVariableId('var_ratio');
    flagId = StoryVariableId('var_flag');
    nameId = StoryVariableId('var_name');
    unsetCounterId = StoryVariableId('var_unset_counter');

    state = StoryState.initial(
      StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: goldId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(100),
          ),
          StoryVariableDefinition(
            id: ratioId,
            type: StoryValueType.number,
            initialValue: StoryNumberValue(1.5),
          ),
          StoryVariableDefinition(
            id: flagId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(true),
          ),
          StoryVariableDefinition(
            id: nameId,
            type: StoryValueType.string,
            initialValue: const StoryStringValue('Mara'),
          ),
          StoryVariableDefinition(
            id: unsetCounterId,
            type: StoryValueType.integer,
          ),
        ],
      ),
    );
  });

  group('set/unset execution', () {
    test('set produces a new immutable snapshot', () {
      final next = executor.apply(
        StorySetVariableEffect(
          variableId: flagId,
          value: const StoryBooleanValue(false),
        ),
        state,
      );

      expect(next.valueOf(flagId), const StoryBooleanValue(false));
      expect(state.valueOf(flagId), const StoryBooleanValue(true));
    });

    test('set can initialize a declared-but-unset variable', () {
      final next = executor.apply(
        StorySetVariableEffect(
          variableId: unsetCounterId,
          value: StoryIntegerValue(1),
        ),
        state,
      );

      expect(next.valueOf(unsetCounterId), StoryIntegerValue(1));
      expect(state.isSet(unsetCounterId), isFalse);
    });

    test(
      'unset removes a current value without changing the input snapshot',
      () {
        final next = executor.apply(
          StoryUnsetVariableEffect(variableId: nameId),
          state,
        );

        expect(next.isSet(nameId), isFalse);
        expect(state.valueOf(nameId), const StoryStringValue('Mara'));
      },
    );

    test('unsetting an already-unset declared variable remains valid', () {
      final next = executor.apply(
        StoryUnsetVariableEffect(variableId: unsetCounterId),
        state,
      );

      expect(next.isSet(unsetCounterId), isFalse);
      expect(state.isSet(unsetCounterId), isFalse);
    });

    test('undeclared set/unset references are execution errors', () {
      final missing = StoryVariableId('var_missing');

      expect(
        () => executor.apply(
          StorySetVariableEffect(
            variableId: missing,
            value: StoryIntegerValue(1),
          ),
          state,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
      expect(
        () => executor.apply(
          StoryUnsetVariableEffect(variableId: missing),
          state,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });

    test('set rejects a value incompatible with the declared type', () {
      expect(
        () => executor.apply(
          StorySetVariableEffect(
            variableId: goldId,
            value: StoryNumberValue(100.0),
          ),
          state,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });
  });

  group('numeric adjustment execution', () {
    test('increments and decrements integer variables', () {
      final increased = executor.apply(
        StoryIncrementVariableEffect(
          variableId: goldId,
          amount: StoryIntegerValue(25),
        ),
        state,
      );
      final decreased = executor.apply(
        StoryDecrementVariableEffect(
          variableId: goldId,
          amount: StoryIntegerValue(30),
        ),
        increased,
      );

      expect(increased.valueOf(goldId), StoryIntegerValue(125));
      expect(decreased.valueOf(goldId), StoryIntegerValue(95));
      expect(state.valueOf(goldId), StoryIntegerValue(100));
    });

    test('increments and decrements number variables', () {
      final increased = executor.apply(
        StoryIncrementVariableEffect(
          variableId: ratioId,
          amount: StoryNumberValue(0.5),
        ),
        state,
      );
      final decreased = executor.apply(
        StoryDecrementVariableEffect(
          variableId: ratioId,
          amount: StoryNumberValue(0.25),
        ),
        increased,
      );

      expect(increased.valueOf(ratioId), StoryNumberValue(2.0));
      expect(decreased.valueOf(ratioId), StoryNumberValue(1.75));
    });

    test('does not coerce integer and number amounts', () {
      expect(
        () => executor.apply(
          StoryIncrementVariableEffect(
            variableId: goldId,
            amount: StoryNumberValue(1.0),
          ),
          state,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });

    test('rejects numeric adjustment of non-numeric variables', () {
      expect(
        () => executor.apply(
          StoryIncrementVariableEffect(
            variableId: flagId,
            amount: StoryIntegerValue(1),
          ),
          state,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });

    test('rejects adjustment of a declared-but-unset variable', () {
      expect(
        () => executor.apply(
          StoryIncrementVariableEffect(
            variableId: unsetCounterId,
            amount: StoryIntegerValue(1),
          ),
          state,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });

    test('portable integer overflow becomes an effect execution error', () {
      final atLimit = StoryState.fromValues(
        schema: state.schema,
        values: {
          ...state.values,
          goldId: StoryIntegerValue(StoryIntegerValue.maxPortableValue),
        },
      );

      expect(
        () => executor.apply(
          StoryIncrementVariableEffect(
            variableId: goldId,
            amount: StoryIntegerValue(1),
          ),
          atLimit,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });

    test('non-finite number result becomes an effect execution error', () {
      final veryLarge = StoryState.fromValues(
        schema: state.schema,
        values: {...state.values, ratioId: StoryNumberValue(1.7e308)},
      );

      expect(
        () => executor.apply(
          StoryIncrementVariableEffect(
            variableId: ratioId,
            amount: StoryNumberValue(1.7e308),
          ),
          veryLarge,
        ),
        throwsA(isA<StoryEffectExecutionException>()),
      );
    });
  });

  group('ordered effect batches', () {
    test('applyAll uses authored order', () {
      final next = executor.applyAll([
        StoryIncrementVariableEffect(
          variableId: goldId,
          amount: StoryIntegerValue(20),
        ),
        StoryDecrementVariableEffect(
          variableId: goldId,
          amount: StoryIntegerValue(5),
        ),
        StorySetVariableEffect(
          variableId: flagId,
          value: const StoryBooleanValue(false),
        ),
      ], state);

      expect(next.valueOf(goldId), StoryIntegerValue(115));
      expect(next.valueOf(flagId), const StoryBooleanValue(false));
      expect(state.valueOf(goldId), StoryIntegerValue(100));
      expect(state.valueOf(flagId), const StoryBooleanValue(true));
    });

    test('failed batch never mutates the caller input snapshot', () {
      final effects = <StoryEffect>[
        StoryIncrementVariableEffect(
          variableId: goldId,
          amount: StoryIntegerValue(20),
        ),
        StoryIncrementVariableEffect(
          variableId: unsetCounterId,
          amount: StoryIntegerValue(1),
        ),
      ];

      expect(
        () => executor.applyAll(effects, state),
        throwsA(isA<StoryEffectExecutionException>()),
      );
      expect(state.valueOf(goldId), StoryIntegerValue(100));
      expect(state.isSet(unsetCounterId), isFalse);
    });
  });

  group('Stage 9C4 effect explanations', () {
    test('attributes all four scalar effect operations and operands', () {
      final explanations = <StoryEffectExplanation>[];
      final source = StoryEffectSource.eventEntry(
        eventId: StoryEventId('evt_all_effects'),
      );

      executor.applyAllWithExplanations(
        effects: [
          StorySetVariableEffect(
            variableId: flagId,
            value: const StoryBooleanValue(false),
          ),
          StoryIncrementVariableEffect(
            variableId: goldId,
            amount: StoryIntegerValue(5),
          ),
          StoryDecrementVariableEffect(
            variableId: goldId,
            amount: StoryIntegerValue(2),
          ),
          StoryUnsetVariableEffect(variableId: nameId),
        ],
        state: state,
        source: source,
        explanations: explanations,
      );

      expect(explanations.map((explanation) => explanation.operation), [
        StoryEffectOperation.set,
        StoryEffectOperation.increment,
        StoryEffectOperation.decrement,
        StoryEffectOperation.unset,
      ]);
      expect(explanations[0].operand, const StoryBooleanValue(false));
      expect(explanations[1].operand, StoryIntegerValue(5));
      expect(explanations[2].operand, StoryIntegerValue(2));
      expect(explanations[3].operand, isNull);
      expect(explanations.map((explanation) => explanation.authoredIndex), [
        0,
        1,
        2,
        3,
      ]);
      expect(
        explanations.every(
          (explanation) => explanation.outcome == StoryEffectOutcome.committed,
        ),
        isTrue,
      );
    });

    test(
      'records committed and no-op outcomes from the actual effect pass',
      () {
        final explanations = <StoryEffectExplanation>[];
        final source = StoryEffectSource.eventEntry(
          eventId: StoryEventId('evt_effects'),
        );

        final next = executor.applyAllWithExplanations(
          effects: [
            StoryIncrementVariableEffect(
              variableId: goldId,
              amount: StoryIntegerValue(5),
            ),
            StoryUnsetVariableEffect(variableId: unsetCounterId),
          ],
          state: state,
          source: source,
          explanations: explanations,
        );

        expect(next.valueOf(goldId), StoryIntegerValue(105));
        expect(explanations, hasLength(2));
        expect(explanations[0].authoredIndex, 0);
        expect(explanations[0].beforeValue, StoryIntegerValue(100));
        expect(explanations[0].afterValue, StoryIntegerValue(105));
        expect(explanations[0].outcome, StoryEffectOutcome.committed);
        expect(explanations[1].authoredIndex, 1);
        expect(explanations[1].beforeValue, isNull);
        expect(explanations[1].afterValue, isNull);
        expect(explanations[1].outcome, StoryEffectOutcome.noOp);
      },
    );

    test(
      'marks earlier attempts rolled back and the failing effect rejected',
      () {
        final explanations = <StoryEffectExplanation>[];
        final source = StoryEffectSource.choice(
          eventId: StoryEventId('evt_effects'),
          choiceId: StoryChoiceId('choice_effects'),
        );

        expect(
          () => executor.applyAllWithExplanations(
            effects: [
              StoryIncrementVariableEffect(
                variableId: goldId,
                amount: StoryIntegerValue(20),
              ),
              StoryIncrementVariableEffect(
                variableId: unsetCounterId,
                amount: StoryIntegerValue(1),
              ),
            ],
            state: state,
            source: source,
            explanations: explanations,
          ),
          throwsA(isA<StoryEffectExecutionException>()),
        );

        expect(explanations, hasLength(2));
        expect(explanations[0].outcome, StoryEffectOutcome.rolledBack);
        expect(explanations[0].beforeValue, StoryIntegerValue(100));
        expect(explanations[0].afterValue, StoryIntegerValue(120));
        expect(explanations[1].outcome, StoryEffectOutcome.rejected);
        expect(explanations[1].beforeValue, isNull);
        expect(explanations[1].afterValue, isNull);
        expect(state.valueOf(goldId), StoryIntegerValue(100));
        expect(state.isSet(unsetCounterId), isFalse);
      },
    );
  });
}
