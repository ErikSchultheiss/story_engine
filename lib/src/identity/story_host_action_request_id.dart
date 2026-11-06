import 'story_identifier_rules.dart';

/// Stable machine identity for one suspendable host-action request.
///
/// Request IDs are protocol correlation identities. They survive snapshot and
/// restore so the host can reconcile an already-started external operation
/// without relying on an in-memory callback, future, or engine object.
final class StoryHostActionRequestId {
  StoryHostActionRequestId(String value)
    : value = validateStoryMachineId(value);

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryHostActionRequestId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
