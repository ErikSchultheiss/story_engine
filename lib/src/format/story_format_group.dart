import '../identity/story_alias.dart';
import '../identity/story_event_id.dart';
import '../presentation/story_text.dart';
import 'story_format_group_id.dart';

/// One runtime-neutral node in the primary authored organization tree.
///
/// The generic engine deliberately calls this concept a "group", not a
/// chapter or section. A host may interpret a group as a chapter, folder,
/// quest line, location, authoring queue, or another organizational concept.
/// Moving an event between groups has no runtime semantics.
final class StoryFormatGroup {
  factory StoryFormatGroup({
    required StoryFormatGroupId id,
    StoryAlias? alias,
    StoryText? label,
    Iterable<StoryEventId> eventIds = const [],
    Iterable<StoryFormatGroup> children = const [],
  }) => StoryFormatGroup._(
    id: id,
    alias: alias,
    label: label,
    eventIds: List<StoryEventId>.unmodifiable(eventIds),
    children: List<StoryFormatGroup>.unmodifiable(children),
  );

  StoryFormatGroup._({
    required this.id,
    required this.alias,
    required this.label,
    required this.eventIds,
    required this.children,
  });

  /// Stable group identity independent from label/path.
  final StoryFormatGroupId id;

  /// Optional developer-friendly handle; never durable identity.
  final StoryAlias? alias;

  /// Optional source/default-language author-facing label.
  final StoryText? label;

  /// Event membership in explicit authored display/organization order.
  final List<StoryEventId> eventIds;

  /// Child groups in explicit authored order.
  final List<StoryFormatGroup> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatGroup &&
          other.id == id &&
          other.alias == alias &&
          other.label == label &&
          _orderedEqual(eventIds, other.eventIds) &&
          _orderedEqual(children, other.children);

  @override
  int get hashCode => Object.hash(
    StoryFormatGroup,
    id,
    alias,
    label,
    Object.hashAll(eventIds),
    Object.hashAll(children),
  );

  @override
  String toString() =>
      'StoryFormatGroup(id: $id, events: ${eventIds.length}, '
      'children: ${children.length})';
}

bool _orderedEqual<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
