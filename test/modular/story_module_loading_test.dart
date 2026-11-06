import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryModuleValidator', () {
    test('validates unloaded cross-module references and dependencies', () {
      final moduleA = StoryModuleId('module_a');
      final moduleB = StoryModuleId('module_b');
      final eventA = StoryEventId('evt_a');
      final eventB = StoryEventId('evt_b');
      final index = StoryProjectIndex(
        projectId: StoryProjectId('project_modular_validation'),
        stateSchema: StoryStateSchema.empty(),
        modules: [
          StoryModuleIndexEntry(id: moduleA, dependencies: [moduleB]),
          StoryModuleIndexEntry(id: moduleB),
        ],
        events: [
          StoryEventIndexEntry(
            id: eventA,
            moduleId: moduleA,
            outboundEventIds: [eventB],
          ),
          StoryEventIndexEntry(id: eventB, moduleId: moduleB),
        ],
        entryPoints: [
          StoryEntryPoint(id: StoryEntryPointId('entry_a'), eventId: eventA),
        ],
      );

      expect(const StoryModuleValidator().validateIndex(index).isValid, isTrue);
    });

    test('reports missing cross-module dependency without loading bodies', () {
      final moduleA = StoryModuleId('module_a');
      final moduleB = StoryModuleId('module_b');
      final eventA = StoryEventId('evt_a');
      final eventB = StoryEventId('evt_b');
      final report = const StoryModuleValidator().validateIndex(
        StoryProjectIndex(
          projectId: StoryProjectId('project_missing_dependency'),
          stateSchema: StoryStateSchema.empty(),
          modules: [
            StoryModuleIndexEntry(id: moduleA),
            StoryModuleIndexEntry(id: moduleB),
          ],
          events: [
            StoryEventIndexEntry(
              id: eventA,
              moduleId: moduleA,
              outboundEventIds: [eventB],
            ),
            StoryEventIndexEntry(id: eventB, moduleId: moduleB),
          ],
        ),
      );

      expect(report.isValid, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        contains(StoryModuleValidationCode.crossModuleDependencyMissing),
      );
    });

    test('loaded bodies must match indexed event/reference summaries', () {
      final moduleId = StoryModuleId('module_body');
      final first = StoryEventId('evt_first');
      final second = StoryEventId('evt_second');
      final index = StoryProjectIndex(
        projectId: StoryProjectId('project_body_parity'),
        stateSchema: StoryStateSchema.empty(),
        modules: [StoryModuleIndexEntry(id: moduleId)],
        events: [
          StoryEventIndexEntry(
            id: first,
            moduleId: moduleId,
            outboundEventIds: [second],
          ),
          StoryEventIndexEntry(id: second, moduleId: moduleId),
        ],
      );
      final validModule = StoryNarrativeModule(
        projectId: index.projectId,
        id: moduleId,
        events: [
          StoryEvent(
            id: first,
            continuationTransition: StoryEventTransition(
              destinationEventId: second,
            ),
          ),
          StoryEvent(
            id: second,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final invalidModule = StoryNarrativeModule(
        projectId: index.projectId,
        id: moduleId,
        events: [
          StoryEvent(
            id: first,
            continuationTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: second,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      expect(
        const StoryModuleValidator()
            .validateModule(index: index, module: validModule)
            .isValid,
        isTrue,
      );
      expect(
        const StoryModuleValidator()
            .validateModule(index: index, module: invalidModule)
            .issues
            .map((issue) => issue.code),
        contains(StoryModuleValidationCode.moduleOutboundReferencesMismatch),
      );
    });
  });

  group('StoryModuleCache', () {
    test('materializes only requested module dependency closure', () async {
      final sharedModule = StoryModuleId('module_shared');
      final questModule = StoryModuleId('module_quest');
      final unrelatedModule = StoryModuleId('module_unrelated');
      final questStart = StoryEventId('evt_quest_start');
      final sharedEnd = StoryEventId('evt_shared_end');
      final unrelated = StoryEventId('evt_unrelated');
      final entryId = StoryEntryPointId('entry_quest');
      final index = StoryProjectIndex(
        projectId: StoryProjectId('project_lazy_slice'),
        stateSchema: StoryStateSchema.empty(),
        modules: [
          StoryModuleIndexEntry(id: questModule, dependencies: [sharedModule]),
          StoryModuleIndexEntry(id: sharedModule),
          StoryModuleIndexEntry(id: unrelatedModule),
        ],
        events: [
          StoryEventIndexEntry(
            id: questStart,
            moduleId: questModule,
            outboundEventIds: [sharedEnd],
          ),
          StoryEventIndexEntry(id: sharedEnd, moduleId: sharedModule),
          StoryEventIndexEntry(id: unrelated, moduleId: unrelatedModule),
        ],
        entryPoints: [StoryEntryPoint(id: entryId, eventId: questStart)],
      );
      final loader = _MemoryModuleLoader({
        questModule: StoryNarrativeModule(
          projectId: index.projectId,
          id: questModule,
          events: [
            StoryEvent(
              id: questStart,
              continuationTransition: StoryEventTransition(
                destinationEventId: sharedEnd,
              ),
            ),
          ],
        ),
        sharedModule: StoryNarrativeModule(
          projectId: index.projectId,
          id: sharedModule,
          events: [
            StoryEvent(
              id: sharedEnd,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
        unrelatedModule: StoryNarrativeModule(
          projectId: index.projectId,
          id: unrelatedModule,
          events: [
            StoryEvent(
              id: unrelated,
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
      });
      final cache = StoryModuleCache(
        index: index,
        loader: loader,
        maxCachedModules: 8,
      );

      final project = await cache.materializeProjectForEntryPoint(entryId);

      expect(loader.loads, [questModule, sharedModule]);
      expect(loader.loads, isNot(contains(unrelatedModule)));
      expect(project.events.map((event) => event.id), [questStart, sharedEnd]);
      expect(project.entryEventId, questStart);

      final engine = StoryEngine(project: project)..start();
      expect(engine.currentEvent?.id, questStart);
      engine.continueStory();
      expect(engine.currentEvent?.id, sharedEnd);
      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);
    });

    test(
      'cache hits, prefetch, and eviction do not change module data',
      () async {
        final moduleA = StoryModuleId('module_a');
        final moduleB = StoryModuleId('module_b');
        final eventA = StoryEventId('evt_a');
        final eventB = StoryEventId('evt_b');
        final projectId = StoryProjectId('project_cache_behavior');
        final index = StoryProjectIndex(
          projectId: projectId,
          stateSchema: StoryStateSchema.empty(),
          modules: [
            StoryModuleIndexEntry(id: moduleA),
            StoryModuleIndexEntry(id: moduleB),
          ],
          events: [
            StoryEventIndexEntry(id: eventA, moduleId: moduleA),
            StoryEventIndexEntry(id: eventB, moduleId: moduleB),
          ],
        );
        final loader = _MemoryModuleLoader({
          moduleA: _terminalModule(projectId, moduleA, eventA),
          moduleB: _terminalModule(projectId, moduleB, eventB),
        });
        final cache = StoryModuleCache(
          index: index,
          loader: loader,
          maxCachedModules: 1,
        );

        final firstA = await cache.loadModule(moduleA);
        final secondA = await cache.loadModule(moduleA);
        expect(identical(firstA, secondA), isTrue);
        expect(loader.loads, [moduleA]);

        await cache.prefetch([moduleB]);
        expect(cache.cachedModuleIds, [moduleB]);
        expect(cache.isCached(moduleA), isFalse);
        expect(cache.isCached(moduleB), isTrue);

        final reloadedA = await cache.loadModule(moduleA);
        expect(reloadedA.events.single.id, eventA);
        expect(loader.loads, [moduleA, moduleB, moduleA]);
        expect(cache.evict(moduleA), isTrue);
        expect(cache.evict(moduleA), isFalse);
      },
    );

    test('invalid loaded module never enters the verified cache', () async {
      final moduleId = StoryModuleId('module_invalid');
      final eventId = StoryEventId('evt_expected');
      final projectId = StoryProjectId('project_invalid_loader');
      final index = StoryProjectIndex(
        projectId: projectId,
        stateSchema: StoryStateSchema.empty(),
        modules: [StoryModuleIndexEntry(id: moduleId)],
        events: [StoryEventIndexEntry(id: eventId, moduleId: moduleId)],
      );
      final loader = _MemoryModuleLoader({
        moduleId: StoryNarrativeModule(
          projectId: projectId,
          id: moduleId,
          events: [
            StoryEvent(
              id: StoryEventId('evt_wrong'),
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
      });
      final cache = StoryModuleCache(index: index, loader: loader);

      await expectLater(
        cache.loadModule(moduleId),
        throwsA(isA<StoryModuleLoadException>()),
      );
      expect(cache.isCached(moduleId), isFalse);
    });
  });

  test(
    '10,000-event stress fixture resolves one module without full load',
    () async {
      final manifest =
          jsonDecode(
                File(
                  'test/fixtures/modular/stage8h_large_index_manifest.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final moduleCount = manifest['moduleCount'] as int;
      final dialoguesPerModule = manifest['dialoguesPerModule'] as int;
      final eventsPerDialogue = manifest['eventsPerDialogue'] as int;
      final expectedEventCount = manifest['expectedEventCount'] as int;
      final expectedEntryPointCount =
          manifest['expectedEntryPointCount'] as int;
      final targetModuleIndex = manifest['targetModuleIndex'] as int;
      final targetDialogueIndex = manifest['targetDialogueIndex'] as int;

      expect(eventsPerDialogue, 2);
      final projectId = StoryProjectId('project_stage8h_stress');
      final modules = <StoryModuleIndexEntry>[];
      final events = <StoryEventIndexEntry>[];
      final entryPoints = <StoryEntryPoint>[];
      for (var moduleIndex = 0; moduleIndex < moduleCount; moduleIndex++) {
        final moduleId = _moduleId(moduleIndex);
        modules.add(StoryModuleIndexEntry(id: moduleId));
        for (
          var dialogueIndex = 0;
          dialogueIndex < dialoguesPerModule;
          dialogueIndex++
        ) {
          final startId = _dialogueEventId(moduleIndex, dialogueIndex, 0);
          final endId = _dialogueEventId(moduleIndex, dialogueIndex, 1);
          events.add(
            StoryEventIndexEntry(
              id: startId,
              moduleId: moduleId,
              outboundEventIds: [endId],
            ),
          );
          events.add(StoryEventIndexEntry(id: endId, moduleId: moduleId));
          entryPoints.add(
            StoryEntryPoint(
              id: StoryEntryPointId('entry_m${moduleIndex}_d$dialogueIndex'),
              eventId: startId,
            ),
          );
        }
      }
      final index = StoryProjectIndex(
        projectId: projectId,
        stateSchema: StoryStateSchema.empty(),
        modules: modules,
        events: events,
        entryPoints: entryPoints,
      );

      expect(index.events, hasLength(expectedEventCount));
      expect(index.entryPoints, hasLength(expectedEntryPointCount));
      expect(const StoryModuleValidator().validateIndex(index).isValid, isTrue);

      final loader = _GeneratedStressLoader(
        projectId: projectId,
        dialoguesPerModule: dialoguesPerModule,
      );
      final cache = StoryModuleCache(
        index: index,
        loader: loader,
        maxCachedModules: 4,
      );
      final targetEntry = StoryEntryPointId(
        'entry_m${targetModuleIndex}_d$targetDialogueIndex',
      );
      final project = await cache.materializeProjectForEntryPoint(targetEntry);

      expect(loader.loads, [_moduleId(targetModuleIndex)]);
      expect(project.events, hasLength(dialoguesPerModule * eventsPerDialogue));
      expect(project.events.length, lessThan(index.events.length));
      final startId = _dialogueEventId(
        targetModuleIndex,
        targetDialogueIndex,
        0,
      );
      final endId = _dialogueEventId(targetModuleIndex, targetDialogueIndex, 1);
      expect(project.entryEventId, startId);

      final engine = StoryEngine(project: project)..start();
      expect(engine.status, StoryEngineStatus.terminated);
      expect(engine.history.eventRoute, [startId, endId]);
    },
  );
}

StoryNarrativeModule _terminalModule(
  StoryProjectId projectId,
  StoryModuleId moduleId,
  StoryEventId eventId,
) => StoryNarrativeModule(
  projectId: projectId,
  id: moduleId,
  events: [
    StoryEvent(
      id: eventId,
      continuationTransition: const StoryTerminalTransition(),
    ),
  ],
);

StoryModuleId _moduleId(int moduleIndex) =>
    StoryModuleId('module_$moduleIndex');

StoryEventId _dialogueEventId(
  int moduleIndex,
  int dialogueIndex,
  int eventIndex,
) => StoryEventId('evt_m${moduleIndex}_d${dialogueIndex}_e$eventIndex');

final class _MemoryModuleLoader implements StoryModuleLoader {
  _MemoryModuleLoader(this.modules);

  final Map<StoryModuleId, StoryNarrativeModule> modules;
  final List<StoryModuleId> loads = <StoryModuleId>[];

  @override
  Future<StoryNarrativeModule> loadModule(StoryModuleId moduleId) async {
    loads.add(moduleId);
    final module = modules[moduleId];
    if (module == null) {
      throw StoryModuleLoadException(
        message: 'Test module ${moduleId.value} is unavailable.',
      );
    }
    return module;
  }
}

final class _GeneratedStressLoader implements StoryModuleLoader {
  _GeneratedStressLoader({
    required this.projectId,
    required this.dialoguesPerModule,
  });

  final StoryProjectId projectId;
  final int dialoguesPerModule;
  final List<StoryModuleId> loads = <StoryModuleId>[];

  @override
  Future<StoryNarrativeModule> loadModule(StoryModuleId moduleId) async {
    loads.add(moduleId);
    final moduleIndex = int.parse(moduleId.value.substring('module_'.length));
    final events = <StoryEvent>[];
    for (
      var dialogueIndex = 0;
      dialogueIndex < dialoguesPerModule;
      dialogueIndex++
    ) {
      final startId = _dialogueEventId(moduleIndex, dialogueIndex, 0);
      final endId = _dialogueEventId(moduleIndex, dialogueIndex, 1);
      events.add(
        StoryEvent(
          id: startId,
          automaticTransition: StoryEventTransition(destinationEventId: endId),
        ),
      );
      events.add(
        StoryEvent(
          id: endId,
          automaticTransition: const StoryTerminalTransition(),
        ),
      );
    }
    return StoryNarrativeModule(
      projectId: projectId,
      id: moduleId,
      events: events,
    );
  }
}
