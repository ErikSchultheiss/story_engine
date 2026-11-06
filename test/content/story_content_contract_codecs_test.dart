import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 8L content contract codecs', () {
    test('release manifest round-trips deterministically', () {
      final module = StoryModuleId('module_main');
      final sourceRef = StoryModuleRevisionReference(
        moduleId: module,
        moduleVersion: StoryModuleVersion('1'),
        contentHash: StoryContentHash.fromBytes(const [1]),
      );
      final manifest = StoryContentReleaseManifest(
        releaseId: StoryContentReleaseId('release_2'),
        projectId: StoryProjectId('project_codec'),
        bundleId: StoryContentHash.fromBytes(const [2]),
        modules: [
          StoryContentModuleRevision(
            moduleId: module,
            moduleVersion: StoryModuleVersion('2'),
            contentHash: StoryContentHash.fromBytes(const [3]),
            compatibleSaveSources: [sourceRef],
          ),
        ],
      );
      const codec = StoryContentReleaseManifestCodec();

      final encoded = codec.encode(manifest);
      final decoded = codec.decode(encoded);

      expect(codec.encode(decoded), encoded);
      expect(decoded.releaseId, manifest.releaseId);
      expect(decoded.modules.single.compatibleSaveSources, [sourceRef]);
      expect(encoded, contains('"contract": "open_story.content_release"'));
      expect(encoded.endsWith('\n'), isTrue);
    });

    test('patch manifest remains transport-neutral and deterministic', () {
      final module = StoryModuleId('module_main');
      final source = StoryModuleRevisionReference(
        moduleId: module,
        moduleVersion: StoryModuleVersion('1'),
        contentHash: StoryContentHash.fromBytes(const [1]),
      );
      final target = StoryModuleRevisionReference(
        moduleId: module,
        moduleVersion: StoryModuleVersion('2'),
        contentHash: StoryContentHash.fromBytes(const [2]),
      );
      final manifest = StoryContentPatchManifest(
        projectId: StoryProjectId('project_patch_codec'),
        fromReleaseId: StoryContentReleaseId('release_1'),
        toReleaseId: StoryContentReleaseId('release_2'),
        fromBundleId: StoryContentHash.fromBytes(const [3]),
        toBundleId: StoryContentHash.fromBytes(const [4]),
        operations: [
          StoryContentPatchOperation.replace(source: source, target: target),
        ],
      );
      const codec = StoryContentPatchManifestCodec();

      final encoded = codec.encode(manifest);
      final decoded = codec.decode(encoded);

      expect(codec.encode(decoded), encoded);
      expect(
        decoded.operations.single.kind,
        StoryContentPatchOperationKind.replace,
      );
      expect(encoded, isNot(contains('url')));
      expect(encoded, isNot(contains('cdn')));
    });

    test('save binding round-trips exact module revision identities', () {
      final binding = StorySaveContentBinding(
        projectId: StoryProjectId('project_save_codec'),
        releaseId: StoryContentReleaseId('release_1'),
        bundleId: StoryContentHash.fromBytes(const [1]),
        modules: [
          StoryModuleRevisionReference(
            moduleId: StoryModuleId('module_a'),
            moduleVersion: StoryModuleVersion('7'),
            contentHash: StoryContentHash.fromBytes(const [2]),
          ),
        ],
      );
      const codec = StorySaveContentBindingCodec();

      final decoded = codec.decode(codec.encode(binding));

      expect(decoded.projectId, binding.projectId);
      expect(decoded.releaseId, binding.releaseId);
      expect(decoded.modules, binding.modules);
    });

    test('migration redirects encode in stable source-ID order', () {
      final plan = StoryContentMigrationPlan(
        projectId: StoryProjectId('project_migration_codec'),
        fromReleaseId: StoryContentReleaseId('release_1'),
        toReleaseId: StoryContentReleaseId('release_2'),
        eventRedirects: {
          StoryEventId('evt_z'): StoryEventId('evt_z2'),
          StoryEventId('evt_a'): StoryEventId('evt_a2'),
        },
        choiceRedirects: {
          StoryChoiceId('choice_z'): StoryChoiceId('choice_z2'),
          StoryChoiceId('choice_a'): StoryChoiceId('choice_a2'),
        },
        fallbackEntryPointId: StoryEntryPointId('entry_safe'),
      );
      const codec = StoryContentMigrationPlanCodec();

      final encoded = codec.encode(plan);
      final decoded = codec.decode(encoded);

      expect(codec.encode(decoded), encoded);
      expect(encoded.indexOf('evt_a'), lessThan(encoded.indexOf('evt_z')));
      expect(
        encoded.indexOf('choice_a'),
        lessThan(encoded.indexOf('choice_z')),
      );
      expect(decoded.fallbackEntryPointId, StoryEntryPointId('entry_safe'));
    });

    test('invalid migration identities are reported as format failures', () {
      const codec = StoryContentMigrationPlanCodec();
      const source = '''
{
  "contract": "open_story.content_migration",
  "contractVersion": 1,
  "projectId": "project_codec_bad_id",
  "fromReleaseId": "release_1",
  "toReleaseId": "release_2",
  "eventRedirects": [
    {"from": "invalid id with spaces", "to": "evt_target"}
  ],
  "choiceRedirects": [],
  "fallbackEntryPointId": null
}
''';

      expect(
        () => codec.decode(source),
        throwsA(isA<StoryContentContractFormatException>()),
      );
    });

    test('unknown fields are rejected instead of ignored', () {
      const codec = StorySaveContentBindingCodec();
      const source = '''
{
  "contract": "open_story.save_content_binding",
  "contractVersion": 1,
  "projectId": "project_unknown",
  "releaseId": "release_1",
  "bundleId": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  "modules": [],
  "mystery": true
}
''';

      expect(
        () => codec.decode(source),
        throwsA(isA<StoryContentContractFormatException>()),
      );
    });
  });
}
