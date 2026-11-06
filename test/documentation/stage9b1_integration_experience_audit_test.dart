import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 9B1 integration experience audit', () {
    test(
      'canonical integration map exists and orders core before orchestration',
      () {
        final map = File('doc/INTEGRATION_PATH.md').readAsStringSync();

        final quickStart = map.indexOf('Step 1 — Learn the core path');
        final coreExample = map.indexOf(
          'Step 2 — Run the executable core example',
        );
        final authority = map.indexOf('Step 3 — Decide who owns execution');
        final persistence = map.indexOf(
          'Step 4 — Match persistence to the execution authority',
        );
        final hostActionRestore = map.indexOf(
          'Step 5 — Run the suspended-host-action restore example',
        );
        final advanced = map.indexOf(
          'Step 6 — Add only the advanced contracts you use',
        );

        expect(quickStart, greaterThanOrEqualTo(0));
        expect(coreExample, greaterThan(quickStart));
        expect(authority, greaterThan(coreExample));
        expect(persistence, greaterThan(authority));
        expect(hostActionRestore, greaterThan(persistence));
        expect(advanced, greaterThan(hostActionRestore));

        expect(map, contains('StoryEngine'));
        expect(map, contains('StoryRuntimeSnapshot'));
        expect(map, contains('StoryNarrativeRuntime'));
        expect(map, contains('StoryNarrativeRuntimeSnapshot'));
        expect(map, contains('AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md'));
        expect(map, contains('package:story_engine/story_engine.dart'));
        expect(
          RegExp(r'''import\s+['"]package:story_engine/src/''').hasMatch(map),
          isFalse,
        );
      },
    );

    test('README Quick Start and API Guide expose the same canonical path', () {
      final readme = File('README.md').readAsStringSync();
      final quickStart = File('doc/QUICK_START.md').readAsStringSync();
      final apiGuide = File('doc/API_GUIDE.md').readAsStringSync();

      expect(readme, contains('## Start here: canonical integration path'));
      expect(readme, contains('doc/INTEGRATION_PATH.md'));
      expect(
        readme.indexOf('doc/QUICK_START.md'),
        lessThan(readme.indexOf('doc/API_GUIDE.md')),
      );

      expect(
        quickStart,
        contains("first step in the package's canonical integration path"),
      );
      expect(quickStart, contains('INTEGRATION_PATH.md'));
      expect(quickStart, contains('AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md'));
      expect(quickStart, contains('Do not restore retained sessions'));

      expect(apiGuide, contains('## Recommended integration order'));
      expect(apiGuide, contains('INTEGRATION_PATH.md'));
      expect(apiGuide, contains('AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md'));
      expect(
        apiGuide.indexOf('StoryEngine'),
        lessThan(apiGuide.indexOf('StoryNarrativeRuntime')),
      );
    });

    test(
      'current orchestration contract points to Stage 8J and Stage 9A semantics',
      () {
        final orchestration = File(
          'doc/OPEN_WORLD_ORCHESTRATION_V1.md',
        ).readAsStringSync();

        expect(orchestration, contains('**Current integration note:**'));
        expect(orchestration, contains('SESSION_EXECUTION_V1.md'));
        expect(orchestration, contains('AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md'));
        expect(orchestration, contains('NARRATIVE_RUNTIME_PERSISTENCE_V1.md'));
        expect(
          orchestration,
          isNot(contains('Future persistence for the orchestration stream')),
        );
      },
    );
  });
}
