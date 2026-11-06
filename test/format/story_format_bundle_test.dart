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

    test('both bundle layouts reject Windows-special path segments', () {
      for (final path in const [
        'C:/audit-probe.json',
        'C:audit-probe.json',
        'data.txt:alternate',
        'CON.json',
        'events/NuL .json',
        'events/COM¹.runtime',
        'LPT9/data.json',
        r'CONIN$/data.json',
        'events/name?.json',
        'events/name\u0000.json',
        'events/name\u001f.json',
        'events/folder./data.json',
        'events/folder /data.json',
        'events/ folder/data.json',
      ]) {
        expect(
          () => StoryFormatBundle(files: {path: '{}'}),
          throwsArgumentError,
          reason: path,
        );
        expect(
          StoryRuntimeBundleLayout.isPortablePath(path),
          isFalse,
          reason: path,
        );
      }

      for (final path in [
        StoryFormatBundleLayout.eventPath(StoryEventId('event_portable')),
        StoryRuntimeBundleLayout.modulePath(StoryModuleId('module_portable')),
        'data/CONSOLE.COM1.json',
        'data/café notes.json',
        'data/.hidden',
      ]) {
        expect(StoryFormatBundle(files: {path: '{}'}).contains(path), isTrue);
        expect(StoryRuntimeBundleLayout.isPortablePath(path), isTrue);
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
