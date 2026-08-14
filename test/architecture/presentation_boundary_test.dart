import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('presentation layer does not depend on runtime/domain execution layers', () {
    final violations = <String>[];

    for (final entity in Directory('lib/src/presentation').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final forbidden in const [
        '../condition/',
        '../effect/',
        '../identity/',
        '../model/',
        '../runtime/',
        '../state/',
        '../transition/',
        '../serialization/',
      ]) {
        if (source.contains(forbidden)) {
          violations.add('${entity.path}: imports $forbidden');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Presentation is authored data, not executable runtime logic.\n'
          '${violations.join('\n')}',
    );
  });

  test('runtime implementation does not inspect presentation values directly', () {
    final violations = <String>[];

    for (final entity in Directory('lib/src/runtime').listSync()) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (_presentationImportPattern.hasMatch(source) ||
          RegExp(r'\.presentation\b').hasMatch(source)) {
        violations.add(entity.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Runtime control flow must not depend on presentation content.',
    );
  });
}

final _presentationImportPattern = RegExp(
  r'''(?:import|export)\s+['"][^'"]*presentation/''',
);
