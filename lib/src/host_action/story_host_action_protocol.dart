import '../identity/story_host_action_request_id.dart';
import 'story_host_action.dart';

/// Lifecycle of the deterministic suspendable host-action protocol.
enum StoryHostActionProtocolStatus {
  /// No host action is pending and narrative input may proceed.
  ready,

  /// One stable request is pending and narrative input must remain suspended.
  awaitingHost,
}

/// Immutable protocol state required to restore a pending host interaction.
///
/// This contains declarative data only. It never stores a callback, Future,
/// socket, engine object, or another host-owned runtime handle.
final class StoryHostActionProtocolSnapshot {
  StoryHostActionProtocolSnapshot({
    required String scope,
    required this.nextRequestOrdinal,
    required this.pendingRequest,
  }) : scope = _validateScope(scope) {
    if (nextRequestOrdinal < 0 || nextRequestOrdinal > _maxPortableOrdinal) {
      throw ArgumentError.value(
        nextRequestOrdinal,
        'nextRequestOrdinal',
        'The next request ordinal must be a non-negative portable integer.',
      );
    }
    final request = pendingRequest;
    if (request != null) {
      final requestOrdinal = _requestOrdinalForScope(request.id, this.scope);
      if (requestOrdinal == null || requestOrdinal != nextRequestOrdinal - 1) {
        throw ArgumentError.value(
          request.id,
          'pendingRequest',
          'Pending request identity must be the most recently allocated '
              'request in this protocol scope.',
        );
      }
    }
  }

  final String scope;
  final int nextRequestOrdinal;
  final StoryHostActionRequest? pendingRequest;

  StoryHostActionProtocolStatus get status => pendingRequest == null
      ? StoryHostActionProtocolStatus.ready
      : StoryHostActionProtocolStatus.awaitingHost;
}

/// Deterministic one-request-at-a-time suspend/resume state machine.
///
/// The protocol owns correlation identity and resolution validation only. The
/// actual asynchronous work is always performed by trusted host code outside
/// this class.
final class StoryHostActionProtocol {
  StoryHostActionProtocol({required String scope})
    : _scope = _validateScope(scope),
      _nextRequestOrdinal = 0;

  StoryHostActionProtocol._restore(StoryHostActionProtocolSnapshot snapshot)
    : _scope = snapshot.scope,
      _nextRequestOrdinal = snapshot.nextRequestOrdinal,
      _pendingRequest = snapshot.pendingRequest;

  /// Restores one protocol state without re-dispatching the pending action.
  factory StoryHostActionProtocol.restore(
    StoryHostActionProtocolSnapshot snapshot,
  ) => StoryHostActionProtocol._restore(snapshot);

  final String _scope;
  int _nextRequestOrdinal;
  StoryHostActionRequest? _pendingRequest;

  StoryHostActionProtocolStatus get status => _pendingRequest == null
      ? StoryHostActionProtocolStatus.ready
      : StoryHostActionProtocolStatus.awaitingHost;

  StoryHostActionRequest? get pendingRequest => _pendingRequest;

  /// Creates exactly one stable pending request and enters `awaitingHost`.
  StoryHostActionRequest request({
    required String schemaNamespace,
    required String actionId,
    Map<String, Object> arguments = const {},
    StoryHostActionValueType? resultType,
  }) {
    if (_pendingRequest != null) {
      throw const StoryHostActionProtocolException(
        message: 'Cannot emit a second host action while one is pending.',
        operation: 'request',
      );
    }

    final ordinal = _nextRequestOrdinal;
    if (ordinal >= _maxPortableOrdinal) {
      throw const StoryHostActionProtocolException(
        message: 'Host-action request ordinal exhausted the portable range.',
        operation: 'request',
      );
    }
    late final StoryHostActionRequest request;
    try {
      request = StoryHostActionRequest(
        id: StoryHostActionRequestId('host_action_${_scope}_$ordinal'),
        schemaNamespace: schemaNamespace,
        actionId: actionId,
        arguments: arguments,
        resultType: resultType,
      );
    } on ArgumentError catch (error) {
      throw StoryHostActionProtocolException(
        message: 'Invalid host-action request: $error',
        operation: 'request',
      );
    }
    _pendingRequest = request;
    _nextRequestOrdinal = ordinal + 1;
    return request;
  }

  /// Resolves the pending request successfully after exact result validation.
  StoryHostActionCompleted complete(
    StoryHostActionRequestId requestId, {
    Object? value,
  }) {
    final request = _requirePending(requestId, 'complete');
    if (!hostActionResultMatchesType(value, request.resultType)) {
      throw StoryHostActionProtocolException(
        message: request.resultType == null
            ? 'Host action ${request.id} declares no result value.'
            : 'Host action ${request.id} result does not match the declared '
                  '${request.resultType!.kind.name} type.',
        operation: 'complete',
      );
    }
    _pendingRequest = null;
    return StoryHostActionCompleted(requestId: requestId, value: value);
  }

  /// Resolves the pending request as an explicit host-reported failure.
  StoryHostActionFailed fail(
    StoryHostActionRequestId requestId, {
    required String code,
    required String message,
  }) {
    _requirePending(requestId, 'fail');
    late final StoryHostActionFailed outcome;
    try {
      outcome = StoryHostActionFailed(
        requestId: requestId,
        code: code,
        message: message,
      );
    } on ArgumentError catch (error) {
      throw StoryHostActionProtocolException(
        message: 'Invalid host-action failure: $error',
        operation: 'fail',
      );
    }
    _pendingRequest = null;
    return outcome;
  }

  /// Resolves the pending request as an explicit cancellation.
  StoryHostActionCancelled cancel(
    StoryHostActionRequestId requestId, {
    required String code,
    String? message,
  }) {
    _requirePending(requestId, 'cancel');
    late final StoryHostActionCancelled outcome;
    try {
      outcome = StoryHostActionCancelled(
        requestId: requestId,
        code: code,
        message: message,
      );
    } on ArgumentError catch (error) {
      throw StoryHostActionProtocolException(
        message: 'Invalid host-action cancellation: $error',
        operation: 'cancel',
      );
    }
    _pendingRequest = null;
    return outcome;
  }

  /// Captures deterministic protocol state at a committed host boundary.
  StoryHostActionProtocolSnapshot createSnapshot() =>
      StoryHostActionProtocolSnapshot(
        scope: _scope,
        nextRequestOrdinal: _nextRequestOrdinal,
        pendingRequest: _pendingRequest,
      );

  StoryHostActionRequest _requirePending(
    StoryHostActionRequestId requestId,
    String operation,
  ) {
    final pending = _pendingRequest;
    if (pending == null) {
      throw StoryHostActionProtocolException(
        message: 'No host action is pending.',
        operation: operation,
      );
    }
    if (pending.id != requestId) {
      throw StoryHostActionProtocolException(
        message: 'Request $requestId does not match pending ${pending.id}.',
        operation: operation,
      );
    }
    return pending;
  }
}

/// Reports an invalid suspend/resume protocol operation.
final class StoryHostActionProtocolException implements Exception {
  const StoryHostActionProtocolException({
    required this.message,
    required this.operation,
  });

  final String message;
  final String operation;

  @override
  String toString() => 'StoryHostActionProtocolException: $message';
}

final RegExp _scopePattern = RegExp(r'^[a-z][a-z0-9_]*$');

String _validateScope(String value) {
  if (value.length > 99 || !_scopePattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'scope',
      'Host-action protocol scopes must be stable lower-case machine IDs no '
          'longer than 99 characters.',
    );
  }
  return value;
}

const int _maxPortableOrdinal = 9007199254740991;

int? _requestOrdinalForScope(StoryHostActionRequestId id, String scope) {
  final prefix = 'host_action_${scope}_';
  if (!id.value.startsWith(prefix)) {
    return null;
  }
  final suffix = id.value.substring(prefix.length);
  final ordinal = int.tryParse(suffix);
  if (ordinal == null || ordinal < 0 || ordinal.toString() != suffix) {
    return null;
  }
  return ordinal;
}
