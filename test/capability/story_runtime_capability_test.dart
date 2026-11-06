import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Story runtime capability negotiation', () {
    test('canonicalizes requirements and capabilities by stable identity', () {
      expect(StoryRuntimeFeatureId.runtimeCore.value, 'runtime_core');
      expect(
        StoryRuntimeFeatureId.deterministicRandom.value,
        'deterministic_random',
      );
      expect(StoryRuntimeFeatureId.runtimeBundles.value, 'runtime_bundles');

      final profile = StoryRuntimeCapabilityProfile(
        profileId: 'example_rpg',
        profileVersion: 1,
        requiredFeatures: [
          StoryRuntimeFeatureRequirement(
            featureId: StoryRuntimeFeatureId.modularLoading,
            minimumRevision: 1,
          ),
          StoryRuntimeFeatureRequirement(
            featureId: StoryRuntimeFeatureId.hostActions,
            minimumRevision: 1,
          ),
        ],
        requiredExtensions: [
          StoryExtensionSchemaRequirement(
            namespace: 'com.example.quest',
            minimumSchemaVersion: 1,
          ),
          StoryExtensionSchemaRequirement(
            namespace: 'com.example.combat',
            minimumSchemaVersion: 2,
          ),
        ],
      );

      expect(profile.requiredFeatures.map((entry) => entry.featureId.value), [
        'host_actions',
        'modular_loading',
      ]);
      expect(profile.requiredExtensions.map((entry) => entry.namespace), [
        'com.example.combat',
        'com.example.quest',
      ]);
    });

    test('Dart reference runtime reports the Stage 8 semantic feature set', () {
      final capabilities = StoryRuntimeCapabilities.storyEngineReference(
        runtimeVersion: '0.9.0',
      );

      expect(capabilities.runtimeId, 'story_engine');
      expect(capabilities.features.map((feature) => feature.featureId.value), [
        'content_versioning',
        'deterministic_random',
        'host_actions',
        'modular_loading',
        'narrative_sessions',
        'runtime_bundles',
        'runtime_core',
        'runtime_observability',
      ]);
      expect(
        capabilities.features.every((feature) => feature.revision == 1),
        isTrue,
      );
    });

    test('compatible target reports no issues', () {
      final report = StoryRuntimeCompatibilityEvaluator.evaluate(
        profile: _profile(),
        capabilities: _supportedRuntime(),
      );

      expect(report.isCompatible, isTrue);
      expect(report.issues, isEmpty);
      expect(
        () => StoryRuntimeCompatibilityEvaluator.requireCompatible(
          profile: _profile(),
          capabilities: _supportedRuntime(),
        ),
        returnsNormally,
      );
    });

    test('below-minimum revisions are diagnosed without fallback', () {
      final profile = StoryRuntimeCapabilityProfile(
        profileId: 'minimums',
        profileVersion: 1,
        requiredFeatures: [
          StoryRuntimeFeatureRequirement(
            featureId: StoryRuntimeFeatureId.hostActions,
            minimumRevision: 2,
          ),
        ],
        requiredExtensions: [
          StoryExtensionSchemaRequirement(
            namespace: 'com.example.combat',
            minimumSchemaVersion: 3,
          ),
        ],
      );
      final capabilities = StoryRuntimeCapabilities(
        runtimeId: 'older_runtime',
        runtimeVersion: '100.0.0',
        features: [
          StoryRuntimeFeatureCapability(
            featureId: StoryRuntimeFeatureId.hostActions,
            revision: 1,
          ),
          StoryRuntimeFeatureCapability(
            featureId: StoryRuntimeFeatureId.runtimeCore,
            revision: 99,
          ),
        ],
        extensions: [
          StoryRuntimeExtensionCapability(
            namespace: 'com.example.combat',
            schemaVersion: 2,
          ),
          StoryRuntimeExtensionCapability(
            namespace: 'com.example.unused',
            schemaVersion: 99,
          ),
        ],
      );

      final report = StoryRuntimeCompatibilityEvaluator.evaluate(
        profile: profile,
        capabilities: capabilities,
      );

      expect(report.issues.map((issue) => issue.code), [
        StoryRuntimeCompatibilityIssueCode.featureRevisionBelowMinimum,
        StoryRuntimeCompatibilityIssueCode.extensionVersionBelowMinimum,
      ]);
      expect(report.issues.first.minimumRequired, 2);
      expect(report.issues.first.actual, 1);
      expect(report.issues.last.minimumRequired, 3);
      expect(report.issues.last.actual, 2);
    });

    test('missing and out-of-range capabilities fail deterministically', () {
      final report = StoryRuntimeCompatibilityEvaluator.evaluate(
        profile: _profile(),
        capabilities: StoryRuntimeCapabilities(
          runtimeId: 'limited_runtime',
          runtimeVersion: '99.0.0',
          features: [
            StoryRuntimeFeatureCapability(
              featureId: StoryRuntimeFeatureId.modularLoading,
              revision: 2,
            ),
          ],
          extensions: [
            StoryRuntimeExtensionCapability(
              namespace: 'com.example.combat',
              schemaVersion: 5,
            ),
          ],
        ),
      );

      expect(report.isCompatible, isFalse);
      expect(report.profileVersion, 1);
      expect(report.runtimeVersion, '99.0.0');
      expect(report.issues.first.minimumRequired, 1);
      expect(report.issues.first.actual, isNull);
      expect(
        report.issues.map((issue) => '${issue.code.name}:${issue.subject}'),
        [
          'missingFeature:content_versioning',
          'missingFeature:host_actions',
          'featureRevisionAboveMaximum:modular_loading',
          'extensionVersionAboveMaximum:com.example.combat',
          'missingExtension:com.example.quest',
        ],
      );
      expect(
        () => StoryRuntimeCompatibilityEvaluator.requireCompatible(
          profile: _profile(),
          capabilities: StoryRuntimeCapabilities(
            runtimeId: 'limited_runtime',
            runtimeVersion: '99.0.0',
          ),
        ),
        throwsA(isA<StoryRuntimeCompatibilityException>()),
      );
    });

    test('duplicate identities and invalid ranges are rejected', () {
      expect(
        () => StoryRuntimeCapabilityProfile(
          profileId: 'duplicate_features',
          profileVersion: 1,
          requiredFeatures: [
            StoryRuntimeFeatureRequirement(
              featureId: StoryRuntimeFeatureId.hostActions,
              minimumRevision: 1,
            ),
            StoryRuntimeFeatureRequirement(
              featureId: StoryRuntimeFeatureId.hostActions,
              minimumRevision: 1,
            ),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryExtensionSchemaRequirement(
          namespace: 'com.example.combat',
          minimumSchemaVersion: 3,
          maximumSchemaVersion: 2,
        ),
        throwsArgumentError,
      );
    });
  });
}

StoryRuntimeCapabilityProfile _profile() => StoryRuntimeCapabilityProfile(
  profileId: 'example_rpg',
  profileVersion: 1,
  requiredFeatures: [
    StoryRuntimeFeatureRequirement(
      featureId: StoryRuntimeFeatureId.contentVersioning,
      minimumRevision: 1,
    ),
    StoryRuntimeFeatureRequirement(
      featureId: StoryRuntimeFeatureId.hostActions,
      minimumRevision: 1,
      maximumRevision: 1,
    ),
    StoryRuntimeFeatureRequirement(
      featureId: StoryRuntimeFeatureId.modularLoading,
      minimumRevision: 1,
      maximumRevision: 1,
    ),
  ],
  requiredExtensions: [
    StoryExtensionSchemaRequirement(
      namespace: 'com.example.combat',
      minimumSchemaVersion: 2,
      maximumSchemaVersion: 4,
    ),
    StoryExtensionSchemaRequirement(
      namespace: 'com.example.quest',
      minimumSchemaVersion: 1,
    ),
  ],
);

StoryRuntimeCapabilities _supportedRuntime() => StoryRuntimeCapabilities(
  runtimeId: 'example_runtime',
  runtimeVersion: '2.4.0',
  features: [
    StoryRuntimeFeatureCapability(
      featureId: StoryRuntimeFeatureId.contentVersioning,
      revision: 1,
    ),
    StoryRuntimeFeatureCapability(
      featureId: StoryRuntimeFeatureId.hostActions,
      revision: 1,
    ),
    StoryRuntimeFeatureCapability(
      featureId: StoryRuntimeFeatureId.modularLoading,
      revision: 1,
    ),
  ],
  extensions: [
    StoryRuntimeExtensionCapability(
      namespace: 'com.example.combat',
      schemaVersion: 3,
    ),
    StoryRuntimeExtensionCapability(
      namespace: 'com.example.quest',
      schemaVersion: 2,
    ),
  ],
);
