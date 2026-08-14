import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('variable IDs are typed stable machine identities', () {
    final first = StoryVariableId('variable_001');
    final same = StoryVariableId('variable_001');
    final different = StoryVariableId('variable_002');

    expect(first, equals(same));
    expect(first, isNot(equals(different)));
    expect(first.value, 'variable_001');
  });
}
