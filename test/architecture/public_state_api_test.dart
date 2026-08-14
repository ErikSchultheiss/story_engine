import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Stage 1D state vocabulary is usable from package root only', () {
    final variable = StoryVariableDefinition(
      id: StoryVariableId('var_gold'),
      alias: StoryAlias('gold'),
      type: StoryValueType.integer,
      initialValue: StoryIntegerValue(100),
    );
    final schema = StoryStateSchema(variables: [variable]);
    final project = StoryProject(
      id: StoryProjectId('project_001'),
      stateSchema: schema,
    );
    final state = StoryState.initial(project.stateSchema);

    expect(state.valueOf(variable.id), StoryIntegerValue(100));
  });
}
