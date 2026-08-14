import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  final eventA = StoryEventId('evt_a');
  final eventB = StoryEventId('evt_b');
  final variableId = StoryVariableId('var_flag');

  StoryCondition flagIsTrue() => StoryVariableComparisonCondition(
    variableId: variableId,
    operator: StoryComparisonOperator.equal,
    value: const StoryBooleanValue(true),
  );

  group('direct and terminal transitions', () {
    test('event transition stores a typed destination', () {
      final transition = StoryEventTransition(destinationEventId: eventA);

      expect(transition.destinationEventId, eventA);
      expect(
        transition,
        StoryEventTransition(destinationEventId: StoryEventId('evt_a')),
      );
    });

    test('terminal transition is explicit value data', () {
      expect(
        const StoryTerminalTransition(),
        const StoryTerminalTransition(),
      );
    });
  });

  group('conditional transition model', () {
    test('requires at least one branch and always has a fallback', () {
      expect(
        () => StoryConditionalTransition(
          branches: const [],
          fallback: const StoryTerminalTransition(),
        ),
        throwsArgumentError,
      );
    });

    test('copies branch collections immutably', () {
      final source = <StoryConditionalTransitionBranch>[
        StoryConditionalTransitionBranch(
          condition: flagIsTrue(),
          transition: StoryEventTransition(destinationEventId: eventA),
        ),
      ];
      final transition = StoryConditionalTransition(
        branches: source,
        fallback: StoryEventTransition(destinationEventId: eventB),
      );

      source.clear();

      expect(transition.branches, hasLength(1));
      expect(
        () => transition.branches.add(
          StoryConditionalTransitionBranch(
            condition: flagIsTrue(),
            transition: StoryEventTransition(destinationEventId: eventB),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('weighted transition model', () {
    test('requires at least one option', () {
      expect(
        () => StoryWeightedTransition(options: const []),
        throwsArgumentError,
      );
    });

    test('requires strictly positive integer weights', () {
      expect(
        () => StoryWeightedTransitionOption(
          weight: 0,
          transition: const StoryTerminalTransition(),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryWeightedTransitionOption(
          weight: -1,
          transition: const StoryTerminalTransition(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects an individual non-portable weight', () {
      expect(
        () => StoryWeightedTransitionOption(
          weight: StoryWeightedTransition.maxPortableTotalWeight + 1,
          transition: const StoryTerminalTransition(),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a combined total outside portable exact integer range', () {
      expect(
        () => StoryWeightedTransition(
          options: [
            StoryWeightedTransitionOption(
              weight: StoryWeightedTransition.maxPortableTotalWeight,
              transition: StoryEventTransition(destinationEventId: eventA),
            ),
            StoryWeightedTransitionOption(
              weight: 1,
              transition: StoryEventTransition(destinationEventId: eventB),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('calculates total weight and preserves authored order immutably', () {
      final source = <StoryWeightedTransitionOption>[
        StoryWeightedTransitionOption(
          weight: 2,
          transition: StoryEventTransition(destinationEventId: eventA),
        ),
        StoryWeightedTransitionOption(
          weight: 3,
          transition: StoryEventTransition(destinationEventId: eventB),
        ),
      ];
      final transition = StoryWeightedTransition(options: source);

      source.clear();

      expect(transition.options, hasLength(2));
      expect(transition.totalWeight, 5);
      expect(
        () => transition.options.add(
          StoryWeightedTransitionOption(
            weight: 1,
            transition: const StoryTerminalTransition(),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('transition trees have deterministic equality and hash codes', () {
      StoryTransition build() => StoryWeightedTransition(
        options: [
          StoryWeightedTransitionOption(
            weight: 1,
            transition: StoryEventTransition(destinationEventId: eventA),
          ),
          StoryWeightedTransitionOption(
            weight: 3,
            transition: StoryConditionalTransition(
              branches: [
                StoryConditionalTransitionBranch(
                  condition: flagIsTrue(),
                  transition: StoryEventTransition(destinationEventId: eventB),
                ),
              ],
              fallback: const StoryTerminalTransition(),
            ),
          ),
        ],
      );

      final first = build();
      final second = build();

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
