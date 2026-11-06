import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 8L content versioning and save compatibility', () {
    test('release manifest layers explicit versions over Stage 8K hashes', () {
      final moduleA = StoryModuleId('module_a');
      final moduleB = StoryModuleId('module_b');
      const bundleCodec = StoryRuntimeBundleManifestCodec();
      final bundle = bundleCodec.create(
        projectId: StoryProjectId('project_release'),
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1',
        indexArtifact: StoryRuntimeArtifactDescriptor(
          path: StoryRuntimeBundleLayout.indexPath,
          contentHash: StoryContentHash.fromBytes(const [1]),
          byteLength: 1,
        ),
        modules: [
          StoryRuntimeModuleArtifactDescriptor(
            moduleId: moduleA,
            path: StoryRuntimeBundleLayout.modulePath(moduleA),
            contentHash: StoryContentHash.fromBytes(const [2]),
            byteLength: 1,
            dependencies: [moduleB],
          ),
          StoryRuntimeModuleArtifactDescriptor(
            moduleId: moduleB,
            path: StoryRuntimeBundleLayout.modulePath(moduleB),
            contentHash: StoryContentHash.fromBytes(const [3]),
            byteLength: 1,
          ),
        ],
      );
      final sourceRef = StoryModuleRevisionReference(
        moduleId: moduleA,
        moduleVersion: StoryModuleVersion('1.0.0'),
        contentHash: StoryContentHash.fromBytes(const [9]),
      );

      final release = StoryContentReleaseManifest.fromRuntimeBundleManifest(
        releaseId: StoryContentReleaseId('release_2'),
        bundleManifest: bundle,
        moduleVersions: {
          moduleA: StoryModuleVersion('2.0.0'),
          moduleB: StoryModuleVersion('1.0.0'),
        },
        compatibleSaveSources: {
          moduleA: [sourceRef],
        },
      );

      expect(release.bundleId, bundle.bundleId);
      expect(release.modules, hasLength(2));
      expect(release.modules.first.dependencies, [moduleB]);
      expect(release.modules.first.compatibleSaveSources, [sourceRef]);
      expect(
        release.modules.first.contentHash,
        bundle.modules.first.contentHash,
      );
    });

    test('patch planner isolates add replace and remove operations', () {
      final moduleA = StoryModuleId('module_a');
      final moduleB = StoryModuleId('module_b');
      final moduleC = StoryModuleId('module_c');
      final source = _release('release_1', [
        _module(moduleA, '1', 1),
        _module(moduleB, '1', 2),
      ], bundleByte: 10);
      final target = _release('release_2', [
        _module(moduleA, '2', 3),
        _module(moduleC, '1', 4),
      ], bundleByte: 11);

      final patch = const StoryContentPatchPlanner().plan(
        source: source,
        target: target,
      );

      expect(patch.operations.map((operation) => operation.kind), [
        StoryContentPatchOperationKind.replace,
        StoryContentPatchOperationKind.add,
        StoryContentPatchOperationKind.remove,
      ]);
      expect(patch.operations.map((operation) => operation.moduleId), [
        moduleA,
        moduleC,
        moduleB,
      ]);
    });

    test('save binding records route modules and their dependency closure', () {
      final eventA = StoryEventId('evt_a');
      final eventB = StoryEventId('evt_b');
      final moduleA = StoryModuleId('module_a');
      final moduleB = StoryModuleId('module_b');
      final moduleC = StoryModuleId('module_c');
      final project = StoryProject(
        id: StoryProjectId('project_binding'),
        entryEventId: eventA,
        events: [
          StoryEvent(
            id: eventA,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: eventB,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: project)..start();
      final snapshot = engine.createSnapshot();
      final index = StoryProjectIndex(
        projectId: project.id,
        stateSchema: project.stateSchema,
        modules: [
          StoryModuleIndexEntry(id: moduleA, dependencies: [moduleB]),
          StoryModuleIndexEntry(id: moduleB),
          StoryModuleIndexEntry(id: moduleC),
        ],
        events: [
          StoryEventIndexEntry(id: eventA, moduleId: moduleA),
          StoryEventIndexEntry(id: eventB, moduleId: moduleC),
        ],
        defaultEntryEventId: eventA,
      );
      final release = _release(
        'release_binding',
        [
          StoryContentModuleRevision(
            moduleId: moduleA,
            moduleVersion: StoryModuleVersion('1'),
            contentHash: StoryContentHash.fromBytes(const [1]),
            dependencies: [moduleB],
          ),
          _module(moduleB, '1', 2),
          _module(moduleC, '1', 3),
        ],
        bundleByte: 12,
        projectId: project.id,
      );

      final binding = StorySaveContentBinding.fromSnapshot(
        snapshot: snapshot,
        index: index,
        release: release,
      );

      expect(binding.modules, hasLength(2));
      expect(binding.modules.map((module) => module.moduleId), [
        moduleA,
        moduleB,
      ]);
    });

    test(
      'compatibility is explicit and never inferred from version ordering',
      () {
        final module = StoryModuleId('module_main');
        final source = _release('release_1', [
          _module(module, '1.0.0', 1),
        ], bundleByte: 20);
        final binding = StorySaveContentBinding(
          projectId: source.projectId,
          releaseId: source.releaseId,
          bundleId: source.bundleId,
          modules: [source.modules.single.reference],
        );
        final compatibleTarget = _release('release_2', [
          StoryContentModuleRevision(
            moduleId: module,
            moduleVersion: StoryModuleVersion('99.0.0'),
            contentHash: StoryContentHash.fromBytes(const [2]),
            compatibleSaveSources: [source.modules.single.reference],
          ),
        ], bundleByte: 21);
        final byteIdenticalTarget = _release('release_same_bytes', [
          StoryContentModuleRevision(
            moduleId: module,
            moduleVersion: StoryModuleVersion('2.0.0-label-only'),
            contentHash: source.modules.single.contentHash,
          ),
        ], bundleByte: 23);
        final incompatibleTarget = _release('release_2', [
          _module(module, '100.0.0', 3),
        ], bundleByte: 22);
        const evaluator = StorySaveContentCompatibilityEvaluator();

        expect(
          evaluator.evaluate(binding: binding, target: source).status,
          StorySaveCompatibilityStatus.exact,
        );
        expect(
          evaluator.evaluate(binding: binding, target: compatibleTarget).status,
          StorySaveCompatibilityStatus.compatible,
        );
        expect(
          evaluator
              .evaluate(binding: binding, target: byteIdenticalTarget)
              .status,
          StorySaveCompatibilityStatus.compatible,
        );
        expect(
          evaluator
              .evaluate(binding: binding, target: incompatibleTarget)
              .status,
          StorySaveCompatibilityStatus.incompatible,
        );

        final reusedReleaseId = _release(source.releaseId.value, [
          _module(module, '1.0.0', 1),
        ], bundleByte: 24);
        expect(
          evaluator.evaluate(binding: binding, target: reusedReleaseId).status,
          StorySaveCompatibilityStatus.incompatible,
          reason: 'A release ID cannot silently identify two bundle revisions.',
        );

        final redirectPlan = StoryContentMigrationPlan(
          projectId: source.projectId,
          fromReleaseId: source.releaseId,
          toReleaseId: incompatibleTarget.releaseId,
          eventRedirects: {StoryEventId('evt_old'): StoryEventId('evt_new')},
        );
        expect(
          evaluator
              .evaluate(
                binding: binding,
                target: incompatibleTarget,
                migrationPlan: redirectPlan,
              )
              .status,
          StorySaveCompatibilityStatus.migrationRequired,
        );

        final fallbackPlan = StoryContentMigrationPlan(
          projectId: source.projectId,
          fromReleaseId: source.releaseId,
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
      },
    );

    test(
      'structural redirects migrate snapshot IDs and revalidate target flow',
      () {
        final oldEvent = StoryEventId('evt_old');
        final newEvent = StoryEventId('evt_new');
        final oldChoice = StoryChoiceId('choice_old');
        final newChoice = StoryChoiceId('choice_new');
        final sourceProject = StoryProject(
          id: StoryProjectId('project_migrate'),
          entryEventId: oldEvent,
          events: [
            StoryEvent(
              id: oldEvent,
              choices: [
                StoryChoice(
                  id: oldChoice,
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        );
        final sourceEngine = StoryEngine(project: sourceProject)..start();
        sourceEngine.choose(oldChoice);
        final snapshot = sourceEngine.createSnapshot();
        final targetProject = StoryProject(
          id: sourceProject.id,
          entryEventId: newEvent,
          events: [
            StoryEvent(
              id: newEvent,
              choices: [
                StoryChoice(
                  id: newChoice,
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        );
        final plan = StoryContentMigrationPlan(
          projectId: sourceProject.id,
          fromReleaseId: StoryContentReleaseId('release_1'),
          toReleaseId: StoryContentReleaseId('release_2'),
          eventRedirects: {oldEvent: newEvent},
          choiceRedirects: {oldChoice: newChoice},
        );

        final migrated = const StoryRuntimeSnapshotContentMigrator().migrate(
          snapshot: snapshot,
          targetProject: targetProject,
          plan: plan,
        );

        expect(migrated.currentEventId, newEvent);
        expect(migrated.history.eventRoute, [newEvent]);
        expect(migrated.history.selectedChoiceIds, [newChoice]);
        expect(
          StoryEngine.restore(
            project: targetProject,
            snapshot: migrated,
          ).status,
          StoryEngineStatus.terminated,
        );

        final wrongProjectPlan = StoryContentMigrationPlan(
          projectId: StoryProjectId('other_project'),
          fromReleaseId: StoryContentReleaseId('release_1'),
          toReleaseId: StoryContentReleaseId('release_2'),
        );
        expect(
          () => const StoryRuntimeSnapshotContentMigrator().migrate(
            snapshot: snapshot,
            targetProject: targetProject,
            plan: wrongProjectPlan,
          ),
          throwsA(isA<StoryContentMigrationException>()),
        );
      },
    );
  });
}

StoryContentReleaseManifest _release(
  String releaseId,
  List<StoryContentModuleRevision> modules, {
  required int bundleByte,
  StoryProjectId? projectId,
}) => StoryContentReleaseManifest(
  releaseId: StoryContentReleaseId(releaseId),
  projectId: projectId ?? StoryProjectId('project_content'),
  bundleId: StoryContentHash.fromBytes([bundleByte]),
  modules: modules,
);

StoryContentModuleRevision _module(
  StoryModuleId id,
  String version,
  int contentByte,
) => StoryContentModuleRevision(
  moduleId: id,
  moduleVersion: StoryModuleVersion(version),
  contentHash: StoryContentHash.fromBytes([contentByte]),
);
