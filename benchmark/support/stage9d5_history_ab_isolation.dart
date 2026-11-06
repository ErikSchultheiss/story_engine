import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:story_engine/story_engine.dart';
import 'package:story_engine/src/orchestration/story_narrative_runtime.dart'
    as internal;

import 'stage9d5_optimization_baseline.dart';

enum Stage9d5AbVariant { a, b, c, d, e, hybrid }

extension Stage9d5AbVariantContract on Stage9d5AbVariant {
  String get label => switch (this) {
    Stage9d5AbVariant.a => 'A',
    Stage9d5AbVariant.b => 'B',
    Stage9d5AbVariant.c => 'C',
    Stage9d5AbVariant.d => 'D',
    Stage9d5AbVariant.e => 'E',
    Stage9d5AbVariant.hybrid => 'H',
  };

  String get rollbackStrategy => switch (this) {
    Stage9d5AbVariant.a || Stage9d5AbVariant.b => 'eager',
    Stage9d5AbVariant.c || Stage9d5AbVariant.d => 'lazy',
    Stage9d5AbVariant.e => 'lazy_selective_shared_change',
    Stage9d5AbVariant.hybrid => 'hybrid',
  };

  String get observationStrategy => switch (this) {
    Stage9d5AbVariant.a || Stage9d5AbVariant.c => 'copied_history',
    Stage9d5AbVariant.b ||
    Stage9d5AbVariant.d ||
    Stage9d5AbVariant.e ||
    Stage9d5AbVariant.hybrid => 'indexed_suffix',
  };

  internal.StoryNarrativeRuntimeHistoryStrategy get runtimeStrategy =>
      switch (this) {
        Stage9d5AbVariant.a =>
          internal.StoryNarrativeRuntimeHistoryStrategy.eagerCopied,
        Stage9d5AbVariant.b =>
          internal.StoryNarrativeRuntimeHistoryStrategy.eagerIndexed,
        Stage9d5AbVariant.c =>
          internal.StoryNarrativeRuntimeHistoryStrategy.lazyCopied,
        Stage9d5AbVariant.d =>
          internal.StoryNarrativeRuntimeHistoryStrategy.lazyIndexed,
        Stage9d5AbVariant.e =>
          internal.StoryNarrativeRuntimeHistoryStrategy.selectiveIndexed,
        Stage9d5AbVariant.hybrid =>
          internal.StoryNarrativeRuntimeHistoryStrategy.hybridIndexed,
      };
}

enum Stage9d5AbPreparationMode { natural, restored }

const List<int> stage9d5AbSessionCounts = <int>[1, 2, 50];
const List<Stage9d5HistoryProfile> stage9d5AbHistoryProfiles =
    <Stage9d5HistoryProfile>[
      Stage9d5HistoryProfile(name: 'medium', loopChoices: 32),
      Stage9d5HistoryProfile(name: 'very_long', loopChoices: 512),
    ];

StoryNarrativeRuntimeSnapshot buildStage9d5CanonicalRuntimeSnapshot({
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required int sessionCount,
}) {
  final runtime = StoryNarrativeRuntime(
    project: fixture.project,
    entryPoints: <StoryEntryPoint>[fixture.entryPoint],
    randomSeed: 0x9d5a,
  );
  final sessions = <StoryNarrativeSession>[
    for (var index = 0; index < sessionCount; index++)
      runtime.startSession(fixture.entryPoint.id),
  ];
  for (final session in sessions) {
    for (var step = 0; step < historyProfile.loopChoices; step++) {
      session.choose(fixture.loopChoiceId);
    }
  }
  final snapshot = runtime.createSnapshot();
  _verifyPreparedRuntime(
    runtime: runtime,
    fixture: fixture,
    historyProfile: historyProfile,
    sessionCount: sessionCount,
  );
  return snapshot;
}

final class Stage9d5AbHistoryPrepared {
  const Stage9d5AbHistoryPrepared({
    required this.variant,
    required this.preparationMode,
    required this.fixture,
    required this.historyProfile,
    required this.sessionCount,
    required this.runtime,
  });

  final Stage9d5AbVariant variant;
  final Stage9d5AbPreparationMode preparationMode;
  final Stage9d5Fixture fixture;
  final Stage9d5HistoryProfile historyProfile;
  final int sessionCount;
  final StoryNarrativeRuntime runtime;
}

Stage9d5AbHistoryPrepared prepareStage9d5AbHistory({
  required Stage9d5AbVariant variant,
  required Stage9d5AbPreparationMode preparationMode,
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required int sessionCount,
  StoryNarrativeRuntimeSnapshot? canonicalSnapshot,
}) {
  final runtime = switch (preparationMode) {
    Stage9d5AbPreparationMode.natural =>
      internal.createStoryNarrativeRuntimeForStage9d5Benchmark(
        project: fixture.project,
        entryPoints: <StoryEntryPoint>[fixture.entryPoint],
        historyStrategy: variant.runtimeStrategy,
        randomSeed: 0x9d5a,
      ),
    Stage9d5AbPreparationMode.restored =>
      internal.restoreStoryNarrativeRuntimeForStage9d5Benchmark(
        project: fixture.project,
        entryPoints: <StoryEntryPoint>[fixture.entryPoint],
        snapshot: canonicalSnapshot!,
        historyStrategy: variant.runtimeStrategy,
      ),
  };

  if (preparationMode == Stage9d5AbPreparationMode.natural) {
    final sessions = <StoryNarrativeSession>[
      for (var index = 0; index < sessionCount; index++)
        runtime.startSession(fixture.entryPoint.id),
    ];
    for (final session in sessions) {
      for (var step = 0; step < historyProfile.loopChoices; step++) {
        session.choose(fixture.loopChoiceId);
      }
    }
  }

  _verifyPreparedRuntime(
    runtime: runtime,
    fixture: fixture,
    historyProfile: historyProfile,
    sessionCount: sessionCount,
  );
  return Stage9d5AbHistoryPrepared(
    variant: variant,
    preparationMode: preparationMode,
    fixture: fixture,
    historyProfile: historyProfile,
    sessionCount: sessionCount,
    runtime: runtime,
  );
}

Stage9d5AbHistoryPrepared runStage9d5AbHistory(
  Stage9d5AbHistoryPrepared prepared,
) {
  final source = prepared.runtime.activeSessions.first;
  for (var step = 0; step < stage9d5MeasuredAdditionalChoices; step++) {
    source.choose(prepared.fixture.loopChoiceId);
  }
  return prepared;
}

String stage9d5AbHistoryFingerprint(Stage9d5AbHistoryPrepared result) {
  final runtime = result.runtime;
  final sessions = runtime.activeSessions;
  final expectedSourceChoices =
      result.historyProfile.loopChoices + stage9d5MeasuredAdditionalChoices;
  final expectedSiblingChoices = result.historyProfile.loopChoices;

  if (runtime.persistentStateRevision != 0 ||
      runtime.persistentState.rawValueOf(result.fixture.counterId) != 0 ||
      sessions.length != result.sessionCount) {
    throw StateError('History-only A/B case changed shared runtime authority.');
  }
  for (var index = 0; index < sessions.length; index++) {
    _verifyLoopSession(
      session: sessions[index],
      fixture: result.fixture,
      expectedLoopChoices: index == 0
          ? expectedSourceChoices
          : expectedSiblingChoices,
    );
  }
  return _runtimeFingerprint(runtime.createSnapshot());
}

Map<String, Object?> stage9d5AbHistoryMetrics(
  Stage9d5AbHistoryPrepared result,
) => <String, Object?>{
  'variant': result.variant.label,
  'rollbackStrategy': result.variant.rollbackStrategy,
  'observationStrategy': result.variant.observationStrategy,
  'preparationMode': result.preparationMode.name,
  'sessionCount': result.sessionCount,
  'preparedLoopChoices': result.historyProfile.loopChoices,
  'measuredAdditionalChoices': stage9d5MeasuredAdditionalChoices,
  'sourceFinalHistorySteps':
      1 +
      2 *
          (result.historyProfile.loopChoices +
              stage9d5MeasuredAdditionalChoices),
  'siblingHistorySteps': 1 + 2 * result.historyProfile.loopChoices,
};

final class Stage9d5AbPropagationPrepared {
  const Stage9d5AbPropagationPrepared({
    required this.variant,
    required this.preparationMode,
    required this.fixture,
    required this.historyProfile,
    required this.sessionCount,
    required this.prewarmedProjectPreparation,
    required this.runtime,
  });

  final Stage9d5AbVariant variant;
  final Stage9d5AbPreparationMode preparationMode;
  final Stage9d5Fixture fixture;
  final Stage9d5HistoryProfile historyProfile;
  final int sessionCount;
  final bool prewarmedProjectPreparation;
  final StoryNarrativeRuntime runtime;
}

Stage9d5AbPropagationPrepared prepareStage9d5AbPropagation({
  required Stage9d5AbVariant variant,
  required Stage9d5AbPreparationMode preparationMode,
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required int sessionCount,
  required bool prewarmProjectPreparation,
  StoryNarrativeRuntimeSnapshot? canonicalSnapshot,
}) {
  final historyPrepared = prepareStage9d5AbHistory(
    variant: variant,
    preparationMode: preparationMode,
    fixture: fixture,
    historyProfile: historyProfile,
    sessionCount: sessionCount,
    canonicalSnapshot: canonicalSnapshot,
  );
  if (prewarmProjectPreparation && sessionCount > 1) {
    internal.warmStoryNarrativeRuntimeProjectPreparationForStage9d5Benchmark(
      historyPrepared.runtime,
    );
  }
  return Stage9d5AbPropagationPrepared(
    variant: variant,
    preparationMode: preparationMode,
    fixture: fixture,
    historyProfile: historyProfile,
    sessionCount: sessionCount,
    prewarmedProjectPreparation: prewarmProjectPreparation,
    runtime: historyPrepared.runtime,
  );
}

Stage9d5AbPropagationPrepared runStage9d5AbPropagation(
  Stage9d5AbPropagationPrepared prepared,
) {
  prepared.runtime.activeSessions.first.choose(prepared.fixture.commitChoiceId);
  return prepared;
}

String stage9d5AbPropagationFingerprint(Stage9d5AbPropagationPrepared result) {
  final runtime = result.runtime;
  final sessions = runtime.activeSessions;
  if (runtime.persistentStateRevision != 1 ||
      runtime.persistentState.rawValueOf(result.fixture.counterId) != 1 ||
      sessions.length != result.sessionCount) {
    throw StateError(
      'A/B propagation did not commit shared state exactly once.',
    );
  }
  for (var index = 0; index < sessions.length; index++) {
    final snapshot = sessions[index].createSnapshot().runtimeSnapshot;
    if (snapshot.state?.rawValueOf(result.fixture.counterId) != 1) {
      throw StateError('A/B sibling did not receive committed shared state.');
    }
    if (index == 0) {
      final expectedHistorySteps =
          1 + 2 * result.historyProfile.loopChoices + 2;
      if (snapshot.status != StoryEngineStatus.awaitingContinue ||
          snapshot.currentEventId != result.fixture.commitEventId ||
          snapshot.history.steps.length != expectedHistorySteps) {
        throw StateError('A/B source commit changed unexpected runtime facts.');
      }
    } else {
      _verifyLoopSession(
        session: sessions[index],
        fixture: result.fixture,
        expectedLoopChoices: result.historyProfile.loopChoices,
        expectedCounter: 1,
      );
    }
  }
  return _runtimeFingerprint(runtime.createSnapshot());
}

Map<String, Object?> stage9d5AbPropagationMetrics(
  Stage9d5AbPropagationPrepared result,
) => <String, Object?>{
  'variant': result.variant.label,
  'rollbackStrategy': result.variant.rollbackStrategy,
  'observationStrategy': result.variant.observationStrategy,
  'preparationMode': result.preparationMode.name,
  'sessionCount': result.sessionCount,
  'historyProfile': result.historyProfile.name,
  'preparedLoopChoices': result.historyProfile.loopChoices,
  'prewarmedProjectPreparation': result.prewarmedProjectPreparation,
  'persistentStateRevision': result.runtime.persistentStateRevision,
};

void _verifyPreparedRuntime({
  required StoryNarrativeRuntime runtime,
  required Stage9d5Fixture fixture,
  required Stage9d5HistoryProfile historyProfile,
  required int sessionCount,
}) {
  if (runtime.activeSessions.length != sessionCount ||
      runtime.persistentStateRevision != 0 ||
      runtime.persistentState.rawValueOf(fixture.counterId) != 0) {
    throw StateError('A/B preparation produced unexpected runtime authority.');
  }
  for (final session in runtime.activeSessions) {
    _verifyLoopSession(
      session: session,
      fixture: fixture,
      expectedLoopChoices: historyProfile.loopChoices,
    );
  }
}

void _verifyLoopSession({
  required StoryNarrativeSession session,
  required Stage9d5Fixture fixture,
  required int expectedLoopChoices,
  int expectedCounter = 0,
}) {
  final snapshot = session.createSnapshot().runtimeSnapshot;
  final expectedHistorySteps = 1 + 2 * expectedLoopChoices;
  if (snapshot.status != StoryEngineStatus.awaitingChoice ||
      snapshot.currentEventId != fixture.loopEventId ||
      snapshot.history.steps.length != expectedHistorySteps ||
      snapshot.state?.rawValueOf(fixture.counterId) != expectedCounter) {
    throw StateError(
      'A/B loop session does not match its expected checkpoint.',
    );
  }
}

String _runtimeFingerprint(StoryNarrativeRuntimeSnapshot snapshot) {
  final json = StoryNarrativeRuntimeSnapshotCodec().encodeJson(snapshot);
  return sha256.convert(utf8.encode(json)).toString();
}
