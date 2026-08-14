import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryFormatDocument', () {
    test('uses independent Story Format v1 metadata', () {
      final document = StoryFormatDocument(
        project: StoryProject(id: StoryProjectId('project_format_metadata')),
      );

      expect(document.metadata.formatId, 'story_engine.story_format');
      expect(document.metadata.formatVersion, 1);
      expect(document.metadata, const StoryFormatMetadata.current());
    });

    test('projects to StoryProject without organization runtime semantics', () {
      final eventId = StoryEventId('event_format_projection');
      final project = StoryProject(
        id: StoryProjectId('project_format_projection'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final plain = StoryFormatDocument(project: project);
      final organized = StoryFormatDocument(
        project: project,
        organization: StoryFormatOrganization(
          groups: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_format_projection'),
              label: const StoryText('Chapter-like group'),
              eventIds: [eventId],
            ),
          ],
        ),
      );

      expect(plain.toStoryProject(), same(project));
      expect(organized.toStoryProject(), same(project));

      final plainEngine = StoryEngine(
        project: plain.toStoryProject(),
        randomSeed: 5,
      )..start();
      final organizedEngine = StoryEngine(
        project: organized.toStoryProject(),
        randomSeed: 5,
      )..start();

      expect(plainEngine.createSnapshot(), organizedEngine.createSnapshot());
    });

    test('retains incomplete runtime-authored project semantics losslessly', () {
      final project = StoryProject(
        id: StoryProjectId('project_format_incomplete'),
        events: [
          StoryEvent(
            id: StoryEventId('event_format_incomplete'),
            choices: [
              StoryChoice(id: StoryChoiceId('choice_format_incomplete')),
            ],
          ),
        ],
      );

      final document = StoryFormatDocument(project: project);

      expect(document.toStoryProject(), same(project));
      expect(StoryValidator.validate(project).errors, isNotEmpty);
    });

    test('rejects duplicate extension target/namespace pairs', () {
      final namespace = StoryFormatExtensionNamespace('com.example.notes');
      const target = StoryFormatProjectExtensionTarget();

      expect(
        () => StoryFormatDocument(
          project: StoryProject(id: StoryProjectId('project_duplicate_ext')),
          extensions: [
            StoryFormatExtensionAttachment(
              namespace: namespace,
              target: target,
              payload: StoryFormatExtensionPayload('first'),
            ),
            StoryFormatExtensionAttachment(
              namespace: namespace,
              target: target,
              payload: StoryFormatExtensionPayload('second'),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
