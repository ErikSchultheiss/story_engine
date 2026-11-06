import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryNarrativeSession suspendable host actions', () {
    test('awaitingHost blocks narrative input until typed completion', () {
      final eventId = StoryEventId('evt_shop');
      final entryId = StoryEntryPointId('entry_shop');
      final project = StoryProject(
        id: StoryProjectId('project_host_action_pause'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [StoryEntryPoint(id: entryId, eventId: eventId)],
      );
      final session = runtime.startSession(entryId);

      expect(
        session.sessionStatus,
        StoryNarrativeSessionStatus.awaitingContinue,
      );
      final request = session.requestHostAction(
        schemaNamespace: 'com.example.rpg',
        actionId: 'open_shop',
        arguments: const {'shop': 'village_blacksmith'},
        resultType: const StoryHostActionValueType.boolean(),
      );

      expect(session.status, StoryEngineStatus.awaitingContinue);
      expect(session.sessionStatus, StoryNarrativeSessionStatus.awaitingHost);
      expect(session.pendingHostAction, request);
      expect(runtime.history.sessions.single.isAwaitingHost, isTrue);
      expect(
        runtime.history.sessions.single.sessionStatus,
        StoryNarrativeSessionStatus.awaitingHost,
      );
      expect(session.availableChoices, isEmpty);
      expect(
        session.continueStory,
        throwsA(isA<StoryNarrativeOperationException>()),
      );

      final outcome = session.completeHostAction(request.id, value: true);
      expect(outcome.value, true);
      expect(session.pendingHostAction, isNull);
      expect(
        session.sessionStatus,
        StoryNarrativeSessionStatus.awaitingContinue,
      );

      session.continueStory();
      expect(session.sessionStatus, StoryNarrativeSessionStatus.terminated);
      expect(runtime.activeSession, isNull);
    });

    test('failure and cancellation resume the same committed core pause', () {
      final eventId = StoryEventId('evt_cinematic');
      final entryId = StoryEntryPointId('entry_cinematic');
      final project = StoryProject(
        id: StoryProjectId('project_host_outcomes'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      StoryNarrativeSession buildSession() => StoryNarrativeRuntime(
        project: project,
        entryPoints: [StoryEntryPoint(id: entryId, eventId: eventId)],
      ).startSession(entryId);

      final failed = buildSession();
      final failedRequest = failed.requestHostAction(
        schemaNamespace: 'com.example.rpg',
        actionId: 'play_cinematic',
      );
      final failure = failed.failHostAction(
        failedRequest.id,
        code: 'asset_missing',
        message: 'Cinematic asset was unavailable.',
      );
      expect(failure.code, 'asset_missing');
      expect(
        failed.sessionStatus,
        StoryNarrativeSessionStatus.awaitingContinue,
      );

      final cancelled = buildSession();
      final cancelledRequest = cancelled.requestHostAction(
        schemaNamespace: 'com.example.rpg',
        actionId: 'play_cinematic',
      );
      cancelled.cancelHostAction(cancelledRequest.id, code: 'host_cancelled');
      expect(
        cancelled.sessionStatus,
        StoryNarrativeSessionStatus.awaitingContinue,
      );
    });

    test('snapshot preserves pending request without host-engine objects', () {
      final defaultEventId = StoryEventId('evt_default');
      final hostEventId = StoryEventId('evt_host_selected');
      final entryId = StoryEntryPointId('entry_host_selected');
      final project = StoryProject(
        id: StoryProjectId('project_pending_snapshot'),
        entryEventId: defaultEventId,
        events: [
          StoryEvent(
            id: defaultEventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: hostEventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [StoryEntryPoint(id: entryId, eventId: hostEventId)],
      );
      final session = runtime.startSession(entryId);
      final request = session.requestHostAction(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
        arguments: const {'enemy': 'ancient_dragon'},
        resultType: StoryHostActionValueType.enumeration('combat_result'),
      );

      final snapshot = session.createSnapshot();
      final restoredEngine = StoryEngine.restore(
        project: project,
        snapshot: snapshot.runtimeSnapshot,
      );
      final restoredProtocol = StoryHostActionProtocol.restore(
        snapshot.hostActionSnapshot,
      );

      expect(restoredEngine.currentEvent?.id, hostEventId);
      expect(restoredEngine.status, StoryEngineStatus.awaitingContinue);
      expect(
        restoredProtocol.status,
        StoryHostActionProtocolStatus.awaitingHost,
      );
      expect(restoredProtocol.pendingRequest?.id, request.id);

      // Restore never re-dispatches. The host reconciles request.id, then sends
      // one explicit result when it knows the external operation's outcome.
      restoredProtocol.complete(request.id, value: 'victory');
      expect(restoredProtocol.status, StoryHostActionProtocolStatus.ready);
    });
  });
}
