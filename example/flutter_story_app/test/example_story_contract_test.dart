import 'package:flutter_test/flutter_test.dart';
import 'package:story_engine/story_engine.dart';
import 'package:story_engine_flutter_example/example_story.dart' as example;

void main() {
  group('Flutter example authored story', () {
    test('validates through the public facade', () {
      final project = example.buildFlutterExampleProject();
      final report = StoryValidator.validate(project);

      expect(report.hasErrors, isFalse, reason: report.format());
      expect(report.hasWarnings, isFalse, reason: report.format());
    });

    test('supports the documented save/restore workflow', () {
      final authoredProject = example.buildFlutterExampleProject();
      const storyFormat = StoryFormatCodec();
      final project = storyFormat.decodeProject(
        storyFormat.encodeProject(authoredProject),
      );
      final engine = StoryEngine(project: project)..start();

      expect(engine.status, StoryEngineStatus.awaitingChoice);
      final choice = engine.availableChoices.singleWhere(
        (candidate) => candidate.id == example.lightLanternId,
      );
      engine.choose(choice.id);

      expect(engine.status, StoryEngineStatus.awaitingContinue);
      expect(engine.currentEvent?.id, example.oldTunnelId);
      expect(engine.state?.rawValueOf(example.lanternLitId), isTrue);

      final snapshotCodec = StoryRuntimeSnapshotCodec();
      final json = snapshotCodec.encodeJson(engine.createSnapshot());
      final expectedSnapshot = engine.createSnapshot();

      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);

      final restored = StoryEngine.restore(
        project: project,
        snapshot: snapshotCodec.decodeJson(json, project: project),
      );
      expect(restored.status, StoryEngineStatus.awaitingContinue);
      expect(restored.currentEvent?.id, example.oldTunnelId);
      expect(restored.state?.rawValueOf(example.lanternLitId), isTrue);
      expect(restored.createSnapshot(), expectedSnapshot);
    });
  });
}
