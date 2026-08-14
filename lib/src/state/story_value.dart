import 'story_value_type.dart';

/// Base type for portable authored/runtime scalar state values.
///
/// Story values are immutable and deliberately exclude arbitrary Dart objects.
/// This keeps narrative state deterministic, inspectable, and suitable for
/// future portable serialization.
sealed class StoryValue {
  const StoryValue();

  /// Converts one supported Dart scalar into its portable story value.
  ///
  /// This is a developer-integration convenience for host data and test setup;
  /// the resulting value uses the same validation and portability rules as the
  /// concrete value classes. Supported inputs are `bool`, `int`, `double`, and
  /// `String`.
  factory StoryValue.fromRaw(Object value) => switch (value) {
    bool value => StoryBooleanValue(value),
    int value => StoryIntegerValue(value),
    double value => StoryNumberValue(value),
    String value => StoryStringValue(value),
    _ => throw ArgumentError.value(
      value,
      'value',
      'Story values support only bool, int, double, and String scalars.',
    ),
  };

  /// The declared scalar category of this value.
  StoryValueType get type;

  /// The underlying Dart scalar.
  Object get rawValue;
}

/// Immutable boolean story value.
final class StoryBooleanValue extends StoryValue {
  const StoryBooleanValue(this.value);

  final bool value;

  @override
  StoryValueType get type => StoryValueType.boolean;

  @override
  Object get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryBooleanValue && other.value == value;

  @override
  int get hashCode => Object.hash(StoryBooleanValue, value);

  @override
  String toString() => 'StoryBooleanValue($value)';
}

/// Immutable integer story value.
///
/// Integers are constrained to +/- (2^53 - 1). This is the largest integer
/// range that remains exact across Dart VM and JavaScript runtimes, which
/// avoids cross-platform state divergence when the engine later runs on web.
final class StoryIntegerValue extends StoryValue {
  StoryIntegerValue(int value) : value = _validatePortableInteger(value);

  /// Largest exactly representable integer across JavaScript number runtimes.
  static const int maxPortableValue = 9007199254740991;

  /// Smallest exactly representable integer across JavaScript number runtimes.
  static const int minPortableValue = -9007199254740991;

  final int value;

  @override
  StoryValueType get type => StoryValueType.integer;

  @override
  Object get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryIntegerValue && other.value == value;

  @override
  int get hashCode => Object.hash(StoryIntegerValue, value);

  @override
  String toString() => 'StoryIntegerValue($value)';
}

/// Immutable finite floating-point story value.
final class StoryNumberValue extends StoryValue {
  StoryNumberValue(double value) : value = _validateFiniteNumber(value);

  final double value;

  @override
  StoryValueType get type => StoryValueType.number;

  @override
  Object get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryNumberValue && other.value == value;

  @override
  int get hashCode => Object.hash(StoryNumberValue, value);

  @override
  String toString() => 'StoryNumberValue($value)';
}

/// Immutable string story value.
final class StoryStringValue extends StoryValue {
  const StoryStringValue(this.value);

  final String value;

  @override
  StoryValueType get type => StoryValueType.string;

  @override
  Object get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryStringValue && other.value == value;

  @override
  int get hashCode => Object.hash(StoryStringValue, value);

  @override
  String toString() => 'StoryStringValue($value)';
}

int _validatePortableInteger(int value) {
  if (value < StoryIntegerValue.minPortableValue ||
      value > StoryIntegerValue.maxPortableValue) {
    throw ArgumentError.value(
      value,
      'value',
      'Story integers must be within the portable range '
          '${StoryIntegerValue.minPortableValue}..'
          '${StoryIntegerValue.maxPortableValue}.',
    );
  }
  return value;
}

double _validateFiniteNumber(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      'value',
      'Story numbers must be finite; NaN and infinity are not supported.',
    );
  }
  return value;
}
