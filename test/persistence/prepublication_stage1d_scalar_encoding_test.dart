import 'dart:convert';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test('1D Story Format retains canonical scalar objects and bundle bytes', () {
    final project = _project();
    const codec = StoryFormatCodec();
    final bundle = codec.encodeProject(project);
    final manifest =
        jsonDecode(bundle.file('project.json')!) as Map<String, dynamic>;
    final encodedProject = manifest['project'] as Map<String, dynamic>;
    final schema = encodedProject['stateSchema'] as Map<String, dynamic>;
    final variables = schema['variables'] as List<Object?>;
    final leaves = <Map<String, Object?>>[];
    for (final variable in variables) {
      final definition = variable as Map<String, Object?>;
      if (definition.containsKey('initialValue')) {
        leaves.add(definition['initialValue'] as Map<String, Object?>);
      }
    }
    _expectLeaves(leaves);
    expect(variables, hasLength(5));
    expect(manifest['formatId'], 'story_engine.story_format');
    expect(codec.encodeProject(codec.decodeProject(bundle)), bundle);
  });

  test(
    '1D core snapshot retains scalar order, tags and exact JSON round trip',
    () {
      final project = _project();
      final snapshot = (StoryEngine(
        project: project,
      )..start()).createSnapshot();
      final codec = StoryRuntimeSnapshotCodec();
      final encoded = codec.encode(snapshot);
      _expectLeaves(_leaves(encoded, 'state'));
      expect(encoded['documentType'], 'story_engine_runtime_snapshot');
      final decoded = codec.decode(encoded, project: project);
      expect(decoded, snapshot);
      expect(codec.encodeJson(decoded), codec.encodeJson(snapshot));
    },
  );

  test(
    '1D aggregate and nested core snapshots retain independent envelopes',
    () {
      final project = _project();
      final entries = [
        StoryEntryPoint(id: StoryEntryPointId('entry'), eventId: _root),
      ];
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: entries,
      );
      runtime.startSession(entries.single.id);
      final snapshot = runtime.createSnapshot();
      final codec = StoryNarrativeRuntimeSnapshotCodec();
      final encoded = codec.encode(snapshot);
      _expectLeaves(_leaves(encoded, 'persistentState'));
      final sessions = encoded['sessions'] as List<Object?>;
      final session = sessions.single as Map<String, Object?>;
      final core = session['runtimeSnapshot'] as Map<String, Object?>;
      _expectLeaves(_leaves(core, 'state'));
      expect(
        encoded['documentType'],
        'story_engine_narrative_runtime_snapshot',
      );
      expect(core['documentType'], 'story_engine_runtime_snapshot');
      final decoded = codec.decode(
        encoded,
        project: project,
        entryPoints: entries,
      );
      expect(codec.encodeJson(decoded), codec.encodeJson(snapshot));
    },
  );

  test(
    '1D scalar encoding returns fresh maps without mutating saved state',
    () {
      final project = _project();
      final snapshot = (StoryEngine(
        project: project,
      )..start()).createSnapshot();
      final codec = StoryRuntimeSnapshotCodec();
      final first = codec.encode(snapshot);
      final second = codec.encode(snapshot);
      final firstLeaf = _leaves(first, 'state').first;
      final secondLeaf = _leaves(second, 'state').first;
      expect(identical(firstLeaf, secondLeaf), isFalse);
      firstLeaf['type'] = 'changed';
      firstLeaf['value'] = true;
      _expectLeaves(_leaves(second, 'state'));
      _expectLeaves(_leaves(codec.encode(snapshot), 'state'));
      expect(snapshot.state!.rawValueOf(StoryVariableId('flag')), isFalse);
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: [
          StoryEntryPoint(id: StoryEntryPointId('entry'), eventId: _root),
        ],
      );
      _expectLeaves(
        _leaves(
          StoryNarrativeRuntimeSnapshotCodec().encode(runtime.createSnapshot()),
          'persistentState',
        ),
      );
    },
  );
}

final _root = StoryEventId('root');
const _expected = <Map<String, Object?>>[
  {'type': 'boolean', 'value': false},
  {'type': 'integer', 'value': StoryIntegerValue.minPortableValue},
  {'type': 'number', 'value': 1.25},
  {'type': 'string', 'value': 'Grüße_日本'},
];

void _expectLeaves(List<Map<String, Object?>> leaves) {
  expect(leaves, _expected);
  expect(jsonEncode(leaves), jsonEncode(_expected));
  for (final leaf in leaves) {
    expect(leaf.keys, ['type', 'value']);
  }
}

List<Map<String, Object?>> _leaves(
  Map<String, Object?> document,
  String stateKey,
) {
  final state = document[stateKey] as Map<String, Object?>;
  final values = state['values'] as List<Object?>;
  return [
    for (final entry in values)
      (entry as Map<String, Object?>)['value'] as Map<String, Object?>,
  ];
}

StoryProject _project() => StoryProject(
  id: StoryProjectId('scalar_encoding_1d'),
  entryEventId: _root,
  stateSchema: StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: StoryVariableId('flag'),
        type: StoryValueType.boolean,
        initialValue: const StoryBooleanValue(false),
      ),
      StoryVariableDefinition(
        id: StoryVariableId('count'),
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(StoryIntegerValue.minPortableValue),
      ),
      StoryVariableDefinition(
        id: StoryVariableId('ratio'),
        type: StoryValueType.number,
        initialValue: StoryNumberValue(1.25),
      ),
      StoryVariableDefinition(
        id: StoryVariableId('label'),
        type: StoryValueType.string,
        initialValue: const StoryStringValue('Grüße_日本'),
      ),
      StoryVariableDefinition(
        id: StoryVariableId('unassigned'),
        type: StoryValueType.integer,
      ),
    ],
  ),
  events: [
    StoryEvent(
      id: _root,
      continuationTransition: const StoryTerminalTransition(),
    ),
  ],
);
