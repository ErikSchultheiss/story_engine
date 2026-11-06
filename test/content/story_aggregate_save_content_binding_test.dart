import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9A6 aggregate save-content binding', () {
    test(
      'retained sessions contribute one deterministic module/dependency union',
      () {
        final fixture = _aggregateFixture();
        final snapshot = fixture.runtime.createSnapshot();

        final binding = StorySaveContentBinding.fromRetainedSessionSnapshots(
          projectId: snapshot.projectId,
          snapshots: snapshot.sessions.map(
            (session) => session.runtimeSnapshot,
          ),
          index: fixture.index,
          release: fixture.release,
        );

        expect(binding.projectId, fixture.project.id);
        expect(binding.releaseId, fixture.release.releaseId);
        expect(binding.bundleId, fixture.release.bundleId);
        expect(
          binding.modules.map((module) => module.moduleId),
          [fixture.moduleA, fixture.sharedModule, fixture.moduleB],
          reason:
              'Modules follow retained-session/route first-reference order '
              'with dependency closure deduplicated across sessions.',
        );
        expect(
          binding.modules.map((module) => module.moduleId),
          isNot(contains(fixture.unusedModule)),
        );

        const codec = StorySaveContentBindingCodec();
        final encoded = codec.encode(binding);
        final decoded = codec.decode(encoded);
        expect(codec.encode(decoded), encoded);
        expect(decoded.projectId, binding.projectId);
        expect(decoded.releaseId, binding.releaseId);
        expect(decoded.bundleId, binding.bundleId);
        expect(decoded.modules, binding.modules);
      },
    );

    test(
      'completed and unfinished retained sessions both remain content-bound',
      () {
        final fixture = _aggregateFixture();
        final snapshot = fixture.runtime.createSnapshot();

        expect(snapshot.sessions, hasLength(2));
        expect(
          snapshot.sessions.first.runtimeSnapshot.status,
          StoryEngineStatus.terminated,
        );
        expect(
          snapshot.sessions.last.runtimeSnapshot.status,
          StoryEngineStatus.awaitingContinue,
        );

        final binding = StorySaveContentBinding.fromRetainedSessionSnapshots(
          projectId: snapshot.projectId,
          snapshots: snapshot.sessions.map(
            (session) => session.runtimeSnapshot,
          ),
          index: fixture.index,
          release: fixture.release,
        );

        expect(
          binding.modules.map((module) => module.moduleId),
          containsAll([fixture.moduleA, fixture.moduleB]),
        );
      },
    );

    test(
      'an empty aggregate still binds project release and bundle identity',
      () {
        final fixture = _aggregateFixture(startSessions: false);
        final snapshot = fixture.runtime.createSnapshot();

        final binding = StorySaveContentBinding.fromRetainedSessionSnapshots(
          projectId: snapshot.projectId,
          snapshots: snapshot.sessions.map(
            (session) => session.runtimeSnapshot,
          ),
          index: fixture.index,
          release: fixture.release,
        );

        expect(binding.projectId, fixture.project.id);
        expect(binding.releaseId, fixture.release.releaseId);
        expect(binding.bundleId, fixture.release.bundleId);
        expect(binding.modules, isEmpty);
      },
    );

    test('aggregate bindings reuse explicit compatibility categories', () {
      final fixture = _aggregateFixture();
      final snapshot = fixture.runtime.createSnapshot();
      final binding = StorySaveContentBinding.fromRetainedSessionSnapshots(
        projectId: snapshot.projectId,
        snapshots: snapshot.sessions.map((session) => session.runtimeSnapshot),
        index: fixture.index,
        release: fixture.release,
      );
      const evaluator = StorySaveContentCompatibilityEvaluator();

      expect(
        evaluator.evaluate(binding: binding, target: fixture.release).status,
        StorySaveCompatibilityStatus.exact,
      );

      final compatibleTarget = StoryContentReleaseManifest(
        releaseId: StoryContentReleaseId('release_aggregate_2'),
        projectId: fixture.project.id,
        bundleId: StoryContentHash.fromBytes(const [42]),
        modules: [
          StoryContentModuleRevision(
            moduleId: fixture.moduleA,
            moduleVersion: StoryModuleVersion('2'),
            contentHash: StoryContentHash.fromBytes(const [11]),
            dependencies: [fixture.sharedModule],
            compatibleSaveSources: [
              fixture.release.moduleFor(fixture.moduleA)!.reference,
            ],
          ),
          fixture.release.moduleFor(fixture.sharedModule)!,
          fixture.release.moduleFor(fixture.moduleB)!,
          fixture.release.moduleFor(fixture.unusedModule)!,
        ],
      );
      expect(
        evaluator.evaluate(binding: binding, target: compatibleTarget).status,
        StorySaveCompatibilityStatus.compatible,
      );

      final incompatibleTarget = StoryContentReleaseManifest(
        releaseId: StoryContentReleaseId('release_aggregate_3'),
        projectId: fixture.project.id,
        bundleId: StoryContentHash.fromBytes(const [43]),
        modules: [
          fixture.release.moduleFor(fixture.moduleA)!,
          fixture.release.moduleFor(fixture.sharedModule)!,
          StoryContentModuleRevision(
            moduleId: fixture.moduleB,
            moduleVersion: StoryModuleVersion('2'),
            contentHash: StoryContentHash.fromBytes(const [12]),
            dependencies: [fixture.sharedModule],
          ),
          fixture.release.moduleFor(fixture.unusedModule)!,
        ],
      );
      expect(
        evaluator.evaluate(binding: binding, target: incompatibleTarget).status,
        StorySaveCompatibilityStatus.incompatible,
      );

      final migrationPlan = StoryContentMigrationPlan(
        projectId: fixture.project.id,
        fromReleaseId: fixture.release.releaseId,
        toReleaseId: incompatibleTarget.releaseId,
        eventRedirects: {fixture.eventB: StoryEventId('evt_b_replacement')},
      );
      expect(
        evaluator
            .evaluate(
              binding: binding,
              target: incompatibleTarget,
              migrationPlan: migrationPlan,
            )
            .status,
        StorySaveCompatibilityStatus.migrationRequired,
      );

      final fallbackPlan = StoryContentMigrationPlan(
        projectId: fixture.project.id,
        fromReleaseId: fixture.release.releaseId,
        toReleaseId: incompatibleTarget.releaseId,
        fallbackEntryPointId: StoryEntryPointId('entry_safe_restart'),
      );
      expect(
        evaluator
            .evaluate(
              binding: binding,
              target: incompatibleTarget,
              migrationPlan: fallbackPlan,
            )
            .status,
        StorySaveCompatibilityStatus.fallbackRequired,
      );
    });

    test(
      'aggregate binding rejects mismatched or incomplete content metadata',
      () {
        final fixture = _aggregateFixture();
        final snapshot = fixture.runtime.createSnapshot();
        final snapshots = snapshot.sessions
            .map((session) => session.runtimeSnapshot)
            .toList(growable: false);

        expect(
          () => StorySaveContentBinding.fromRetainedSessionSnapshots(
            projectId: StoryProjectId('project_wrong'),
            snapshots: snapshots,
            index: fixture.index,
            release: fixture.release,
          ),
          throwsArgumentError,
        );

        final otherProject = StoryProject(
          id: StoryProjectId('project_other'),
          entryEventId: StoryEventId('evt_other'),
          events: [
            StoryEvent(
              id: StoryEventId('evt_other'),
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );
        final otherSnapshot = StoryEngine(project: otherProject)..start();
        expect(
          () => StorySaveContentBinding.fromRetainedSessionSnapshots(
            projectId: fixture.project.id,
            snapshots: [snapshots.first, otherSnapshot.createSnapshot()],
            index: fixture.index,
            release: fixture.release,
          ),
          throwsArgumentError,
        );

        final incompleteRelease = StoryContentReleaseManifest(
          releaseId: StoryContentReleaseId('release_incomplete'),
          projectId: fixture.project.id,
          bundleId: StoryContentHash.fromBytes(const [44]),
          modules: [
            fixture.release.moduleFor(fixture.moduleA)!,
            fixture.release.moduleFor(fixture.sharedModule)!,
          ],
        );
        expect(
          () => StorySaveContentBinding.fromRetainedSessionSnapshots(
            projectId: fixture.project.id,
            snapshots: snapshots,
            index: fixture.index,
            release: incompleteRelease,
          ),
          throwsArgumentError,
        );

        final dependencyMismatchRelease = StoryContentReleaseManifest(
          releaseId: StoryContentReleaseId('release_dependency_mismatch'),
          projectId: fixture.project.id,
          bundleId: StoryContentHash.fromBytes(const [45]),
          modules: [
            StoryContentModuleRevision(
              moduleId: fixture.moduleA,
              moduleVersion: StoryModuleVersion('1'),
              contentHash: StoryContentHash.fromBytes(const [1]),
            ),
            fixture.release.moduleFor(fixture.sharedModule)!,
            fixture.release.moduleFor(fixture.moduleB)!,
            fixture.release.moduleFor(fixture.unusedModule)!,
          ],
        );
        expect(
          () => StorySaveContentBinding.fromRetainedSessionSnapshots(
            projectId: fixture.project.id,
            snapshots: snapshots,
            index: fixture.index,
            release: dependencyMismatchRelease,
          ),
          throwsArgumentError,
        );
      },
    );
  });
}

_AggregateFixture _aggregateFixture({bool startSessions = true}) {
  final projectId = StoryProjectId('project_aggregate_binding');
  final eventA = StoryEventId('evt_a');
  final eventB = StoryEventId('evt_b');
  final entryA = StoryEntryPointId('entry_a');
  final entryB = StoryEntryPointId('entry_b');
  final moduleA = StoryModuleId('module_a');
  final moduleB = StoryModuleId('module_b');
  final sharedModule = StoryModuleId('module_shared');
  final unusedModule = StoryModuleId('module_unused');

  final project = StoryProject(
    id: projectId,
    entryEventId: eventA,
    events: [
      StoryEvent(
        id: eventA,
        automaticTransition: const StoryTerminalTransition(),
      ),
      StoryEvent(
        id: eventB,
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  final entryPoints = [
    StoryEntryPoint(id: entryA, eventId: eventA),
    StoryEntryPoint(id: entryB, eventId: eventB),
  ];
  final runtime = StoryNarrativeRuntime(
    project: project,
    entryPoints: entryPoints,
    randomSeed: 90210,
  );
  if (startSessions) {
    runtime.startSession(entryA);
    runtime.startSession(entryB);
  }

  final index = StoryProjectIndex(
    projectId: project.id,
    stateSchema: project.stateSchema,
    modules: [
      StoryModuleIndexEntry(id: moduleA, dependencies: [sharedModule]),
      StoryModuleIndexEntry(id: sharedModule),
      StoryModuleIndexEntry(id: moduleB, dependencies: [sharedModule]),
      StoryModuleIndexEntry(id: unusedModule),
    ],
    events: [
      StoryEventIndexEntry(id: eventA, moduleId: moduleA),
      StoryEventIndexEntry(id: eventB, moduleId: moduleB),
    ],
    entryPoints: entryPoints,
    defaultEntryEventId: eventA,
  );
  final release = StoryContentReleaseManifest(
    releaseId: StoryContentReleaseId('release_aggregate_1'),
    projectId: project.id,
    bundleId: StoryContentHash.fromBytes(const [41]),
    modules: [
      StoryContentModuleRevision(
        moduleId: moduleA,
        moduleVersion: StoryModuleVersion('1'),
        contentHash: StoryContentHash.fromBytes(const [1]),
        dependencies: [sharedModule],
      ),
      StoryContentModuleRevision(
        moduleId: sharedModule,
        moduleVersion: StoryModuleVersion('1'),
        contentHash: StoryContentHash.fromBytes(const [2]),
      ),
      StoryContentModuleRevision(
        moduleId: moduleB,
        moduleVersion: StoryModuleVersion('1'),
        contentHash: StoryContentHash.fromBytes(const [3]),
        dependencies: [sharedModule],
      ),
      StoryContentModuleRevision(
        moduleId: unusedModule,
        moduleVersion: StoryModuleVersion('1'),
        contentHash: StoryContentHash.fromBytes(const [4]),
      ),
    ],
  );

  return _AggregateFixture(
    project: project,
    runtime: runtime,
    index: index,
    release: release,
    eventB: eventB,
    moduleA: moduleA,
    moduleB: moduleB,
    sharedModule: sharedModule,
    unusedModule: unusedModule,
  );
}

final class _AggregateFixture {
  const _AggregateFixture({
    required this.project,
    required this.runtime,
    required this.index,
    required this.release,
    required this.eventB,
    required this.moduleA,
    required this.moduleB,
    required this.sharedModule,
    required this.unusedModule,
  });

  final StoryProject project;
  final StoryNarrativeRuntime runtime;
  final StoryProjectIndex index;
  final StoryContentReleaseManifest release;
  final StoryEventId eventB;
  final StoryModuleId moduleA;
  final StoryModuleId moduleB;
  final StoryModuleId sharedModule;
  final StoryModuleId unusedModule;
}
