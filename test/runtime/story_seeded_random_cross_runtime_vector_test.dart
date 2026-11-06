import 'dart:convert';
import 'dart:io';

import 'package:story_engine/src/runtime/story_seeded_random_source.dart';
import 'package:story_engine/src/transition/story_transition_resolver.dart';
import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 8C cross-runtime RNG vectors', () {
    final vectors = _loadVectors();

    test('profile identity matches the persisted Dart runtime contract', () {
      expect(
        vectors['algorithmId'],
        StorySeededRandomSource.runtimeStateAlgorithmId,
      );
      expect(
        vectors['algorithmVersion'],
        StorySeededRandomSource.runtimeStateAlgorithmVersion,
      );
      expect(
        _asMap(vectors['constants'])['uint32Max'],
        StorySeededRandomSource.maxSeed,
      );
      expect(
        _asMap(vectors['constants'])['maxBound'],
        StoryIntegerValue.maxPortableValue,
      );
    });

    test(
      'machine-readable raw LCG and exact-53 vectors are self-consistent',
      () {
        final constants = _asMap(vectors['constants']);
        final uint32Range = _asInt(constants['uint32Range']);
        final multiplier = _asInt(constants['multiplier']);
        final increment = _asInt(constants['increment']);
        final high21Range = _asInt(constants['high21Range']);

        for (final rawSequence in _asList(vectors['uint32Sequences'])) {
          final sequence = _asMap(rawSequence);
          final expectedOutputs = _asIntList(sequence['outputs']);
          var state = _asInt(sequence['seed']);
          final actual = <int>[];

          for (var index = 0; index < expectedOutputs.length; index++) {
            state = (multiplier * state + increment) % uint32Range;
            actual.add(state);
          }

          expect(actual, expectedOutputs);
        }

        final exact53 = _asMap(vectors['exact53Sequence']);
        final expectedCandidates = _asIntList(exact53['candidates']);
        var state = _asInt(exact53['seed']);
        final actualCandidates = <int>[];

        for (var index = 0; index < expectedCandidates.length; index++) {
          state = (multiplier * state + increment) % uint32Range;
          final first = state;
          state = (multiplier * state + increment) % uint32Range;
          final second = state;
          actualCandidates.add((first % high21Range) * uint32Range + second);
        }

        expect(actualCandidates, expectedCandidates);
      },
    );

    test('Dart seeded source matches sequential bounded reference vectors', () {
      for (final rawSequence in _asList(vectors['boundedSequences'])) {
        final sequence = _asMap(rawSequence);
        final source = StorySeededRandomSource.fromSeed(
          _asInt(sequence['seed']),
        );
        final bounds = _asIntList(sequence['bounds']);
        final actual = <int>[for (final bound in bounds) source.nextInt(bound)];

        expect(actual, _asIntList(sequence['outputs']));
        expect(source.createRuntimeState().stateWords, [
          _asInt(sequence['seed']),
          _asInt(sequence['finalState']),
        ]);
      }
    });

    test('Dart seeded source matches rejection-consumption vector', () {
      for (final rawCase in _asList(vectors['rejectionCases'])) {
        final rejection = _asMap(rawCase);
        final source = StorySeededRandomSource.fromSeed(
          _asInt(rejection['seed']),
        );

        expect(
          source.nextInt(_asInt(rejection['bound'])),
          _asInt(rejection['output']),
        );
        expect(source.createRuntimeState().stateWords, [
          _asInt(rejection['seed']),
          _asInt(rejection['finalState']),
        ]);
        expect(_asInt(rejection['acceptedAttempt']), greaterThan(1));
      }
    });

    test('actual resolver matches weighted route reference vectors', () {
      const resolver = StoryTransitionResolver();
      final context = StoryConditionContext(
        state: StoryState.initial(StoryStateSchema.empty()),
      );
      final weighted = _asMap(_asList(vectors['weightedSelections']).single);
      final weights = _asIntList(weighted['weights']);
      final destinations = <StoryEventId>[
        for (var index = 0; index < weights.length; index++)
          StoryEventId('option_$index'),
      ];
      final transition = StoryWeightedTransition(
        options: [
          for (var index = 0; index < weights.length; index++)
            StoryWeightedTransitionOption(
              weight: weights[index],
              transition: StoryEventTransition(
                destinationEventId: destinations[index],
              ),
            ),
        ],
      );

      for (final rawSeedCase in _asList(weighted['seeds'])) {
        final seedCase = _asMap(rawSeedCase);
        final source = StorySeededRandomSource.fromSeed(
          _asInt(seedCase['seed']),
        );
        final expectedIndexes = _asIntList(seedCase['optionIndexes']);
        final actualIndexes = <int>[];

        for (
          var index = 0;
          index < _asInt(weighted['selectionCount']);
          index++
        ) {
          final resolution = resolver.resolve(
            transition: transition,
            context: context,
            randomSource: source,
          );
          expect(resolution, isA<StoryEventTransitionResolution>());
          final destination =
              (resolution as StoryEventTransitionResolution).destinationEventId;
          actualIndexes.add(destinations.indexOf(destination));
        }

        expect(
          actualIndexes,
          expectedIndexes,
          reason: "seed ${seedCase['seed']}",
        );
      }
    });
  });
}

Map<String, dynamic> _loadVectors() => _asMap(
  jsonDecode(
    File('test/fixtures/rng_v1_reference_vectors.json').readAsStringSync(),
  ),
);

Map<String, dynamic> _asMap(Object? value) => value as Map<String, dynamic>;

List<dynamic> _asList(Object? value) => value as List<dynamic>;

int _asInt(Object? value) => value as int;

List<int> _asIntList(Object? value) =>
    _asList(value).map(_asInt).toList(growable: false);
