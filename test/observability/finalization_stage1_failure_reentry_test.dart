import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/orchestration/story_narrative_runtime.dart'
    as internal_runtime;
import 'package:test/test.dart';

void main() {
  group('Finalization Stage 1 guarded failure diagnostics', () {
    for (final continueMode in [false, true]) {
      test(
        'failed effect callbacks reject all authority re-entry (continue=$continueMode)',
        () {
          final adapter = _ReenteringAdapter();
          final fixture = _fixture(
            adapter: adapter,
            continueMode: continueMode,
          );
          final source = fixture.runtime.startSession(_sourceEntry);
          final sibling = fixture.runtime.startSession(_safeEntry);
          adapter.action = () => _tryReentry(fixture.runtime, source);
          final before = _encode(fixture.runtime);
          final baseline = _fixture(continueMode: continueMode);
          final plainSource = baseline.runtime.startSession(_sourceEntry);
          baseline.runtime.startSession(_safeEntry);
          final plainError = _capture(
            () => continueMode
                ? plainSource.continueStory()
                : plainSource.choose(_fail),
          );

          final error = _capture(
            () => continueMode ? source.continueStory() : source.choose(_fail),
          );

          expect(error.runtimeType, plainError.runtimeType);
          expect(error.toString(), plainError.toString());
          expect(adapter.attempts, hasLength(5));
          expect(
            adapter.attempts,
            everyElement(isA<StoryNarrativeOperationException>()),
          );
          expect(adapter.values.map((e) => e.outcome), [
            StoryEffectOutcome.rolledBack,
            StoryEffectOutcome.rejected,
          ]);
          expect(_encode(fixture.runtime), before);
          expect(sibling.state.rawValueOf(_score), 0);
          // Subsequent caller input is allowed after the failed call has returned.
          final next = fixture.runtime.startSession(_safeEntry);
          expect(next.index, 2);
        },
      );
    }

    test('propagation failure exposes rolled-back effects under the guard', () {
      final adapter = _ReenteringAdapter();
      final fixture = _fixture(adapter: adapter, validEffects: true);
      final source = fixture.runtime.startSession(_sourceEntry);
      fixture.runtime.startSession(_safeEntry);
      adapter.action = () => _tryReentry(fixture.runtime, source);
      final before = _encode(fixture.runtime);
      final probe = internal_runtime.installStage9d6RollbackTestProbe(
        runtime: fixture.runtime,
        failAfterPreparedSiblingCount: 1,
      );

      expect(() => source.choose(_fail), throwsStateError);
      expect(probe.preparedSiblingReplacementCount, 1);
      expect(probe.rollbackRestoreAttemptCount, 1);
      expect(adapter.attempts, hasLength(5));
      expect(
        adapter.attempts,
        everyElement(isA<StoryNarrativeOperationException>()),
      );
      expect(adapter.values.map((e) => e.outcome), [
        StoryEffectOutcome.rolledBack,
      ]);
      expect(_encode(fixture.runtime), before);
    });
  });
}

final _score = StoryVariableId('score');
final _unset = StoryVariableId('unset_counter');
final _sourceEvent = StoryEventId('source');
final _safeEvent = StoryEventId('safe');
final _destination = StoryEventId('destination');
final _sourceEntry = StoryEntryPointId('source_entry');
final _safeEntry = StoryEntryPointId('safe_entry');
final _fail = StoryChoiceId('fail');
final _finish = StoryChoiceId('finish');

({StoryNarrativeRuntime runtime}) _fixture({
  StoryNarrativeDebugAdapter? adapter,
  bool continueMode = false,
  bool validEffects = false,
}) {
  final effects = <StoryEffect>[
    StoryIncrementVariableEffect(
      variableId: _score,
      amount: StoryIntegerValue(1),
    ),
    if (!validEffects)
      StoryIncrementVariableEffect(
        variableId: _unset,
        amount: StoryIntegerValue(1),
      ),
  ];
  final project = StoryProject(
    id: StoryProjectId('stage1_reentry'),
    entryEventId: _sourceEvent,
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: _score,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
        StoryVariableDefinition(id: _unset, type: StoryValueType.integer),
      ],
    ),
    events: [
      StoryEvent(
        id: _sourceEvent,
        choices: continueMode
            ? const []
            : [
                StoryChoice(
                  id: _fail,
                  transition: StoryEventTransition(
                    destinationEventId: _destination,
                  ),
                ),
                StoryChoice(
                  id: _finish,
                  transition: const StoryTerminalTransition(),
                ),
              ],
        continuationTransition: continueMode
            ? StoryEventTransition(destinationEventId: _destination)
            : null,
      ),
      StoryEvent(
        id: _safeEvent,
        continuationTransition: const StoryTerminalTransition(),
      ),
      StoryEvent(
        id: _destination,
        entryEffects: effects,
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  return (
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: [
        StoryEntryPoint(id: _sourceEntry, eventId: _sourceEvent),
        StoryEntryPoint(id: _safeEntry, eventId: _safeEvent),
      ],
      debugAdapter: adapter,
    ),
  );
}

List<Object> _tryReentry(
  StoryNarrativeRuntime runtime,
  StoryNarrativeSession source,
) => [
  _capture(() => runtime.startSession(_safeEntry)),
  _capture(() => source.choose(_finish)),
  _capture(source.continueStory),
  _capture(
    () => source.requestHostAction(
      schemaNamespace: 'com.example.stage1',
      actionId: 'wait',
    ),
  ),
  _capture(() => runtime.createSnapshot()),
];

String _encode(StoryNarrativeRuntime runtime) =>
    StoryNarrativeRuntimeSnapshotCodec().encodeJson(runtime.createSnapshot());

Object _capture(void Function() action) {
  try {
    action();
  } on Object catch (error) {
    return error;
  }
  return 'unexpected success';
}

final class _ReenteringAdapter extends StoryNarrativeDebugAdapter {
  List<Object> Function()? action;
  List<Object> attempts = [];
  List<StoryEffectExplanation> values = [];
  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) {
    values = explanations;
    attempts = action?.call() ?? [];
    // A broken adapter must not replace the authoritative execution exception.
    throw StateError('deliberately broken failure adapter');
  }
}
