import 'story_text.dart';

/// Optional human-facing presentation attached to a `StoryChoice`.
///
/// Stage 2B requires only the visible choice text. The presentation object is
/// optional on the choice itself so incomplete editor data and non-textual host
/// integrations remain representable.
final class StoryChoicePresentation {
  const StoryChoicePresentation({required this.text});

  /// Visible/source-language label for the choice.
  final StoryText text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryChoicePresentation && other.text == text;

  @override
  int get hashCode => Object.hash(StoryChoicePresentation, text);

  @override
  String toString() => 'StoryChoicePresentation(text: $text)';
}
