import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Extension Schema v1', () {
    test('reference schema decodes and re-encodes deterministically', () {
      const codec = StoryExtensionSchemaCodec();
      final source = File(
        'conformance/extensions/schema-v1/com.example.rpg.schema.json',
      ).readAsStringSync();

      final schema = codec.decodeJson(source);

      expect(schema.namespace, 'com.example.rpg');
      expect(schema.schemaVersion, 3);
      expect(schema.actions.single.id, 'start_combat');
      expect(schema.conditions.single.id, 'enemy_defeated');
      expect(schema.enums.single.id, 'combat_mode');
      expect(schema.referenceTypes, hasLength(2));
      expect(codec.encodeJson(schema), source);
    });

    test('schema rejects references to undeclared enum types', () {
      expect(
        () => StoryExtensionSchema(
          namespace: 'com.example.test',
          schemaVersion: 1,
          actions: [
            StoryExtensionActionDefinition(
              id: 'do_thing',
              parameters: [
                StoryExtensionParameterDefinition(
                  name: 'mode',
                  type: StoryExtensionParameterType.enumeration('missing'),
                ),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('enum defaults must name declared values', () {
      expect(
        () => StoryExtensionSchema(
          namespace: 'com.example.test',
          schemaVersion: 1,
          enums: [
            StoryExtensionEnumDefinition(
              id: 'mode',
              values: [StoryExtensionEnumValueDefinition(id: 'safe')],
            ),
          ],
          actions: [
            StoryExtensionActionDefinition(
              id: 'do_thing',
              parameters: [
                StoryExtensionParameterDefinition(
                  name: 'mode',
                  type: StoryExtensionParameterType.enumeration('mode'),
                  isRequired: false,
                  defaultValue: 'unsafe',
                ),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('Integer and Number defaults stay semantically distinct', () {
      expect(
        () => StoryExtensionSchema(
          namespace: 'com.example.test',
          schemaVersion: 1,
          actions: [
            StoryExtensionActionDefinition(
              id: 'do_thing',
              parameters: [
                StoryExtensionParameterDefinition(
                  name: 'amount',
                  type: const StoryExtensionParameterType.number(),
                  isRequired: false,
                  defaultValue: 1,
                ),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('codec rejects unknown semantic fields instead of guessing', () {
      const codec = StoryExtensionSchemaCodec();
      const source = '''
{
  "contract": "open_story.extension_schema",
  "contractVersion": 1,
  "namespace": "com.example.test",
  "schemaVersion": 1,
  "enums": [],
  "referenceTypes": [],
  "actions": [],
  "conditions": [],
  "implementation": "dangerousCallback"
}
''';

      expect(
        () => codec.decodeJson(source),
        throwsA(isA<StoryExtensionSchemaFormatException>()),
      );
    });

    test(
      'editor metadata is copied deeply and remains non-executable data',
      () {
        final sourceList = <Object?>['first'];
        final schema = StoryExtensionSchema(
          namespace: 'com.example.test',
          schemaVersion: 1,
          metadata: StoryExtensionSchemaMetadata(editor: {'items': sourceList}),
        );

        sourceList.add('second');

        expect(schema.metadata!.editor['items'], ['first']);
        expect(
          () => (schema.metadata!.editor['items']! as List<Object?>).add('bad'),
          throwsUnsupportedError,
        );
      },
    );
  });
}
