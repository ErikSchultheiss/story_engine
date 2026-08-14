import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 4F runtime persistence architecture review', () {
    test('public snapshot compatibility issue vocabulary remains stable', () {
      expect(
        StoryRuntimeSnapshotCompatibilityIssue.values
            .map((issue) => issue.name)
            .toList(),
        const [
          'unsupportedFormatVersion',
          'unsupportedRuntimeContractVersion',
          'projectIdMismatch',
          'stateSchemaMismatch',
          'duplicateProjectEventId',
          'duplicateProjectChoiceId',
          'missingEvent',
          'missingChoice',
          'invalidHistorySequence',
          'historyTransitionMismatch',
          'historyActionModeMismatch',
          'statusEventModeMismatch',
          'unsupportedRandomAlgorithm',
          'unsupportedRandomAlgorithmVersion',
          'invalidRandomState',
        ],
      );
    });

    test('snapshot compatibility axes and RNG identity remain explicit', () {
      final project = _terminalProject('project_stage4_contract');
      final engine = StoryEngine(project: project, randomSeed: 42);
      final snapshot = engine.createSnapshot();

      expect(snapshot.metadata.formatVersion, 1);
      expect(snapshot.metadata.runtimeContractVersion, 1);
      expect(
        StoryRuntimeSnapshotCodec.documentType,
        'story_engine_runtime_snapshot',
      );
      expect(snapshot.randomState.algorithmId, 'story_engine.lcg32');
      expect(snapshot.randomState.algorithmVersion, 1);
      expect(snapshot.randomState.stateWords, hasLength(2));
    });

    test('direct and encoded restore apply the same state compatibility rule', () {
      final firstId = StoryVariableId('var_stage4_first');
      final secondId = StoryVariableId('var_stage4_second');
      final eventId = StoryEventId('event_stage4_state_compat');
      final projectId = StoryProjectId('project_stage4_state_compat');

      final originalSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: firstId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(1),
          ),
          StoryVariableDefinition(
            id: secondId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(true),
          ),
        ],
      );
      final originalProject = StoryProject(
        id: projectId,
        stateSchema: originalSchema,
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );
      final engine = StoryEngine(project: originalProject, randomSeed: 73);
      engine.start();
      final snapshot = engine.createSnapshot();

      final reorderedSchema = StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: secondId,
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
          StoryVariableDefinition(
            id: firstId,
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(99),
          ),
        ],
      );
      final currentProject = StoryProject(
        id: projectId,
        stateSchema: reorderedSchema,
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            continuationTransition: const StoryTerminalTransition(),
          ),
        ],
      );

      final direct = StoryEngine.restore(
        project: currentProject,
        snapshot: snapshot,
      );
      final codec = StoryRuntimeSnapshotCodec();
      final decoded = codec.decodeJson(
        codec.encodeJson(snapshot),
        project: currentProject,
      );
      final encoded = StoryEngine.restore(
        project: currentProject,
        snapshot: decoded,
      );

      expect(direct.createSnapshot(), encoded.createSnapshot());
      expect(direct.state?.schema, same(currentProject.stateSchema));
      expect(encoded.state?.schema, same(currentProject.stateSchema));
    });

    test('engine restore rejects a structurally forged committed history', () {
      final entryId = StoryEventId('event_stage4_forged_entry');
      final expectedId = StoryEventId('event_stage4_expected');
      final forgedId = StoryEventId('event_stage4_forged');
      final choiceId = StoryChoiceId('choice_stage4_expected');
      final project = StoryProject(
        id: StoryProjectId('project_stage4_forged_history'),
        entryEventId: entryId,
        events: [
          StoryEvent(
            id: entryId,
            choices: [
              StoryChoice(
                id: choiceId,
                transition: StoryEventTransition(
                  destinationEventId: expectedId,
                ),
              ),
            ],
          ),
          StoryEvent(
            id: expectedId,
            automaticTransition: const StoryTerminalTransition(),
          ),
          StoryEvent(
            id: forgedId,
            choices: [
              StoryChoice(
                id: StoryChoiceId('choice_stage4_forged_finish'),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.awaitingChoice,
        state: StoryState.initial(project.stateSchema),
        currentEventId: forgedId,
        history: StoryRuntimeHistory(
          steps: [
            StoryEventEnteredStep(eventId: entryId),
            StoryChoiceSelectedStep(eventId: entryId, choiceId: choiceId),
            StoryEventEnteredStep(eventId: forgedId),
          ],
        ),
        randomState: StoryRuntimeRandomState(
          algorithmId: 'story_engine.lcg32',
          algorithmVersion: 1,
          stateWords: const [11, 11],
        ),
        maxAutomaticTransitions: StoryEngine.defaultMaxAutomaticTransitions,
      );

      expect(
        () => StoryEngine.restore(project: project, snapshot: snapshot),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          ),
        ),
      );
    });
  });
}

StoryProject _terminalProject(String projectId) {
  final eventId = StoryEventId('event_stage4_terminal');
  return StoryProject(
    id: StoryProjectId(projectId),
    entryEventId: eventId,
    events: [
      StoryEvent(
        id: eventId,
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );
}
