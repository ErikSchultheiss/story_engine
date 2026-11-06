import '../identity/story_event_id.dart';
import '../model/story_project.dart';

/// Entry and state assumptions for a validation run.
enum StoryValidationMode { standalone, orchestration, moduleSlice }

/// Immutable validation policy for the same semantic rule families.
///
/// Standalone validation requires the project's default entry and assumes a
/// fresh schema-initialized state. Orchestration accepts host-declared roots
/// without a default entry and assumes existing shared state (set or unset).
/// Module slices additionally accept explicitly known external destinations;
/// paths crossing those boundaries remain incomplete in graph analysis.
/// No mode suppresses malformed flow, duplicate identities, or type errors.
final class StoryValidationContext {
  const StoryValidationContext.standalone()
    : mode = StoryValidationMode.standalone,
      entryEventIds = const [],
      knownExternalEventIds = const {};
  factory StoryValidationContext.orchestration({
    required Iterable<StoryEventId> entryEventIds,
  }) => StoryValidationContext._(
    StoryValidationMode.orchestration,
    entryEventIds,
    const [],
  );
  factory StoryValidationContext.moduleSlice({
    Iterable<StoryEventId> entryEventIds = const [],
    required Iterable<StoryEventId> knownExternalEventIds,
  }) => StoryValidationContext._(
    StoryValidationMode.moduleSlice,
    entryEventIds,
    knownExternalEventIds,
  );
  StoryValidationContext._(
    this.mode,
    Iterable<StoryEventId> roots,
    Iterable<StoryEventId> external,
  ) : entryEventIds = List.unmodifiable(roots.toSet()),
      knownExternalEventIds = Set.unmodifiable(external);
  final StoryValidationMode mode;
  final List<StoryEventId> entryEventIds;
  final Set<StoryEventId> knownExternalEventIds;
  bool get requiresDefaultEntry => mode == StoryValidationMode.standalone;
  bool get assumesInitialState => mode == StoryValidationMode.standalone;

  /// Declared default (when present) plus context roots, in declaration order.
  List<StoryEventId> rootsFor(StoryProject project) => List.unmodifiable({
    if (project.entryEventId != null) project.entryEventId!,
    ...entryEventIds,
  });
}
