import 'package:story_engine/story_engine.dart';

/// Canonical Stage 2 reference project.
///
/// This fixture deliberately consumes only the public story_engine barrel. It
/// is engineered for architecture coverage rather than literary quality.
final class LanternMysteryFixture {
  LanternMysteryFixture._();

  static const int safeSeed = 0;
  static const int collapseSeed = 1;

  static final StoryProjectId projectId = StoryProjectId('prj_0001');

  static final StoryVariableId hasLanternId = StoryVariableId('var_0001');
  static final StoryVariableId caretakerTrustId = StoryVariableId('var_0002');
  static final StoryVariableId temperatureId = StoryVariableId('var_0003');
  static final StoryVariableId codenameId = StoryVariableId('var_0004');
  static final StoryVariableId alarmTriggeredId = StoryVariableId('var_0005');
  static final StoryVariableId knowsSafeRouteId = StoryVariableId('var_0006');

  static final StoryEventId foyerId = StoryEventId('evt_0001');
  static final StoryEventId caretakerId = StoryEventId('evt_0002');
  static final StoryEventId libraryId = StoryEventId('evt_0003');
  static final StoryEventId corridorId = StoryEventId('evt_0004');
  static final StoryEventId coldChamberId = StoryEventId('evt_0005');
  static final StoryEventId cellarId = StoryEventId('evt_0006');
  static final StoryEventId archiveId = StoryEventId('evt_0007');
  static final StoryEventId unstablePassageId = StoryEventId('evt_0008');
  static final StoryEventId oldTunnelId = StoryEventId('evt_0009');
  static final StoryEventId goodOutcomeId = StoryEventId('evt_0010');
  static final StoryEventId neutralOutcomeId = StoryEventId('evt_0011');
  static final StoryEventId badOutcomeId = StoryEventId('evt_0012');

  static final StoryChoiceId inspectAlarmId = StoryChoiceId('ch_0001');
  static final StoryChoiceId openServiceDrawerId = StoryChoiceId('ch_0002');
  static final StoryChoiceId visitCaretakerId = StoryChoiceId('ch_0003');
  static final StoryChoiceId enterCorridorId = StoryChoiceId('ch_0004');
  static final StoryChoiceId leaveFoyerId = StoryChoiceId('ch_0005');
  static final StoryChoiceId correctCodenameId = StoryChoiceId('ch_0006');
  static final StoryChoiceId fakeCodenameId = StoryChoiceId('ch_0007');
  static final StoryChoiceId refuseCodenameId = StoryChoiceId('ch_0008');
  static final StoryChoiceId readMaintenanceNoteId = StoryChoiceId('ch_0009');
  static final StoryChoiceId takeColdStairwayId = StoryChoiceId('ch_0010');
  static final StoryChoiceId enterCellarId = StoryChoiceId('ch_0011');
  static final StoryChoiceId resetAlarmId = StoryChoiceId('ch_0012');
  static final StoryChoiceId openArchiveId = StoryChoiceId('ch_0013');
  static final StoryChoiceId leaveCorridorId = StoryChoiceId('ch_0014');
  static final StoryChoiceId studyFrostId = StoryChoiceId('ch_0015');
  static final StoryChoiceId enterUnstablePassageId = StoryChoiceId('ch_0016');
  static final StoryChoiceId returnToCorridorFromCellarId = StoryChoiceId(
    'ch_0017',
  );
  static final StoryChoiceId followMarkedSafeRouteId = StoryChoiceId('ch_0018');
  static final StoryChoiceId takeUnmarkedStairwayId = StoryChoiceId('ch_0019');
  static final StoryChoiceId returnToCorridorFromArchiveId = StoryChoiceId(
    'ch_0020',
  );
  static final StoryChoiceId followChalkMarksId = StoryChoiceId('ch_0021');
  static final StoryChoiceId takeNearestExitId = StoryChoiceId('ch_0022');

  static StoryProject buildProject() {
    final archiveAccessCondition = _archiveAccessCondition();

    return StoryProject(
      id: projectId,
      alias: StoryAlias('lantern_mystery'),
      stateSchema: StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: hasLanternId,
            alias: StoryAlias('has_lantern'),
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
          StoryVariableDefinition(
            id: caretakerTrustId,
            alias: StoryAlias('caretaker_trust'),
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(40),
          ),
          StoryVariableDefinition(
            id: temperatureId,
            alias: StoryAlias('temperature'),
            type: StoryValueType.number,
            initialValue: StoryNumberValue(18.5),
          ),
          StoryVariableDefinition(
            id: codenameId,
            alias: StoryAlias('codename'),
            type: StoryValueType.string,
            initialValue: const StoryStringValue('Rook'),
          ),
          StoryVariableDefinition(
            id: alarmTriggeredId,
            alias: StoryAlias('alarm_triggered'),
            type: StoryValueType.boolean,
          ),
          StoryVariableDefinition(
            id: knowsSafeRouteId,
            alias: StoryAlias('knows_safe_route'),
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(false),
          ),
        ],
      ),
      entryEventId: foyerId,
      events: [
        _foyer(),
        _caretaker(),
        _library(),
        _corridor(archiveAccessCondition),
        _coldChamber(),
        _cellar(),
        _archive(archiveAccessCondition),
        _unstablePassage(),
        _oldTunnel(),
        _goodOutcome(),
        _neutralOutcome(),
        _badOutcome(),
      ],
    );
  }

  static StoryEvent _foyer() => StoryEvent(
    id: foyerId,
    alias: StoryAlias('foyer'),
    presentation: StoryEventPresentation(
      title: const StoryText('Foyer'),
      body: const StoryText(
        'You stand inside the entrance hall of an abandoned research station. '
        'A service drawer is built into one wall. Beside it is an old alarm '
        'panel. A caretaker waits behind a glass office door, and a dark '
        'corridor leads deeper into the building.',
      ),
    ),
    choices: [
      StoryChoice(
        id: inspectAlarmId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Inspect the alarm panel'),
        ),
        availabilityCondition: StoryVariableIsUnsetCondition(
          variableId: alarmTriggeredId,
        ),
        effects: [
          StorySetVariableEffect(
            variableId: alarmTriggeredId,
            value: const StoryBooleanValue(false),
          ),
        ],
        transition: StoryEventTransition(destinationEventId: foyerId),
      ),
      StoryChoice(
        id: openServiceDrawerId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Open the service drawer'),
        ),
        availabilityCondition: StoryAllCondition([
          _boolComparison(
            alarmTriggeredId,
            StoryComparisonOperator.notEqual,
            true,
          ),
          StoryNotCondition(
            _boolComparison(hasLanternId, StoryComparisonOperator.equal, true),
          ),
        ]),
        effects: [
          StorySetVariableEffect(
            variableId: hasLanternId,
            value: const StoryBooleanValue(true),
          ),
        ],
        transition: StoryEventTransition(destinationEventId: foyerId),
      ),
      StoryChoice(
        id: visitCaretakerId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Visit the caretaker'),
        ),
        transition: StoryEventTransition(destinationEventId: caretakerId),
      ),
      StoryChoice(
        id: enterCorridorId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Enter the dark corridor'),
        ),
        availabilityCondition: _boolComparison(
          hasLanternId,
          StoryComparisonOperator.equal,
          true,
        ),
        transition: StoryEventTransition(destinationEventId: corridorId),
      ),
      StoryChoice(
        id: leaveFoyerId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Leave the station'),
        ),
        transition: StoryEventTransition(destinationEventId: neutralOutcomeId),
      ),
    ],
  );

  static StoryEvent _caretaker() => StoryEvent(
    id: caretakerId,
    alias: StoryAlias('caretaker'),
    presentation: StoryEventPresentation(
      title: const StoryText('The Caretaker'),
      body: const StoryText(
        'The caretaker studies you suspiciously. “Codename?”',
      ),
    ),
    entryEffects: [
      StoryIncrementVariableEffect(
        variableId: caretakerTrustId,
        amount: StoryIntegerValue(5),
      ),
    ],
    choices: [
      StoryChoice(
        id: correctCodenameId,
        presentation: const StoryChoicePresentation(text: StoryText('“Rook.”')),
        availabilityCondition: _stringComparison(
          codenameId,
          StoryComparisonOperator.equal,
          'Rook',
        ),
        effects: [
          StoryIncrementVariableEffect(
            variableId: caretakerTrustId,
            amount: StoryIntegerValue(20),
          ),
        ],
        transition: StoryConditionalTransition(
          branches: [
            StoryConditionalTransitionBranch(
              condition: _integerComparison(
                caretakerTrustId,
                StoryComparisonOperator.greaterThanOrEqual,
                60,
              ),
              transition: StoryEventTransition(destinationEventId: libraryId),
            ),
          ],
          fallback: StoryEventTransition(destinationEventId: corridorId),
        ),
      ),
      StoryChoice(
        id: fakeCodenameId,
        presentation: const StoryChoicePresentation(text: StoryText('“Fox.”')),
        effects: [
          StorySetVariableEffect(
            variableId: codenameId,
            value: const StoryStringValue('Fox'),
          ),
          StorySetVariableEffect(
            variableId: alarmTriggeredId,
            value: const StoryBooleanValue(true),
          ),
        ],
        transition: StoryEventTransition(destinationEventId: corridorId),
      ),
      StoryChoice(
        id: refuseCodenameId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Say nothing'),
        ),
        transition: StoryEventTransition(destinationEventId: corridorId),
      ),
    ],
  );

  static StoryEvent _library() => StoryEvent(
    id: libraryId,
    alias: StoryAlias('library'),
    presentation: StoryEventPresentation(
      title: const StoryText('Library'),
      body: const StoryText(
        'The caretaker unlocks a narrow library. A maintenance note lies on a '
        'desk. At the rear, stone steps descend into a visibly colder part of '
        'the station.',
      ),
    ),
    availabilityCondition: _integerComparison(
      caretakerTrustId,
      StoryComparisonOperator.greaterThanOrEqual,
      60,
    ),
    choices: [
      StoryChoice(
        id: readMaintenanceNoteId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Read the maintenance note'),
        ),
        effects: [
          StorySetVariableEffect(
            variableId: knowsSafeRouteId,
            value: const StoryBooleanValue(true),
          ),
        ],
        transition: StoryEventTransition(destinationEventId: corridorId),
      ),
      StoryChoice(
        id: takeColdStairwayId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Take the cold stairway'),
        ),
        transition: StoryEventTransition(destinationEventId: coldChamberId),
      ),
    ],
  );

  static StoryEvent _corridor(
    StoryCondition archiveAccessCondition,
  ) => StoryEvent(
    id: corridorId,
    alias: StoryAlias('corridor'),
    presentation: StoryEventPresentation(
      title: const StoryText('Main Corridor'),
      body: const StoryText(
        'The corridor splits between a cellar stairway and a reinforced '
        'archive door. An alarm control box hangs beside the wall.',
      ),
    ),
    choices: [
      StoryChoice(
        id: enterCellarId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Enter the cellar'),
        ),
        availabilityCondition: StoryAllCondition([
          _boolComparison(hasLanternId, StoryComparisonOperator.equal, true),
          StoryNotCondition(
            _boolComparison(
              alarmTriggeredId,
              StoryComparisonOperator.equal,
              true,
            ),
          ),
        ]),
        transition: StoryEventTransition(destinationEventId: cellarId),
      ),
      StoryChoice(
        id: resetAlarmId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Reset the alarm wiring'),
        ),
        availabilityCondition: _boolComparison(
          alarmTriggeredId,
          StoryComparisonOperator.equal,
          true,
        ),
        effects: [StoryUnsetVariableEffect(variableId: alarmTriggeredId)],
        transition: StoryEventTransition(destinationEventId: corridorId),
      ),
      StoryChoice(
        id: openArchiveId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Open the archive door'),
        ),
        availabilityCondition: archiveAccessCondition,
        transition: StoryEventTransition(destinationEventId: archiveId),
      ),
      StoryChoice(
        id: leaveCorridorId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Give up and leave'),
        ),
        transition: StoryEventTransition(destinationEventId: neutralOutcomeId),
      ),
    ],
  );

  static StoryEvent _coldChamber() => StoryEvent(
    id: coldChamberId,
    alias: StoryAlias('cold_chamber'),
    presentation: StoryEventPresentation(
      title: const StoryText('Cold Chamber'),
      body: const StoryText(
        'The stairway passes through a freezing service chamber before '
        'reaching the cellar.',
      ),
    ),
    entryEffects: [
      StoryDecrementVariableEffect(
        variableId: temperatureId,
        amount: StoryNumberValue(2.5),
      ),
    ],
    continuationTransition: StoryEventTransition(destinationEventId: cellarId),
  );

  static StoryEvent _cellar() => StoryEvent(
    id: cellarId,
    alias: StoryAlias('cellar'),
    presentation: StoryEventPresentation(
      title: const StoryText('Cellar'),
      body: const StoryText(
        'The cellar contains a frost-covered wall and a narrow unstable '
        'passage leading underground.',
      ),
    ),
    choices: [
      StoryChoice(
        id: studyFrostId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Study the frost markings'),
        ),
        availabilityCondition: StoryAllCondition([
          _numberComparison(
            temperatureId,
            StoryComparisonOperator.lessThanOrEqual,
            16.0,
          ),
          StoryNotCondition(
            _boolComparison(
              knowsSafeRouteId,
              StoryComparisonOperator.equal,
              true,
            ),
          ),
        ]),
        effects: [
          StorySetVariableEffect(
            variableId: knowsSafeRouteId,
            value: const StoryBooleanValue(true),
          ),
        ],
        transition: StoryEventTransition(destinationEventId: cellarId),
      ),
      StoryChoice(
        id: enterUnstablePassageId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Enter the unstable passage'),
        ),
        availabilityCondition: _boolComparison(
          hasLanternId,
          StoryComparisonOperator.equal,
          true,
        ),
        transition: StoryEventTransition(destinationEventId: unstablePassageId),
      ),
      StoryChoice(
        id: returnToCorridorFromCellarId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Return upstairs'),
        ),
        transition: StoryEventTransition(destinationEventId: corridorId),
      ),
    ],
  );

  static StoryEvent _archive(StoryCondition archiveAccessCondition) =>
      StoryEvent(
        id: archiveId,
        alias: StoryAlias('archive'),
        presentation: StoryEventPresentation(
          title: const StoryText('Archive'),
          body: const StoryText(
            'Inside the archive you find old maps of the underground tunnels '
            'and records describing a safe emergency exit.',
          ),
        ),
        availabilityCondition: archiveAccessCondition,
        choices: [
          StoryChoice(
            id: followMarkedSafeRouteId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Follow the marked safe route'),
            ),
            availabilityCondition: _boolComparison(
              knowsSafeRouteId,
              StoryComparisonOperator.equal,
              true,
            ),
            transition: StoryEventTransition(destinationEventId: goodOutcomeId),
          ),
          StoryChoice(
            id: takeUnmarkedStairwayId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Take the unmarked stairway'),
            ),
            transition: StoryEventTransition(
              destinationEventId: unstablePassageId,
            ),
          ),
          StoryChoice(
            id: returnToCorridorFromArchiveId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Return to the corridor'),
            ),
            transition: StoryEventTransition(destinationEventId: corridorId),
          ),
        ],
      );

  static StoryEvent _unstablePassage() => StoryEvent(
    id: unstablePassageId,
    alias: StoryAlias('unstable_passage'),
    automaticTransition: StoryWeightedTransition(
      options: [
        StoryWeightedTransitionOption(
          weight: 3,
          transition: StoryEventTransition(destinationEventId: oldTunnelId),
        ),
        StoryWeightedTransitionOption(
          weight: 1,
          transition: StoryEventTransition(destinationEventId: badOutcomeId),
        ),
      ],
    ),
  );

  static StoryEvent _oldTunnel() => StoryEvent(
    id: oldTunnelId,
    alias: StoryAlias('old_tunnel'),
    presentation: StoryEventPresentation(
      title: const StoryText('Old Tunnel'),
      body: const StoryText(
        'You reach an old service tunnel. Faded chalk marks point toward one '
        'exit, while another passage appears shorter.',
      ),
    ),
    choices: [
      StoryChoice(
        id: followChalkMarksId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Follow the chalk marks'),
        ),
        availabilityCondition: _boolComparison(
          knowsSafeRouteId,
          StoryComparisonOperator.equal,
          true,
        ),
        transition: StoryEventTransition(destinationEventId: goodOutcomeId),
      ),
      StoryChoice(
        id: takeNearestExitId,
        presentation: const StoryChoicePresentation(
          text: StoryText('Take the nearest exit'),
        ),
        availabilityCondition: StoryNotCondition(
          _boolComparison(
            knowsSafeRouteId,
            StoryComparisonOperator.equal,
            true,
          ),
        ),
        transition: StoryEventTransition(destinationEventId: neutralOutcomeId),
      ),
    ],
  );

  static StoryEvent _goodOutcome() => _outcomeEvent(
    id: goodOutcomeId,
    alias: 'good_outcome',
    title: 'Safe Exit',
    body:
        'You find the marked emergency tunnel and leave the station safely '
        'with enough information to understand what happened there.',
  );

  static StoryEvent _neutralOutcome() => _outcomeEvent(
    id: neutralOutcomeId,
    alias: 'neutral_outcome',
    title: 'Outside Again',
    body:
        'You leave the station safely, although most of its secrets remain '
        'unsolved.',
  );

  static StoryEvent _badOutcome() => _outcomeEvent(
    id: badOutcomeId,
    alias: 'bad_outcome',
    title: 'Collapse',
    body:
        'The unstable passage gives way. Your exploration ends beneath a pile '
        'of fallen stone.',
  );

  static StoryEvent _outcomeEvent({
    required StoryEventId id,
    required String alias,
    required String title,
    required String body,
  }) => StoryEvent(
    id: id,
    alias: StoryAlias(alias),
    presentation: StoryEventPresentation(
      title: StoryText(title),
      body: StoryText(body),
    ),
    continuationTransition: const StoryTerminalTransition(),
  );

  static StoryCondition _archiveAccessCondition() => StoryAllCondition([
    _boolComparison(hasLanternId, StoryComparisonOperator.equal, true),
    StoryAnyCondition([
      _integerComparison(
        caretakerTrustId,
        StoryComparisonOperator.greaterThanOrEqual,
        60,
      ),
      _stringComparison(codenameId, StoryComparisonOperator.equal, 'Rook'),
    ]),
    StoryNotCondition(
      _boolComparison(alarmTriggeredId, StoryComparisonOperator.equal, true),
    ),
  ]);

  static StoryVariableComparisonCondition _boolComparison(
    StoryVariableId variableId,
    StoryComparisonOperator operator,
    bool value,
  ) => StoryVariableComparisonCondition(
    variableId: variableId,
    operator: operator,
    value: StoryBooleanValue(value),
  );

  static StoryVariableComparisonCondition _integerComparison(
    StoryVariableId variableId,
    StoryComparisonOperator operator,
    int value,
  ) => StoryVariableComparisonCondition(
    variableId: variableId,
    operator: operator,
    value: StoryIntegerValue(value),
  );

  static StoryVariableComparisonCondition _numberComparison(
    StoryVariableId variableId,
    StoryComparisonOperator operator,
    double value,
  ) => StoryVariableComparisonCondition(
    variableId: variableId,
    operator: operator,
    value: StoryNumberValue(value),
  );

  static StoryVariableComparisonCondition _stringComparison(
    StoryVariableId variableId,
    StoryComparisonOperator operator,
    String value,
  ) => StoryVariableComparisonCondition(
    variableId: variableId,
    operator: operator,
    value: StoryStringValue(value),
  );
}
