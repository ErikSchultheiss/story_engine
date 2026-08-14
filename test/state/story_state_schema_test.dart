import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryVariableDefinition', () {
    test('initial value is optional and unset remains distinct', () {
      final definition = StoryVariableDefinition(
        id: StoryVariableId('var_has_key'),
        alias: StoryAlias('has_key'),
        type: StoryValueType.boolean,
      );

      expect(definition.initialValue, isNull);
    });

    test('wrong initial value type is rejected', () {
      expect(
        () => StoryVariableDefinition(
          id: StoryVariableId('var_gold'),
          type: StoryValueType.integer,
          initialValue: const StoryStringValue('100'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('StoryStateSchema', () {
    test('indexes definitions by stable ID and optional alias', () {
      final definition = StoryVariableDefinition(
        id: StoryVariableId('var_trust'),
        alias: StoryAlias('mara_trust'),
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(50),
      );
      final schema = StoryStateSchema(variables: [definition]);

      expect(schema.definitionFor(definition.id), same(definition));
      expect(
        schema.definitionForAlias(StoryAlias('mara_trust')),
        same(definition),
      );
    });

    test('duplicate variable IDs are rejected', () {
      final id = StoryVariableId('var_same');

      expect(
        () => StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: id,
              alias: StoryAlias('first'),
              type: StoryValueType.boolean,
            ),
            StoryVariableDefinition(
              id: id,
              alias: StoryAlias('second'),
              type: StoryValueType.boolean,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('aliases are unique within the variable namespace', () {
      final alias = StoryAlias('mara_trust');

      expect(
        () => StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: StoryVariableId('var_a'),
              alias: alias,
              type: StoryValueType.integer,
            ),
            StoryVariableDefinition(
              id: StoryVariableId('var_b'),
              alias: alias,
              type: StoryValueType.integer,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test(
      'alias uniqueness does not create a global cross-entity namespace',
      () {
        final project = StoryProject(
          id: StoryProjectId('project_001'),
          alias: StoryAlias('shared_name'),
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: StoryVariableId('var_001'),
                alias: StoryAlias('shared_name'),
                type: StoryValueType.boolean,
              ),
            ],
          ),
        );

        expect(project.alias, StoryAlias('shared_name'));
        expect(
          project.stateSchema.definitionForAlias(StoryAlias('shared_name')),
          isNotNull,
        );
      },
    );
  });
}
