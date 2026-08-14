import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryFormatBundle', () {
    test('copies files immutably and exposes lookup helpers', () {
      final source = <String, String>{'project.json': '{}\n'};
      final bundle = StoryFormatBundle(files: source);
      source['project.json'] = 'changed';

      expect(bundle.file('project.json'), '{}\n');
      expect(bundle.contains('project.json'), isTrue);
      expect(bundle.contains('missing.json'), isFalse);
      expect(
        () => bundle.files['project.json'] = 'mutate',
        throwsUnsupportedError,
      );
    });

    test('rejects non-portable relative paths', () {
      for (final path in const [
        '',
        '/project.json',
        'folder/',
        r'events\event.json',
        './project.json',
        '../project.json',
        'events/../project.json',
        'events//event.json',
      ]) {
        expect(
          () => StoryFormatBundle(files: {path: '{}\n'}),
          throwsArgumentError,
          reason: path,
        );
      }
    });

    test('equality is based on path/content rather than map identity', () {
      final first = StoryFormatBundle(
        files: const {'project.json': '{}\n', 'events/a.json': '{"id":"a"}\n'},
      );
      final second = StoryFormatBundle(
        files: const {'events/a.json': '{"id":"a"}\n', 'project.json': '{}\n'},
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });
}
