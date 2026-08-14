/// Portable scalar value categories supported by the Stage 1D state model.
///
/// More complex narrative concepts such as inventory, relationships, and
/// achievements are deliberately not collapsed into this enum.
enum StoryValueType {
  /// A two-state true/false value.
  boolean,

  /// An exact integer within the portable JavaScript-safe integer range.
  integer,

  /// A finite IEEE-754 double-precision number.
  number,

  /// Arbitrary Dart string content.
  string,
}
