import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Stage 6F Flutter developer example', () {
    test('Flutter app depends downstream on the public package', () {
      final pubspec = File(
        'example/flutter_story_app/pubspec.yaml',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final mainSource = File(
        'example/flutter_story_app/lib/main.dart',
      ).readAsStringSync();
      final storySource = File(
        'example/flutter_story_app/lib/example_story.dart',
      ).readAsStringSync();

      expect(pubspec, contains('story_engine:\n    path: ../..'));
      expect(pubspec, contains('flutter:\n    sdk: flutter'));

      for (final source in <String>[mainSource, storySource]) {
        expect(
          source,
          contains("import 'package:story_engine/story_engine.dart';"),
        );
        expect(source, isNot(contains('package:story_engine/src/')));
      }

      expect(mainSource, contains("import 'package:flutter/material.dart';"));
      expect(storySource, isNot(contains('package:flutter/')));
      expect(storySource, isNot(contains('dart:ui')));
    });

    test('nested executable contracts use the Flutter package boundary', () {
      final storyContractSource = File(
        'example/flutter_story_app/test/example_story_contract_test.dart',
      ).readAsStringSync();
      final widgetTestSource = File(
        'example/flutter_story_app/test/story_player_screen_test.dart',
      ).readAsStringSync();

      expect(
        storyContractSource,
        contains(
          "import 'package:story_engine_flutter_example/example_story.dart' as example;",
        ),
      );
      expect(
        storyContractSource,
        contains("import 'package:story_engine/story_engine.dart';"),
      );
      expect(storyContractSource, isNot(contains("../../lib/")));
      expect(widgetTestSource, contains('StoryEngineExampleApp'));
    });

    test(
      'Flutter UI source demonstrates the intended host responsibilities',
      () {
        final source = File(
          'example/flutter_story_app/lib/main.dart',
        ).readAsStringSync();

        for (final publicWorkflowToken in <String>[
          'StoryFormatCodec()',
          'StoryValidator.validate(_project)',
          'StoryEngine(project: _project)..start()',
          'engine.currentEvent',
          'engine.availableChoices',
          '_engine!.choose(choice.id)',
          '_engine!.continueStory()',
          '_engine!.createSnapshot()',
          '_snapshotCodec.encodeJson(',
          '_snapshotCodec.decodeJson(',
          'StoryEngine.restore(',
        ]) {
          expect(source, contains(publicWorkflowToken));
        }

        expect(source, contains("String? _savedSnapshotJson;"));
        expect(source, isNot(contains('shared_preferences')));
        expect(source, isNot(contains('dart:io')));
      },
    );
  });
}
