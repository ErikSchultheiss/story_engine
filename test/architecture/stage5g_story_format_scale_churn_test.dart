import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 5G Story Format scale and Git-churn architecture', () {
    test('scale/churn pressure is a regression contract rather than production API', () {
      final source = File(
        'test/scale/story_format_scale_git_churn_test.dart',
      ).readAsStringSync();
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(source, contains('SyntheticStoryProfile.large'));
      expect(source, contains('1000'));
      expect(source, contains('_changedPaths'));
      expect(source, contains('StoryFormatBundleLayout.organizationPath'));
      expect(barrel, isNot(contains('GitChurn')));
      expect(barrel, isNot(contains('PerformanceBaseline')));
    });

    test('Story Format v1 remains independent from TimeTwirlers', () {
      final formatSources = Directory('lib/src/format')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(formatSources, isNot(contains('TimeTwirlers')));
      expect(formatSources, isNot(contains('timetwirlers')));
      expect(
        Directory('test/fixtures/story_format_v1/timetwirlers').existsSync(),
        isFalse,
      );
    });

    test('Stage 5G does not introduce hard wall-clock promises', () {
      final source = File(
        'test/scale/story_format_scale_git_churn_test.dart',
      ).readAsStringSync();

      expect(source, contains('Stopwatch'));
      expect(source, isNot(contains('elapsedMilliseconds, lessThan')));
      expect(source, isNot(contains('elapsedMicroseconds, lessThan')));
    });
  });
}
