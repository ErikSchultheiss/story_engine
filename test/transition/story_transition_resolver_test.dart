import 'package:story_engine/src/transition/story_transition_resolver.dart';
import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  const resolver = StoryTransitionResolver();

  late StoryVariableId trustId;
  late StoryVariableId flagId;
  late StoryState state;
  late StoryConditionContext context;

  final eventA = StoryEventId('evt_a');
  final eventB = StoryEventId('evt_b');
  final eventC = StoryEventId('evt_c');

  setUp(() {
    trustId = StoryVariableId('var_trust');
    flagId = StoryVariableId('var_flag');
    state = StoryState.initial(
      StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: trustId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(65),
          ),
          StoryVariableDefinition(
            id: flagId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(true),
          ),
        ],
      ),
    );
    context = StoryConditionContext(state: state);
  });

  StoryCondition trustAtLeast(int value) => StoryVariableComparisonCondition(
    variableId: trustId,
    operator: StoryComparisonOperator.greaterThanOrEqual,
    value: StoryIntegerValue(value),
  );

  group('direct resolution', () {
    test('direct event and terminal transitions consume no randomness', () {
      final random = _ThrowingRandomSource();

      expect(
        resolver.resolve(
          transition: StoryEventTransition(destinationEventId: eventA),
          context: context,
          randomSource: random,
        ),
        StoryEventTransitionResolution(destinationEventId: eventA),
      );
      expect(
        resolver.resolve(
          transition: const StoryTerminalTransition(),
          context: context,
          randomSource: random,
        ),
        const StoryTerminalTransitionResolution(),
      );
      expect(random.calls, 0);
    });
  });

  group('conditional resolution', () {
    test('uses the first true branch in authored order', () {
      final transition = StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: trustAtLeast(60),
            transition: StoryEventTransition(destinationEventId: eventA),
          ),
          StoryConditionalTransitionBranch(
            condition: trustAtLeast(50),
            transition: StoryEventTransition(destinationEventId: eventB),
          ),
        ],
        fallback: StoryEventTransition(destinationEventId: eventC),
      );

      expect(
        resolver.resolve(
          transition: transition,
          context: context,
          randomSource: _ThrowingRandomSource(),
        ),
        StoryEventTransitionResolution(destinationEventId: eventA),
      );
    });

    test('uses explicit fallback when no condition matches', () {
      final transition = StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: trustAtLeast(100),
            transition: StoryEventTransition(destinationEventId: eventA),
          ),
        ],
        fallback: StoryEventTransition(destinationEventId: eventC),
      );

      expect(
        resolver.resolve(
          transition: transition,
          context: context,
          randomSource: _ThrowingRandomSource(),
        ),
        StoryEventTransitionResolution(destinationEventId: eventC),
      );
    });

    test('short-circuits later conditions after the first match', () {
      final missingId = StoryVariableId('var_missing');
      final transition = StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: StoryVariableComparisonCondition(
              variableId: flagId,
              operator: StoryComparisonOperator.equal,
              value: const StoryBooleanValue(true),
            ),
            transition: StoryEventTransition(destinationEventId: eventA),
          ),
          StoryConditionalTransitionBranch(
            condition: StoryVariableIsSetCondition(variableId: missingId),
            transition: StoryEventTransition(destinationEventId: eventB),
          ),
        ],
        fallback: StoryEventTransition(destinationEventId: eventC),
      );

      expect(
        resolver.resolve(
          transition: transition,
          context: context,
          randomSource: _ThrowingRandomSource(),
        ),
        StoryEventTransitionResolution(destinationEventId: eventA),
      );
    });
  });

  group('weighted resolution', () {
    StoryWeightedTransition weighted() => StoryWeightedTransition(
      options: [
        StoryWeightedTransitionOption(
          weight: 2,
          transition: StoryEventTransition(destinationEventId: eventA),
        ),
        StoryWeightedTransitionOption(
          weight: 3,
          transition: StoryEventTransition(destinationEventId: eventB),
        ),
        StoryWeightedTransitionOption(
          weight: 1,
          transition: StoryEventTransition(destinationEventId: eventC),
        ),
      ],
    );

    test('maps integer intervals to authored options exactly', () {
      final expectations = <int, StoryEventId>{
        0: eventA,
        1: eventA,
        2: eventB,
        3: eventB,
        4: eventB,
        5: eventC,
      };

      for (final entry in expectations.entries) {
        final random = _FixedRandomSource(entry.key);
        final resolution = resolver.resolve(
          transition: weighted(),
          context: context,
          randomSource: random,
        );

        expect(
          resolution,
          StoryEventTransitionResolution(destinationEventId: entry.value),
          reason: 'sample ${entry.key}',
        );
        expect(random.maxExclusiveArguments, [6]);
      }
    });

    test('same supplied RNG sequence produces the same resolved route', () {
      final transition = StoryWeightedTransition(
        options: [
          StoryWeightedTransitionOption(
            weight: 1,
            transition: StoryEventTransition(destinationEventId: eventA),
          ),
          StoryWeightedTransitionOption(
            weight: 1,
            transition: StoryWeightedTransition(
              options: [
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: StoryEventTransition(destinationEventId: eventB),
                ),
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: StoryEventTransition(destinationEventId: eventC),
                ),
              ],
            ),
          ),
        ],
      );

      StoryTransitionResolution run() => resolver.resolve(
        transition: transition,
        context: context,
        randomSource: _SequenceRandomSource([1, 0]),
      );

      expect(run(), StoryEventTransitionResolution(destinationEventId: eventB));
      expect(run(), StoryEventTransitionResolution(destinationEventId: eventB));
    });

    test('nested conditional/weighted transitions compose', () {
      final transition = StoryConditionalTransition(
        branches: [
          StoryConditionalTransitionBranch(
            condition: trustAtLeast(60),
            transition: StoryWeightedTransition(
              options: [
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: StoryEventTransition(destinationEventId: eventA),
                ),
                StoryWeightedTransitionOption(
                  weight: 1,
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ),
        ],
        fallback: StoryEventTransition(destinationEventId: eventC),
      );

      expect(
        resolver.resolve(
          transition: transition,
          context: context,
          randomSource: _FixedRandomSource(1),
        ),
        const StoryTerminalTransitionResolution(),
      );
    });

    test('invalid random-source output is an explicit resolution error', () {
      expect(
        () => resolver.resolve(
          transition: weighted(),
          context: context,
          randomSource: _FixedRandomSource(6),
        ),
        throwsA(isA<StoryTransitionResolutionException>()),
      );
      expect(
        () => resolver.resolve(
          transition: weighted(),
          context: context,
          randomSource: _FixedRandomSource(-1),
        ),
        throwsA(isA<StoryTransitionResolutionException>()),
      );
    });
  });
}

final class _ThrowingRandomSource implements StoryRandomSource {
  int calls = 0;

  @override
  int nextInt(int maxExclusive) {
    calls++;
    throw StateError('Randomness must not be consumed by this transition.');
  }
}

final class _FixedRandomSource implements StoryRandomSource {
  _FixedRandomSource(this.value);

  final int value;
  final List<int> maxExclusiveArguments = [];

  @override
  int nextInt(int maxExclusive) {
    maxExclusiveArguments.add(maxExclusive);
    return value;
  }
}

final class _SequenceRandomSource implements StoryRandomSource {
  _SequenceRandomSource(Iterable<int> values)
    : _values = List<int>.of(values);

  final List<int> _values;
  var _index = 0;

  @override
  int nextInt(int maxExclusive) {
    if (_index >= _values.length) {
      throw StateError('No deterministic test random values remain.');
    }
    return _values[_index++];
  }
}
