import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../../example/authored_analysis_and_validation.dart'
    as analysis_example;
import '../../example/story_engine_example.dart' as core_example;
import '../../example/story_narrative_modular_host_action_restore_example.dart'
    as restore_example;
import '../../example/story_narrative_shared_state_example.dart'
    as shared_state_example;

void main() {
  group('Stage 9B6 public example CI contract', () {
    test('canonical Pure-Dart example inventory is explicit and stable', () {
      final topLevelDartExamples =
          Directory('example')
              .listSync(followLinks: false)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .map((file) => file.uri.pathSegments.last)
              .toList()
            ..sort();

      expect(topLevelDartExamples, <String>[
        'authored_analysis_and_validation.dart',
        'story_engine_example.dart',
        'story_narrative_modular_host_action_restore_example.dart',
        'story_narrative_shared_state_example.dart',
      ]);
    });

    test('all four canonical Pure-Dart main entry points execute', () async {
      await runZoned<Future<void>>(
        () async {
          analysis_example.main();
          core_example.main();
          shared_state_example.main();
          await restore_example.main();
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {},
        ),
      );
    });

    test('every example uses only the public story_engine package facade', () {
      final dartFiles =
          Directory('example')
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .where((file) {
                final normalized = file.path.replaceAll('\\', '/');
                return !normalized.contains('/.dart_tool/') &&
                    !normalized.contains('/build/');
              })
              .toList()
            ..sort((left, right) => left.path.compareTo(right.path));

      expect(dartFiles, isNotEmpty);

      final storyEngineImport = RegExp(
        r'''import\s+['\"]package:story_engine/([^'\"]+)['\"]''',
      );
      final relativeEngineImport = RegExp(r'''import\s+['\"](?:\.\./)+lib/''');

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        final imports = storyEngineImport.allMatches(source).toList();

        for (final match in imports) {
          expect(
            match.group(1),
            'story_engine.dart',
            reason: '${file.path} must use only the public package facade.',
          );
        }

        expect(
          source,
          isNot(contains('package:story_engine/src/')),
          reason: '${file.path} must not import implementation libraries.',
        );
        expect(
          source,
          isNot(matches(relativeEngineImport)),
          reason: '${file.path} must not reach into the package lib/ tree.',
        );
      }

      for (final path in <String>[
        'example/authored_analysis_and_validation.dart',
        'example/story_engine_example.dart',
        'example/story_narrative_shared_state_example.dart',
        'example/story_narrative_modular_host_action_restore_example.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains("import 'package:story_engine/story_engine.dart';"),
          reason: '$path must demonstrate the supported consumer import.',
        );
      }
    });

    test('public docs expose the continuously tested example set', () {
      final exampleReadme = File('example/README.md').readAsStringSync();
      final integrationPath = File(
        'doc/INTEGRATION_PATH.md',
      ).readAsStringSync();

      for (final token in <String>[
        'authored_analysis_and_validation.dart',
        'story_engine_example.dart',
        'story_narrative_shared_state_example.dart',
        'story_narrative_modular_host_action_restore_example.dart',
        'stage9b6_public_examples_ci_test.dart',
      ]) {
        expect(exampleReadme, contains(token), reason: token);
      }

      expect(integrationPath, contains('Stage 9B6'));
      expect(
        integrationPath,
        contains('all four canonical Pure-Dart examples'),
      );
    });
  });
}
