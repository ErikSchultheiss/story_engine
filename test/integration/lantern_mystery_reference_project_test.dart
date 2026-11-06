import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  group('Lantern Mystery canonical Stage 2 fixture', () {
    test('contains the complete 12-event, 22-choice, 6-variable project', () {
      final project = LanternMysteryFixture.buildProject();

      expect(project.id, LanternMysteryFixture.projectId);
      expect(project.alias, StoryAlias('lantern_mystery'));
      expect(project.entryEventId, LanternMysteryFixture.foyerId);
      expect(project.stateSchema.variables, hasLength(6));
      expect(project.events, hasLength(12));
      expect(project.events.expand((event) => event.choices), hasLength(22));

      for (final event in project.events) {
        if (event.choices.isNotEmpty || event.continuationTransition != null) {
          expect(
            event.presentation,
            isNotNull,
            reason: '${event.id} is host-visible and needs fixture text',
          );
        }
        for (final choice in event.choices) {
          expect(
            choice.presentation,
            isNotNull,
            reason: '${choice.id} needs visible choice text',
          );
        }
      }
    });

    test('scenario A: unset is not false', () {
      final engine = _startedEngine();

      expect(engine.currentEvent?.id, LanternMysteryFixture.foyerId);
      expect(
        engine.state?.isSet(LanternMysteryFixture.alarmTriggeredId),
        isFalse,
      );
      expect(
        _availableIds(engine),
        equals({
          LanternMysteryFixture.inspectAlarmId,
          LanternMysteryFixture.visitCaretakerId,
          LanternMysteryFixture.leaveFoyerId,
        }),
      );
      expect(
        _availableIds(engine),
        isNot(contains(LanternMysteryFixture.openServiceDrawerId)),
      );

      engine.choose(LanternMysteryFixture.inspectAlarmId);

      expect(
        engine.state?.valueOf(LanternMysteryFixture.alarmTriggeredId),
        const StoryBooleanValue(false),
      );
      expect(
        _availableIds(engine),
        contains(LanternMysteryFixture.openServiceDrawerId),
      );
    });

    test('scenario B: choice effects precede conditional transition', () {
      final engine = _startedEngine();

      engine.choose(LanternMysteryFixture.visitCaretakerId);
      expect(engine.currentEvent?.id, LanternMysteryFixture.caretakerId);
      expect(
        engine.state?.valueOf(LanternMysteryFixture.caretakerTrustId),
        StoryIntegerValue(45),
      );

      engine.choose(LanternMysteryFixture.correctCodenameId);

      expect(
        engine.state?.valueOf(LanternMysteryFixture.caretakerTrustId),
        StoryIntegerValue(65),
      );
      expect(engine.currentEvent?.id, LanternMysteryFixture.libraryId);
    });

    test('conditional transition fallback remains executable', () {
      final project = LanternMysteryFixture.buildProject();
      final initialState = StoryState.fromValues(
        schema: project.stateSchema,
        values: {
          LanternMysteryFixture.hasLanternId: const StoryBooleanValue(false),
          LanternMysteryFixture.caretakerTrustId: StoryIntegerValue(0),
          LanternMysteryFixture.temperatureId: StoryNumberValue(18.5),
          LanternMysteryFixture.codenameId: const StoryStringValue('Rook'),
          LanternMysteryFixture.knowsSafeRouteId: const StoryBooleanValue(
            false,
          ),
        },
      );
      final engine = StoryEngine(
        project: project,
        randomSeed: LanternMysteryFixture.safeSeed,
      )..start(initialState: initialState);

      engine.choose(LanternMysteryFixture.visitCaretakerId);
      expect(
        engine.state?.valueOf(LanternMysteryFixture.caretakerTrustId),
        StoryIntegerValue(5),
      );

      engine.choose(LanternMysteryFixture.correctCodenameId);

      expect(
        engine.state?.valueOf(LanternMysteryFixture.caretakerTrustId),
        StoryIntegerValue(25),
      );
      expect(engine.currentEvent?.id, LanternMysteryFixture.corridorId);
    });

    test('scenario C: presented cold chamber pauses before continuing', () {
      final engine = _startedEngine();

      _obtainLantern(engine);
      engine.choose(LanternMysteryFixture.visitCaretakerId);
      engine.choose(LanternMysteryFixture.correctCodenameId);
      engine.choose(LanternMysteryFixture.takeColdStairwayId);

      expect(engine.currentEvent?.id, LanternMysteryFixture.coldChamberId);
      expect(engine.status, StoryEngineStatus.awaitingContinue);
      expect(
        engine.state?.valueOf(LanternMysteryFixture.temperatureId),
        StoryNumberValue(16.0),
      );
      expect(engine.availableChoices, isEmpty);

      engine.continueStory();

      expect(engine.currentEvent?.id, LanternMysteryFixture.cellarId);
      expect(engine.status, StoryEngineStatus.awaitingChoice);
      expect(
        _availableIds(engine),
        contains(LanternMysteryFixture.studyFrostId),
      );

      engine.choose(LanternMysteryFixture.studyFrostId);
      expect(
        engine.state?.valueOf(LanternMysteryFixture.knowsSafeRouteId),
        const StoryBooleanValue(true),
      );
    });

    test('scenario D: alarm can move from true back to unset', () {
      final engine = _startedEngine();

      _obtainLantern(engine);
      engine.choose(LanternMysteryFixture.visitCaretakerId);
      engine.choose(LanternMysteryFixture.fakeCodenameId);

      expect(engine.currentEvent?.id, LanternMysteryFixture.corridorId);
      expect(
        engine.state?.valueOf(LanternMysteryFixture.codenameId),
        const StoryStringValue('Fox'),
      );
      expect(
        engine.state?.valueOf(LanternMysteryFixture.alarmTriggeredId),
        const StoryBooleanValue(true),
      );
      expect(
        _availableIds(engine),
        contains(LanternMysteryFixture.resetAlarmId),
      );
      expect(
        _availableIds(engine),
        isNot(contains(LanternMysteryFixture.enterCellarId)),
      );
      expect(
        _availableIds(engine),
        isNot(contains(LanternMysteryFixture.openArchiveId)),
      );

      engine.choose(LanternMysteryFixture.resetAlarmId);

      expect(
        engine.state?.isSet(LanternMysteryFixture.alarmTriggeredId),
        isFalse,
      );
      expect(
        _availableIds(engine),
        contains(LanternMysteryFixture.enterCellarId),
      );
    });

    test('scenario E: nested archive condition is executable end to end', () {
      final engine = _startedEngine();

      _obtainLantern(engine);
      engine.choose(LanternMysteryFixture.enterCorridorId);

      expect(
        _availableIds(engine),
        contains(LanternMysteryFixture.openArchiveId),
        reason: 'The String branch codename == Rook satisfies the nested ANY.',
      );

      engine.choose(LanternMysteryFixture.openArchiveId);

      expect(engine.currentEvent?.id, LanternMysteryFixture.archiveId);
    });

    test('scenario F: safe seed deterministically reaches old tunnel', () {
      final engine = _startedEngine(seed: LanternMysteryFixture.safeSeed);

      _reachUnstablePassage(engine);

      expect(engine.currentEvent?.id, LanternMysteryFixture.oldTunnelId);
      expect(engine.status, StoryEngineStatus.awaitingChoice);
    });

    test('scenario G: collapse seed deterministically reaches bad outcome', () {
      final engine = _startedEngine(seed: LanternMysteryFixture.collapseSeed);

      _reachUnstablePassage(engine);

      expect(engine.currentEvent?.id, LanternMysteryFixture.badOutcomeId);
      expect(engine.status, StoryEngineStatus.awaitingContinue);
      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);
    });

    test('weighted routes repeat for identical project, seed, and choices', () {
      StoryEventId run(int seed) {
        final engine = _startedEngine(seed: seed);
        _reachUnstablePassage(engine);
        return engine.currentEvent!.id;
      }

      expect(
        run(LanternMysteryFixture.safeSeed),
        LanternMysteryFixture.oldTunnelId,
      );
      expect(
        run(LanternMysteryFixture.safeSeed),
        LanternMysteryFixture.oldTunnelId,
      );
      expect(
        run(LanternMysteryFixture.collapseSeed),
        LanternMysteryFixture.badOutcomeId,
      );
      expect(
        run(LanternMysteryFixture.collapseSeed),
        LanternMysteryFixture.badOutcomeId,
      );
    });

    test('scenario H: canonical good route terminates successfully', () {
      final engine = _startedEngine();

      _obtainLantern(engine);
      engine.choose(LanternMysteryFixture.visitCaretakerId);
      engine.choose(LanternMysteryFixture.correctCodenameId);
      engine.choose(LanternMysteryFixture.readMaintenanceNoteId);
      engine.choose(LanternMysteryFixture.openArchiveId);
      engine.choose(LanternMysteryFixture.followMarkedSafeRouteId);

      expect(engine.currentEvent?.id, LanternMysteryFixture.goodOutcomeId);
      expect(
        engine.state?.valueOf(LanternMysteryFixture.knowsSafeRouteId),
        const StoryBooleanValue(true),
      );

      expect(engine.status, StoryEngineStatus.awaitingContinue);
      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);
    });

    test('scenario I: simplest neutral route terminates successfully', () {
      final engine = _startedEngine();

      engine.choose(LanternMysteryFixture.leaveFoyerId);
      expect(engine.currentEvent?.id, LanternMysteryFixture.neutralOutcomeId);

      expect(engine.status, StoryEngineStatus.awaitingContinue);
      engine.continueStory();
      expect(engine.status, StoryEngineStatus.terminated);
    });

    test(
      'scenario J: safe weighted route without route knowledge is neutral',
      () {
        final engine = _startedEngine(seed: LanternMysteryFixture.safeSeed);

        _reachUnstablePassage(engine);

        expect(engine.currentEvent?.id, LanternMysteryFixture.oldTunnelId);
        expect(
          _availableIds(engine),
          equals({LanternMysteryFixture.takeNearestExitId}),
        );

        engine.choose(LanternMysteryFixture.takeNearestExitId);
        expect(engine.currentEvent?.id, LanternMysteryFixture.neutralOutcomeId);
      },
    );

    test('Stage 2D records the exact canonical good-route history', () {
      final engine = _startedEngine();

      _obtainLantern(engine);
      engine.choose(LanternMysteryFixture.visitCaretakerId);
      engine.choose(LanternMysteryFixture.correctCodenameId);
      engine.choose(LanternMysteryFixture.readMaintenanceNoteId);
      engine.choose(LanternMysteryFixture.openArchiveId);
      engine.choose(LanternMysteryFixture.followMarkedSafeRouteId);
      engine.continueStory();

      expect(engine.history.eventRoute, [
        LanternMysteryFixture.foyerId,
        LanternMysteryFixture.foyerId,
        LanternMysteryFixture.foyerId,
        LanternMysteryFixture.caretakerId,
        LanternMysteryFixture.libraryId,
        LanternMysteryFixture.corridorId,
        LanternMysteryFixture.archiveId,
        LanternMysteryFixture.goodOutcomeId,
      ]);
      expect(engine.history.selectedChoiceIds, [
        LanternMysteryFixture.inspectAlarmId,
        LanternMysteryFixture.openServiceDrawerId,
        LanternMysteryFixture.visitCaretakerId,
        LanternMysteryFixture.correctCodenameId,
        LanternMysteryFixture.readMaintenanceNoteId,
        LanternMysteryFixture.openArchiveId,
        LanternMysteryFixture.followMarkedSafeRouteId,
      ]);
      expect(
        engine.history.eventOccurrenceCount(LanternMysteryFixture.foyerId),
        3,
      );
      expect(
        engine.history.hasVisitedEvent(LanternMysteryFixture.archiveId),
        isTrue,
      );
      expect(
        engine.history.hasContinuedEvent(LanternMysteryFixture.goodOutcomeId),
        isTrue,
      );
      expect(engine.history.continuedEventIds, [
        LanternMysteryFixture.goodOutcomeId,
      ]);
    });

    test(
      'history keeps continuation events and synchronous automatic events',
      () {
        final engine = _startedEngine(seed: LanternMysteryFixture.safeSeed);

        _obtainLantern(engine);
        engine.choose(LanternMysteryFixture.visitCaretakerId);
        engine.choose(LanternMysteryFixture.correctCodenameId);
        engine.choose(LanternMysteryFixture.takeColdStairwayId);

        expect(engine.currentEvent?.id, LanternMysteryFixture.coldChamberId);
        expect(engine.status, StoryEngineStatus.awaitingContinue);
        expect(
          engine.history.eventRoute,
          containsAllInOrder([
            LanternMysteryFixture.libraryId,
            LanternMysteryFixture.coldChamberId,
          ]),
        );

        engine.continueStory();
        expect(engine.currentEvent?.id, LanternMysteryFixture.cellarId);
        expect(
          engine.history.continuedEventIds,
          contains(LanternMysteryFixture.coldChamberId),
        );

        engine.choose(LanternMysteryFixture.enterUnstablePassageId);

        expect(
          engine.history.eventRoute,
          containsAllInOrder([
            LanternMysteryFixture.cellarId,
            LanternMysteryFixture.unstablePassageId,
            LanternMysteryFixture.oldTunnelId,
          ]),
        );
      },
    );

    test('presented continuation pauses while automatic routing does not', () {
      final project = LanternMysteryFixture.buildProject();
      final coldChamber = project.events.singleWhere(
        (event) => event.id == LanternMysteryFixture.coldChamberId,
      );
      final unstablePassage = project.events.singleWhere(
        (event) => event.id == LanternMysteryFixture.unstablePassageId,
      );

      expect(coldChamber.presentation?.title?.value, 'Cold Chamber');
      expect(coldChamber.continuationTransition, isNotNull);
      expect(unstablePassage.presentation, isNull);
      expect(unstablePassage.automaticTransition, isNotNull);

      final engine = StoryEngine(
        project: project,
        randomSeed: LanternMysteryFixture.safeSeed,
      )..start();
      _obtainLantern(engine);
      engine.choose(LanternMysteryFixture.visitCaretakerId);
      engine.choose(LanternMysteryFixture.correctCodenameId);
      engine.choose(LanternMysteryFixture.takeColdStairwayId);

      expect(engine.currentEvent?.id, LanternMysteryFixture.coldChamberId);
      expect(engine.status, StoryEngineStatus.awaitingContinue);

      engine.continueStory();
      expect(engine.currentEvent?.id, LanternMysteryFixture.cellarId);

      engine.choose(LanternMysteryFixture.enterUnstablePassageId);
      expect(
        engine.currentEvent?.id,
        LanternMysteryFixture.oldTunnelId,
        reason: 'Automatic routing remains synchronous and non-pausing.',
      );
    });
  });
}

StoryEngine _startedEngine({int seed = LanternMysteryFixture.safeSeed}) {
  final engine = StoryEngine(
    project: LanternMysteryFixture.buildProject(),
    randomSeed: seed,
  );
  engine.start();
  return engine;
}

Set<StoryChoiceId> _availableIds(StoryEngine engine) =>
    engine.availableChoices.map((choice) => choice.id).toSet();

void _obtainLantern(StoryEngine engine) {
  engine.choose(LanternMysteryFixture.inspectAlarmId);
  engine.choose(LanternMysteryFixture.openServiceDrawerId);
}

void _reachUnstablePassage(StoryEngine engine) {
  _obtainLantern(engine);
  engine.choose(LanternMysteryFixture.enterCorridorId);
  engine.choose(LanternMysteryFixture.enterCellarId);
  engine.choose(LanternMysteryFixture.enterUnstablePassageId);
}
