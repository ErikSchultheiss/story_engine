import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Story Format organization', () {
    test('groups preserve authored event and child order', () {
      final eventB = StoryEventId('event_group_b');
      final eventA = StoryEventId('event_group_a');
      final childB = StoryFormatGroup(
        id: StoryFormatGroupId('group_child_b'),
      );
      final childA = StoryFormatGroup(
        id: StoryFormatGroupId('group_child_a'),
      );

      final group = StoryFormatGroup(
        id: StoryFormatGroupId('group_root'),
        eventIds: [eventB, eventA],
        children: [childB, childA],
      );

      expect(group.eventIds, [eventB, eventA]);
      expect(group.children, [childB, childA]);
    });

    test('an event may appear only once in the primary group tree', () {
      final eventId = StoryEventId('event_primary_once');

      expect(
        () => StoryFormatOrganization(
          groups: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_primary_a'),
              eventIds: [eventId],
            ),
            StoryFormatGroup(
              id: StoryFormatGroupId('group_primary_b'),
              eventIds: [eventId],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('group IDs are unique across the nested tree', () {
      final duplicateId = StoryFormatGroupId('group_duplicate');

      expect(
        () => StoryFormatOrganization(
          groups: [
            StoryFormatGroup(
              id: duplicateId,
              children: [StoryFormatGroup(id: duplicateId)],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('tag membership is set-like and stored in stable ID order', () {
      final eventB = StoryEventId('event_tag_b');
      final eventA = StoryEventId('event_tag_a');
      final tag = StoryFormatTag(
        id: StoryFormatTagId('tag_puzzle'),
        eventIds: [eventB, eventA],
      );

      expect(tag.eventIds, [eventA, eventB]);
      expect(
        () => StoryFormatTag(
          id: StoryFormatTagId('tag_duplicate_member'),
          eventIds: [eventA, eventA],
        ),
        throwsArgumentError,
      );
    });

    test('tag declarations preserve author-facing order', () {
      final second = StoryFormatTag(id: StoryFormatTagId('tag_second'));
      final first = StoryFormatTag(id: StoryFormatTagId('tag_first'));
      final organization = StoryFormatOrganization(tags: [second, first]);

      expect(organization.tags, [second, first]);
    });
  });
}
