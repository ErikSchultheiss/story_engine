import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryRuntimeSnapshotCodec', () {
    final codec = StoryRuntimeSnapshotCodec();

    test('emits the canonical deterministic format-v1 document shape', () {
      final fixture = _fixture();

      expect(codec.encode(fixture.snapshot), <String, Object?>{
        'documentType': 'story_engine_runtime_snapshot',
        'formatVersion': 1,
        'runtimeContractVersion': 1,
        'projectId': 'project_snapshot_codec',
        'status': 'awaitingContinue',
        'state': <String, Object?>{
          'values': <Object?>[
            <String, Object?>{
              'variableId': 'var_bool',
              'value': <String, Object?>{'type': 'boolean', 'value': false},
            },
            <String, Object?>{
              'variableId': 'var_int',
              'value': <String, Object?>{'type': 'integer', 'value': 9},
            },
            <String, Object?>{
              'variableId': 'var_number',
              'value': <String, Object?>{'type': 'number', 'value': 3.75},
            },
            <String, Object?>{
              'variableId': 'var_string',
              'value': <String, Object?>{'type': 'string', 'value': 'restored'},
            },
          ],
        },
        'currentEventId': 'event_continue',
        'history': <String, Object?>{
          'steps': <Object?>[
            <String, Object?>{
              'type': 'event_entered',
              'eventId': 'event_start',
            },
            <String, Object?>{
              'type': 'choice_selected',
              'eventId': 'event_start',
              'choiceId': 'choice_continue',
            },
            <String, Object?>{
              'type': 'event_entered',
              'eventId': 'event_continue',
            },
          ],
        },
        'randomState': <String, Object?>{
          'algorithmId': 'story_engine.lcg32',
          'algorithmVersion': 1,
          'stateWords': <int>[1, 2],
        },
        'maxAutomaticTransitions': 27,
      });
    });

    test('round-trips all scalar values and canonical history exactly', () {
      final fixture = _fixture();
      final snapshot = fixture.snapshot;

      final encoded = codec.encode(snapshot);
      final decoded = codec.decode(encoded, project: fixture.project);

      expect(decoded, snapshot);
      expect(decoded.history, snapshot.history);
      expect(decoded.state, snapshot.state);
      expect(decoded.randomState, snapshot.randomState);
    });

    test('compact JSON encoding is deterministic', () {
      final fixture = _fixture();

      final first = codec.encodeJson(fixture.snapshot);
      final second = codec.encodeJson(fixture.snapshot);

      expect(second, first);
      expect(
        codec.decodeJson(first, project: fixture.project),
        fixture.snapshot,
      );
    });

    test('encoded state stores values without duplicating authored schema', () {
      final encoded = codec.encode(_fixture().snapshot);
      final state = encoded['state']! as Map<String, Object?>;

      expect(state.keys, ['values']);
      expect(state, isNot(contains('schema')));
      expect(state, isNot(contains('variables')));
    });

    test('round-trips a committed not-started snapshot', () {
      final project = _notStartedProject();
      final snapshot = StoryRuntimeSnapshot(
        projectId: project.id,
        status: StoryEngineStatus.notStarted,
        state: null,
        currentEventId: null,
        history: StoryRuntimeHistory(),
        randomState: _randomState(),
        maxAutomaticTransitions: 19,
      );

      expect(codec.decode(codec.encode(snapshot), project: project), snapshot);
    });

    test('rejects invalid JSON as malformed snapshot data', () {
      expect(
        () => codec.decodeJson('{broken', project: _notStartedProject()),
        throwsA(
          isA<StoryRuntimeSnapshotFormatException>()
              .having((error) => error.path, 'path', r'$')
              .having(
                (error) => error.message,
                'message',
                contains('not valid JSON'),
              ),
        ),
      );
    });

    test('rejects unknown fields instead of silently discarding them', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['futureField'] = true;

      expect(
        () => codec.decode(encoded, project: fixture.project),
        throwsA(
          isA<StoryRuntimeSnapshotFormatException>().having(
            (error) => error.path,
            'path',
            r'$.futureField',
          ),
        ),
      );
    });

    test('rejects malformed lifecycle tokens', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['status'] = 'sleeping';

      expect(
        () => codec.decode(encoded, project: fixture.project),
        throwsA(
          isA<StoryRuntimeSnapshotFormatException>().having(
            (error) => error.path,
            'path',
            r'$.status',
          ),
        ),
      );
    });

    test('rejects duplicate persisted state variable entries', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final state = encoded['state']! as Map<String, Object?>;
      final values = state['values']! as List<Object?>;
      values.add(
        Map<String, Object?>.of(values.first! as Map<String, Object?>),
      );

      expect(
        () => codec.decode(encoded, project: fixture.project),
        throwsA(
          isA<StoryRuntimeSnapshotFormatException>().having(
            (error) => error.message,
            'message',
            contains('duplicate variable ID'),
          ),
        ),
      );
    });

    test('rejects a newer snapshot format as incompatible', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['formatVersion'] =
          StoryRuntimeSnapshotMetadata.currentFormatVersion + 1;

      expect(
        () => codec.decode(encoded, project: fixture.project),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion,
          ),
        ),
      );
    });

    test('rejects an unsupported runtime contract as incompatible', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      encoded['runtimeContractVersion'] =
          StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion + 1;

      expect(
        () => codec.decode(encoded, project: fixture.project),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue
                .unsupportedRuntimeContractVersion,
          ),
        ),
      );
    });

    test('rejects a snapshot from another project before decoding state', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final other = StoryProject(
        id: StoryProjectId('project_other'),
        stateSchema: StoryStateSchema.empty(),
      );

      expect(
        () => codec.decode(encoded, project: other),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
          ),
        ),
      );
    });

    test('rejects persisted state whose variable type no longer matches', () {
      final fixture = _fixture();
      final encoded = codec.encode(fixture.snapshot);
      final changedProject = _fixture(
        integerType: StoryValueType.number,
      ).project;

      expect(
        () => codec.decode(encoded, project: changedProject),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.stateSchemaMismatch,
          ),
        ),
      );
    });

    test(
      'JSON representation uses stable top-level compatibility metadata',
      () {
        final encoded =
            jsonDecode(codec.encodeJson(_fixture().snapshot))
                as Map<String, Object?>;

        expect(encoded['documentType'], StoryRuntimeSnapshotCodec.documentType);
        expect(
          encoded['formatVersion'],
          StoryRuntimeSnapshotMetadata.currentFormatVersion,
        );
        expect(
          encoded['runtimeContractVersion'],
          StoryRuntimeSnapshotMetadata.currentRuntimeContractVersion,
        );
      },
    );
  });
}

({StoryProject project, StoryRuntimeSnapshot snapshot}) _fixture({
  StoryValueType integerType = StoryValueType.integer,
}) {
  final boolId = StoryVariableId('var_bool');
  final intId = StoryVariableId('var_int');
  final numberId = StoryVariableId('var_number');
  final stringId = StoryVariableId('var_string');
  final startId = StoryEventId('event_start');
  final continueId = StoryEventId('event_continue');
  final choiceId = StoryChoiceId('choice_continue');

  final schema = StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: boolId,
        type: StoryValueType.boolean,
        initialValue: const StoryBooleanValue(true),
      ),
      StoryVariableDefinition(
        id: intId,
        type: integerType,
        initialValue: integerType == StoryValueType.integer
            ? StoryIntegerValue(7)
            : StoryNumberValue(7.0),
      ),
      StoryVariableDefinition(
        id: numberId,
        type: StoryValueType.number,
        initialValue: StoryNumberValue(2.5),
      ),
      StoryVariableDefinition(
        id: stringId,
        type: StoryValueType.string,
        initialValue: const StoryStringValue('lantern'),
      ),
    ],
  );
  final project = StoryProject(
    id: StoryProjectId('project_snapshot_codec'),
    stateSchema: schema,
    entryEventId: startId,
    events: [
      StoryEvent(
        id: startId,
        choices: [
          StoryChoice(
            id: choiceId,
            transition: StoryEventTransition(destinationEventId: continueId),
          ),
        ],
      ),
      StoryEvent(
        id: continueId,
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );

  final values = <StoryVariableId, StoryValue>{
    boolId: const StoryBooleanValue(false),
    intId: integerType == StoryValueType.integer
        ? StoryIntegerValue(9)
        : StoryNumberValue(9.0),
    numberId: StoryNumberValue(3.75),
    stringId: const StoryStringValue('restored'),
  };

  return (
    project: project,
    snapshot: StoryRuntimeSnapshot(
      projectId: project.id,
      status: StoryEngineStatus.awaitingContinue,
      state: StoryState.fromValues(schema: schema, values: values),
      currentEventId: continueId,
      history: StoryRuntimeHistory(
        steps: [
          StoryEventEnteredStep(eventId: startId),
          StoryChoiceSelectedStep(eventId: startId, choiceId: choiceId),
          StoryEventEnteredStep(eventId: continueId),
        ],
      ),
      randomState: _randomState(),
      maxAutomaticTransitions: 27,
    ),
  );
}

StoryProject _notStartedProject() => StoryProject(
  id: StoryProjectId('project_not_started_codec'),
  entryEventId: StoryEventId('event_start'),
  events: [
    StoryEvent(
      id: StoryEventId('event_start'),
      automaticTransition: const StoryTerminalTransition(),
    ),
  ],
);

StoryRuntimeRandomState _randomState() => StoryRuntimeRandomState(
  algorithmId: 'story_engine.lcg32',
  algorithmVersion: 1,
  stateWords: const [1, 2],
);
