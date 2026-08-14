import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('story_engine platform boundary', () {
    test('production library has no Flutter or platform-specific imports', () {
      final violations = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final source = entity.readAsStringSync();
        for (final forbiddenImport in _forbiddenImports) {
          if (forbiddenImport.pattern.hasMatch(source)) {
            violations.add('${entity.path}: ${forbiddenImport.reason}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'story_engine must remain platform-neutral pure Dart.\n'
            '${violations.join('\n')}',
      );
    });

    test('pubspec has no Flutter SDK dependency', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, isNot(contains('sdk: flutter')));
      expect(pubspec, isNot(contains('package:flutter')));
    });
  });
}

final _forbiddenImports = <({RegExp pattern, String reason})>[
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]package:flutter/'''),
    reason: 'Flutter framework dependency',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]dart:ui['"]'''),
    reason: 'dart:ui dependency',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]dart:io['"]'''),
    reason: 'dart:io dependency in the core runtime',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]dart:html['"]'''),
    reason: 'dart:html dependency in the core runtime',
  ),
  (
    pattern: RegExp(r'''(?:import|export)\s+['"]package:shared_preferences/'''),
    reason: 'storage-adapter dependency',
  ),
];
