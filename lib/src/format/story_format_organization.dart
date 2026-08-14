import '../identity/story_event_id.dart';
import 'story_format_group.dart';
import 'story_format_group_id.dart';
import 'story_format_tag.dart';
import 'story_format_tag_id.dart';

/// Runtime-neutral authoring organization carried by Story Format v1.
///
/// Primary organization uses an ordered nested group tree. An event may occur
/// at most once in that tree. Cross-cutting tag membership is independent and
/// many-to-many.
final class StoryFormatOrganization {
  factory StoryFormatOrganization({
    Iterable<StoryFormatGroup> groups = const [],
    Iterable<StoryFormatTag> tags = const [],
  }) {
    final copiedGroups = List<StoryFormatGroup>.unmodifiable(groups);
    final copiedTags = List<StoryFormatTag>.unmodifiable(tags);

    final groupIds = <StoryFormatGroupId>{};
    final groupedEventIds = <StoryEventId>{};
    for (final group in copiedGroups) {
      _collectGroupIdentities(
        group,
        groupIds: groupIds,
        groupedEventIds: groupedEventIds,
      );
    }

    final tagIds = <StoryFormatTagId>{};
    for (final tag in copiedTags) {
      if (!tagIds.add(tag.id)) {
        throw ArgumentError.value(
          tag.id,
          'tags',
          'Story Format tag IDs must be unique within one organization.',
        );
      }
    }

    return StoryFormatOrganization._(
      groups: copiedGroups,
      tags: copiedTags,
    );
  }

  StoryFormatOrganization._({required this.groups, required this.tags});

  /// Creates an organization with no groups or tags.
  factory StoryFormatOrganization.empty() => StoryFormatOrganization();

  /// Ordered primary root groups.
  final List<StoryFormatGroup> groups;

  /// Tags in explicit author-facing declaration order.
  final List<StoryFormatTag> tags;

  /// Whether this organization carries no group or tag metadata.
  bool get isEmpty => groups.isEmpty && tags.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatOrganization &&
          _orderedEqual(groups, other.groups) &&
          _orderedEqual(tags, other.tags);

  @override
  int get hashCode => Object.hash(
    StoryFormatOrganization,
    Object.hashAll(groups),
    Object.hashAll(tags),
  );

  @override
  String toString() =>
      'StoryFormatOrganization(groups: ${groups.length}, tags: ${tags.length})';
}

void _collectGroupIdentities(
  StoryFormatGroup group, {
  required Set<StoryFormatGroupId> groupIds,
  required Set<StoryEventId> groupedEventIds,
}) {
  if (!groupIds.add(group.id)) {
    throw ArgumentError.value(
      group.id,
      'groups',
      'Story Format group IDs must be unique across the complete group tree.',
    );
  }

  for (final eventId in group.eventIds) {
    if (!groupedEventIds.add(eventId)) {
      throw ArgumentError.value(
        eventId,
        'groups',
        'An event may appear at most once in the primary Story Format group '
            'tree.',
      );
    }
  }

  for (final child in group.children) {
    _collectGroupIdentities(
      child,
      groupIds: groupIds,
      groupedEventIds: groupedEventIds,
    );
  }
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
