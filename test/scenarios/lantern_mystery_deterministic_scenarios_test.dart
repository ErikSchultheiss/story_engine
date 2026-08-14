import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  group('Stage 2E deterministic Lantern Mystery scenarios', () {
    for (final scenario in _canonicalScenarios()) {
      test(scenario.name, () {
        final first = _runScenario(scenario);
        final replay = _runScenario(scenario);

        _expectScenarioResult(first, scenario);

        expect(
          replay.status,
          first.status,
          reason: 'Identical scenario inputs must reproduce engine status.',
        );
        expect(
          replay.currentEventId,
          first.currentEventId,
          reason: 'Identical scenario inputs must reproduce the terminal event.',
        );
        expect(
          replay.state,
          first.state,
          reason: 'Identical scenario inputs must reproduce final story state.',
        );
        expect(
          replay.history,
          first.history,
          reason: 'Identical scenario inputs must reproduce the exact route.',
        );
      });
    }
  });
}

_ScenarioRunResult _runScenario(_ScenarioCase scenario) {
  final project = LanternMysteryFixture.buildProject();
  final engine = StoryEngine(
    project: project,
    randomSeed: scenario.seed,
  );

  engine.start(initialState: scenario.initialState?.call(project));
  for (final action in scenario.actions) {
    switch (action) {
      case _ChooseAction(:final choiceId):
        engine.choose(choiceId);
      case _ContinueAction():
        engine.continueStory();
    }
  }

  return _ScenarioRunResult(
    status: engine.status,
    currentEventId: engine.currentEvent?.id,
    state: engine.state!,
    history: engine.history,
  );
}

void _expectScenarioResult(_ScenarioRunResult result, _ScenarioCase scenario) {
  expect(result.status, StoryEngineStatus.terminated);
  expect(result.currentEventId, scenario.expectedTerminalEventId);
  expect(result.history.eventRoute, scenario.expectedEventRoute);
  expect(result.history.selectedChoiceIds, scenario.expectedSelectedChoiceIds);
  expect(result.history.continuedEventIds, scenario.expectedContinuedEventIds);
  expect(
    result.history.steps,
    hasLength(
      scenario.expectedEventRoute.length +
          scenario.expectedSelectedChoiceIds.length +
          scenario.expectedContinuedEventIds.length,
    ),
    reason: 'Every committed route observation should be represented once.',
  );

  expect(
    scenario.expectedValues.keys.toSet(),
    equals(_allVariableIds),
    reason: 'Every canonical scenario must specify all six variable states.',
  );

  for (final entry in scenario.expectedValues.entries) {
    final expectedValue = entry.value;
    if (expectedValue == null) {
      expect(
        result.state.isSet(entry.key),
        isFalse,
        reason: '${entry.key} should finish unset in ${scenario.name}.',
      );
    } else {
      expect(
        result.state.valueOf(entry.key),
        expectedValue,
        reason: '${entry.key} has the wrong final value in ${scenario.name}.',
      );
    }
  }
}

List<_ScenarioCase> _canonicalScenarios() => [
  _ScenarioCase(
    name: 'canonical good route captures route, choices, state, and terminal',
    seed: LanternMysteryFixture.safeSeed,
    actions: [
      _choose(LanternMysteryFixture.inspectAlarmId),
      _choose(LanternMysteryFixture.openServiceDrawerId),
      _choose(LanternMysteryFixture.visitCaretakerId),
      _choose(LanternMysteryFixture.correctCodenameId),
      _choose(LanternMysteryFixture.readMaintenanceNoteId),
      _choose(LanternMysteryFixture.openArchiveId),
      _choose(LanternMysteryFixture.followMarkedSafeRouteId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.caretakerId,
      LanternMysteryFixture.libraryId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.archiveId,
      LanternMysteryFixture.goodOutcomeId,
    ],
    expectedContinuedEventIds: [LanternMysteryFixture.goodOutcomeId],
    expectedTerminalEventId: LanternMysteryFixture.goodOutcomeId,
    expectedValues: _values(
      hasLantern: true,
      caretakerTrust: 65,
      temperature: 18.5,
      codename: 'Rook',
      alarmTriggered: false,
      knowsSafeRoute: true,
    ),
  ),
  _ScenarioCase(
    name: 'immediate neutral route preserves initial state including unset alarm',
    seed: LanternMysteryFixture.safeSeed,
    actions: [
      _choose(LanternMysteryFixture.leaveFoyerId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.neutralOutcomeId,
    ],
    expectedContinuedEventIds: [LanternMysteryFixture.neutralOutcomeId],
    expectedTerminalEventId: LanternMysteryFixture.neutralOutcomeId,
    expectedValues: _values(
      hasLantern: false,
      caretakerTrust: 40,
      temperature: 18.5,
      codename: 'Rook',
      alarmTriggered: null,
      knowsSafeRoute: false,
    ),
  ),
  _ScenarioCase(
    name: 'collapse seed produces the complete deterministic bad route',
    seed: LanternMysteryFixture.collapseSeed,
    actions: [
      _choose(LanternMysteryFixture.inspectAlarmId),
      _choose(LanternMysteryFixture.openServiceDrawerId),
      _choose(LanternMysteryFixture.enterCorridorId),
      _choose(LanternMysteryFixture.enterCellarId),
      _choose(LanternMysteryFixture.enterUnstablePassageId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.cellarId,
      LanternMysteryFixture.unstablePassageId,
      LanternMysteryFixture.badOutcomeId,
    ],
    expectedContinuedEventIds: [LanternMysteryFixture.badOutcomeId],
    expectedTerminalEventId: LanternMysteryFixture.badOutcomeId,
    expectedValues: _values(
      hasLantern: true,
      caretakerTrust: 40,
      temperature: 18.5,
      codename: 'Rook',
      alarmTriggered: false,
      knowsSafeRoute: false,
    ),
  ),
  _ScenarioCase(
    name: 'safe weighted route without route knowledge finishes neutral',
    seed: LanternMysteryFixture.safeSeed,
    actions: [
      _choose(LanternMysteryFixture.inspectAlarmId),
      _choose(LanternMysteryFixture.openServiceDrawerId),
      _choose(LanternMysteryFixture.enterCorridorId),
      _choose(LanternMysteryFixture.enterCellarId),
      _choose(LanternMysteryFixture.enterUnstablePassageId),
      _choose(LanternMysteryFixture.takeNearestExitId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.cellarId,
      LanternMysteryFixture.unstablePassageId,
      LanternMysteryFixture.oldTunnelId,
      LanternMysteryFixture.neutralOutcomeId,
    ],
    expectedContinuedEventIds: [LanternMysteryFixture.neutralOutcomeId],
    expectedTerminalEventId: LanternMysteryFixture.neutralOutcomeId,
    expectedValues: _values(
      hasLantern: true,
      caretakerTrust: 40,
      temperature: 18.5,
      codename: 'Rook',
      alarmTriggered: false,
      knowsSafeRoute: false,
    ),
  ),
  _ScenarioCase(
    name: 'cold-route discovery records continue and automatic flow',
    seed: LanternMysteryFixture.safeSeed,
    actions: [
      _choose(LanternMysteryFixture.inspectAlarmId),
      _choose(LanternMysteryFixture.openServiceDrawerId),
      _choose(LanternMysteryFixture.visitCaretakerId),
      _choose(LanternMysteryFixture.correctCodenameId),
      _choose(LanternMysteryFixture.takeColdStairwayId),
      const _ContinueAction(),
      _choose(LanternMysteryFixture.studyFrostId),
      _choose(LanternMysteryFixture.enterUnstablePassageId),
      _choose(LanternMysteryFixture.followChalkMarksId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.caretakerId,
      LanternMysteryFixture.libraryId,
      LanternMysteryFixture.coldChamberId,
      LanternMysteryFixture.cellarId,
      LanternMysteryFixture.cellarId,
      LanternMysteryFixture.unstablePassageId,
      LanternMysteryFixture.oldTunnelId,
      LanternMysteryFixture.goodOutcomeId,
    ],
    expectedContinuedEventIds: [
      LanternMysteryFixture.coldChamberId,
      LanternMysteryFixture.goodOutcomeId,
    ],
    expectedTerminalEventId: LanternMysteryFixture.goodOutcomeId,
    expectedValues: _values(
      hasLantern: true,
      caretakerTrust: 65,
      temperature: 16.0,
      codename: 'Rook',
      alarmTriggered: false,
      knowsSafeRoute: true,
    ),
  ),
  _ScenarioCase(
    name: 'fake codename then alarm reset finishes with alarm genuinely unset',
    seed: LanternMysteryFixture.safeSeed,
    actions: [
      _choose(LanternMysteryFixture.inspectAlarmId),
      _choose(LanternMysteryFixture.openServiceDrawerId),
      _choose(LanternMysteryFixture.visitCaretakerId),
      _choose(LanternMysteryFixture.fakeCodenameId),
      _choose(LanternMysteryFixture.resetAlarmId),
      _choose(LanternMysteryFixture.enterCellarId),
      _choose(LanternMysteryFixture.returnToCorridorFromCellarId),
      _choose(LanternMysteryFixture.leaveCorridorId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.caretakerId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.cellarId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.neutralOutcomeId,
    ],
    expectedContinuedEventIds: [LanternMysteryFixture.neutralOutcomeId],
    expectedTerminalEventId: LanternMysteryFixture.neutralOutcomeId,
    expectedValues: _values(
      hasLantern: true,
      caretakerTrust: 45,
      temperature: 18.5,
      codename: 'Fox',
      alarmTriggered: null,
      knowsSafeRoute: false,
    ),
  ),
  _ScenarioCase(
    name: 'low-trust custom initial state takes conditional fallback route',
    seed: LanternMysteryFixture.safeSeed,
    initialState: _lowTrustInitialState,
    actions: [
      _choose(LanternMysteryFixture.visitCaretakerId),
      _choose(LanternMysteryFixture.correctCodenameId),
      _choose(LanternMysteryFixture.leaveCorridorId),
      const _ContinueAction(),
    ],
    expectedEventRoute: [
      LanternMysteryFixture.foyerId,
      LanternMysteryFixture.caretakerId,
      LanternMysteryFixture.corridorId,
      LanternMysteryFixture.neutralOutcomeId,
    ],
    expectedContinuedEventIds: [LanternMysteryFixture.neutralOutcomeId],
    expectedTerminalEventId: LanternMysteryFixture.neutralOutcomeId,
    expectedValues: _values(
      hasLantern: false,
      caretakerTrust: 25,
      temperature: 18.5,
      codename: 'Rook',
      alarmTriggered: null,
      knowsSafeRoute: false,
    ),
  ),
];

StoryState _lowTrustInitialState(StoryProject project) => StoryState.fromValues(
  schema: project.stateSchema,
  values: {
    LanternMysteryFixture.hasLanternId: const StoryBooleanValue(false),
    LanternMysteryFixture.caretakerTrustId: StoryIntegerValue(0),
    LanternMysteryFixture.temperatureId: StoryNumberValue(18.5),
    LanternMysteryFixture.codenameId: const StoryStringValue('Rook'),
    LanternMysteryFixture.knowsSafeRouteId: const StoryBooleanValue(false),
  },
);

Map<StoryVariableId, StoryValue?> _values({
  required bool hasLantern,
  required int caretakerTrust,
  required double temperature,
  required String codename,
  required bool? alarmTriggered,
  required bool knowsSafeRoute,
}) => {
  LanternMysteryFixture.hasLanternId: StoryBooleanValue(hasLantern),
  LanternMysteryFixture.caretakerTrustId: StoryIntegerValue(caretakerTrust),
  LanternMysteryFixture.temperatureId: StoryNumberValue(temperature),
  LanternMysteryFixture.codenameId: StoryStringValue(codename),
  LanternMysteryFixture.alarmTriggeredId: alarmTriggered == null
      ? null
      : StoryBooleanValue(alarmTriggered),
  LanternMysteryFixture.knowsSafeRouteId: StoryBooleanValue(knowsSafeRoute),
};

final Set<StoryVariableId> _allVariableIds = {
  LanternMysteryFixture.hasLanternId,
  LanternMysteryFixture.caretakerTrustId,
  LanternMysteryFixture.temperatureId,
  LanternMysteryFixture.codenameId,
  LanternMysteryFixture.alarmTriggeredId,
  LanternMysteryFixture.knowsSafeRouteId,
};

typedef _InitialStateBuilder = StoryState Function(StoryProject project);

sealed class _ScenarioAction {
  const _ScenarioAction();
}

final class _ChooseAction extends _ScenarioAction {
  const _ChooseAction(this.choiceId);

  final StoryChoiceId choiceId;
}

final class _ContinueAction extends _ScenarioAction {
  const _ContinueAction();
}

_ChooseAction _choose(StoryChoiceId choiceId) => _ChooseAction(choiceId);

final class _ScenarioCase {
  _ScenarioCase({
    required this.name,
    required this.seed,
    required List<_ScenarioAction> actions,
    required List<StoryEventId> expectedEventRoute,
    required List<StoryEventId> expectedContinuedEventIds,
    required this.expectedTerminalEventId,
    required Map<StoryVariableId, StoryValue?> expectedValues,
    this.initialState,
  }) : actions = List<_ScenarioAction>.unmodifiable(actions),
       expectedEventRoute = List<StoryEventId>.unmodifiable(expectedEventRoute),
       expectedContinuedEventIds = List<StoryEventId>.unmodifiable(
         expectedContinuedEventIds,
       ),
       expectedValues = Map<StoryVariableId, StoryValue?>.unmodifiable(
         expectedValues,
       );

  final String name;
  final int seed;
  final List<_ScenarioAction> actions;
  final List<StoryEventId> expectedEventRoute;
  final List<StoryEventId> expectedContinuedEventIds;
  final StoryEventId expectedTerminalEventId;
  final Map<StoryVariableId, StoryValue?> expectedValues;
  final _InitialStateBuilder? initialState;

  List<StoryChoiceId> get expectedSelectedChoiceIds => [
    for (final action in actions)
      if (action case _ChooseAction(:final choiceId)) choiceId,
  ];
}

final class _ScenarioRunResult {
  const _ScenarioRunResult({
    required this.status,
    required this.currentEventId,
    required this.state,
    required this.history,
  });

  final StoryEngineStatus status;
  final StoryEventId? currentEventId;
  final StoryState state;
  final StoryRuntimeHistory history;
}
