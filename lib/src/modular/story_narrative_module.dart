import '../identity/story_module_id.dart';
import '../identity/story_project_id.dart';
import '../model/story_event.dart';

/// One independently loadable collection of event bodies from a logical project.
///
/// Project-global state schema, entry-point metadata, and global identity maps
/// live in [StoryProjectIndex]. A module carries only its stable ownership
/// identity and event bodies, keeping loading units small and relocatable.
final class StoryNarrativeModule {
  StoryNarrativeModule({
    required this.projectId,
    required this.id,
    Iterable<StoryEvent> events = const [],
  }) : events = List<StoryEvent>.unmodifiable(events);

  /// Logical project to which this module belongs.
  final StoryProjectId projectId;

  /// Stable module identity.
  final StoryModuleId id;

  /// Event bodies owned by this module in deterministic authored order.
  final List<StoryEvent> events;
}
