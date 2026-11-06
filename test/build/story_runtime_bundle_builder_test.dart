import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeBundleBuilder', () {
    test('SHA-256 content identity matches the standard abc vector', () {
      final hash = StoryContentHash.fromBytes(utf8.encode('abc'));

      expect(
        hash.value,
        'sha256:ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
      expect(StoryContentHash.parse(hash.value), hash);
    });

    test(
      'same semantic build inputs produce byte-identical bundle identity',
      () {
        final fixture = _fixture();
        const builder = StoryRuntimeBundleBuilder();

        final first = builder.build(
          index: fixture.index,
          compiledIndexBytes: utf8.encode('compiled-index-v1'),
          compiledModuleBytes: {
            fixture.moduleA: utf8.encode('module-a-v1'),
            fixture.moduleB: utf8.encode('module-b-v1'),
          },
          buildProfile: 'reference-proof-v1',
          builderId: 'story-engine-stage8k',
          builderVersion: '1.0.0',
        );
        final second = builder.build(
          index: fixture.index,
          compiledIndexBytes: utf8.encode('compiled-index-v1'),
          compiledModuleBytes: {
            // Map input order must not participate in output identity.
            fixture.moduleB: utf8.encode('module-b-v1'),
            fixture.moduleA: utf8.encode('module-a-v1'),
          },
          buildProfile: 'reference-proof-v1',
          builderId: 'story-engine-stage8k',
          builderVersion: '1.0.0',
        );

        expect(second.manifest.bundleId, first.manifest.bundleId);
        expect(second.files.keys.toList(), first.files.keys.toList());
        for (final path in first.files.keys) {
          expect(second.files[path], first.files[path], reason: path);
        }
        builder.verifyIntegrity(first);
        builder.verifyIntegrity(second);
      },
    );

    test('artifact byte change changes module hash and bundle identity', () {
      final fixture = _fixture();
      const builder = StoryRuntimeBundleBuilder();

      StoryRuntimeBundle build(String moduleB) => builder.build(
        index: fixture.index,
        compiledIndexBytes: utf8.encode('compiled-index-v1'),
        compiledModuleBytes: {
          fixture.moduleA: utf8.encode('module-a-v1'),
          fixture.moduleB: utf8.encode(moduleB),
        },
        buildProfile: 'reference-proof-v1',
        builderId: 'story-engine-stage8k',
        builderVersion: '1.0.0',
      );

      final first = build('module-b-v1');
      final changed = build('module-b-v2');

      expect(changed.manifest.bundleId, isNot(first.manifest.bundleId));
      expect(
        changed.manifest.modules[1].contentHash,
        isNot(first.manifest.modules[1].contentHash),
      );
      expect(
        changed.manifest.modules.first.contentHash,
        first.manifest.modules.first.contentHash,
      );
    });

    test('builder version participates in reproducible bundle identity', () {
      final fixture = _fixture();
      const builder = StoryRuntimeBundleBuilder();

      StoryRuntimeBundle build(String builderVersion) => builder.build(
        index: fixture.index,
        compiledIndexBytes: const [1, 2, 3],
        compiledModuleBytes: {
          fixture.moduleA: const [4],
          fixture.moduleB: const [5],
        },
        buildProfile: 'reference-proof-v1',
        builderId: 'story-engine-stage8k',
        builderVersion: builderVersion,
      );

      expect(
        build('1.0.1').manifest.bundleId,
        isNot(build('1.0.0').manifest.bundleId),
      );
    });

    test('compiled module set must exactly match Stage 8H index', () {
      final fixture = _fixture();
      const builder = StoryRuntimeBundleBuilder();

      expect(
        () => builder.build(
          index: fixture.index,
          compiledIndexBytes: const [1],
          compiledModuleBytes: {
            fixture.moduleA: const [2],
          },
          buildProfile: 'reference-proof-v1',
          builderId: 'stage8k',
          builderVersion: '1',
        ),
        throwsA(isA<StoryRuntimeBundleBuildException>()),
      );
    });

    test('integrity verification rejects modified artifact bytes', () {
      final fixture = _fixture();
      const builder = StoryRuntimeBundleBuilder();
      final bundle = builder.build(
        index: fixture.index,
        compiledIndexBytes: const [1, 2],
        compiledModuleBytes: {
          fixture.moduleA: const [3],
          fixture.moduleB: const [4],
        },
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1',
      );
      final tampered = StoryRuntimeBundle(
        manifest: bundle.manifest,
        files: {
          ...bundle.files,
          StoryRuntimeBundleLayout.modulePath(fixture.moduleB): const [99],
        },
      );

      expect(
        () => builder.verifyIntegrity(tampered),
        throwsA(isA<StoryRuntimeBundleBuildException>()),
      );
    });

    test('in-memory manifest metadata must match manifest bytes', () {
      final fixture = _fixture();
      const builder = StoryRuntimeBundleBuilder();
      final bundle = builder.build(
        index: fixture.index,
        compiledIndexBytes: const [1, 2],
        compiledModuleBytes: {
          fixture.moduleA: const [3],
          fixture.moduleB: const [4],
        },
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1',
      );
      final mismatchedManifest = StoryRuntimeBundleManifest(
        bundleId: bundle.manifest.bundleId,
        projectId: bundle.manifest.projectId,
        buildProfile: bundle.manifest.buildProfile,
        builderId: bundle.manifest.builderId,
        builderVersion: 'different-version',
        indexArtifact: bundle.manifest.indexArtifact,
        modules: bundle.manifest.modules,
      );
      final mismatched = StoryRuntimeBundle(
        manifest: mismatchedManifest,
        files: bundle.files,
      );

      expect(
        () => builder.verifyIntegrity(mismatched),
        throwsA(isA<StoryRuntimeBundleBuildException>()),
      );
    });

    test('hundred-module build remains an indexed artifact set', () {
      final projectId = StoryProjectId('project_stage8k_hundred_modules');
      final modules = <StoryModuleIndexEntry>[];
      final compiled = <StoryModuleId, List<int>>{};
      for (var i = 0; i < 100; i++) {
        final id = StoryModuleId('module_${i.toString().padLeft(3, '0')}');
        modules.add(StoryModuleIndexEntry(id: id));
        compiled[id] = utf8.encode('payload-$i');
      }
      final index = StoryProjectIndex(
        projectId: projectId,
        stateSchema: StoryStateSchema.empty(),
        modules: modules,
      );

      final bundle = const StoryRuntimeBundleBuilder().build(
        index: index,
        compiledIndexBytes: utf8.encode('100-module-index'),
        compiledModuleBytes: compiled,
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1',
      );

      expect(bundle.manifest.modules, hasLength(100));
      expect(bundle.files, hasLength(102));
    });
  });
}

_Fixture _fixture() {
  final moduleA = StoryModuleId('module_a');
  final moduleB = StoryModuleId('module_b');
  return _Fixture(
    moduleA: moduleA,
    moduleB: moduleB,
    index: StoryProjectIndex(
      projectId: StoryProjectId('project_stage8k_bundle'),
      stateSchema: StoryStateSchema.empty(),
      modules: [
        StoryModuleIndexEntry(id: moduleA, dependencies: [moduleB]),
        StoryModuleIndexEntry(id: moduleB),
      ],
    ),
  );
}

final class _Fixture {
  const _Fixture({
    required this.moduleA,
    required this.moduleB,
    required this.index,
  });

  final StoryModuleId moduleA;
  final StoryModuleId moduleB;
  final StoryProjectIndex index;
}
