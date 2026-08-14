import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('public repository safety', () {
    test('pubspec identifies the intended public repository and alpha release', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('name: story_engine'));
      expect(pubspec, contains('version: 0.1.0-alpha.1'));
      expect(
        pubspec,
        contains('repository: https://github.com/ErikSchultheiss/story_engine'),
      );
      expect(pubspec, isNot(contains('publish_to: none')));
    });

    test('Git exclusions protect private workspace material', () {
      final ignore = File('.gitignore').readAsStringSync();
      for (final entry in <String>[
        'doc/architecture/',
        'doc/PUBLICATION_CHECKLIST.md',
        'doc/fixtures/',
        'lib/src/README.md',
        'cyoa_studio/',
        'CYOA-Development*/',
        '*.zip',
        '.env',
        '*.jks',
        '*.keystore',
        'key.properties',
        'local.properties',
      ]) {
        expect(ignore, contains(entry), reason: '$entry must remain ignored.');
      }
    });

    test('public-facing package docs do not expose private project names', () {
      final documents = <String>[
        'README.md',
        'CHANGELOG.md',
        'doc/QUICK_START.md',
        'doc/API_GUIDE.md',
        'doc/STORY_FORMAT_V1.md',
        'doc/PERFORMANCE_BASELINES.md',
        'example/README.md',
        'example/flutter_story_app/README.md',
      ];

      for (final path in documents) {
        final text = File(path).readAsStringSync().toLowerCase();
        expect(text, isNot(contains('cyoa studio')), reason: path);
        expect(text, isNot(contains('cyoa_studio')), reason: path);
        expect(text, isNot(contains('timetwirlers')), reason: path);
        expect(text, isNot(contains('time twirlers')), reason: path);
      }
    });
  });
}
