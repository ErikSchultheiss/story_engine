import '../identity/story_alias.dart';
import '../identity/story_event_id.dart';
import '../presentation/story_text.dart';
import 'story_format_tag_id.dart';

/// One cross-cutting authored classification tag.
///
/// Tag membership is set-like rather than sequence-sensitive. The constructor
/// therefore rejects duplicate event membership and stores members in stable
/// event-ID order. The tag declaration itself may still appear in author-chosen
/// order inside `StoryFormatOrganization`.
final class StoryFormatTag {
  factory StoryFormatTag({
    required StoryFormatTagId id,
    StoryAlias? alias,
    StoryText? label,
    Iterable<StoryEventId> eventIds = const [],
  }) {
    final unique = <StoryEventId>{};
    for (final eventId in eventIds) {
      if (!unique.add(eventId)) {
        throw ArgumentError.value(
          eventId,
          'eventIds',
          'A Story Format tag cannot contain the same event more than once.',
        );
      }
    }
    final ordered = unique.toList()
      ..sort((left, right) => left.value.compareTo(right.value));

    return StoryFormatTag._(
      id: id,
      alias: alias,
      label: label,
      eventIds: List<StoryEventId>.unmodifiable(ordered),
    );
  }

  StoryFormatTag._({
    required this.id,
    required this.alias,
    required this.label,
    required this.eventIds,
  });

  /// Stable tag identity.
  final StoryFormatTagId id;

  /// Optional developer-friendly handle; never durable identity.
  final StoryAlias? alias;

  /// Optional source/default-language author-facing label.
  final StoryText? label;

  /// Set-like event membership in canonical event-ID order.
  final List<StoryEventId> eventIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatTag &&
          other.id == id &&
          other.alias == alias &&
          other.label == label &&
          _orderedEventIdsEqual(eventIds, other.eventIds);

  @override
  int get hashCode => Object.hash(
    StoryFormatTag,
    id,
    alias,
    label,
    Object.hashAll(eventIds),
  );

  @override
  String toString() =>
      'StoryFormatTag(id: $id, events: ${eventIds.length})';
}

bool _orderedEventIdsEqual(List<StoryEventId> left, List<StoryEventId> right) {
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
