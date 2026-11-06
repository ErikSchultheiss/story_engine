import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Story narrative observability', () {
    test('emits deterministic structural observations in committed order', () {
      final observer = _CollectingObserver();
      final fixture = _fixture(observer);
      final session = fixture.runtime.startSession(fixture.entryPointId);

      expect(observer.events, hasLength(3));
      expect(observer.events[0], isA<StoryNarrativeSessionStarted>());
      expect(observer.events[1], isA<StoryNarrativeEventEntered>());
      expect(observer.events[2], isA<StoryNarrativeChoicePresented>());

      session.choose(fixture.choiceId);

      expect(observer.events, hasLength(6));
      expect(observer.events[3], isA<StoryNarrativeChoiceSelected>());
      expect(observer.events[4], isA<StoryNarrativeEventEntered>());
      expect(observer.events[5], isA<StoryNarrativeSessionEnded>());
      expect(observer.events.map((event) => event.sequence), [
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
    });

    test('host-action request and resolution are structured observations', () {
      final observer = _CollectingObserver();
      final fixture = _fixture(observer);
      final session = fixture.runtime.startSession(fixture.entryPointId);
      final request = session.requestHostAction(
        schemaNamespace: 'com.example.game',
        actionId: 'open_shop',
      );

      final requested =
          observer.events.last as StoryNarrativeHostActionRequested;
      expect(requested.requestId, request.id);
      expect(requested.actionId, 'open_shop');

      session.failHostAction(
        request.id,
        code: 'shop_unavailable',
        message: 'Shop is closed.',
      );
      final completed =
          observer.events.last as StoryNarrativeHostActionCompleted;
      expect(completed.requestId, request.id);
      expect(completed.resolution, StoryNarrativeHostActionResolution.failed);
      expect(completed.code, 'shop_unavailable');
    });

    test('observer failures never alter narrative semantics', () {
      final throwing = _ThrowingObserver();
      final fixture = _fixture(throwing);
      final session = fixture.runtime.startSession(fixture.entryPointId);

      expect(session.sessionStatus, StoryNarrativeSessionStatus.awaitingChoice);
      expect(() => session.choose(fixture.choiceId), returnsNormally);
      expect(session.isTerminated, isTrue);
    });

    test('observer callbacks cannot re-enter the same runtime authority', () {
      late StoryNarrativeRuntime runtime;
      final observer = _ReentryObserver(() {
        runtime.resolveAndStartSession();
      });
      final base = _fixture(observer);
      runtime = base.runtime;

      final session = runtime.startSession(base.entryPointId);
      expect(observer.reentryRejected, isTrue);
      expect(session.sessionStatus, StoryNarrativeSessionStatus.awaitingChoice);
    });

    test('failed operations emit a non-authoritative structured error', () {
      final observer = _CollectingObserver();
      final fixture = _fixture(observer);
      final session = fixture.runtime.startSession(fixture.entryPointId);
      session.choose(fixture.choiceId);

      expect(
        () => session.choose(fixture.choiceId),
        throwsA(isA<StoryNarrativeOperationException>()),
      );
      final error = observer.events.last as StoryNarrativeError;
      expect(error.category, StoryNarrativeErrorCategory.operation);
      expect(error.operation, 'choose');
      expect(error.sessionIndex, session.index);
    });

    test('observer event model contains no timestamps or host objects', () {
      final source = File(
        'lib/src/observability/story_narrative_observer.dart',
      ).readAsStringSync();
      for (final forbidden in <String>[
        'DateTime',
        'timestamp',
        'Stopwatch',
        'BuildContext',
        'GameObject',
        'UObject',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

({
  StoryNarrativeRuntime runtime,
  StoryEntryPointId entryPointId,
  StoryChoiceId choiceId,
})
_fixture(StoryNarrativeObserver observer) {
  final startId = StoryEventId('evt_observe_start');
  final endId = StoryEventId('evt_observe_end');
  final choiceId = StoryChoiceId('choice_observe_go');
  final entryPointId = StoryEntryPointId('entry_observe');
  final project = StoryProject(
    id: StoryProjectId('project_observe'),
    entryEventId: startId,
    events: [
      StoryEvent(
        id: startId,
        choices: [
          StoryChoice(
            id: choiceId,
            transition: StoryEventTransition(destinationEventId: endId),
          ),
        ],
      ),
      StoryEvent(
        id: endId,
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  return (
    runtime: StoryNarrativeRuntime(
      project: project,
      entryPoints: [StoryEntryPoint(id: entryPointId, eventId: startId)],
      observers: [observer],
    ),
    entryPointId: entryPointId,
    choiceId: choiceId,
  );
}

final class _CollectingObserver implements StoryNarrativeObserver {
  final List<StoryNarrativeObservation> events = [];

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    events.add(observation);
  }
}

final class _ThrowingObserver implements StoryNarrativeObserver {
  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    throw StateError('observer failure');
  }
}

final class _ReentryObserver implements StoryNarrativeObserver {
  _ReentryObserver(this.reenter);

  final void Function() reenter;
  bool reentryRejected = false;

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    if (reentryRejected) {
      return;
    }
    try {
      reenter();
    } on StoryNarrativeOperationException {
      reentryRejected = true;
    }
  }
}
