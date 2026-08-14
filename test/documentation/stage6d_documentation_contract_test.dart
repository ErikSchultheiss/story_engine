import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 6D package documentation contract', () {
    test('consumer docs use only the supported package import boundary', () {
      final documents = <String, String>{
        'README.md': File('README.md').readAsStringSync(),
        'doc/QUICK_START.md': File('doc/QUICK_START.md').readAsStringSync(),
        'doc/API_GUIDE.md': File('doc/API_GUIDE.md').readAsStringSync(),
      };

      for (final entry in documents.entries) {
        expect(
          entry.value,
          contains("import 'package:story_engine/story_engine.dart';"),
          reason: '${entry.key} should demonstrate the supported root import.',
        );
        expect(
          RegExp(
            r'''import\s+['"]package:story_engine/src/''',
          ).hasMatch(entry.value),
          isFalse,
          reason: '${entry.key} must not demonstrate a direct src import.',
        );
      }
    });

    test('README is a consumer landing page with durable next-step links', () {
      final readme = File('README.md').readAsStringSync();

      expect(readme, contains('## Quick start'));
      expect(readme, contains('doc/QUICK_START.md'));
      expect(readme, contains('doc/API_GUIDE.md'));
      expect(readme, contains('doc/STORY_FORMAT_V1.md'));
      expect(readme, contains('## Save and restore'));
      expect(readme, contains('## Error handling'));
      expect(readme, isNot(contains('Stage 6D next')));
    });

    test('API guide indexes the exact symbol-pinned public inventory', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final barrelSymbols = <String>{
        for (final match in RegExp(
          r'''export\s+['"][^'"]+['"]\s+show\s+([^;]+);''',
          multiLine: true,
        ).allMatches(barrel))
          ...match
              .group(1)!
              .split(',')
              .map((symbol) => symbol.trim())
              .where((symbol) => symbol.isNotEmpty),
      };

      final guide = File('doc/API_GUIDE.md').readAsStringSync();
      final start = guide.indexOf('<!-- PUBLIC_API_INDEX_START -->');
      final end = guide.indexOf('<!-- PUBLIC_API_INDEX_END -->');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final index = guide.substring(start, end);
      final indexedSymbols = <String>{
        for (final match in RegExp(
          r'^- `([A-Za-z][A-Za-z0-9_]*)`$',
          multiLine: true,
        ).allMatches(index))
          match.group(1)!,
      };

      expect(barrelSymbols, hasLength(98));
      expect(indexedSymbols, barrelSymbols);
    });

    test('every exported top-level declaration retains Dartdoc', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final exportPattern = RegExp(
        r'''export\s+['"]([^'"]+)['"]\s+show\s+([^;]+);''',
        multiLine: true,
      );

      for (final export in exportPattern.allMatches(barrel)) {
        final sourcePath = 'lib/${export.group(1)!}';
        final source = File(sourcePath).readAsStringSync();
        final symbols = export
            .group(2)!
            .split(',')
            .map((symbol) => symbol.trim())
            .where((symbol) => symbol.isNotEmpty);

        for (final symbol in symbols) {
          final declaration = RegExp(
            '(?:^|\\n)(?:///[^\\n]*\\n)+(?:abstract final |sealed |final |abstract )?'
            '(?:class|enum|typedef)\\s+${RegExp.escape(symbol)}\\b',
            multiLine: true,
          );
          expect(
            declaration.hasMatch(source),
            isTrue,
            reason: '$symbol in $sourcePath must retain top-level Dartdoc.',
          );
        }
      }
    });

    test('documented minimal happy path is executable through public API', () {
      final startId = StoryEventId('start');
      final leaveId = StoryChoiceId('leave');
      final project = StoryProject(
        id: StoryProjectId('tiny_adventure'),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            presentation: StoryEventPresentation(
              body: const StoryText('You stand at the forest gate.'),
            ),
            choices: [
              StoryChoice(
                id: leaveId,
                presentation: const StoryChoicePresentation(
                  text: StoryText('Turn back'),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      final report = StoryValidator.validate(project);
      expect(report.hasErrors, isFalse, reason: report.format());

      final engine = StoryEngine(project: project)..start();
      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(engine.availableChoices.single.id, leaveId);
      engine.choose(leaveId);
      expect(engine.status, StoryEngineStatus.terminated);
    });
  });
}
