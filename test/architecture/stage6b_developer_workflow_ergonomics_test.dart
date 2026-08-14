import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 6B developer workflow ergonomics', () {
    test('validation is a stateless static facade', () {
      final project = StoryProject(id: StoryProjectId('stage6b_validation'));

      final first = StoryValidator.validate(project);
      final second = StoryValidator.validate(project);

      expect(first.diagnostics, second.diagnostics);
      expect(first.hasErrors, isTrue);
    });

    test('raw scalar convenience preserves concrete story value types', () {
      expect(
        StoryValue.fromRaw(true),
        const StoryBooleanValue(true),
      );
      expect(StoryValue.fromRaw(7), StoryIntegerValue(7));
      expect(StoryValue.fromRaw(7.5), StoryNumberValue(7.5));
      expect(
        StoryValue.fromRaw('seven'),
        const StoryStringValue('seven'),
      );
      expect(() => StoryValue.fromRaw(DateTime(2026)), throwsArgumentError);
    });

    test('Stage 6B does not enlarge the top-level symbol inventory', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final exports = RegExp(
        r'''export\s+['"][^'"]+['"]\s+show\s+([^;]+);''',
        multiLine: true,
      ).allMatches(barrel);
      final symbols = <String>{
        for (final export in exports)
          ...export
              .group(1)!
              .split(',')
              .map((symbol) => symbol.trim())
              .where((symbol) => symbol.isNotEmpty),
      };

      expect(symbols, hasLength(98));
    });
  });
}
