import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 4D deterministic RNG snapshot parity', () {
    test(
      'weighted future execution matches uninterrupted run across seeds and checkpoints',
      () {
        final project = _buildRandomLoopProject();
        final codec = StoryRuntimeSnapshotCodec();
        final seeds = <int>[0, 1, 2, 3, 42, 123456789, 4294967295];
        final checkpointDepths = <int>[0, 1, 2, 3, 5, 8, 13];

        for (final seed in seeds) {
          for (final checkpointDepth in checkpointDepths) {
            final uninterrupted = StoryEngine(
              project: project,
              randomSeed: seed,
              maxAutomaticTransitions: 37,
            )..start();

            for (var index = 0; index < checkpointDepth; index++) {
              uninterrupted.continueStory();
            }

            final encoded = codec.encodeJson(uninterrupted.createSnapshot());
            final decoded = codec.decodeJson(encoded, project: project);
            final restored = StoryEngine.restore(
              project: project,
              snapshot: decoded,
            );

            _expectSameCommittedRuntime(restored, uninterrupted);

            for (var futureStep = 0; futureStep < 24; futureStep++) {
              uninterrupted.continueStory();
              restored.continueStory();
              _expectSameCommittedRuntime(restored, uninterrupted);
            }
          }
        }
      },
    );

    test('not-started snapshot preserves the same future random stream', () {
      final project = _buildRandomLoopProject();
      final codec = StoryRuntimeSnapshotCodec();
      final uninterrupted = StoryEngine(project: project, randomSeed: 97);
      final encoded = codec.encodeJson(uninterrupted.createSnapshot());
      final restored = StoryEngine.restore(
        project: project,
        snapshot: codec.decodeJson(encoded, project: project),
      );

      _expectSameCommittedRuntime(restored, uninterrupted);
      uninterrupted.start();
      restored.start();
      _expectSameCommittedRuntime(restored, uninterrupted);

      for (var index = 0; index < 24; index++) {
        uninterrupted.continueStory();
        restored.continueStory();
        _expectSameCommittedRuntime(restored, uninterrupted);
      }
    });

    test(
      'snapshot random state changes only when weighted randomness is consumed',
      () {
        final project = _buildRandomLoopProject();
        final engine = StoryEngine(project: project, randomSeed: 73)..start();
        final before = engine.createSnapshot();

        engine.continueStory();
        final afterRandomTraversal = engine.createSnapshot();

        expect(afterRandomTraversal.randomState, isNot(before.randomState));
        expect(
          afterRandomTraversal.randomState.algorithmId,
          'story_engine.lcg32',
        );
        expect(afterRandomTraversal.randomState.algorithmVersion, 1);
        expect(afterRandomTraversal.randomState.stateWords.first, 73);
      },
    );

    test(
      'codec validation rejects incompatible RNG contract before engine restore',
      () {
        final project = _buildRandomLoopProject();
        final codec = StoryRuntimeSnapshotCodec();
        final valid = (StoryEngine(
          project: project,
          randomSeed: 89,
        )..start()).createSnapshot();

        final wrongAlgorithm = _withRandomState(
          valid,
          StoryRuntimeRandomState(
            algorithmId: 'story_engine.other_rng',
            algorithmVersion: 1,
            stateWords: const [89, 89],
          ),
        );
        expect(
          () => codec.decode(codec.encode(wrongAlgorithm), project: project),
          throwsA(
            _compatibilityIssue(
              StoryRuntimeSnapshotCompatibilityIssue.unsupportedRandomAlgorithm,
            ),
          ),
        );

        final wrongVersion = _withRandomState(
          valid,
          StoryRuntimeRandomState(
            algorithmId: valid.randomState.algorithmId,
            algorithmVersion: 2,
            stateWords: const [89, 89],
          ),
        );
        expect(
          () => codec.decode(codec.encode(wrongVersion), project: project),
          throwsA(
            _compatibilityIssue(
              StoryRuntimeSnapshotCompatibilityIssue
                  .unsupportedRandomAlgorithmVersion,
            ),
          ),
        );

        final invalidPayload = _withRandomState(
          valid,
          StoryRuntimeRandomState(
            algorithmId: valid.randomState.algorithmId,
            algorithmVersion: valid.randomState.algorithmVersion,
            stateWords: const [89],
          ),
        );
        expect(
          () => codec.decode(codec.encode(invalidPayload), project: project),
          throwsA(
            _compatibilityIssue(
              StoryRuntimeSnapshotCompatibilityIssue.invalidRandomState,
            ),
          ),
        );
      },
    );
  });
}

StoryProject _buildRandomLoopProject() {
  final totalId = StoryVariableId('var_rng_total');
  final branchAId = StoryVariableId('var_rng_branch_a');
  final branchBId = StoryVariableId('var_rng_branch_b');
  final branchCId = StoryVariableId('var_rng_branch_c');
  final branchDId = StoryVariableId('var_rng_branch_d');
  final hubId = StoryEventId('event_rng_hub');
  final aId = StoryEventId('event_rng_a');
  final bId = StoryEventId('event_rng_b');
  final cId = StoryEventId('event_rng_c');
  final dId = StoryEventId('event_rng_d');

  final schema = StoryStateSchema(
    variables: [
      for (final id in [totalId, branchAId, branchBId, branchCId, branchDId])
        StoryVariableDefinition(
          id: id,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
    ],
  );

  StoryIncrementVariableEffect increment(StoryVariableId id) =>
      StoryIncrementVariableEffect(
        variableId: id,
        amount: StoryIntegerValue(1),
      );

  StoryEvent branch(StoryEventId id, StoryVariableId counterId) => StoryEvent(
    id: id,
    entryEffects: [increment(totalId), increment(counterId)],
    automaticTransition: StoryEventTransition(destinationEventId: hubId),
  );

  final nested = StoryWeightedTransition(
    options: [
      StoryWeightedTransitionOption(
        weight: 1,
        transition: StoryEventTransition(destinationEventId: bId),
      ),
      StoryWeightedTransitionOption(
        weight: 1,
        transition: StoryEventTransition(destinationEventId: cId),
      ),
    ],
  );

  return StoryProject(
    id: StoryProjectId('project_rng_snapshot_parity'),
    stateSchema: schema,
    entryEventId: hubId,
    events: [
      StoryEvent(
        id: hubId,
        continuationTransition: StoryWeightedTransition(
          options: [
            StoryWeightedTransitionOption(
              weight: 2,
              transition: StoryEventTransition(destinationEventId: aId),
            ),
            StoryWeightedTransitionOption(weight: 3, transition: nested),
            StoryWeightedTransitionOption(
              weight: 5,
              transition: StoryEventTransition(destinationEventId: dId),
            ),
          ],
        ),
      ),
      branch(aId, branchAId),
      branch(bId, branchBId),
      branch(cId, branchCId),
      branch(dId, branchDId),
    ],
  );
}

void _expectSameCommittedRuntime(StoryEngine actual, StoryEngine expected) {
  expect(actual.randomSeed, expected.randomSeed);
  expect(actual.maxAutomaticTransitions, expected.maxAutomaticTransitions);
  expect(actual.status, expected.status);
  expect(actual.currentEvent?.id, expected.currentEvent?.id);
  expect(actual.state, expected.state);
  expect(actual.history, expected.history);
  expect(actual.createSnapshot(), expected.createSnapshot());
}

StoryRuntimeSnapshot _withRandomState(
  StoryRuntimeSnapshot snapshot,
  StoryRuntimeRandomState randomState,
) => StoryRuntimeSnapshot(
  metadata: snapshot.metadata,
  projectId: snapshot.projectId,
  status: snapshot.status,
  state: snapshot.state,
  currentEventId: snapshot.currentEventId,
  history: snapshot.history,
  randomState: randomState,
  maxAutomaticTransitions: snapshot.maxAutomaticTransitions,
);

Matcher _compatibilityIssue(StoryRuntimeSnapshotCompatibilityIssue issue) =>
    isA<StoryRuntimeSnapshotCompatibilityException>().having(
      (error) => error.issue,
      'issue',
      issue,
    );
