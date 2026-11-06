import '../identity/story_entry_point_id.dart';
import '../identity/story_event_id.dart';
import '../identity/story_module_id.dart';
import '../model/story_event.dart';
import '../model/story_project.dart';
import '../validation/story_project_analysis.dart';
import 'story_narrative_module.dart';
import 'story_project_index.dart';

/// Stable categories reported by modular index/content validation.
enum StoryModuleValidationCode {
  duplicateModuleId,
  duplicateEventId,
  duplicateEntryPointId,
  duplicateModuleDependency,
  duplicateOutboundEventReference,
  selfModuleDependency,
  unknownModuleDependency,
  eventOwnerModuleMissing,
  defaultEntryEventMissing,
  entryPointEventMissing,
  outboundEventMissing,
  crossModuleDependencyMissing,
  moduleNotIndexed,
  moduleProjectMismatch,
  moduleDuplicateEventId,
  moduleMissingEvent,
  moduleUnexpectedEvent,
  moduleOutboundReferencesMismatch,
}

/// One deterministic issue found in a modular project index or loaded module.
final class StoryModuleValidationIssue {
  const StoryModuleValidationIssue({
    required this.code,
    required this.message,
    this.moduleId,
    this.eventId,
  });

  final StoryModuleValidationCode code;
  final String message;
  final StoryModuleId? moduleId;
  final StoryEventId? eventId;
}

/// Immutable result of modular index/content validation.
final class StoryModuleValidationReport {
  StoryModuleValidationReport({
    Iterable<StoryModuleValidationIssue> issues = const [],
  }) : issues = List<StoryModuleValidationIssue>.unmodifiable(issues);

  final List<StoryModuleValidationIssue> issues;

  /// Whether no blocking modular-contract issues were found.
  bool get isValid => issues.isEmpty;
}

/// Validates lightweight whole-project indexes and loaded module/index parity.
///
/// Index validation requires no event bodies. Loaded-module validation checks
/// that a module actually matches the IDs and outbound-reference summaries the
/// global index advertised. Existing `StoryValidator` remains the semantic
/// validator for a materialized executable project slice.
final class StoryModuleValidator {
  const StoryModuleValidator();

  /// Validates identities, ownership, dependencies, entry points, and outbound
  /// references using only the lightweight global index.
  StoryModuleValidationReport validateIndex(StoryProjectIndex index) {
    final issues = <StoryModuleValidationIssue>[];
    // Preserve phase order and first-definition ownership for duplicate IDs.
    final modules = _indexModules(index, issues);
    final events = _indexEvents(index, modules, issues);
    _validateModuleDependencies(index, modules, issues);
    _validateIndexEntryPoints(index, events, issues);
    _validateOutboundReferences(index, modules, events, issues);

    return StoryModuleValidationReport(issues: issues);
  }

  Map<StoryModuleId, StoryModuleIndexEntry> _indexModules(
    StoryProjectIndex index,
    List<StoryModuleValidationIssue> issues,
  ) {
    final modules = <StoryModuleId, StoryModuleIndexEntry>{};

    for (final module in index.modules) {
      if (modules.containsKey(module.id)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.duplicateModuleId,
            message: 'Duplicate module ID ${module.id.value}.',
            moduleId: module.id,
          ),
        );
      } else {
        modules[module.id] = module;
      }
    }
    return modules;
  }

  Map<StoryEventId, StoryEventIndexEntry> _indexEvents(
    StoryProjectIndex index,
    Map<StoryModuleId, StoryModuleIndexEntry> modules,
    List<StoryModuleValidationIssue> issues,
  ) {
    final events = <StoryEventId, StoryEventIndexEntry>{};
    for (final event in index.events) {
      if (events.containsKey(event.id)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.duplicateEventId,
            message: 'Duplicate indexed event ID ${event.id.value}.',
            moduleId: event.moduleId,
            eventId: event.id,
          ),
        );
      } else {
        events[event.id] = event;
      }
      if (!modules.containsKey(event.moduleId)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.eventOwnerModuleMissing,
            message:
                'Event ${event.id.value} belongs to unknown module '
                '${event.moduleId.value}.',
            moduleId: event.moduleId,
            eventId: event.id,
          ),
        );
      }
    }
    return events;
  }

  void _validateModuleDependencies(
    StoryProjectIndex index,
    Map<StoryModuleId, StoryModuleIndexEntry> modules,
    List<StoryModuleValidationIssue> issues,
  ) {
    for (final module in index.modules) {
      final seenDependencies = <StoryModuleId>{};
      for (final dependency in module.dependencies) {
        if (!seenDependencies.add(dependency)) {
          issues.add(
            StoryModuleValidationIssue(
              code: StoryModuleValidationCode.duplicateModuleDependency,
              message:
                  'Module ${module.id.value} repeats dependency '
                  '${dependency.value}.',
              moduleId: module.id,
            ),
          );
        }
        if (dependency == module.id) {
          issues.add(
            StoryModuleValidationIssue(
              code: StoryModuleValidationCode.selfModuleDependency,
              message: 'Module ${module.id.value} depends on itself.',
              moduleId: module.id,
            ),
          );
        } else if (!modules.containsKey(dependency)) {
          issues.add(
            StoryModuleValidationIssue(
              code: StoryModuleValidationCode.unknownModuleDependency,
              message:
                  'Module ${module.id.value} depends on unknown module '
                  '${dependency.value}.',
              moduleId: module.id,
            ),
          );
        }
      }
    }
  }

  void _validateIndexEntryPoints(
    StoryProjectIndex index,
    Map<StoryEventId, StoryEventIndexEntry> events,
    List<StoryModuleValidationIssue> issues,
  ) {
    final defaultEntry = index.defaultEntryEventId;
    if (defaultEntry != null && !events.containsKey(defaultEntry)) {
      issues.add(
        StoryModuleValidationIssue(
          code: StoryModuleValidationCode.defaultEntryEventMissing,
          message: 'Default entry event ${defaultEntry.value} is not indexed.',
          eventId: defaultEntry,
        ),
      );
    }

    final entryPointIds = <StoryEntryPointId>{};
    for (final entryPoint in index.entryPoints) {
      if (!entryPointIds.add(entryPoint.id)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.duplicateEntryPointId,
            message: 'Duplicate entry-point ID ${entryPoint.id.value}.',
            eventId: entryPoint.eventId,
          ),
        );
      }
      if (!events.containsKey(entryPoint.eventId)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.entryPointEventMissing,
            message:
                'Entry point ${entryPoint.id.value} targets unindexed '
                'event ${entryPoint.eventId.value}.',
            eventId: entryPoint.eventId,
          ),
        );
      }
    }
  }

  void _validateOutboundReferences(
    StoryProjectIndex index,
    Map<StoryModuleId, StoryModuleIndexEntry> modules,
    Map<StoryEventId, StoryEventIndexEntry> events,
    List<StoryModuleValidationIssue> issues,
  ) {
    for (final event in index.events) {
      final sourceModule = modules[event.moduleId];
      final seenOutbound = <StoryEventId>{};
      for (final destinationId in event.outboundEventIds) {
        if (!seenOutbound.add(destinationId)) {
          issues.add(
            StoryModuleValidationIssue(
              code: StoryModuleValidationCode.duplicateOutboundEventReference,
              message:
                  'Event ${event.id.value} repeats outbound reference '
                  '${destinationId.value}.',
              moduleId: event.moduleId,
              eventId: event.id,
            ),
          );
          continue;
        }
        final destination = events[destinationId];
        if (destination == null) {
          issues.add(
            StoryModuleValidationIssue(
              code: StoryModuleValidationCode.outboundEventMissing,
              message:
                  'Event ${event.id.value} references unindexed event '
                  '${destinationId.value}.',
              moduleId: event.moduleId,
              eventId: event.id,
            ),
          );
          continue;
        }
        if (sourceModule != null &&
            destination.moduleId != event.moduleId &&
            !sourceModule.dependencies.contains(destination.moduleId)) {
          issues.add(
            StoryModuleValidationIssue(
              code: StoryModuleValidationCode.crossModuleDependencyMissing,
              message:
                  'Event ${event.id.value} references event '
                  '${destination.id.value} in module '
                  '${destination.moduleId.value}, but module '
                  '${event.moduleId.value} does not declare that dependency.',
              moduleId: event.moduleId,
              eventId: event.id,
            ),
          );
        }
      }
    }
  }

  /// Verifies a loaded module against the lightweight index contract.
  StoryModuleValidationReport validateModule({
    required StoryProjectIndex index,
    required StoryNarrativeModule module,
  }) {
    final issues = <StoryModuleValidationIssue>[];
    final moduleDescriptor = index.moduleFor(module.id);
    if (moduleDescriptor == null) {
      issues.add(
        StoryModuleValidationIssue(
          code: StoryModuleValidationCode.moduleNotIndexed,
          message: 'Loaded module ${module.id.value} is not indexed.',
          moduleId: module.id,
        ),
      );
      return StoryModuleValidationReport(issues: issues);
    }

    if (module.projectId != index.projectId) {
      issues.add(
        StoryModuleValidationIssue(
          code: StoryModuleValidationCode.moduleProjectMismatch,
          message:
              'Loaded module ${module.id.value} belongs to project '
              '${module.projectId.value}, expected ${index.projectId.value}.',
          moduleId: module.id,
        ),
      );
    }

    final expectedEntries = <StoryEventId, StoryEventIndexEntry>{
      for (final event in index.events)
        if (event.moduleId == module.id) event.id: event,
    };
    final actualEvents = <StoryEventId, StoryEvent>{};
    for (final event in module.events) {
      if (actualEvents.containsKey(event.id)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.moduleDuplicateEventId,
            message:
                'Loaded module ${module.id.value} repeats event '
                '${event.id.value}.',
            moduleId: module.id,
            eventId: event.id,
          ),
        );
      } else {
        actualEvents[event.id] = event;
      }
    }

    for (final expected in expectedEntries.keys) {
      if (!actualEvents.containsKey(expected)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.moduleMissingEvent,
            message:
                'Loaded module ${module.id.value} is missing indexed '
                'event ${expected.value}.',
            moduleId: module.id,
            eventId: expected,
          ),
        );
      }
    }
    for (final actual in actualEvents.keys) {
      if (!expectedEntries.containsKey(actual)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.moduleUnexpectedEvent,
            message:
                'Loaded module ${module.id.value} contains unindexed '
                'event ${actual.value}.',
            moduleId: module.id,
            eventId: actual,
          ),
        );
      }
    }

    final analysis = StoryProjectAnalysis.analyze(
      StoryProject(
        id: module.projectId,
        stateSchema: index.stateSchema,
        events: actualEvents.values,
      ),
    );
    for (final entry in actualEvents.entries) {
      final expected = expectedEntries[entry.key];
      if (expected == null) {
        continue;
      }
      final actualReferences = analysis
          .outgoingReferences(entry.key)
          .map((reference) => reference.destinationEventId)
          .toSet()
          .toList();
      if (!_sameEventIds(actualReferences, expected.outboundEventIds)) {
        issues.add(
          StoryModuleValidationIssue(
            code: StoryModuleValidationCode.moduleOutboundReferencesMismatch,
            message:
                'Loaded event ${entry.key.value} outbound references do '
                'not match the project index.',
            moduleId: module.id,
            eventId: entry.key,
          ),
        );
      }
    }

    return StoryModuleValidationReport(issues: issues);
  }
}

bool _sameEventIds(List<StoryEventId> left, List<StoryEventId> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
