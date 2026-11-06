import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/transition/story_transition_resolver.dart';
import 'package:test/test.dart';

void main() {
  const resolver = StoryTransitionResolver();
  final context = StoryConditionContext(
    state: StoryState.initial(StoryStateSchema(variables: [])),
  );
  final location = StoryDiagnosticLocation.transition(
    projectId: StoryProjectId('draw_count'),
    eventId: StoryEventId('auto'),
    path: [const StoryDiagnosticPathSegment.field('automaticTransition')],
  );
  final inner = StoryWeightedTransition(
    options: [
      StoryWeightedTransitionOption(
        weight: 1,
        transition: const StoryTerminalTransition(),
      ),
    ],
  );
  final outer = StoryWeightedTransition(
    options: [
      StoryWeightedTransitionOption(
        weight: 1,
        transition: const StoryTerminalTransition(),
      ),
      StoryWeightedTransitionOption(weight: 3, transition: inner),
    ],
  );
  test(
    'capture records exactly the two real draws, including a single-option draw',
    () {
      final random = _Random([3, 0]);
      final steps = <StoryRuntimeExplanationStep>[];
      resolver.resolve(
        transition: outer,
        context: context,
        randomSource: random,
        onExplanation: steps.add,
        explanationLocation: location,
      );
      expect(random.bounds, [4, 1]);
      final draws = steps
          .whereType<StoryWeightedTransitionExplanation>()
          .toList();
      expect(draws.map((draw) => draw.sampledOffset), [3, 0]);
      expect(draws.map((draw) => draw.selectedOptionIndex), [1, 0]);
      expect(
        draws.last.location.pathString,
        'automaticTransition.options[1].transition',
      );
      expect(steps.last, isA<StoryTerminalTransitionExplanation>());
    },
  );
  test('ordinary resolution consumes the same two draws', () {
    final random = _Random([3, 0]);
    expect(
      resolver.resolve(
        transition: outer,
        context: context,
        randomSource: random,
      ),
      isA<StoryTerminalTransitionResolution>(),
    );
    expect(random.bounds, [4, 1]);
  });
  test(
    'invalid RNG result is not turned into a completed weighted decision',
    () {
      for (final sampled in [-1, 4]) {
        final steps = <StoryRuntimeExplanationStep>[];
        final random = _Random([sampled]);
        expect(
          () => resolver.resolve(
            transition: outer,
            context: context,
            randomSource: random,
            onExplanation: steps.add,
            explanationLocation: location,
          ),
          throwsA(isA<StoryTransitionResolutionException>()),
        );
        expect(random.bounds, [4]);
        expect(steps, isEmpty);
      }
    },
  );
}

final class _Random implements StoryRandomSource {
  _Random(this.samples);
  final List<int> samples;
  final bounds = <int>[];
  @override
  int nextInt(int maxExclusive) {
    bounds.add(maxExclusive);
    return samples[bounds.length - 1];
  }
}
