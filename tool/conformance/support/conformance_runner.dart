import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';

/// Execute one portable corpus and return a Revision 1 conformance report.
/// This is tooling, not part of the runtime package's public API.
Map<String, Object?> runFixtureSet(String manifestPath) {
  final manifestFile = File(manifestPath);
  final manifest = _readJson(manifestPath);
  _require(manifest['formatId'], 'open_story.conformance_fixture_set');
  _require(manifest['formatVersion'], 1);
  final fixtureSetId = manifest['fixtureSetId'];
  if (fixtureSetId is! String || fixtureSetId.isEmpty) {
    throw const FormatException('A conformance set must have an identity.');
  }
  final profile = manifest['profile'] as String;
  final cases = manifest['cases'] as List<dynamic>;
  if (cases.isEmpty) {
    throw const FormatException('A conformance set must contain cases.');
  }
  final ids = <String>{};
  for (final raw in cases) {
    final id = (raw as Map<String, dynamic>)['caseId'] as String;
    if (id.isEmpty || !ids.add(id)) {
      throw FormatException('Duplicate/empty conformance case ID: $id');
    }
  }
  final unsupported = <Map<String, Object?>>[];
  if (profile != 'runtime-core-v1' && profile != 'runtime-finalization-v1') {
    unsupported.add({
      'kind': 'unsupportedContract',
      'path': r'$.profile',
      'actual': profile,
      'message':
          'Supported profiles are runtime-core-v1 and runtime-finalization-v1.',
    });
  }
  final requiredContracts = <String, Map<String, Object>>{
    'storyFormat': {
      'formatId': 'story_engine.story_format',
      'formatVersion': 1,
    },
    'runtimeSemantics': {'coreRevision': 1},
    'deterministicRandom': {
      'algorithmId': 'story_engine.lcg32',
      'algorithmVersion': 1,
    },
  };
  for (final requirement in requiredContracts.entries) {
    final actual = manifest['contracts']?[requirement.key];
    if (!_equal(actual, requirement.value)) {
      unsupported.add({
        'kind': 'unsupportedContract',
        'path': '\$.contracts.${requirement.key}',
        'expected': requirement.value,
        'actual': actual,
        'message': 'Unsupported declared ${requirement.key} contract.',
      });
    }
  }
  final results = <Map<String, Object?>>[];
  for (final raw in cases) {
    final descriptor = raw as Map<String, dynamic>;
    final failures = <Map<String, Object?>>[];
    var status = 'pass';
    if (unsupported.isNotEmpty) {
      status = 'skipped';
      failures.addAll(unsupported);
    } else {
      try {
        if (profile == 'runtime-core-v1') {
          final result = _runFoundationCase(
            fixtureRoot: manifestFile.parent.path,
            caseDescriptor: descriptor,
          );
          _compare(
            result.expectedTrace,
            result.actualTrace,
            'traceMismatch',
            failures,
          );
          _compare(
            result.expectedFinalState,
            result.actualFinalState,
            'finalStateMismatch',
            failures,
          );
          _compare(
            result.expectedHistory,
            result.actualHistory,
            'historyMismatch',
            failures,
          );
        } else {
          final casePath = _fixturePath(
            manifestFile.parent.path,
            descriptor['path'] as String,
          );
          final expected = _readJson('$casePath/expected_trace.json');
          final actual = _runHardeningCase(
            manifestFile.parent.path,
            descriptor,
          );
          _compare(expected, actual, 'traceMismatch', failures);
        }
      } on _CaseFailure catch (error) {
        failures.add({'kind': error.kind, 'message': error.message});
      } catch (error) {
        failures.add({'kind': 'runnerFailure', 'message': '$error'});
      }
      if (failures.isNotEmpty) status = 'fail';
    }
    results.add({
      'caseId': descriptor['caseId'],
      'status': status,
      'failures': failures,
    });
  }
  return {
    'formatId': 'open_story.conformance_report',
    'formatVersion': 1,
    'profile': profile,
    'fixtureSetId': fixtureSetId,
    'implementation': {
      'name': 'story_engine Dart reference',
      'version': '0.9.0',
      'language': 'Dart',
      'runtimeSemantics': {'coreRevision': 1},
      'randomProfiles': [
        {'algorithmId': 'story_engine.lcg32', 'algorithmVersion': 1},
      ],
    },
    'summary': {
      'total': results.length,
      'passed': results.where((r) => r['status'] == 'pass').length,
      'failed': results.where((r) => r['status'] == 'fail').length,
      'skipped': results.where((r) => r['status'] == 'skipped').length,
    },
    'results': results,
  };
}

final class _CaseFailure implements Exception {
  const _CaseFailure(this.kind, this.message);
  final String kind;
  final String message;
}

void _require(Object? actual, Object? expected, {String? reason}) {
  if (!_equal(actual, expected)) {
    throw FormatException(reason ?? 'Expected $expected; found $actual');
  }
}

bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (n) => n).every((n) => _equal(a[n], b[n]));
  }
  return a == b;
}

void _compare(
  Object? expected,
  Object? actual,
  String kind,
  List<Map<String, Object?>> failures,
) {
  final difference = _difference(expected, actual, r'$');
  if (difference != null) {
    failures.add({
      'kind': kind,
      ...difference,
      'message': 'Observed data differs from the committed fixture.',
    });
  }
}

Map<String, Object?>? _difference(
  Object? expected,
  Object? actual,
  String path,
) {
  if (_equal(expected, actual)) return null;
  if (expected is Map &&
      actual is Map &&
      expected.keys.toSet().containsAll(actual.keys) &&
      actual.keys.toSet().containsAll(expected.keys)) {
    for (final key in expected.keys) {
      final result = _difference(expected[key], actual[key], '$path.$key');
      if (result != null) return result;
    }
  }
  if (expected is List && actual is List && expected.length == actual.length) {
    for (var n = 0; n < expected.length; n++) {
      final result = _difference(expected[n], actual[n], '$path[$n]');
      if (result != null) return result;
    }
  }
  return {'path': path, 'expected': expected, 'actual': actual};
}

String _fixturePath(String root, String relative) {
  if (relative.isEmpty ||
      relative.startsWith('/') ||
      relative.contains('\\') ||
      relative.contains(':') ||
      relative.split('/').any((p) => p.isEmpty || p == '.' || p == '..')) {
    throw FormatException(
      'Fixture path must stay below its manifest directory: $relative',
    );
  }
  final path = '$root/$relative';
  // Do not follow a fixture symlink outside the explicitly selected corpus.
  final entity = FileSystemEntity.typeSync(path);
  if (entity != FileSystemEntityType.notFound) {
    final resolvedRoot = Directory(root).resolveSymbolicLinksSync();
    final resolved = entity == FileSystemEntityType.directory
        ? Directory(path).resolveSymbolicLinksSync()
        : File(path).resolveSymbolicLinksSync();
    if (!resolved.startsWith('$resolvedRoot${Platform.pathSeparator}')) {
      throw const FormatException(
        'Fixture path resolves outside its manifest directory.',
      );
    }
  }
  return path;
}

StoryProject _loadProject(String root, Map<String, dynamic> descriptor) {
  try {
    return const StoryFormatCodec().decodeProject(
      _loadBundle(_fixturePath(root, descriptor['projectPath'] as String)),
    );
  } catch (error) {
    throw _CaseFailure('projectLoadFailure', '$error');
  }
}

_ConformanceRunResult _runFoundationCase({
  required String fixtureRoot,
  required Map<String, dynamic> caseDescriptor,
}) {
  final casePath = _fixturePath(fixtureRoot, caseDescriptor['path'] as String);
  final project = _loadProject(fixtureRoot, caseDescriptor);

  final initialStateDocument = _readJson('$casePath/initial_state.json');
  final inputTrace = _readJson('$casePath/input_trace.json');
  final expectedTrace = _readJson('$casePath/expected_trace.json');
  final expectedFinalState = _readJson('$casePath/expected_final_state.json');
  final expectedHistory = _readJson('$casePath/expected_history.json');

  final random = inputTrace['random'] as Map<String, dynamic>;
  _require(random['algorithmId'], 'story_engine.lcg32');
  _require(random['algorithmVersion'], 1);
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
    try {
      switch (input['kind']) {
        case 'start':
          _require(index, 0, reason: 'start must be the first input');
          engine.start(initialState: initialState);
        case 'choose':
          engine.choose(StoryChoiceId(input['choiceId'] as String));
        case 'continue':
          engine.continueStory();
        default:
          throw FormatException(
            "Unknown conformance input kind: ${input['kind']}",
          );
      }
    } on StoryEngineException catch (error) {
      throw _CaseFailure('inputFailure', 'Input $index: $error');
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
  _require(document['formatId'], 'open_story.conformance_state');
  _require(document['formatVersion'], 1);

  switch (document['mode']) {
    case 'projectDefaults':
      return null;
    case 'explicit':
      final rawValues = document['values'] as List<dynamic>;
      _require(rawValues.length, schema.variables.length);
      final values = <StoryVariableId, StoryValue>{};

      for (var index = 0; index < rawValues.length; index++) {
        final entry = rawValues[index] as Map<String, dynamic>;
        final definition = schema.variables[index];
        _require(entry['variableId'], definition.id.value);
        switch (entry['state']) {
          case 'set':
            values[definition.id] = _decodeStoryValue(
              entry['value'] as Map<String, dynamic>,
            );
          case 'unset':
            _require(entry.containsKey('value'), false);
          default:
            throw FormatException(
              "Unknown conformance state entry: ${entry['state']}",
            );
        }
      }

      return StoryState.fromValues(schema: schema, values: values);
    default:
      throw FormatException(
        "Unknown conformance state mode: ${document['mode']}",
      );
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

Map<String, Object?> _runHardeningCase(
  String root,
  Map<String, dynamic> descriptor,
) {
  final project = _loadProject(root, descriptor);
  final path = _fixturePath(root, descriptor['path'] as String);
  final trace = _readJson('$path/input_trace.json');
  _require(trace['formatId'], 'open_story.conformance_hardening_input_trace');
  _require(trace['formatVersion'], 1);
  final random = trace['random'] as Map<String, dynamic>;
  _require(random['algorithmId'], 'story_engine.lcg32');
  _require(random['algorithmVersion'], 1);
  final seed = random['seed'] as int;
  final guard = trace['maxAutomaticTransitions'] as int;
  final inputs = trace['inputs'] as List<dynamic>;
  if (inputs.isEmpty) {
    throw const FormatException('Hardening trace has no inputs.');
  }
  final observations = <Map<String, Object?>>[];
  if (trace['runtime'] == 'core') {
    var engine = StoryEngine(
      project: project,
      randomSeed: seed,
      maxAutomaticTransitions: guard,
    );
    final codec = StoryRuntimeSnapshotCodec();
    for (var n = 0; n < inputs.length; n++) {
      final input = inputs[n] as Map<String, dynamic>;
      final before = codec.encodeJson(engine.createSnapshot());
      String? error;
      try {
        switch (input['kind']) {
          case 'start':
            engine.start();
          case 'startAt':
            engine.startAt(StoryEventId(input['eventId'] as String));
          case 'choose':
            engine.choose(StoryChoiceId(input['choiceId'] as String));
          case 'continue':
            engine.continueStory();
          case 'restore':
            final decoded = codec.decodeJson(before, project: project);
            engine = StoryEngine.restore(project: project, snapshot: decoded);
          default:
            throw FormatException('Unknown core input: ${input['kind']}');
        }
      } catch (failure) {
        error = _rejection(failure);
      }
      final after = codec.encodeJson(engine.createSnapshot());
      observations.add({
        'afterInputIndex': n,
        'outcome': error == null ? 'committed' : 'rejected',
        'error': error,
        'checkpointUnchanged': before == after,
        ..._runtimeObservation(engine, n),
        'state': engine.state == null
            ? null
            : _encodeState(engine.state!, mode: 'explicit'),
        'history': _encodeHistory(engine.history),
      });
    }
  } else if (trace['runtime'] == 'narrative') {
    final entries = <StoryEntryPoint>[
      for (final raw in trace['entryPoints'] as List<dynamic>)
        StoryEntryPoint(
          id: StoryEntryPointId((raw as Map<String, dynamic>)['id'] as String),
          eventId: StoryEventId(raw['eventId'] as String),
        ),
    ];
    var runtime = StoryNarrativeRuntime(
      project: project,
      entryPoints: entries,
      randomSeed: seed,
      maxAutomaticTransitions: guard,
    );
    final codec = StoryNarrativeRuntimeSnapshotCodec();
    for (var n = 0; n < inputs.length; n++) {
      final input = inputs[n] as Map<String, dynamic>;
      final before = codec.encodeJson(runtime.createSnapshot());
      String? error;
      int? replayed;
      try {
        switch (input['kind']) {
          case 'startSession':
            runtime.startSession(
              StoryEntryPointId(input['entryPointId'] as String),
            );
          case 'choose':
            runtime
                .sessionByIndex(input['sessionIndex'] as int)
                .choose(StoryChoiceId(input['choiceId'] as String));
          case 'continue':
            runtime
                .sessionByIndex(input['sessionIndex'] as int)
                .continueStory();
          case 'requestHost':
            runtime
                .sessionByIndex(input['sessionIndex'] as int)
                .requestHostAction(
                  schemaNamespace: 'org.example.conformance',
                  actionId: 'approve',
                  arguments: const {'subject': 'portable'},
                  resultType: const StoryHostActionValueType.boolean(),
                );
          case 'completeHost':
            final index = input['sessionIndex'] as int;
            runtime
                .sessionByIndex(index)
                .completeHostAction(
                  StoryHostActionRequestId(input['requestId'] as String),
                  value: input['value'],
                );
          case 'restore' || 'restoreInvalid':
            final observer = _RestoreObserver();
            var encoded = before;
            if (input['kind'] == 'restoreInvalid') {
              final object = jsonDecode(encoded) as Map<String, dynamic>;
              _mutate(object, input['path'] as List<dynamic>, input['value']);
              encoded = jsonEncode(object);
            }
            final decoded = codec.decodeJson(
              encoded,
              project: project,
              entryPoints: entries,
            );
            final candidate = StoryNarrativeRuntime.restore(
              project: project,
              entryPoints: entries,
              snapshot: decoded,
              observers: [observer],
            );
            replayed = observer.count;
            runtime = candidate;
          default:
            throw FormatException('Unknown narrative input: ${input['kind']}');
        }
      } catch (failure) {
        error = _rejection(failure);
      }
      final after = codec.encodeJson(runtime.createSnapshot());
      observations.add({
        'afterInputIndex': n,
        'outcome': error == null ? 'committed' : 'rejected',
        'error': error,
        'checkpointUnchanged': _aggregateCheckpointEqual(before, after),
        'observationsReplayed': ?replayed,
        ..._narrativeObservation(runtime),
      });
    }
  } else {
    throw FormatException('Unknown hardening runtime: ${trace['runtime']}');
  }
  return {
    'formatId': 'open_story.conformance_hardening_expected_trace',
    'formatVersion': 1,
    'observations': observations,
  };
}

String _rejection(Object failure) {
  return switch (failure) {
    StoryEngineExecutionException() ||
    StoryNarrativeExecutionException() => 'executionRejected',
    StoryEngineOperationException() ||
    StoryNarrativeOperationException() => 'operationRejected',
    StoryConditionEvaluationException() => 'conditionRejected',
    StoryHostActionProtocolException() => 'hostProtocolRejected',
    StoryRuntimeSnapshotCompatibilityException() ||
    StoryNarrativeRuntimeSnapshotCompatibilityException() =>
      'snapshotCompatibility',
    StoryRuntimeSnapshotFormatException() ||
    StoryNarrativeRuntimeSnapshotFormatException() => 'snapshotFormat',
    _ => throw _CaseFailure(
      'runnerFailure',
      'Unexpected input/harness failure: $failure',
    ),
  };
}

Map<String, Object?> _narrativeObservation(StoryNarrativeRuntime runtime) {
  final snapshot = runtime.createSnapshot();
  return {
    'persistentState': _encodeState(runtime.persistentState, mode: 'explicit'),
    'persistentStateRevision': snapshot.persistentStateRevision,
    'nextSessionIndex': snapshot.nextSessionIndex,
    'activeSessionIndexes': [
      for (final session in runtime.activeSessions) session.index,
    ],
    'sessions': [
      for (final session in snapshot.sessions)
        {
          'sessionIndex': session.sessionIndex,
          'entryPointId': session.entryPointId.value,
          'status': runtime
              .sessionByIndex(session.sessionIndex)
              .sessionStatus
              .name,
          'currentEventId': session.runtimeSnapshot.currentEventId?.value,
          'availableChoiceIds': [
            for (final choice
                in runtime
                    .sessionByIndex(session.sessionIndex)
                    .availableChoices)
              choice.id.value,
          ],
          'state': _encodeState(
            session.runtimeSnapshot.state!,
            mode: 'explicit',
          ),
          'history': _encodeHistory(session.runtimeSnapshot.history),
          'nextRequestOrdinal': session.hostActionSnapshot.nextRequestOrdinal,
          'pendingRequest': session.hostActionSnapshot.pendingRequest == null
              ? null
              : {
                  'id': session.hostActionSnapshot.pendingRequest!.id.value,
                  'schemaNamespace': session
                      .hostActionSnapshot
                      .pendingRequest!
                      .schemaNamespace,
                  'actionId':
                      session.hostActionSnapshot.pendingRequest!.actionId,
                  'arguments':
                      session.hostActionSnapshot.pendingRequest!.arguments,
                },
        },
    ],
  };
}

void _mutate(Object root, List<dynamic> path, Object? value) {
  if (path.isEmpty) {
    throw const FormatException(
      'A corruption path must name an existing field.',
    );
  }
  Object? current = root;
  for (final segment in path.take(path.length - 1)) {
    current = switch ((current, segment)) {
      (Map<String, dynamic> map, String field) when map.containsKey(field) =>
        map[field],
      (List<dynamic> list, int index) when index >= 0 && index < list.length =>
        list[index],
      _ => throw const FormatException('Invalid corruption path.'),
    };
  }
  final last = path.last;
  switch ((current, last)) {
    case (Map<String, dynamic> map, String field) when map.containsKey(field):
      map[field] = value;
    case (List<dynamic> list, int index) when index >= 0 && index < list.length:
      list[index] = value;
    default:
      throw const FormatException('Invalid corruption field.');
  }
}

final class _RestoreObserver implements StoryNarrativeObserver {
  int count = 0;
  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    count++;
  }
}

// Subscribed failure observations legitimately advance the telemetry cursor.
// Transactional equality covers all other durable fields, including every RNG,
// retained session, host request, history, shared value and allocation cursor.
bool _aggregateCheckpointEqual(String before, String after) {
  final left = jsonDecode(before) as Map<String, dynamic>;
  final right = jsonDecode(after) as Map<String, dynamic>;
  left.remove('nextObservationSequence');
  right.remove('nextObservationSequence');
  return _equal(left, right);
}
