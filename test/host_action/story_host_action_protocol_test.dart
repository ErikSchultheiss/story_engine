import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryHostActionProtocol', () {
    test('allocates stable monotonic request IDs without a random source', () {
      final protocol = StoryHostActionProtocol(scope: 'session_7');

      final first = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
        arguments: const {'enemy': 'ancient_dragon'},
      );
      expect(first.id.value, 'host_action_session_7_0');
      expect(protocol.status, StoryHostActionProtocolStatus.awaitingHost);

      protocol.complete(first.id);
      final second = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'open_shop',
      );
      expect(second.id.value, 'host_action_session_7_1');
    });

    test('rejects scopes too long for portable request identity', () {
      expect(
        () => StoryHostActionProtocol(scope: List.filled(100, 'a').join()),
        throwsArgumentError,
      );
    });

    test('invalid request data does not consume request identity', () {
      final protocol = StoryHostActionProtocol(scope: 'session_8');

      expect(
        () => protocol.request(
          schemaNamespace: 'com.example.rpg',
          actionId: 'start_combat',
          arguments: const {'difficulty': 9007199254740992},
        ),
        throwsA(isA<StoryHostActionProtocolException>()),
      );

      final request = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
      );
      expect(request.id.value, 'host_action_session_8_0');
    });

    test('rejects re-entry while one request is pending', () {
      final protocol = StoryHostActionProtocol(scope: 'session_0');
      final request = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
      );

      expect(
        () => protocol.request(
          schemaNamespace: 'com.example.rpg',
          actionId: 'play_cinematic',
        ),
        throwsA(isA<StoryHostActionProtocolException>()),
      );
      expect(protocol.pendingRequest, request);
    });

    test('validates successful result type exactly', () {
      final protocol = StoryHostActionProtocol(scope: 'session_1');
      final request = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
        resultType: StoryHostActionValueType.enumeration('combat_result'),
      );

      expect(
        () => protocol.complete(request.id, value: 1),
        throwsA(isA<StoryHostActionProtocolException>()),
      );
      expect(protocol.status, StoryHostActionProtocolStatus.awaitingHost);

      final outcome = protocol.complete(request.id, value: 'victory');
      expect(outcome.requestId, request.id);
      expect(outcome.value, 'victory');
      expect(protocol.status, StoryHostActionProtocolStatus.ready);
    });

    test(
      'mismatched and duplicate resolution cannot mutate protocol state',
      () {
        final protocol = StoryHostActionProtocol(scope: 'session_2');
        final request = protocol.request(
          schemaNamespace: 'com.example.rpg',
          actionId: 'load_level',
        );
        final wrong = StoryHostActionRequestId('host_action_session_2_99');

        expect(
          () => protocol.complete(wrong),
          throwsA(isA<StoryHostActionProtocolException>()),
        );
        expect(protocol.pendingRequest, request);

        protocol.complete(request.id);
        expect(
          () => protocol.complete(request.id),
          throwsA(isA<StoryHostActionProtocolException>()),
        );
        expect(protocol.status, StoryHostActionProtocolStatus.ready);
      },
    );

    test('failure and cancellation are explicit host inputs', () {
      final failed = StoryHostActionProtocol(scope: 'session_3');
      final failedRequest = failed.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
      );
      final failure = failed.fail(
        failedRequest.id,
        code: 'host_error',
        message: 'Combat subsystem rejected the request.',
      );
      expect(failure.code, 'host_error');
      expect(failed.status, StoryHostActionProtocolStatus.ready);

      final cancelled = StoryHostActionProtocol(scope: 'session_4');
      final cancelledRequest = cancelled.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'open_shop',
      );
      final cancellation = cancelled.cancel(
        cancelledRequest.id,
        code: 'player_cancelled',
      );
      expect(cancellation.code, 'player_cancelled');
      expect(cancelled.status, StoryHostActionProtocolStatus.ready);
    });

    test('invalid outcome data leaves the pending request intact', () {
      final protocol = StoryHostActionProtocol(scope: 'session_9');
      final request = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
      );

      expect(
        () => protocol.fail(
          request.id,
          code: 'INVALID CODE',
          message: 'Bad machine token.',
        ),
        throwsA(isA<StoryHostActionProtocolException>()),
      );
      expect(protocol.pendingRequest, request);
    });

    test('pending protocol snapshot round-trips and restores same request', () {
      final protocol = StoryHostActionProtocol(scope: 'session_5');
      final request = protocol.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'start_combat',
        arguments: const {
          'enemy': 'ancient_dragon',
          'difficulty': 3,
          'boss': true,
        },
        resultType: StoryHostActionValueType.reference('combat_outcome'),
      );
      final codec = const StoryHostActionProtocolSnapshotCodec();

      final encoded = codec.encode(protocol.createSnapshot());
      final decoded = codec.decode(encoded);
      expect(codec.encode(decoded), encoded);
      final restored = StoryHostActionProtocol.restore(decoded);

      expect(restored.status, StoryHostActionProtocolStatus.awaitingHost);
      expect(restored.pendingRequest, request);
      expect(restored.pendingRequest?.id, request.id);

      restored.complete(request.id, value: 'outcome_victory');
      final next = restored.request(
        schemaNamespace: 'com.example.rpg',
        actionId: 'play_cinematic',
      );
      expect(next.id.value, 'host_action_session_5_1');
    });
  });
}
