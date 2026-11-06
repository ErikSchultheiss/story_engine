import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../example/story_narrative_modular_host_action_restore_example.dart'
    as example;

void main() {
  group('Stage 9B4 modular host-action aggregate-restore example', () {
    test('example composes only supported public integration surfaces', () {
      final source = File(
        'example/story_narrative_modular_host_action_restore_example.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("import 'package:story_engine/story_engine.dart';"),
      );
      expect(source, isNot(contains('package:story_engine/src/')));
      expect(source, isNot(contains('package:flutter/')));
      expect(source, isNot(contains('dart:io')));
      expect(source, contains('StoryModuleCache('));
      expect(source, contains('materializeProjectForEntryPoint('));
      expect(source, contains('StoryNarrativeRuntime('));
      expect(source, contains('requestHostAction('));
      expect(source, contains('StoryNarrativeRuntimeSnapshotCodec()'));
      expect(source, contains('StoryNarrativeRuntime.restore('));
      expect(source, contains('StoryNarrativeHostActionCompletedInput('));
      expect(source, contains('StoryNarrativeContinueInput('));
      expect(source, isNot(contains('StoryFormatCodec')));
      expect(source, isNot(contains('StorySaveContentBinding')));
    });

    test('modular slice loads only the entry dependency closure', () async {
      final index = example.buildModularHostActionExampleIndex();
      final report = const StoryModuleValidator().validateIndex(index);
      expect(report.isValid, isTrue, reason: report.issues.toString());

      final loader = example.ExampleModuleLoader(
        example.buildModularHostActionExampleModules(),
      );
      final cache = StoryModuleCache(index: index, loader: loader);
      final project = await cache.materializeProjectForEntryPoint(
        StoryEntryPointId('blacksmith'),
      );

      expect(loader.loads.map((id) => id.value), [
        'module_village_dialogue',
        'module_shared_outcome',
      ]);
      expect(
        loader.loads.map((id) => id.value),
        isNot(contains('module_unrelated')),
      );
      expect(project.events.map((event) => event.id.value), [
        'blacksmith_dialogue',
        'market_ready',
      ]);

      final validation = StoryValidator.validate(
        project,
        additionalEntryEventIds: index.entryPoints.map(
          (entry) => entry.eventId,
        ),
      );
      expect(validation.hasErrors, isFalse, reason: validation.format());
      expect(validation.hasWarnings, isFalse, reason: validation.format());
    });

    test(
      'aggregate restore preserves pending request without redispatch',
      () async {
        final index = example.buildModularHostActionExampleIndex();
        final loader = example.ExampleModuleLoader(
          example.buildModularHostActionExampleModules(),
        );
        final project = await StoryModuleCache(
          index: index,
          loader: loader,
        ).materializeProjectForEntryPoint(StoryEntryPointId('blacksmith'));
        final entryPoints = index.entryPoints;
        final runtime = StoryNarrativeRuntime(
          project: project,
          entryPoints: entryPoints,
        );
        final session = runtime.startSession(StoryEntryPointId('blacksmith'));
        final request = session.requestHostAction(
          schemaNamespace: 'com.example.world',
          actionId: 'load_market_scene',
          arguments: const {'area': 'market'},
          resultType: const StoryHostActionValueType.boolean(),
        );
        expect(session.sessionStatus, StoryNarrativeSessionStatus.awaitingHost);

        final codec = StoryNarrativeRuntimeSnapshotCodec();
        final encoded = codec.encodeJson(runtime.createSnapshot());
        final decoded = codec.decodeJson(
          encoded,
          project: project,
          entryPoints: entryPoints,
        );
        final observer = _RecordingObserver();
        final restored = StoryNarrativeRuntime.restore(
          project: project,
          entryPoints: entryPoints,
          snapshot: decoded,
          observers: [observer],
        );
        final restoredSession = restored.sessionByIndex(session.index);

        expect(observer.observations, isEmpty);
        expect(
          restoredSession.sessionStatus,
          StoryNarrativeSessionStatus.awaitingHost,
        );
        expect(restoredSession.pendingHostAction?.id, request.id);
        expect(restoredSession.pendingHostAction?.arguments, const {
          'area': 'market',
        });

        restored.applyInput(
          StoryNarrativeHostActionCompletedInput(
            sessionIndex: restoredSession.index,
            requestId: request.id,
            value: true,
          ),
        );
        expect(
          restoredSession.sessionStatus,
          StoryNarrativeSessionStatus.awaitingContinue,
        );

        restored.applyInput(
          StoryNarrativeContinueInput(sessionIndex: restoredSession.index),
        );
        expect(restoredSession.currentEvent?.id, StoryEventId('market_ready'));
        expect(
          restoredSession.sessionStatus,
          StoryNarrativeSessionStatus.awaitingContinue,
        );

        restored.applyInput(
          StoryNarrativeContinueInput(sessionIndex: restoredSession.index),
        );
        expect(restoredSession.isTerminated, isTrue);
        expect(restored.activeSessions, isEmpty);
      },
    );

    test('script shows reconcile-not-redispatch lifecycle in order', () async {
      final output = <Object?>[];

      await example.runModularHostActionRestoreExample(log: output.add);
      final text = output.join('\n');

      final loaded = text.indexOf(
        'Loaded modules: module_village_dialogue, module_shared_outcome',
      );
      final dispatch = text.indexOf('External dispatch #1:');
      final saved = text.indexOf('Saved aggregate snapshot:');
      final restored = text.indexOf('Restored pending request:');
      final replay = text.indexOf(
        'Host-action requests replayed during restore: 0',
      );
      final reconcile = text.indexOf('Reconciled existing request:');
      final dispatchCount = text.indexOf(
        'External dispatch count after restore: 1',
      );
      final result = text.indexOf('Status after host result: awaitingContinue');
      final sharedEvent = text.indexOf(
        'Current event after continue: market_ready',
      );
      final finish = text.indexOf('Finished status: terminated');

      expect(text, contains('Validation: 0 errors, 0 warnings'));
      expect(text, isNot(contains('module_unrelated')));
      expect(loaded, greaterThanOrEqualTo(0));
      expect(dispatch, greaterThan(loaded));
      expect(saved, greaterThan(dispatch));
      expect(restored, greaterThan(saved));
      expect(replay, greaterThan(restored));
      expect(reconcile, greaterThan(replay));
      expect(dispatchCount, greaterThan(reconcile));
      expect(result, greaterThan(dispatchCount));
      expect(sharedEvent, greaterThan(result));
      expect(finish, greaterThan(sharedEvent));
    });

    test('documentation exposes Example 3 and the no-redispatch rule', () {
      final paths = <String>[
        'README.md',
        'doc/QUICK_START.md',
        'doc/INTEGRATION_PATH.md',
        'doc/API_GUIDE.md',
        'doc/MODULAR_PROJECT_LOADING_V1.md',
        'doc/HOST_ACTION_PROTOCOL_V1.md',
        'doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md',
        'example/README.md',
      ];

      for (final path in paths) {
        final text = File(path).readAsStringSync();
        expect(
          text,
          contains('story_narrative_modular_host_action_restore_example.dart'),
          reason: path,
        );
      }

      final integrationPath = File(
        'doc/INTEGRATION_PATH.md',
      ).readAsStringSync();
      expect(integrationPath, contains('Stage 9B4 freezes'));
      expect(integrationPath, contains('does not redispatch'));

      final exampleReadme = File('example/README.md').readAsStringSync();
      expect(
        exampleReadme,
        contains('Example 3 — modular host action + aggregate restore'),
      );
      expect(exampleReadme, contains('reconcile'));
      expect(exampleReadme, contains('does **not** redispatch'));
    });
  });
}

final class _RecordingObserver implements StoryNarrativeObserver {
  final List<StoryNarrativeObservation> observations =
      <StoryNarrativeObservation>[];

  @override
  void onNarrativeObservation(StoryNarrativeObservation observation) {
    observations.add(observation);
  }
}
