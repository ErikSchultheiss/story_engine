import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryFormatBundleLayout', () {
    test('freezes the minimal v1 logical paths', () {
      expect(StoryFormatBundleLayout.projectPath, 'project.json');
      expect(StoryFormatBundleLayout.eventsDirectory, 'events');
      expect(StoryFormatBundleLayout.organizationPath, 'organization.json');
      expect(StoryFormatBundleLayout.extensionsPath, 'extensions.json');
    });

    test('event filename token is lowercase RFC 4648 Base32 without padding', () {
      expect(
        StoryFormatBundleLayout.eventFileToken(StoryEventId('event_intro')),
        'mv3gk3tul5uw45dsn4',
      );
      expect(
        StoryFormatBundleLayout.eventFileToken(StoryEventId('Event.Intro:1')),
        'iv3gk3tufzew45dsn45dc',
      );
      expect(
        StoryFormatBundleLayout.eventPath(StoryEventId('event_intro')),
        'events/mv3gk3tul5uw45dsn4.json',
      );
    });

    test('portable tokens avoid filesystem-sensitive ID spelling collisions', () {
      final lower = StoryFormatBundleLayout.eventFileToken(
        StoryEventId('event.a:1'),
      );
      final upper = StoryFormatBundleLayout.eventFileToken(
        StoryEventId('Event.A:1'),
      );

      expect(lower, isNot(upper));
      expect(lower, matches(RegExp(r'^[a-z2-7]+$')));
      expect(upper, matches(RegExp(r'^[a-z2-7]+$')));
      expect(lower, isNot(contains('.')));
      expect(lower, isNot(contains(':')));
      expect(lower, isNot(contains('/')));
      expect(lower, isNot(contains('\\')));
    });

    test('maximum machine ID stays below common filename component limit', () {
      final eventId = StoryEventId(List.filled(128, 'z').join());
      final token = StoryFormatBundleLayout.eventFileToken(eventId);
      final fileNameLength = token.length + '.json'.length;

      expect(token, hasLength(205));
      expect(fileNameLength, lessThan(255));
    });

    test('empty document requires only the root manifest', () {
      final document = StoryFormatDocument(
        project: StoryProject(id: StoryProjectId('project_layout_empty')),
      );

      expect(
        StoryFormatBundleLayout.canonicalFilePaths(document),
        [StoryFormatBundleLayout.projectPath],
      );
    });

    test('canonical file set isolates optional metadata and event files', () {
      final eventB = StoryEventId('event_layout_b');
      final eventA = StoryEventId('event_layout_a');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_layout_full'),
          events: [StoryEvent(id: eventB), StoryEvent(id: eventA)],
        ),
        organization: StoryFormatOrganization(
          groups: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_layout'),
              eventIds: [eventB, eventA],
            ),
          ],
        ),
        extensions: [
          StoryFormatExtensionAttachment(
            namespace: StoryFormatExtensionNamespace('com.example.layout'),
            target: const StoryFormatProjectExtensionTarget(),
            payload: StoryFormatExtensionPayload({'enabled': true}),
          ),
        ],
      );

      final expectedEventPaths = [
        StoryFormatBundleLayout.eventPath(eventA),
        StoryFormatBundleLayout.eventPath(eventB),
      ]..sort();

      expect(
        StoryFormatBundleLayout.canonicalFilePaths(document),
        [
          'project.json',
          'organization.json',
          'extensions.json',
          ...expectedEventPaths,
        ],
      );
    });

    test('event authored order does not change physical event paths', () {
      final eventA = StoryEventId('event_layout_order_a');
      final eventB = StoryEventId('event_layout_order_b');

      StoryFormatDocument build(List<StoryEventId> order) =>
          StoryFormatDocument(
            project: StoryProject(
              id: StoryProjectId('project_layout_order'),
              events: [for (final id in order) StoryEvent(id: id)],
            ),
          );

      expect(
        StoryFormatBundleLayout.canonicalFilePaths(
          build([eventA, eventB]),
        ),
        StoryFormatBundleLayout.canonicalFilePaths(
          build([eventB, eventA]),
        ),
      );
    });

    test('renaming presentation/organization never changes event storage path', () {
      final eventId = StoryEventId('event_layout_stable');
      final before = StoryFormatBundleLayout.eventPath(eventId);
      final afterTitleRename = StoryFormatBundleLayout.eventPath(eventId);
      final afterGroupMove = StoryFormatBundleLayout.eventPath(eventId);

      expect(afterTitleRename, before);
      expect(afterGroupMove, before);
    });

    test('duplicate event identity cannot own two physical event files', () {
      final duplicateId = StoryEventId('event_layout_duplicate');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_layout_duplicate'),
          events: [
            StoryEvent(id: duplicateId),
            StoryEvent(id: duplicateId),
          ],
        ),
      );

      expect(
        () => StoryFormatBundleLayout.canonicalFilePaths(document),
        throwsArgumentError,
      );
    });
  });
}
