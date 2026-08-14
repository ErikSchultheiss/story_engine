import '../identity/story_alias.dart';
import '../identity/story_event_id.dart';
import '../identity/story_project_id.dart';
import '../state/story_state_schema.dart';
import 'story_event.dart';

/// The authored definition of one narrative or event-system project.
///
/// A [StoryProject] is project data, not a running playthrough and not
/// persistence state. Stage 1H attaches the minimum event collection and
/// optional entry point required by the first runtime contract.
///
/// The project model intentionally remains permissive enough to represent
/// incomplete editor work. Duplicate IDs and missing/invalid runtime flow are
/// rejected by `StoryEngine` when a project is prepared or entered rather than
/// making half-authored Studio documents impossible to represent.
final class StoryProject {
  /// Creates an authored project definition.
  factory StoryProject({
    required StoryProjectId id,
    StoryAlias? alias,
    StoryStateSchema? stateSchema,
    Iterable<StoryEvent> events = const [],
    StoryEventId? entryEventId,
  }) => StoryProject._(
    id: id,
    alias: alias,
    stateSchema: stateSchema ?? StoryStateSchema.empty(),
    events: List<StoryEvent>.unmodifiable(events),
    entryEventId: entryEventId,
  );

  StoryProject._({
    required this.id,
    required this.alias,
    required this.stateSchema,
    required this.events,
    required this.entryEventId,
  });

  /// Stable machine identity for this project.
  final StoryProjectId id;

  /// Optional developer-friendly name that is not used as machine identity.
  final StoryAlias? alias;

  /// Authored declaration of the project's scalar narrative variables.
  final StoryStateSchema stateSchema;

  /// Authored events in deterministic project order.
  final List<StoryEvent> events;

  /// Event entered by `StoryEngine.start()`.
  ///
  /// Null is permitted in editor data but makes the project non-runnable until
  /// an entry event is chosen.
  final StoryEventId? entryEventId;
}
