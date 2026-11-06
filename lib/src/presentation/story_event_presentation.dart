import 'story_text.dart';

/// Optional human-facing presentation attached to a `StoryEvent`.
///
/// The engine's executable unit remains the generic `StoryEvent`; presentation
/// is optional so non-prose event systems can use the same runtime model.
/// Stage 2B supports only a title and body. Media, speakers, structured blocks,
/// localization, styling, and other rendering concerns are deliberately
/// deferred until concrete requirements justify them.
final class StoryEventPresentation {
  factory StoryEventPresentation({StoryText? title, StoryText? body}) {
    if (title == null && body == null) {
      throw ArgumentError(
        'StoryEventPresentation requires a title, a body, or both. '
        'Use null on StoryEvent to represent no presentation.',
      );
    }
    return StoryEventPresentation._(title: title, body: body);
  }

  const StoryEventPresentation._({this.title, this.body});

  /// Optional short heading for the event.
  final StoryText? title;

  /// Optional primary textual content for the event.
  final StoryText? body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEventPresentation &&
          other.title == title &&
          other.body == body;

  @override
  int get hashCode => Object.hash(StoryEventPresentation, title, body);

  @override
  String toString() => 'StoryEventPresentation(title: $title, body: $body)';
}
