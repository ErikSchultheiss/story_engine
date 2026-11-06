import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryValue', () {
    test('scalar categories remain strongly typed', () {
      expect(const StoryBooleanValue(true).type, StoryValueType.boolean);
      expect(StoryIntegerValue(12).type, StoryValueType.integer);
      expect(StoryNumberValue(12.5).type, StoryValueType.number);
      expect(const StoryStringValue('Luca').type, StoryValueType.string);
    });

    test('integer and number are distinct value categories', () {
      expect(StoryIntegerValue(1), isNot(equals(StoryNumberValue(1.0))));
    });

    test('fromRaw converts supported host scalars without coercion', () {
      expect(StoryValue.fromRaw(true), const StoryBooleanValue(true));
      expect(StoryValue.fromRaw(12), StoryIntegerValue(12));
      expect(StoryValue.fromRaw(12.5), StoryNumberValue(12.5));
      expect(StoryValue.fromRaw('Luca'), const StoryStringValue('Luca'));
    });

    test('fromRaw preserves concrete validation rules', () {
      expect(() => StoryValue.fromRaw(double.nan), throwsArgumentError);
      expect(() => StoryValue.fromRaw(DateTime(2026)), throwsArgumentError);
    });

    test('portable integer boundaries are accepted', () {
      expect(
        StoryIntegerValue(StoryIntegerValue.maxPortableValue).value,
        StoryIntegerValue.maxPortableValue,
      );
      expect(
        StoryIntegerValue(StoryIntegerValue.minPortableValue).value,
        StoryIntegerValue.minPortableValue,
      );
    });

    test('integers outside the portable cross-platform range are rejected', () {
      expect(
        () => StoryIntegerValue(StoryIntegerValue.maxPortableValue + 1),
        throwsArgumentError,
      );
      expect(
        () => StoryIntegerValue(StoryIntegerValue.minPortableValue - 1),
        throwsArgumentError,
      );
    });

    test('NaN and infinities are rejected', () {
      expect(() => StoryNumberValue(double.nan), throwsArgumentError);
      expect(() => StoryNumberValue(double.infinity), throwsArgumentError);
      expect(
        () => StoryNumberValue(double.negativeInfinity),
        throwsArgumentError,
      );
    });

    test('values compare deterministically by concrete type and scalar', () {
      expect(const StoryBooleanValue(true), const StoryBooleanValue(true));
      expect(StoryIntegerValue(7), StoryIntegerValue(7));
      expect(StoryNumberValue(7.5), StoryNumberValue(7.5));
      expect(const StoryStringValue('x'), const StoryStringValue('x'));
    });
  });
}
