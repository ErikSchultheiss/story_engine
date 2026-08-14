import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('typed machine identity', () {
    test('IDs compare by concrete type and token value', () {
      expect(StoryEventId('same_token'), equals(StoryEventId('same_token')));
      expect(
        StoryEventId('same_token'),
        isNot(equals(StoryEventId('different_token'))),
      );
      expect(
        StoryEventId('same_token'),
        isNot(equals(StoryProjectId('same_token'))),
      );
    });

    test('ID tokens remain available without semantic interpretation', () {
      final id = StoryEventId('evt:01J_TEST-7.alpha');

      expect(id.value, 'evt:01J_TEST-7.alpha');
      expect(id.toString(), 'StoryEventId(evt:01J_TEST-7.alpha)');
    });

    test('valid UUID-style tokens are accepted without requiring UUIDs', () {
      final id = StoryProjectId('550e8400-e29b-41d4-a716-446655440000');

      expect(id.value, '550e8400-e29b-41d4-a716-446655440000');
    });

    test('blank, whitespace, and path-like IDs are rejected', () {
      expect(() => StoryEventId(''), throwsArgumentError);
      expect(() => StoryEventId('forest gate'), throwsArgumentError);
      expect(() => StoryEventId('../forest'), throwsArgumentError);
      expect(() => StoryEventId('/forest'), throwsArgumentError);
    });
  });

  group('developer aliases', () {
    test('lower-case snake_case aliases are supported', () {
      final alias = StoryAlias('forest_gate');

      expect(alias.value, 'forest_gate');
      expect(alias, equals(StoryAlias('forest_gate')));
    });

    test('aliases reject display-name and path syntax', () {
      expect(() => StoryAlias('Forest Gate'), throwsArgumentError);
      expect(() => StoryAlias('forest-gate'), throwsArgumentError);
      expect(() => StoryAlias('../forest'), throwsArgumentError);
      expect(() => StoryAlias('_forest'), throwsArgumentError);
    });

    test('aliases have a bounded developer-facing representation', () {
      final tooLong = 'a${List.filled(80, 'a').join()}';

      expect(() => StoryAlias(tooLong), throwsArgumentError);
    });
  });

  group('authored entity identity', () {
    test('public authored entities require typed machine IDs', () {
      final project = StoryProject(
        id: StoryProjectId('project_001'),
        alias: StoryAlias('demo_project'),
      );
      final event = StoryEvent(
        id: StoryEventId('event_001'),
        alias: StoryAlias('forest_gate'),
      );
      final choice = StoryChoice(
        id: StoryChoiceId('choice_001'),
        alias: StoryAlias('enter_forest'),
      );

      expect(project.id, StoryProjectId('project_001'));
      expect(event.id, StoryEventId('event_001'));
      expect(choice.id, StoryChoiceId('choice_001'));
    });

    test('changing an alias does not require changing machine identity', () {
      final id = StoryEventId('event_001');
      final before = StoryEvent(id: id, alias: StoryAlias('forest_gate'));
      final after = StoryEvent(id: id, alias: StoryAlias('ancient_forest_gate'));

      expect(before.id, equals(after.id));
      expect(before.alias, isNot(equals(after.alias)));
    });

    test('choice identity is not derived from a parent event', () {
      final choice = StoryChoice(
        id: StoryChoiceId('choice_9f2b'),
        alias: StoryAlias('continue_path'),
      );

      expect(choice.id.value, 'choice_9f2b');
    });
  });
}
