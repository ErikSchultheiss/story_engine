import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  for (final action in [true, false]) {
    final owner = action ? 'action' : 'condition';

    test('1D $owner parameter duplicates precede an invalid member ID', () {
      final duplicate = _parameter('repeated');
      expect(
        () => _parameters(action, 'Invalid id', [duplicate, duplicate]),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'parameters')
              .having((error) => error.invalidValue, 'invalidValue', 'repeated')
              .having(
                (error) => error.message,
                'message',
                'Duplicate identifier: repeated.',
              ),
        ),
      );
    });

    test(
      '1D $owner consumes parameter input before validating its member ID',
      () {
        final error = StateError('parameter source failed');
        expect(
          () => _parameters(action, 'Invalid id', _failingParameters(error)),
          throwsA(same(error)),
        );
      },
    );

    test(
      '1D $owner preserves parameter order, identity and immutable ownership',
      () {
        final first = _parameter('first');
        final second = _parameter('second');
        final input = [first, second];
        final copied = _parameters(action, 'valid_id', input);
        input.clear();
        expect(copied.map((p) => p.name), ['first', 'second']);
        expect(copied.first, same(first));
        expect(copied.last, same(second));
        expect(() => copied.clear(), throwsUnsupportedError);
        expect(_parameters(action, 'empty', const []), isEmpty);
      },
    );
  }
}

List<StoryExtensionParameterDefinition> _parameters(
  bool action,
  String id,
  Iterable<StoryExtensionParameterDefinition> parameters,
) => action
    ? StoryExtensionActionDefinition(id: id, parameters: parameters).parameters
    : StoryExtensionConditionDefinition(
        id: id,
        parameters: parameters,
      ).parameters;

StoryExtensionParameterDefinition _parameter(String name) =>
    StoryExtensionParameterDefinition(
      name: name,
      type: const StoryExtensionParameterType.integer(),
    );

Iterable<StoryExtensionParameterDefinition> _failingParameters(
  Object error,
) sync* {
  yield _parameter('first');
  throw error;
}
