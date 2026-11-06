import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../example/story_engine_example.dart' as example;

void main() {
  group('Stage 9B2 branching core save/load example', () {
    test('example is deliberately limited to the public core runtime path', () {
      final source = File(
        'example/story_engine_example.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("import 'package:story_engine/story_engine.dart';"),
      );
      expect(source, isNot(contains('package:story_engine/src/')));
      expect(source, isNot(contains('StoryNarrativeRuntime')));
      expect(source, isNot(contains('StoryFormatCodec')));
      expect(source, isNot(contains('package:flutter/')));
      expect(source, isNot(contains('dart:io')));
    });

    test('authored project exposes a real branch and validates cleanly', () {
      final project = example.buildExampleProject();
      final validation = StoryValidator.validate(project);

      expect(validation.hasErrors, isFalse, reason: validation.format());
      expect(validation.hasWarnings, isFalse, reason: validation.format());

      final engine = StoryEngine(project: project)..start();
      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(
        engine.availableChoices.map((choice) => choice.id.value),
        containsAll(<String>['light_lantern', 'leave']),
      );
    });

    test(
      'script follows validate start choose snapshot codec restore continue',
      () {
        final output = <Object?>[];

        example.runExample(log: output.add);
        final text = output.join('\n');

        final validation = text.indexOf('Validation: 0 errors, 0 warnings');
        final firstEvent = text.indexOf('Forest Gate');
        final choice = text.indexOf('Selecting: Light the lantern and enter');
        final checkpoint = text.indexOf('Saved runtime snapshot:');
        final restore = text.indexOf('Restored status: awaitingContinue');
        final finish = text.indexOf('Finished status: terminated');

        expect(validation, greaterThanOrEqualTo(0));
        expect(firstEvent, greaterThan(validation));
        expect(choice, greaterThan(firstEvent));
        expect(checkpoint, greaterThan(choice));
        expect(restore, greaterThan(checkpoint));
        expect(finish, greaterThan(restore));
        expect(text, contains('lantern_lit = true'));
        expect(text, contains('Restored lantern_lit = true'));
      },
    );

    test('encoded checkpoint restores the exact committed core state', () {
      final project = example.buildExampleProject();
      final engine = StoryEngine(project: project)..start();

      engine.choose(StoryChoiceId('light_lantern'));
      final before = engine.createSnapshot();

      final codec = StoryRuntimeSnapshotCodec();
      final encoded = codec.encodeJson(before);
      final decoded = codec.decodeJson(encoded, project: project);
      final restored = StoryEngine.restore(project: project, snapshot: decoded);

      expect(restored.createSnapshot(), before);
      expect(restored.status, StoryEngineStatus.awaitingContinue);
      expect(
        restored.state?.rawValueOf(StoryVariableId('lantern_lit')),
        isTrue,
      );

      restored.continueStory();
      expect(restored.status, StoryEngineStatus.terminated);
    });

    test('documentation keeps Story Format separate from first example', () {
      final exampleReadme = File('example/README.md').readAsStringSync();
      final integrationPath = File(
        'doc/INTEGRATION_PATH.md',
      ).readAsStringSync();
      final readme = File('README.md').readAsStringSync();

      expect(exampleReadme, contains('smallest complete core save/load path'));
      expect(
        exampleReadme,
        contains('Why Story Format is not in this first example'),
      );
      expect(
        exampleReadme,
        contains('Story Format persists **authored project data**'),
      );
      expect(integrationPath, contains('Story Format is kept'));
      expect(
        integrationPath,
        contains('separate from this first runtime example'),
      );
      expect(readme, contains('snapshot JSON encode/decode'));
    });
  });
}
