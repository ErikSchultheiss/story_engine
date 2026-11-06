import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Prepublication 1B index issues retain phase order and first owners', () {
    final a = StoryModuleId('module_a');
    final b = StoryModuleId('module_b');
    final missing = StoryModuleId('missing');
    final eventA = StoryEventId('event_a');
    final eventB = StoryEventId('event_b');
    final eventC = StoryEventId('event_c');
    final ghost = StoryEventId('ghost');
    final index = StoryProjectIndex(
      projectId: StoryProjectId('index_validation'),
      stateSchema: StoryStateSchema(variables: const []),
      modules: [
        StoryModuleIndexEntry(id: a, dependencies: [a, missing, missing]),
        // A duplicate must not replace the first module's dependency set.
        StoryModuleIndexEntry(id: a, dependencies: [b]),
        StoryModuleIndexEntry(id: b),
      ],
      events: [
        StoryEventIndexEntry(
          id: eventA,
          moduleId: a,
          outboundEventIds: [eventB, eventB, ghost, ghost],
        ),
        StoryEventIndexEntry(id: eventB, moduleId: b),
        // References to event_b must keep its original module_b owner.
        StoryEventIndexEntry(id: eventB, moduleId: missing),
        StoryEventIndexEntry(
          id: eventC,
          moduleId: missing,
          outboundEventIds: [eventB, ghost],
        ),
      ],
      defaultEntryEventId: ghost,
      entryPoints: [
        StoryEntryPoint(id: StoryEntryPointId('entry'), eventId: eventA),
        StoryEntryPoint(id: StoryEntryPointId('entry'), eventId: ghost),
        StoryEntryPoint(id: StoryEntryPointId('other_entry'), eventId: ghost),
      ],
    );

    final report = const StoryModuleValidator().validateIndex(index);

    expect(
      report.issues.map(
        (issue) => (
          issue.code,
          issue.moduleId?.value,
          issue.eventId?.value,
          issue.message,
        ),
      ),
      [
        (
          StoryModuleValidationCode.duplicateModuleId,
          'module_a',
          null,
          'Duplicate module ID module_a.',
        ),
        (
          StoryModuleValidationCode.duplicateEventId,
          'missing',
          'event_b',
          'Duplicate indexed event ID event_b.',
        ),
        (
          StoryModuleValidationCode.eventOwnerModuleMissing,
          'missing',
          'event_b',
          'Event event_b belongs to unknown module missing.',
        ),
        (
          StoryModuleValidationCode.eventOwnerModuleMissing,
          'missing',
          'event_c',
          'Event event_c belongs to unknown module missing.',
        ),
        (
          StoryModuleValidationCode.selfModuleDependency,
          'module_a',
          null,
          'Module module_a depends on itself.',
        ),
        (
          StoryModuleValidationCode.unknownModuleDependency,
          'module_a',
          null,
          'Module module_a depends on unknown module missing.',
        ),
        (
          StoryModuleValidationCode.duplicateModuleDependency,
          'module_a',
          null,
          'Module module_a repeats dependency missing.',
        ),
        (
          StoryModuleValidationCode.unknownModuleDependency,
          'module_a',
          null,
          'Module module_a depends on unknown module missing.',
        ),
        (
          StoryModuleValidationCode.defaultEntryEventMissing,
          null,
          'ghost',
          'Default entry event ghost is not indexed.',
        ),
        (
          StoryModuleValidationCode.duplicateEntryPointId,
          null,
          'ghost',
          'Duplicate entry-point ID entry.',
        ),
        (
          StoryModuleValidationCode.entryPointEventMissing,
          null,
          'ghost',
          'Entry point entry targets unindexed event ghost.',
        ),
        (
          StoryModuleValidationCode.entryPointEventMissing,
          null,
          'ghost',
          'Entry point other_entry targets unindexed event ghost.',
        ),
        (
          StoryModuleValidationCode.crossModuleDependencyMissing,
          'module_a',
          'event_a',
          'Event event_a references event event_b in module module_b, but module '
              'module_a does not declare that dependency.',
        ),
        (
          StoryModuleValidationCode.duplicateOutboundEventReference,
          'module_a',
          'event_a',
          'Event event_a repeats outbound reference event_b.',
        ),
        (
          StoryModuleValidationCode.outboundEventMissing,
          'module_a',
          'event_a',
          'Event event_a references unindexed event ghost.',
        ),
        (
          StoryModuleValidationCode.duplicateOutboundEventReference,
          'module_a',
          'event_a',
          'Event event_a repeats outbound reference ghost.',
        ),
        (
          StoryModuleValidationCode.outboundEventMissing,
          'missing',
          'event_c',
          'Event event_c references unindexed event ghost.',
        ),
      ],
    );
    expect(report.isValid, isFalse);
  });
}
