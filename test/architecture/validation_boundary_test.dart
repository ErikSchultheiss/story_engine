import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 3 validation architecture boundary', () {
    test('validation production code has no runtime/Studio/platform dependency', () {
      final violations = <String>[];

      for (final entity in Directory('lib/src/validation').listSync(
        recursive: true,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final source = entity.readAsStringSync();
        for (final forbidden in _forbiddenDependencies) {
          if (forbidden.pattern.hasMatch(source)) {
            violations.add('${entity.path}: ${forbidden.reason}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Static validation must remain a pure read-only authored-data '
            'layer independent of StoryEngine execution and Studio.\n'
            '${violations.join('\n')}',
      );
    });

    test('StoryValidator does not instantiate or invoke StoryEngine', () {
      final source = File(
        'lib/src/validation/story_validator.dart',
      ).readAsStringSync();

      expect(source, isNot(matches(RegExp(r'\bStoryEngine\s*\('))));
      expect(source, isNot(contains('.start()')));
      expect(source, isNot(contains('.choose(')));
      expect(source, isNot(contains('.continueStory()')));
    });
  });
}

final _forbiddenDependencies = <({RegExp pattern, String reason})>[
  (
    pattern: RegExp(r'''(?:import|export)\s+['"][^'"]*\/runtime\/'''),
    reason: 'runtime execution dependency',
  ),
  (
    pattern: RegExp(
      r'''(?:import|export)\s+['"][^'"]*(?:condition_evaluator|effect_executor|transition_resolver)\.dart['"]''',
    ),
    reason: 'runtime evaluation/execution helper dependency',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"][^'"]*\/serialization\/'''),
    reason: 'serialization adapter dependency',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]package:flutter/'''),
    reason: 'Flutter framework dependency',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]dart:(?:io|ui|html)['"]'''),
    reason: 'platform-specific Dart library dependency',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]package:cyoa_studio/'''),
    reason: 'CYOA Studio dependency',
  ),
];
