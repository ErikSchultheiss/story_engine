/// One authored source/default-language text value used for presentation.
///
/// Stage 2B deliberately keeps this type small. It is not a localization key,
/// translation identity, rich-text document, or markup language. Localization
/// will later be designed as its own first-class layer without making runtime
/// control flow depend on visible text.
///
/// Empty strings and whitespace are preserved intentionally so authoring tools
/// can represent in-progress work without the engine silently normalizing the
/// author's text.
final class StoryText {
  const StoryText(this.value);

  /// Authored text exactly as supplied.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoryText && other.value == value;

  @override
  int get hashCode => Object.hash(StoryText, value);

  @override
  String toString() => 'StoryText($value)';
}
