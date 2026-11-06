import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Finalization Stage 1 atomic presentation', () {
    for (final diagnostics in [false, true]) {
      for (final observers in [false, true]) {
        final label = 'diagnostics=$diagnostics observers=$observers';
        test('invalid startup choices leave no allocated session ($label)', () {
          final observer = _RecordingObserver();
          final adapter = diagnostics ? _RecordingAdapter() : null;
          final fixture = _fixture(
            adapter: adapter,
            observer: observers ? observer : null,
          );
          final before = _encode(fixture.runtime);

          expect(
            () => fixture.runtime.startSession(_badEntry),
            throwsA(isA<StoryEngineExecutionException>()),
          );

          expect(_encode(fixture.runtime, observationSequence: 0), before);
          expect(fixture.runtime.activeSessions, isEmpty);
          expect(fixture.runtime.history.sessions, isEmpty);
          expect(
            observer.events.where((e) => e is! StoryNarrativeError),
            isEmpty,
          );
          if (adapter != null) {
            expect(adapter.effects, hasLength(1));
            expect(adapter.effects.single.sessionIndex, isNull);
            expect(
              adapter.effects.single.values.map((e) => e.outcome),
              everyElement(StoryEffectOutcome.rolledBack),
            );
            expect(adapter.choices, isEmpty);
          }

          final session = fixture.runtime.startSession(_safeEntry);
          final fresh = _fixture().runtime.startSession(_safeEntry);
          expect(session.index, 0);
          expect(session.randomSeed, fresh.randomSeed);
          expect(
            session.createSnapshot().runtimeSnapshot,
            fresh.createSnapshot().runtimeSnapshot,
          );
        });

        for (final continueMode in [false, true]) {
          test(
            'invalid destination rolls back source and siblings ($label continue=$continueMode)',
            () {
              final observer = _RecordingObserver();
              final adapter = diagnostics ? _RecordingAdapter() : null;
              final fixture = _fixture(
                adapter: adapter,
                observer: observers ? observer : null,
              );
              final source = fixture.runtime.startSession(
                continueMode ? _continueEntry : _safeEntry,
              );
              final sibling = fixture.runtime.startSession(_safeEntry);
              // A pending host request in a sibling must survive source rollback.
              final request = sibling.requestHostAction(
                schemaNamespace: 'com.example.stage1',
                actionId: 'wait',
              );
              final before = _encode(fixture.runtime);
              final beforeSequence = fixture.runtime
                  .createSnapshot()
                  .nextObservationSequence;
              final beforeSource = source.createSnapshot().runtimeSnapshot;
              final beforeSibling = sibling.createSnapshot().runtimeSnapshot;
              observer.events.clear();
              adapter?.effects.clear();
              adapter?.choices.clear();

              expect(
                () => continueMode
                    ? source.continueStory()
                    : source.choose(_goBad),
                throwsA(isA<StoryEngineExecutionException>()),
              );

              expect(
                _encode(fixture.runtime, observationSequence: beforeSequence),
                before,
              );
              expect(source.createSnapshot().runtimeSnapshot, beforeSource);
              expect(sibling.createSnapshot().runtimeSnapshot, beforeSibling);
              expect(sibling.pendingHostAction?.id, request.id);
              expect(fixture.runtime.activeSessions.map((s) => s.index), [
                0,
                1,
              ]);
              expect(
                observer.events.where((e) => e is! StoryNarrativeError),
                isEmpty,
              );
              if (adapter != null) {
                expect(adapter.effects, hasLength(1));
                expect(adapter.effects.single.sessionIndex, source.index);
                expect(
                  adapter.effects.single.values.map((e) => e.outcome),
                  everyElement(StoryEffectOutcome.rolledBack),
                );
                expect(adapter.choices, isEmpty);
              }
              // The rolled-back source remains usable and its checkpoint restores.
              final restored = StoryNarrativeRuntime.restore(
                project: fixture.project,
                entryPoints: fixture.entries,
                snapshot: fixture.runtime.createSnapshot(),
              );
              if (!continueMode) {
                source.choose(_finish);
                restored.sessionByIndex(source.index).choose(_finish);
                expect(
                  source.createSnapshot().runtimeSnapshot,
                  restored
                      .sessionByIndex(source.index)
                      .createSnapshot()
                      .runtimeSnapshot,
                );
              }
            },
          );
        }
      }
    }

    test(
      'weighted automatic entry failure preserves orchestration RNG and next seed',
      () {
        final fixture = _fixture();
        final runtime = StoryNarrativeRuntime(
          project: fixture.project,
          entryPoints: [
            StoryEntryPoint(
              id: StoryEntryPointId('bad_a'),
              eventId: _badEvent,
              weight: 1,
            ),
            StoryEntryPoint(
              id: StoryEntryPointId('bad_b'),
              eventId: _badEvent,
              weight: 3,
            ),
            StoryEntryPoint(id: _safeEntry, eventId: _safeEvent, priority: -1),
          ],
          randomSeed: 123,
        );
        final before = _encode(runtime);
        for (var attempt = 0; attempt < 2; attempt++) {
          expect(
            () => runtime.resolveAndStartSession(),
            throwsA(isA<StoryEngineExecutionException>()),
          );
          expect(_encode(runtime), before);
        }
        final session = runtime.startSession(_safeEntry);
        final fresh = StoryNarrativeRuntime(
          project: fixture.project,
          entryPoints: runtime.entryPoints,
          randomSeed: 123,
        ).startSession(_safeEntry);
        expect(session.randomSeed, fresh.randomSeed);
        expect(session.index, fresh.index);
      },
    );

    test(
      'invalid choice presentation has identical exceptions with diagnostics off/on',
      () {
        final plain = _fixture();
        final debug = _fixture(adapter: _RecordingAdapter());
        final plainSession = plain.runtime.startSession(_safeEntry);
        final debugSession = debug.runtime.startSession(_safeEntry);
        final plainError = _capture(() => plainSession.choose(_goBad));
        final debugError = _capture(() => debugSession.choose(_goBad));
        expect(debugError.runtimeType, plainError.runtimeType);
        expect(debugError.toString(), plainError.toString());
        expect(_encode(debug.runtime), _encode(plain.runtime));
      },
    );

    test('successful presentation and lifecycle order remain unchanged', () {
      final observer = _RecordingObserver();
      final adapter = _RecordingAdapter();
      final fixture = _fixture(adapter: adapter, observer: observer);
      final session = fixture.runtime.startSession(_safeEntry);
      expect(observer.events.map((e) => e.runtimeType), [
        StoryNarrativeSessionStarted,
        StoryNarrativeEventEntered,
        StoryNarrativeChoicePresented,
        StoryNarrativeChoicePresented,
      ]);
      expect(adapter.choices.single.map((e) => e.choiceId), [_goBad, _finish]);
      expect(session.availableChoices.map((e) => e.id), [_goBad, _finish]);
      session.choose(_finish);
      expect(observer.events.map((e) => e.runtimeType).toList().sublist(4), [
        StoryNarrativeChoiceSelected,
        StoryNarrativeSessionEnded,
      ]);
      expect(session.isTerminated, isTrue);
    });
  });
}

final _score = StoryVariableId('score');
final _missing = StoryVariableId('missing');
final _safeEvent = StoryEventId('safe');
final _badEvent = StoryEventId('bad');
final _continueEvent = StoryEventId('continue');
final _safeEntry = StoryEntryPointId('safe_entry');
final _badEntry = StoryEntryPointId('bad_entry');
final _continueEntry = StoryEntryPointId('continue_entry');
final _goBad = StoryChoiceId('go_bad');
final _finish = StoryChoiceId('finish');

({
  StoryProject project,
  List<StoryEntryPoint> entries,
  StoryNarrativeRuntime runtime,
})
_fixture({
  StoryNarrativeDebugAdapter? adapter,
  StoryNarrativeObserver? observer,
}) {
  StoryTransition randomBadTransition() => StoryWeightedTransition(
    options: [
      StoryWeightedTransitionOption(
        weight: 1,
        transition: StoryEventTransition(destinationEventId: _badEvent),
      ),
      StoryWeightedTransitionOption(
        weight: 3,
        transition: StoryEventTransition(destinationEventId: _badEvent),
      ),
    ],
  );
  final project = StoryProject(
    id: StoryProjectId('stage1_atomic'),
    entryEventId: _safeEvent,
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: _score,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(0),
        ),
      ],
    ),
    events: [
      StoryEvent(
        id: _safeEvent,
        choices: [
          StoryChoice(
            id: _goBad,
            effects: [
              StoryIncrementVariableEffect(
                variableId: _score,
                amount: StoryIntegerValue(2),
              ),
            ],
            transition: randomBadTransition(),
          ),
          StoryChoice(id: _finish, transition: const StoryTerminalTransition()),
        ],
      ),
      StoryEvent(
        id: _continueEvent,
        continuationTransition: randomBadTransition(),
      ),
      StoryEvent(
        id: _badEvent,
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: _score,
            amount: StoryIntegerValue(3),
          ),
        ],
        choices: [
          StoryChoice(
            id: StoryChoiceId('invalid'),
            availabilityCondition: StoryVariableIsSetCondition(
              variableId: _missing,
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
    ],
  );
  final entries = [
    StoryEntryPoint(id: _safeEntry, eventId: _safeEvent),
    StoryEntryPoint(id: _badEntry, eventId: _badEvent),
    StoryEntryPoint(id: _continueEntry, eventId: _continueEvent),
  ];
  return (
    project: project,
    entries: entries,
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: entries,
      randomSeed: 123,
      debugAdapter: adapter,
      observers: [?observer],
    ),
  );
}

String _encode(StoryNarrativeRuntime runtime, {int? observationSequence}) {
  final encoded = StoryNarrativeRuntimeSnapshotCodec().encode(
    runtime.createSnapshot(),
  );
  if (observationSequence != null) {
    encoded['nextObservationSequence'] = observationSequence;
  }
  return jsonEncode(encoded);
}

Object _capture(void Function() action) {
  try {
    action();
  } on Object catch (error) {
    return error;
  }
  throw StateError('Expected failure');
}

final class _RecordingObserver implements StoryNarrativeObserver {
  final events = <StoryNarrativeObservation>[];
  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) =>
      events.add(observation);
}

final class _RecordingAdapter extends StoryNarrativeDebugAdapter {
  final effects =
      <({int? sessionIndex, List<StoryEffectExplanation> values})>[];
  final choices = <List<StoryChoiceExplanation>>[];
  @override
  void onEffectExplanations({
    required int? sessionIndex,
    required List<StoryEffectExplanation> explanations,
  }) => effects.add((sessionIndex: sessionIndex, values: explanations));
  @override
  void onChoiceExplanations({
    required int sessionIndex,
    required List<StoryChoiceExplanation> explanations,
  }) => choices.add(explanations);
}
