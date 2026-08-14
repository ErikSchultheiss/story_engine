import '../identity/story_alias.dart';
import '../identity/story_section_id.dart';

/// An optional authored grouping of related story events.
///
/// A section can later represent concepts such as a chapter, quest line,
/// dialogue group, or event category. Section membership is organizational;
/// it must not become an implicit runtime control-flow rule.
final class StorySection {
  /// Creates the current foundation-stage section definition.
  StorySection({required this.id, this.alias});

  /// Stable machine identity for this section.
  final StorySectionId id;

  /// Optional developer-friendly name that is not used as machine identity.
  final StoryAlias? alias;
}
