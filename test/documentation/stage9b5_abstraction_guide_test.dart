import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 9B5 abstraction guide', () {
    test('compact guide covers the approved concept-selection surface', () {
      final guide = File('doc/ABSTRACTION_GUIDE.md').readAsStringSync();

      for (final token in <String>[
        '# story_engine Abstraction Guide',
        'which public abstraction do I need',
        "import 'package:story_engine/story_engine.dart';",
        'StoryProject',
        'StoryFormatDocument',
        'StoryFormatBundle',
        'StoryRuntimeBundle',
        'StoryProjectIndex',
        'StoryNarrativeModule',
        'StoryModuleCache',
        'StoryEntryPoint',
        'StoryNarrativeRuntime',
        'StoryNarrativeSession',
        'StoryHostActionRequest',
        'StoryRuntimeCapabilityProfile',
        'StoryRuntimeCapabilities',
        'StoryContentReleaseManifest',
        'StorySaveContentBinding',
      ]) {
        expect(guide, contains(token), reason: token);
      }

      expect(guide, isNot(contains('package:story_engine/src/')));
    });

    test('guide preserves the important cross-layer distinctions', () {
      final guide = File('doc/ABSTRACTION_GUIDE.md').readAsStringSync();

      for (final token in <String>[
        'Story Format persists authored data',
        'not a portable file/archive format',
        'StoryFormatBundle`** is the logical path-to-JSON-text container',
        'StoryRuntimeBundle`** is different',
        'not a second execution model',
        'entry point is **not** an',
        'active conversation or the current event',
        'Multiple unfinished sessions can',
        'coexist while successful persistent-state commits',
        'restore **does not',
        'redispatch external work',
        'Capabilities answer',
        'content release',
        'does not guess',
        'compatibility from version ordering',
      ]) {
        expect(guide, contains(token), reason: token);
      }
    });

    test(
      'guide links to the existing normative contracts rather than replacing them',
      () {
        final guide = File('doc/ABSTRACTION_GUIDE.md').readAsStringSync();

        for (final path in <String>[
          'INTEGRATION_PATH.md',
          'QUICK_START.md',
          'API_GUIDE.md',
          'STORY_FORMAT_V1.md',
          'RUNTIME_BUNDLE_BUILD_V1.md',
          'MODULAR_PROJECT_LOADING_V1.md',
          'SESSION_EXECUTION_V1.md',
          'HOST_ACTION_PROTOCOL_V1.md',
          'RUNTIME_CAPABILITIES_V1.md',
          'CONTENT_VERSIONING_V1.md',
          'AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md',
        ]) {
          expect(guide, contains(path), reason: path);
        }
      },
    );

    test('all canonical onboarding surfaces expose the abstraction guide', () {
      for (final path in <String>[
        'README.md',
        'doc/QUICK_START.md',
        'doc/INTEGRATION_PATH.md',
        'doc/API_GUIDE.md',
        'example/README.md',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, contains('ABSTRACTION_GUIDE.md'), reason: path);
      }
    });
  });
}
