import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Story Format opaque extensions', () {
    test('namespace is explicit and collision-oriented', () {
      expect(
        StoryFormatExtensionNamespace('com.example.editor_notes').value,
        'com.example.editor_notes',
      );
      expect(
        () => StoryFormatExtensionNamespace('single_component'),
        throwsArgumentError,
      );
      expect(
        () => StoryFormatExtensionNamespace('Com.Example.Bad'),
        throwsArgumentError,
      );
    });

    test('payload accepts only deeply immutable JSON-shaped data', () {
      final sourceList = <Object?>['beta', 'alpha'];
      final sourceMap = <String, Object?>{
        'z': sourceList,
        'a': <String, Object?>{'enabled': true},
      };
      final payload = StoryFormatExtensionPayload(sourceMap);

      sourceList.add('later mutation');
      sourceMap['new'] = 'later mutation';

      final normalized = payload.value! as Map<String, Object?>;
      expect(normalized.keys.toList(), ['a', 'z']);
      expect(normalized.containsKey('new'), isFalse);
      expect(normalized['z'], ['beta', 'alpha']);
      expect(() => normalized['x'] = 1, throwsUnsupportedError);
      expect(
        () => (normalized['z']! as List<Object?>).add('x'),
        throwsUnsupportedError,
      );
    });

    test('payload rejects executable/non-portable values', () {
      expect(
        () => StoryFormatExtensionPayload(DateTime(2026)),
        throwsArgumentError,
      );
      expect(
        () => StoryFormatExtensionPayload(double.nan),
        throwsArgumentError,
      );
      expect(
        () => StoryFormatExtensionPayload(9007199254740992),
        throwsArgumentError,
      );
      expect(
        () => StoryFormatExtensionPayload(<Object?, Object?>{1: 'bad key'}),
        throwsArgumentError,
      );
    });

    test('stable identity entities are explicit extension targets', () {
      final targets = <StoryFormatExtensionTarget>[
        const StoryFormatProjectExtensionTarget(),
        StoryFormatEventExtensionTarget(StoryEventId('event_ext')),
        StoryFormatChoiceExtensionTarget(StoryChoiceId('choice_ext')),
        StoryFormatVariableExtensionTarget(StoryVariableId('var_ext')),
        StoryFormatGroupExtensionTarget(StoryFormatGroupId('group_ext')),
        StoryFormatTagExtensionTarget(StoryFormatTagId('tag_ext')),
      ];

      expect(targets, hasLength(6));
    });
  });
}
