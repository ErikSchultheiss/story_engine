import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_module_id.dart';
import '../identity/story_project_id.dart';
import '../orchestration/story_entry_point.dart';
import '../state/story_state_schema.dart';

/// Lightweight metadata for one independently loadable narrative module.
final class StoryModuleIndexEntry {
  StoryModuleIndexEntry({
    required this.id,
    Iterable<StoryModuleId> dependencies = const [],
  }) : dependencies = List<StoryModuleId>.unmodifiable(dependencies);

  /// Stable module identity.
  final StoryModuleId id;

  /// Other modules whose event bodies may be required while executing this
  /// module, in deterministic declaration order.
  ///
  /// Dependencies describe loadability, not authored control-flow order.
  final List<StoryModuleId> dependencies;
}

/// Lightweight global index entry for one stable event identity.
final class StoryEventIndexEntry {
  StoryEventIndexEntry({
    required this.id,
    required this.moduleId,
    Iterable<StoryEventId> outboundEventIds = const [],
  }) : outboundEventIds = List<StoryEventId>.unmodifiable(outboundEventIds);

  /// Globally stable event identity.
  final StoryEventId id;

  /// Module currently owning the event body.
  final StoryModuleId moduleId;

  /// Unique outbound event references in first-authored-reference order.
  ///
  /// This summary lets whole-project reference validation operate without
  /// loading the event body. Moving an event between modules does not change
  /// the event ID or references that target it.
  final List<StoryEventId> outboundEventIds;
}

/// Lightweight global index for a logically unified modular story project.
///
/// The index contains enough information to resolve stable event/entry-point
/// identities and verify cross-module references without materializing every
/// event body. It is runtime/build metadata, not a replacement for the human-
/// readable Story Format source of truth.
final class StoryProjectIndex {
  factory StoryProjectIndex({
    required StoryProjectId projectId,
    required StoryStateSchema stateSchema,
    Iterable<StoryModuleIndexEntry> modules = const [],
    Iterable<StoryEventIndexEntry> events = const [],
    Iterable<StoryEntryPoint> entryPoints = const [],
    StoryEventId? defaultEntryEventId,
  }) {
    final copiedModules = List<StoryModuleIndexEntry>.unmodifiable(modules);
    final copiedEvents = List<StoryEventIndexEntry>.unmodifiable(events);
    final copiedEntryPoints = List<StoryEntryPoint>.unmodifiable(entryPoints);
    return StoryProjectIndex._(
      projectId: projectId,
      stateSchema: stateSchema,
      modules: copiedModules,
      events: copiedEvents,
      entryPoints: copiedEntryPoints,
      defaultEntryEventId: defaultEntryEventId,
      moduleById: _firstModuleById(copiedModules),
      eventById: _firstEventById(copiedEvents),
      entryPointById: _firstEntryPointById(copiedEntryPoints),
    );
  }

  StoryProjectIndex._({
    required this.projectId,
    required this.stateSchema,
    required this.modules,
    required this.events,
    required this.entryPoints,
    required this.defaultEntryEventId,
    required Map<StoryModuleId, StoryModuleIndexEntry> moduleById,
    required Map<StoryEventId, StoryEventIndexEntry> eventById,
    required Map<StoryEntryPointId, StoryEntryPoint> entryPointById,
  }) : _moduleById = moduleById,
       _eventById = eventById,
       _entryPointById = entryPointById;

  /// Stable identity shared by every module in this logical project.
  final StoryProjectId projectId;

  /// Project-global scalar narrative-state schema.
  final StoryStateSchema stateSchema;

  /// Module descriptors in deterministic index order.
  final List<StoryModuleIndexEntry> modules;

  /// Global event index in deterministic index order.
  final List<StoryEventIndexEntry> events;

  /// Host-addressable entry-point metadata available without event bodies.
  final List<StoryEntryPoint> entryPoints;

  /// Optional conventional default entry event for classic single-run hosts.
  final StoryEventId? defaultEntryEventId;

  final Map<StoryModuleId, StoryModuleIndexEntry> _moduleById;
  final Map<StoryEventId, StoryEventIndexEntry> _eventById;
  final Map<StoryEntryPointId, StoryEntryPoint> _entryPointById;

  /// First indexed module with [id], or null when none exists.
  ///
  /// Runtime consumers must validate the index before relying on lookups;
  /// duplicate identities are reported by `StoryModuleValidator`.
  StoryModuleIndexEntry? moduleFor(StoryModuleId id) => _moduleById[id];

  /// First indexed event with [id], or null when none exists.
  StoryEventIndexEntry? eventFor(StoryEventId id) => _eventById[id];

  /// First indexed entry point with [id], or null when none exists.
  StoryEntryPoint? entryPointFor(StoryEntryPointId id) => _entryPointById[id];
}

Map<StoryModuleId, StoryModuleIndexEntry> _firstModuleById(
  Iterable<StoryModuleIndexEntry> modules,
) {
  final result = <StoryModuleId, StoryModuleIndexEntry>{};
  for (final module in modules) {
    result.putIfAbsent(module.id, () => module);
  }
  return Map<StoryModuleId, StoryModuleIndexEntry>.unmodifiable(result);
}

Map<StoryEventId, StoryEventIndexEntry> _firstEventById(
  Iterable<StoryEventIndexEntry> events,
) {
  final result = <StoryEventId, StoryEventIndexEntry>{};
  for (final event in events) {
    result.putIfAbsent(event.id, () => event);
  }
  return Map<StoryEventId, StoryEventIndexEntry>.unmodifiable(result);
}

Map<StoryEntryPointId, StoryEntryPoint> _firstEntryPointById(
  Iterable<StoryEntryPoint> entryPoints,
) {
  final result = <StoryEntryPointId, StoryEntryPoint>{};
  for (final entryPoint in entryPoints) {
    result.putIfAbsent(entryPoint.id, () => entryPoint);
  }
  return Map<StoryEntryPointId, StoryEntryPoint>.unmodifiable(result);
}
