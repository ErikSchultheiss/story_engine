import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../tool/conformance/support/conformance_runner.dart';

void main() {
  test(
    '0.9.0 identity agrees across package pages and conformance reports',
    () {
      final version = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
      expect(version, '0.9.0');
      for (final path in [
        'README.md',
        'doc/QUICK_START.md',
        'doc/API_GUIDE.md',
        'doc/RELEASE_0_9_0.md',
        'doc/UPGRADING_TO_0_9_0.md',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, contains(version), reason: path);
        expect(text, isNot(contains('0.1.0-alpha.1')), reason: path);
      }
      for (final profile in ['runtime-core-v1', 'runtime-finalization-v1']) {
        final report = runFixtureSet(
          'conformance/fixtures/$profile/fixture-set.json',
        );
        expect((report['implementation']! as Map)['version'], version);
        expect((report['summary']! as Map)['failed'], 0);
        expect((report['summary']! as Map)['skipped'], 0);
      }
      final changelog = File('CHANGELOG.md').readAsStringSync();
      expect(changelog, startsWith('# Changelog\n'));
      expect(changelog, contains('## 0.9.0'));
      expect(changelog, contains('## 0.1.0-alpha.1')); // Historical release.
      expect(StoryFormatMetadata.currentFormatVersion, 1);
      expect(StoryRuntimeSnapshotMetadata.currentFormatVersion, 1);
      expect(StoryNarrativeRuntimeSnapshotMetadata.currentFormatVersion, 1);
    },
  );

  test('pre-release core v1 checkpoint resumes through the public facade', () {
    final project = _project();
    final raw =
        jsonDecode(
              File(
                'test/fixtures/narrative_runtime_snapshot_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final core = (raw['sessions'] as List).single['runtimeSnapshot'];
    final codec = StoryRuntimeSnapshotCodec();
    final snapshot = codec.decode(core, project: project);
    final engine = StoryEngine.restore(project: project, snapshot: snapshot);
    expect(codec.encode(engine.createSnapshot()), core);
    expect(
      engine.state!.valueOf(StoryVariableId('var_score')),
      StoryIntegerValue(5),
    );
    engine.continueStory();
    expect(engine.status, StoryEngineStatus.terminated);
    expect(
      engine.history.steps.last,
      StoryEventContinuedStep(eventId: StoryEventId('event_primary')),
    );
    expect(engine.createSnapshot().randomState, snapshot.randomState);
  });

  test(
    'pre-release aggregate v1 checkpoint preserves pending request and allocation',
    () {
      final project = _project();
      final entries = [
        StoryEntryPoint(
          id: StoryEntryPointId('entry_primary'),
          eventId: StoryEventId('event_primary'),
        ),
      ];
      final saved = File(
        'test/fixtures/narrative_runtime_snapshot_v1.json',
      ).readAsStringSync().trim();
      final codec = StoryNarrativeRuntimeSnapshotCodec();
      final snapshot = codec.decodeJson(
        saved,
        project: project,
        entryPoints: entries,
      );
      final observer = _Observer();
      final runtime = StoryNarrativeRuntime.restore(
        project: project,
        entryPoints: entries,
        snapshot: snapshot,
        observers: [observer],
      );
      expect(observer.count, 0);
      expect(codec.encodeJson(runtime.createSnapshot()), saved);
      final session = runtime.sessionByIndex(0);
      expect(session.sessionStatus, StoryNarrativeSessionStatus.awaitingHost);
      expect(
        () => session.continueStory(),
        throwsA(isA<StoryNarrativeOperationException>()),
      );
      session.completeHostAction(
        StoryHostActionRequestId('host_action_session_0_0'),
        value: 'Accepted',
      );
      session.continueStory();
      expect(session.sessionStatus, StoryNarrativeSessionStatus.terminated);
      expect(runtime.persistentStateRevision, 3);
      expect(
        runtime.persistentState.valueOf(StoryVariableId('var_score')),
        StoryIntegerValue(5),
      );
      expect(runtime.startSession(entries.single.id).index, 1);
      expect(runtime.createSnapshot().nextSessionIndex, 2);
    },
  );
}

StoryProject _project() => StoryProject(
  id: StoryProjectId('project_stage9a4'),
  stateSchema: StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: StoryVariableId('var_score'),
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(5),
      ),
    ],
  ),
  events: [
    StoryEvent(
      id: StoryEventId('event_primary'),
      continuationTransition: const StoryTerminalTransition(),
    ),
  ],
);

final class _Observer implements StoryNarrativeObserver {
  int count = 0;
  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    count++;
  }
}
