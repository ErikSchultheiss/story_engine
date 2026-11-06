import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/state/story_state.dart'
    show StoryStateMutation;
import 'package:test/test.dart';

void main() {
  final trustId = StoryVariableId('var_trust');
  final keyId = StoryVariableId('var_has_key');
  final goldId = StoryVariableId('var_gold');

  StoryStateSchema buildSchema() => StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: trustId,
        alias: StoryAlias('mara_trust'),
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(50),
      ),
      StoryVariableDefinition(
        id: keyId,
        alias: StoryAlias('has_key'),
        type: StoryValueType.boolean,
      ),
      StoryVariableDefinition(
        id: goldId,
        alias: StoryAlias('gold'),
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(100),
      ),
    ],
  );

  group('StoryState initial construction', () {
    test(
      'includes declared initial values and omits intentionally unset ones',
      () {
        final state = StoryState.initial(buildSchema());

        expect(state.valueOf(trustId), StoryIntegerValue(50));
        expect(state.valueOf(goldId), StoryIntegerValue(100));
        expect(state.valueOf(keyId), isNull);
        expect(state.isSet(keyId), isFalse);
      },
    );

    test('undeclared IDs are not confused with unset declared variables', () {
      final state = StoryState.initial(buildSchema());
      final undeclared = StoryVariableId('var_unknown');

      expect(() => state.valueOf(undeclared), throwsArgumentError);
      expect(() => state.isSet(undeclared), throwsArgumentError);
    });
  });

  group('StoryState explicit snapshots', () {
    test('raw host values convert through the declared schema', () {
      final state = StoryState.fromRawValues(
        schema: buildSchema(),
        values: {trustId: 65, keyId: true},
      );

      expect(state.valueOf(trustId), StoryIntegerValue(65));
      expect(state.rawValueOf(trustId), 65);
      expect(state.valueOf(keyId), const StoryBooleanValue(true));
      expect(state.rawValueOf(keyId), isTrue);
      expect(state.rawValueOf(goldId), isNull);
    });

    test('raw host values still enforce schema types', () {
      expect(
        () => StoryState.fromRawValues(
          schema: buildSchema(),
          values: {trustId: 'high'},
        ),
        throwsArgumentError,
      );
    });

    test('reject undeclared variable IDs', () {
      expect(
        () => StoryState.fromValues(
          schema: buildSchema(),
          values: {
            StoryVariableId('var_unknown'): const StoryBooleanValue(true),
          },
        ),
        throwsArgumentError,
      );
    });

    test('reject values with the wrong declared type', () {
      expect(
        () => StoryState.fromValues(
          schema: buildSchema(),
          values: {trustId: const StoryStringValue('high')},
        ),
        throwsArgumentError,
      );
    });

    test('caller cannot mutate the values map', () {
      final state = StoryState.initial(buildSchema());

      expect(
        () => state.values[trustId] = StoryIntegerValue(99),
        throwsUnsupportedError,
      );
    });

    test('equality is deterministic for equivalent schemas and values', () {
      final left = StoryState.initial(buildSchema());
      final right = StoryState.initial(buildSchema());

      expect(left, equals(right));
      expect(left.hashCode, equals(right.hashCode));
    });
  });

  group('package-internal StoryStateMutation', () {
    test('set produces a new snapshot without changing the previous state', () {
      final before = StoryState.initial(buildSchema());
      final after = StoryStateMutation.set(
        before,
        trustId,
        StoryIntegerValue(65),
      );

      expect(before.valueOf(trustId), StoryIntegerValue(50));
      expect(after.valueOf(trustId), StoryIntegerValue(65));
      expect(identical(before, after), isFalse);
    });

    test('set validates declared value type', () {
      final state = StoryState.initial(buildSchema());

      expect(
        () => StoryStateMutation.set(
          state,
          trustId,
          const StoryStringValue('sixty-five'),
        ),
        throwsArgumentError,
      );
    });

    test('unset produces a new snapshot and preserves the previous one', () {
      final before = StoryState.initial(buildSchema());
      final after = StoryStateMutation.unset(before, trustId);

      expect(before.isSet(trustId), isTrue);
      expect(after.isSet(trustId), isFalse);
    });
  });
}
