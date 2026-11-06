import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  const fixtureRoot = 'conformance/fixtures/runtime-core-v1';
  final fixtureSet = _readJson('$fixtureRoot/fixture-set.json');
  final cases = fixtureSet['cases'] as List<dynamic>;

  group('Stage 8D runtime-core-v1 conformance fixtures', () {
    test('fixture manifest freezes the foundation contract profile', () {
      expect(fixtureSet['formatId'], 'open_story.conformance_fixture_set');
      expect(fixtureSet['formatVersion'], 1);
      expect(fixtureSet['fixtureSetId'], 'runtime-core-v1-foundation');
      expect(fixtureSet['profile'], 'runtime-core-v1');

      final contracts = fixtureSet['contracts'] as Map<String, dynamic>;
      expect(
        contracts['storyFormat'],
        equals(<String, dynamic>{
          'formatId': 'story_engine.story_format',
          'formatVersion': 1,
        }),
      );
      expect(
        contracts['runtimeSemantics'],
        equals(<String, dynamic>{'coreRevision': 1}),
      );
      expect(
        contracts['deterministicRandom'],
        equals(<String, dynamic>{
          'algorithmId': 'story_engine.lcg32',
          'algorithmVersion': 1,
        }),
      );
      expect(cases, hasLength(6));
    });

    test('conformance project is the canonical Story Format v1 golden', () {
      final conformance = _loadBundle(
        '$fixtureRoot/lantern-mystery/project.story',
      );
      final canonical = _loadBundle(
        'test/fixtures/story_format_v1/lantern_mystery',
      );

      expect(conformance, canonical);
      final document = const StoryFormatCodec().decode(conformance);
      expect(StoryValidator.validate(document.project).errors, isEmpty);
    });

    for (final rawCase in cases) {
      final caseDescriptor = rawCase as Map<String, dynamic>;
      final caseId = caseDescriptor['caseId'] as String;

      test('$caseId executes exactly as the language-neutral vector', () {
        final result = _runCase(
          fixtureRoot: fixtureRoot,
          caseDescriptor: caseDescriptor,
        );

        expect(result.actualTrace, result.expectedTrace);
        expect(result.actualFinalState, result.expectedFinalState);
        expect(result.actualHistory, result.expectedHistory);
      });
    }

    test('example report covers every foundation case exactly once', () {
      final report = _readJson('conformance/report-example-v1.json');
      expect(report['formatId'], 'open_story.conformance_report');
      expect(report['formatVersion'], 1);
      expect(report['profile'], fixtureSet['profile']);
      expect(report['fixtureSetId'], fixtureSet['fixtureSetId']);

      final summary = report['summary'] as Map<String, dynamic>;
      final total = summary['total'] as int;
      final passed = summary['passed'] as int;
      final failed = summary['failed'] as int;
      final skipped = summary['skipped'] as int;
      expect(total, passed + failed + skipped);
      expect(total, cases.length);

      final expectedCaseIds = <String>{
        for (final rawCase in cases)
          (rawCase as Map<String, dynamic>)['caseId'] as String,
      };
      final reportResults = report['results'] as List<dynamic>;
      final actualCaseIds = <String>{};

      for (final rawResult in reportResults) {
        final result = rawResult as Map<String, dynamic>;
        final caseId = result['caseId'] as String;
        expect(actualCaseIds.add(caseId), isTrue, reason: caseId);
        expect(result['status'], isIn(<String>['pass', 'fail', 'skipped']));
        expect(result['failures'], isA<List<dynamic>>());
      }

      expect(actualCaseIds, expectedCaseIds);
    });
  });
}

_ConformanceRunResult _runCase({
  required String fixtureRoot,
  required Map<String, dynamic> caseDescriptor,
}) {
  final casePath = "$fixtureRoot/${caseDescriptor['path']}";
  final projectPath = "$fixtureRoot/${caseDescriptor['projectPath']}";
  final project = const StoryFormatCodec().decodeProject(
    _loadBundle(projectPath),
  );

  final initialStateDocument = _readJson('$casePath/initial_state.json');
  final inputTrace = _readJson('$casePath/input_trace.json');
  final expectedTrace = _readJson('$casePath/expected_trace.json');
  final expectedFinalState = _readJson('$casePath/expected_final_state.json');
  final expectedHistory = _readJson('$casePath/expected_history.json');

  final random = inputTrace['random'] as Map<String, dynamic>;
  expect(random['algorithmId'], 'story_engine.lcg32');
  expect(random['algorithmVersion'], 1);
  final engine = StoryEngine(
    project: project,
    randomSeed: random['seed'] as int,
  );

  final initialState = _decodeInitialState(
    initialStateDocument,
    project.stateSchema,
  );
  final inputs = inputTrace['inputs'] as List<dynamic>;
  final observations = <Map<String, dynamic>>[];

  for (var index = 0; index < inputs.length; index++) {
    final input = inputs[index] as Map<String, dynamic>;
    switch (input['kind']) {
      case 'start':
        expect(index, 0, reason: 'start must be the first input');
        engine.start(initialState: initialState);
      case 'choose':
        engine.choose(StoryChoiceId(input['choiceId'] as String));
      case 'continue':
        engine.continueStory();
      default:
        fail("Unknown conformance input kind: ${input['kind']}");
    }

    observations.add(_runtimeObservation(engine, index));
  }

  return _ConformanceRunResult(
    actualTrace: <String, dynamic>{
      'formatId': 'open_story.conformance_expected_trace',
      'formatVersion': 1,
      'observations': observations,
    },
    expectedTrace: expectedTrace,
    actualFinalState: _encodeState(engine.state!, mode: 'explicit'),
    expectedFinalState: expectedFinalState,
    actualHistory: _encodeHistory(engine.history),
    expectedHistory: expectedHistory,
  );
}

StoryState? _decodeInitialState(
  Map<String, dynamic> document,
  StoryStateSchema schema,
) {
  expect(document['formatId'], 'open_story.conformance_state');
  expect(document['formatVersion'], 1);

  switch (document['mode']) {
    case 'projectDefaults':
      return null;
    case 'explicit':
      final rawValues = document['values'] as List<dynamic>;
      expect(rawValues, hasLength(schema.variables.length));
      final values = <StoryVariableId, StoryValue>{};

      for (var index = 0; index < rawValues.length; index++) {
        final entry = rawValues[index] as Map<String, dynamic>;
        final definition = schema.variables[index];
        expect(entry['variableId'], definition.id.value);
        switch (entry['state']) {
          case 'set':
            values[definition.id] = _decodeStoryValue(
              entry['value'] as Map<String, dynamic>,
            );
          case 'unset':
            expect(entry.containsKey('value'), isFalse);
          default:
            fail("Unknown conformance state entry: ${entry['state']}");
        }
      }

      return StoryState.fromValues(schema: schema, values: values);
    default:
      fail("Unknown conformance state mode: ${document['mode']}");
  }
}

StoryValue _decodeStoryValue(Map<String, dynamic> source) =>
    switch (source['type']) {
      'boolean' => StoryBooleanValue(source['value'] as bool),
      'integer' => StoryIntegerValue(source['value'] as int),
      'number' => StoryNumberValue((source['value'] as num).toDouble()),
      'string' => StoryStringValue(source['value'] as String),
      final type => throw StateError('Unknown Story scalar type: $type'),
    };

Map<String, dynamic> _runtimeObservation(StoryEngine engine, int index) =>
    <String, dynamic>{
      'afterInputIndex': index,
      'status': engine.status.name,
      'currentEventId': engine.currentEvent?.id.value,
      'availableChoiceIds': <String>[
        for (final choice in engine.availableChoices) choice.id.value,
      ],
    };

Map<String, dynamic> _encodeState(StoryState state, {required String mode}) =>
    <String, dynamic>{
      'formatId': 'open_story.conformance_state',
      'formatVersion': 1,
      'mode': mode,
      'values': <Map<String, dynamic>>[
        for (final definition in state.schema.variables)
          _encodeStateEntry(state, definition.id),
      ],
    };

Map<String, dynamic> _encodeStateEntry(
  StoryState state,
  StoryVariableId variableId,
) {
  final value = state.valueOf(variableId);
  if (value == null) {
    return <String, dynamic>{'variableId': variableId.value, 'state': 'unset'};
  }

  return <String, dynamic>{
    'variableId': variableId.value,
    'state': 'set',
    'value': <String, dynamic>{
      'type': value.type.name,
      'value': value.rawValue,
    },
  };
}

Map<String, dynamic> _encodeHistory(StoryRuntimeHistory history) =>
    <String, dynamic>{
      'formatId': 'open_story.conformance_history',
      'formatVersion': 1,
      'steps': <Map<String, dynamic>>[
        for (final step in history.steps) _encodeHistoryStep(step),
      ],
    };

Map<String, dynamic> _encodeHistoryStep(StoryRuntimeStep step) {
  if (step is StoryEventEnteredStep) {
    return <String, dynamic>{
      'kind': 'eventEntered',
      'eventId': step.eventId.value,
    };
  }
  if (step is StoryChoiceSelectedStep) {
    return <String, dynamic>{
      'kind': 'choiceSelected',
      'eventId': step.eventId.value,
      'choiceId': step.choiceId.value,
    };
  }
  if (step is StoryEventContinuedStep) {
    return <String, dynamic>{
      'kind': 'eventContinued',
      'eventId': step.eventId.value,
    };
  }
  throw StateError('Unknown runtime history step: ${step.runtimeType}');
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

StoryFormatBundle _loadBundle(String rootPath) {
  final root = Directory(rootPath);
  final files = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  return StoryFormatBundle(
    files: <String, String>{
      for (final file in files)
        file.path.substring(root.path.length + 1).replaceAll('\\', '/'): file
            .readAsStringSync(),
    },
  );
}

final class _ConformanceRunResult {
  const _ConformanceRunResult({
    required this.actualTrace,
    required this.expectedTrace,
    required this.actualFinalState,
    required this.expectedFinalState,
    required this.actualHistory,
    required this.expectedHistory,
  });

  final Map<String, dynamic> actualTrace;
  final Map<String, dynamic> expectedTrace;
  final Map<String, dynamic> actualFinalState;
  final Map<String, dynamic> expectedFinalState;
  final Map<String, dynamic> actualHistory;
  final Map<String, dynamic> expectedHistory;
}
