import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/orchestration/story_narrative_runtime.dart'
    as internal;
import 'package:test/test.dart';

final _score = StoryVariableId('score');
final _flag = StoryVariableId('flag');
final _memo = StoryVariableId('memo');
final _missing = StoryVariableId('missing');
final _source = StoryEventId('source');
final _bad = StoryEventId('bad_presentation');
final _denied = StoryEventId('denied');
final _continue = StoryEventId('continue');
final _entry = StoryEntryPointId('source_entry');
final _badEntry = StoryEntryPointId('bad_entry');
final _deniedEntry = StoryEntryPointId('denied_entry');
final _continueEntry = StoryEntryPointId('continue_entry');
final _change = StoryChoiceId('change');
final _noChange = StoryChoiceId('no_change');
final _badChoice = StoryChoiceId('bad');
final _denyChoice = StoryChoiceId('deny');

void main() {
  group('Finalization Stage 2 aggregate execution adapter', () {
    test(
      'commit deltas are net changes in schema order, after execution, before presentation',
      () {
        final adapter = _Adapter();
        final fixture = _fixture(adapter: adapter);
        final source = fixture.runtime.startSession(_entry);
        final sibling = fixture.runtime.startSession(_entry);
        final third = fixture.runtime.startSession(_entry);
        final request = third.requestHostAction(
          schemaNamespace: 'com.example.stage2',
          actionId: 'wait',
        );
        expect(adapter.commits, isEmpty);
        adapter.calls.clear();
        source.choose(_change);
        expect(adapter.calls, ['effects', 'execution', 'commit', 'choices']);
        final commit = adapter.commits.single;
        expect(commit.sourceSessionIndex, source.index);
        expect(commit.previousRevision, 0);
        expect(commit.revision, 1);
        expect(commit.propagatedSessionIndexes, [sibling.index, third.index]);
        expect(commit.changes.map((delta) => delta.variableId), [
          _score,
          _flag,
          _memo,
        ]);
        expect(commit.changes.map((delta) => delta.beforeValue), [
          StoryIntegerValue(0),
          const StoryBooleanValue(true),
          null,
        ]);
        expect(commit.changes.map((delta) => delta.afterValue), [
          StoryIntegerValue(1),
          null,
          StoryStringValue('text'),
        ]);
        expect(sibling.state.values[_score], StoryIntegerValue(1));
        expect(third.state.values[_flag], isNull);
        expect(third.pendingHostAction, request);
        expect(
          adapter.traces.last.effects.last.outcome,
          StoryEffectOutcome.noOp,
        );
        expect(
          adapter.traces.last.outcome,
          StoryRuntimeExecutionOutcome.committed,
        );
        expect(() => commit.changes.clear(), throwsUnsupportedError);
        expect(
          () => commit.propagatedSessionIndexes.clear(),
          throwsUnsupportedError,
        );
        source.choose(_change);
        expect(adapter.commits.last.previousRevision, 1);
        expect(adapter.commits.last.revision, 2);
        expect(
          adapter.commits.last.changes.map((change) => change.variableId),
          [_score],
        );
      },
    );

    test(
      'effects with zero net shared change do not invent a revision notification',
      () {
        final adapter = _Adapter();
        final fixture = _fixture(adapter: adapter);
        final source = fixture.runtime.startSession(_entry);
        fixture.runtime.startSession(_entry);
        source.choose(_noChange);
        expect(adapter.traces.last.effects.map((effect) => effect.outcome), [
          StoryEffectOutcome.committed,
          StoryEffectOutcome.committed,
        ]);
        expect(adapter.commits, isEmpty);
        expect(fixture.runtime.persistentStateRevision, 0);
        expect(source.state.values[_score], StoryIntegerValue(0));
      },
    );

    for (final invalidPresentation in [false, true]) {
      test(
        'failed startup has no committed trace identity (presentation=$invalidPresentation)',
        () {
          final adapter = _Adapter();
          final fixture = _fixture(adapter: adapter);
          final before = _snapshot(fixture.runtime);
          final error = _failure(
            () => fixture.runtime.startSession(
              invalidPresentation ? _badEntry : _deniedEntry,
            ),
          );
          expect(
            error,
            anyOf(
              isA<StoryEngineException>(),
              isA<StoryNarrativeExecutionException>(),
            ),
          );
          expect(adapter.traces, hasLength(1));
          expect(adapter.indexes, [null]);
          expect(
            adapter.traces.single.outcome,
            StoryRuntimeExecutionOutcome.rolledBack,
          );
          expect(adapter.commits, isEmpty);
          expect(_snapshot(fixture.runtime), before);
          final valid = fixture.runtime.startSession(_entry);
          expect(valid.index, 0);
          expect(
            valid.randomSeed,
            _fixture().runtime.startSession(_entry).randomSeed,
          );
        },
      );

      test(
        'core and aggregate failures expose rolled-back traces under the guard (presentation=$invalidPresentation)',
        () {
          final adapter = _Adapter();
          final fixture = _fixture(adapter: adapter);
          final source = fixture.runtime.startSession(_entry);
          final sibling = fixture.runtime.startSession(_entry);
          sibling.requestHostAction(
            schemaNamespace: 'com.example.stage2',
            actionId: 'wait',
          );
          final before = _snapshot(fixture.runtime);
          adapter.attemptReentry = () => [
            _failure(() => fixture.runtime.startSession(_entry)),
            _failure(() => source.choose(_change)),
            _failure(fixture.runtime.createSnapshot),
          ];
          _failure(
            () => source.choose(invalidPresentation ? _badChoice : _denyChoice),
          );
          expect(adapter.reentryErrors, hasLength(3));
          expect(
            adapter.reentryErrors,
            everyElement(isA<StoryNarrativeOperationException>()),
          );
          final trace = adapter.traces.last;
          expect(trace.operation, 'choose');
          expect(trace.outcome, StoryRuntimeExecutionOutcome.rolledBack);
          expect(trace.effects, isNotEmpty);
          expect(
            trace.effects.map((effect) => effect.outcome),
            everyElement(StoryEffectOutcome.rolledBack),
          );
          expect(adapter.commits, isEmpty);
          expect(_snapshot(fixture.runtime), before);
          adapter.attemptReentry = null;
          source.choose(_change);
          expect(adapter.commits.single.revision, 1);
        },
      );
    }

    test(
      'actual sibling preparation failure publishes neither commit nor successful execution',
      () {
        final adapter = _Adapter();
        final fixture = _fixture(adapter: adapter);
        final source = fixture.runtime.startSession(_entry);
        fixture.runtime.startSession(_entry);
        final before = _snapshot(fixture.runtime);
        final probe = internal.installStage9d6RollbackTestProbe(
          runtime: fixture.runtime,
          failAfterPreparedSiblingCount: 1,
        );
        expect(() => source.choose(_change), throwsStateError);
        expect(probe.preparedSiblingReplacementCount, 1);
        expect(probe.rollbackRestoreAttemptCount, 1);
        expect(
          adapter.traces.last.outcome,
          StoryRuntimeExecutionOutcome.rolledBack,
        );
        expect(
          adapter.traces.last.effects.map((effect) => effect.outcome),
          everyElement(StoryEffectOutcome.rolledBack),
        );
        expect(adapter.commits, isEmpty);
        expect(_snapshot(fixture.runtime), before);
      },
    );

    test(
      'throwing execution and commit callbacks cannot change snapshots, RNG, host IDs, or lifecycle',
      () {
        final baselineObserver = _Observer();
        final diagnosticObserver = _Observer();
        final baseline = _fixture(observer: baselineObserver);
        final adapter = _Adapter()..throwOnCallbacks = true;
        final diagnostic = _fixture(
          adapter: adapter,
          observer: diagnosticObserver,
        );
        void compare() {
          expect(_snapshot(diagnostic.runtime), _snapshot(baseline.runtime));
          expect(diagnosticObserver.events, baselineObserver.events);
        }

        final left = baseline.runtime.startSession(_entry);
        final right = diagnostic.runtime.startSession(_entry);
        compare();
        final leftSibling = baseline.runtime.startSession(_entry);
        final rightSibling = diagnostic.runtime.startSession(_entry);
        final leftRequest = leftSibling.requestHostAction(
          schemaNamespace: 'com.example.stage2',
          actionId: 'wait',
        );
        final rightRequest = rightSibling.requestHostAction(
          schemaNamespace: 'com.example.stage2',
          actionId: 'wait',
        );
        expect(rightRequest.id, leftRequest.id);
        right.choose(_change);
        left.choose(_change);
        compare();
        _expectErrorParity(
          _failure(() => right.choose(_badChoice)),
          _failure(() => left.choose(_badChoice)),
        );
        compare();
        final lc = baseline.runtime.startSession(_continueEntry);
        final rc = diagnostic.runtime.startSession(_continueEntry);
        rc.continueStory();
        lc.continueStory();
        compare();
        expect(
          adapter.traces.last.steps
              .whereType<StoryWeightedTransitionExplanation>(),
          hasLength(1),
        );
        expect(adapter.traces, hasLength(6));
        expect(adapter.commits, hasLength(1));
      },
    );

    test(
      'successful commit callback observes updated siblings and rejects authority reentry',
      () {
        final adapter = _Adapter();
        final fixture = _fixture(adapter: adapter);
        final source = fixture.runtime.startSession(_entry);
        final sibling = fixture.runtime.startSession(_entry);
        adapter.commitCheck = (commit) {
          expect(fixture.runtime.persistentStateRevision, commit.revision);
          expect(sibling.state.values[_score], StoryIntegerValue(1));
          expect(
            _failure(fixture.runtime.createSnapshot),
            isA<StoryNarrativeOperationException>(),
          );
          expect(
            _failure(() => source.choose(_change)),
            isA<StoryNarrativeOperationException>(),
          );
        };
        source.choose(_change);
        expect(adapter.commitChecked, isTrue);
        expect(fixture.runtime.persistentStateRevision, 1);
      },
    );

    test(
      'aggregate restore replays no explanations and future commits retain revision identity',
      () {
        final fixture = _fixture();
        final source = fixture.runtime.startSession(_entry);
        fixture.runtime.startSession(_entry);
        source.choose(_change);
        final adapter = _Adapter();
        final restored = StoryNarrativeRuntime.restore(
          project: fixture.project,
          entryPoints: fixture.entries,
          snapshot: fixture.runtime.createSnapshot(),
          debugAdapter: adapter,
        );
        expect(adapter.traces, isEmpty);
        expect(adapter.commits, isEmpty);
        restored.sessionByIndex(source.index).choose(_change);
        source.choose(_change);
        expect(_snapshot(restored), _snapshot(fixture.runtime));
        expect(adapter.commits.single.previousRevision, 1);
        expect(adapter.commits.single.revision, 2);
        expect(adapter.commits.single.sourceSessionIndex, source.index);
        expect(adapter.commits.single.propagatedSessionIndexes, [1]);
      },
    );

    test(
      'shared-state model defensively owns collections and rejects invalid deltas',
      () {
        final changes = [
          StoryPersistentVariableChange(
            variableId: _score,
            beforeValue: StoryIntegerValue(0),
            afterValue: StoryIntegerValue(1),
          ),
        ];
        final siblings = [1];
        final commit = StoryPersistentStateCommitExplanation(
          sourceSessionIndex: 0,
          previousRevision: 0,
          revision: 1,
          changes: changes,
          propagatedSessionIndexes: siblings,
        );
        changes.clear();
        siblings.clear();
        expect(commit.changes, hasLength(1));
        expect(commit.propagatedSessionIndexes, [1]);
        expect(
          () => StoryPersistentVariableChange(
            variableId: _score,
            beforeValue: null,
            afterValue: null,
          ),
          throwsArgumentError,
        );
        expect(
          () => StoryPersistentStateCommitExplanation(
            sourceSessionIndex: 0,
            previousRevision: 0,
            revision: 2,
            changes: commit.changes,
            propagatedSessionIndexes: [1],
          ),
          throwsArgumentError,
        );
        expect(
          () => StoryPersistentStateCommitExplanation(
            sourceSessionIndex: 0,
            previousRevision: 0,
            revision: 1,
            changes: [...commit.changes, ...commit.changes],
            propagatedSessionIndexes: [1],
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

StoryIncrementVariableEffect _increment(int amount) =>
    StoryIncrementVariableEffect(
      variableId: _score,
      amount: StoryIntegerValue(amount),
    );
StoryVariableComparisonCondition _equals(int value) =>
    StoryVariableComparisonCondition(
      variableId: _score,
      operator: StoryComparisonOperator.equal,
      value: StoryIntegerValue(value),
    );
({
  StoryNarrativeRuntime runtime,
  StoryProject project,
  List<StoryEntryPoint> entries,
})
_fixture({
  StoryNarrativeDebugAdapter? adapter,
  StoryNarrativeObserver? observer,
}) {
  final project = StoryProject(
    id: StoryProjectId('stage2_aggregate'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: _score,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
        StoryVariableDefinition(
          id: _flag,
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(true),
        ),
        StoryVariableDefinition(id: _memo, type: StoryValueType.string),
      ],
    ),
    events: [
      StoryEvent(
        id: _source,
        choices: [
          StoryChoice(
            id: _change,
            effects: [
              StorySetVariableEffect(
                variableId: _memo,
                value: StoryStringValue('text'),
              ),
              StoryUnsetVariableEffect(variableId: _flag),
              _increment(1),
              _increment(0),
            ],
            transition: StoryEventTransition(destinationEventId: _source),
          ),
          StoryChoice(
            id: _noChange,
            effects: [
              _increment(1),
              StoryDecrementVariableEffect(
                variableId: _score,
                amount: StoryIntegerValue(1),
              ),
            ],
            transition: StoryEventTransition(destinationEventId: _source),
          ),
          StoryChoice(
            id: _badChoice,
            effects: [_increment(1)],
            transition: StoryEventTransition(destinationEventId: _bad),
          ),
          StoryChoice(
            id: _denyChoice,
            effects: [_increment(1)],
            transition: StoryEventTransition(destinationEventId: _denied),
          ),
        ],
      ),
      StoryEvent(
        id: _bad,
        entryEffects: [_increment(1)],
        choices: [
          StoryChoice(
            id: StoryChoiceId('malformed_option'),
            availabilityCondition: StoryVariableIsSetCondition(
              variableId: _missing,
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
      StoryEvent(
        id: _denied,
        availabilityCondition: _equals(-1),
        automaticTransition: const StoryTerminalTransition(),
      ),
      StoryEvent(
        id: _continue,
        continuationTransition: StoryWeightedTransition(
          options: [
            StoryWeightedTransitionOption(
              weight: 1,
              transition: const StoryTerminalTransition(),
            ),
          ],
        ),
      ),
    ],
  );
  final entries = [
    StoryEntryPoint(id: _entry, eventId: _source),
    StoryEntryPoint(id: _badEntry, eventId: _bad),
    StoryEntryPoint(id: _deniedEntry, eventId: _denied),
    StoryEntryPoint(id: _continueEntry, eventId: _continue),
  ];
  return (
    project: project,
    entries: entries,
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: entries,
      randomSeed: 93,
      debugAdapter: adapter,
      observers: [?observer],
    ),
  );
}

String _snapshot(StoryNarrativeRuntime runtime) => jsonEncode(
  StoryNarrativeRuntimeSnapshotCodec().encode(runtime.createSnapshot()),
);
Object _failure(void Function() action) {
  try {
    action();
  } on Object catch (error) {
    return error;
  }
  throw StateError('Expected failure');
}

void _expectErrorParity(Object actual, Object expected) {
  expect(actual.runtimeType, expected.runtimeType);
  expect('$actual', '$expected');
}

final class _Observer implements StoryNarrativeObserver {
  final events = <String>[];
  @override
  void onNarrativeObservation(
    StoryNarrativeObservation observation,
  ) => events.add(
    '${observation.runtimeType}:${observation.sequence}:${observation.sessionIndex}',
  );
}

final class _Adapter extends StoryNarrativeDebugAdapter {
  final traces = <StoryRuntimeExecutionExplanation>[];
  final commits = <StoryPersistentStateCommitExplanation>[];
  final indexes = <int?>[];
  final calls = <String>[];
  List<Object> Function()? attemptReentry;
  void Function(StoryPersistentStateCommitExplanation)? commitCheck;
  bool commitChecked = false;
  final reentryErrors = <Object>[];
  bool throwOnCallbacks = false;
  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) => calls.add('effects');
  @override
  void onChoiceExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) => calls.add('choices');
  @override
  void onExecutionExplanation({
    required int? sessionIndex,
    required StoryRuntimeExecutionExplanation explanation,
  }) {
    traces.add(explanation);
    indexes.add(sessionIndex);
    calls.add('execution');
    reentryErrors.addAll(attemptReentry?.call() ?? []);
    if (throwOnCallbacks) {
      throw StateError('Intentional execution adapter failure');
    }
  }

  @override
  void onPersistentStateCommitExplanation(
    StoryPersistentStateCommitExplanation explanation,
  ) {
    commits.add(explanation);
    calls.add('commit');
    commitCheck?.call(explanation);
    commitChecked = true;
    if (throwOnCallbacks) {
      throw StateError('Intentional commit adapter failure');
    }
  }
}
