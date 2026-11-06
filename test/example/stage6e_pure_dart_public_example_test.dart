import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../example/story_engine_example.dart' as example;

void main() {
  group('Stage 6E Pure-Dart public example', () {
    test('source stays on the public Pure-Dart package boundary', () {
      final source = File(
        'example/story_engine_example.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("import 'package:story_engine/story_engine.dart';"),
      );
      expect(source, isNot(contains('package:story_engine/src/')));
      expect(source, isNot(contains('package:flutter/')));
      expect(source, isNot(contains('dart:ui')));
      expect(source, isNot(contains('package:test/')));
    });

    test('authored example validates cleanly through the public facade', () {
      final project = example.buildExampleProject();
      final report = StoryValidator.validate(project);

      expect(report.hasErrors, isFalse, reason: report.format());
      expect(report.hasWarnings, isFalse, reason: report.format());
    });

    test(
      'scripted example covers validate, play, save, restore, and finish',
      () {
        final output = <Object?>[];

        example.runExample(log: output.add);

        final text = output.join('\n');
        expect(text, contains('Validation: 0 errors, 0 warnings'));
        expect(text, contains('Forest Gate'));
        expect(text, contains('Selecting: Light the lantern and enter'));
        expect(text, contains('lantern_lit = true'));
        expect(text, contains('Old Tunnel'));
        expect(text, contains('Saved runtime snapshot:'));
        expect(text, contains('Restored status: awaitingContinue'));
        expect(text, contains('Finished status: terminated'));
      },
    );

    test('snapshot restore remains a committed-state boundary', () {
      final project = example.buildExampleProject();
      final report = StoryValidator.validate(project);
      expect(report.hasErrors, isFalse, reason: report.format());

      final engine = StoryEngine(project: project)..start();
      final choice = engine.availableChoices.singleWhere(
        (candidate) => candidate.id == StoryChoiceId('light_lantern'),
      );
      engine.choose(choice.id);

      final codec = StoryRuntimeSnapshotCodec();
      final json = codec.encodeJson(engine.createSnapshot());
      final restored = StoryEngine.restore(
        project: project,
        snapshot: codec.decodeJson(json, project: project),
      );

      expect(restored.status, StoryEngineStatus.awaitingContinue);
      expect(
        restored.state?.rawValueOf(StoryVariableId('lantern_lit')),
        isTrue,
      );
      expect(restored.createSnapshot(), engine.createSnapshot());
      restored.continueStory();
      expect(restored.status, StoryEngineStatus.terminated);
    });
  });
}
