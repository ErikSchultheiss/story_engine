import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 6B developer workflow', () {
    test('runtime-only format load, validation, play, save, and restore compose', () {
      final trustId = StoryVariableId('trust');
      final startId = StoryEventId('start');
      final leaveId = StoryChoiceId('leave');
      final project = StoryProject(
        id: StoryProjectId('stage6b_workflow'),
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: trustId,
              type: StoryValueType.integer,
            ),
          ],
        ),
        entryEventId: startId,
        events: [
          StoryEvent(
            id: startId,
            choices: [
              StoryChoice(
                id: leaveId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );

      const formatCodec = StoryFormatCodec();
      final bundle = formatCodec.encodeProject(project);
      final loadedProject = formatCodec.decodeProject(bundle);
      final validation = StoryValidator.validate(loadedProject);

      expect(validation.isValid, isTrue);

      final initialState = StoryState.fromRawValues(
        schema: loadedProject.stateSchema,
        values: {trustId: 60},
      );
      final engine = StoryEngine(project: loadedProject)
        ..start(initialState: initialState);

      expect(engine.randomSeed, StoryEngine.defaultRandomSeed);
      expect(engine.state?.rawValueOf(trustId), 60);
      expect(engine.availableChoices.single.id, leaveId);

      final snapshotCodec = StoryRuntimeSnapshotCodec();
      final savedJson = snapshotCodec.encodeJson(engine.createSnapshot());
      final decodedSnapshot = snapshotCodec.decodeJson(
        savedJson,
        project: loadedProject,
      );
      final restored = StoryEngine.restore(
        project: loadedProject,
        snapshot: decodedSnapshot,
      );

      expect(restored.createSnapshot(), engine.createSnapshot());
      restored.choose(leaveId);
      expect(restored.status, StoryEngineStatus.terminated);
    });

    test('explicit random seeds remain available for deliberate variation', () {
      final eventId = StoryEventId('start_seeded');
      final project = StoryProject(
        id: StoryProjectId('stage6b_seeded'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            automaticTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final defaultEngine = StoryEngine(project: project);
      final seededEngine = StoryEngine(project: project, randomSeed: 12345);

      expect(StoryEngine.defaultRandomSeed, 0);
      expect(defaultEngine.randomSeed, 0);
      expect(seededEngine.randomSeed, 12345);
    });
  });
}
