import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeBundleManifestCodec', () {
    test('module path uses canonical lower-case Base32 without padding', () {
      expect(
        StoryRuntimeBundleLayout.modulePath(StoryModuleId('module:one')),
        'modules/nvxwi5lmmu5g63tf.runtime',
      );
    });

    test('canonical manifest round-trips deterministically', () {
      const codec = StoryRuntimeBundleManifestCodec();
      final moduleId = StoryModuleId('module:one');
      final manifest = codec.create(
        projectId: StoryProjectId('project_bundle_manifest'),
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1.0.0-alpha.1',
        indexArtifact: StoryRuntimeArtifactDescriptor(
          path: StoryRuntimeBundleLayout.indexPath,
          contentHash: StoryContentHash.fromBytes(utf8.encode('index')),
          byteLength: 5,
        ),
        modules: [
          StoryRuntimeModuleArtifactDescriptor(
            moduleId: moduleId,
            path: StoryRuntimeBundleLayout.modulePath(moduleId),
            contentHash: StoryContentHash.fromBytes(utf8.encode('module')),
            byteLength: 6,
          ),
        ],
      );

      final encoded = codec.encode(manifest);
      final decoded = codec.decode(encoded);

      expect(codec.encode(decoded), encoded);
      expect(decoded.bundleId, manifest.bundleId);
      expect(decoded.projectId, manifest.projectId);
      expect(decoded.modules.single.moduleId, moduleId);
      expect(encoded.endsWith('\n'), isTrue);
      expect(encoded, contains('"contract": "open_story.runtime_bundle"'));
      expect(encoded, contains('"contractVersion": 1'));
      expect(encoded, contains('"sourceStoryFormatVersion": 1'));
    });

    test('bundle ID mismatch is rejected rather than trusted', () {
      const codec = StoryRuntimeBundleManifestCodec();
      final manifest = codec.create(
        projectId: StoryProjectId('project_tamper'),
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1',
        indexArtifact: StoryRuntimeArtifactDescriptor(
          path: StoryRuntimeBundleLayout.indexPath,
          contentHash: StoryContentHash.fromBytes(const [1]),
          byteLength: 1,
        ),
        modules: const [],
      );
      final encoded = codec.encode(manifest);
      final tampered = encoded.replaceFirst(
        manifest.bundleId.value,
        'sha256:${List<String>.filled(64, '0').join()}',
      );

      expect(
        () => codec.decode(tampered),
        throwsA(isA<StoryRuntimeBundleManifestFormatException>()),
      );
    });

    test('artifact byte lengths stay in the portable integer range', () {
      expect(
        () => StoryRuntimeArtifactDescriptor(
          path: StoryRuntimeBundleLayout.indexPath,
          contentHash: StoryContentHash.fromBytes(const <int>[]),
          byteLength: 9007199254740992,
        ),
        throwsArgumentError,
      );
    });

    test('unknown manifest fields are rejected', () {
      const codec = StoryRuntimeBundleManifestCodec();
      final manifest = codec.create(
        projectId: StoryProjectId('project_unknown_field'),
        buildProfile: 'reference-proof-v1',
        builderId: 'stage8k',
        builderVersion: '1',
        indexArtifact: StoryRuntimeArtifactDescriptor(
          path: StoryRuntimeBundleLayout.indexPath,
          contentHash: StoryContentHash.fromBytes(const <int>[]),
          byteLength: 0,
        ),
        modules: const [],
      );
      final root = jsonDecode(codec.encode(manifest)) as Map<String, dynamic>;
      root['mystery'] = true;

      expect(
        () => codec.decode(jsonEncode(root)),
        throwsA(isA<StoryRuntimeBundleManifestFormatException>()),
      );
    });
  });
}
