import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Prepublication 1B history validation', () {
    test(
      'pending automatic transition precedes choice event and ownership',
      () {
        _reject(
          [
            StoryEventEnteredStep(eventId: _automatic),
            StoryChoiceSelectedStep(eventId: _ghost, choiceId: _missingChoice),
          ],
          StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
          r'$.history.steps[1]',
          'An explicit choice cannot occur before the preceding synchronous '
              'transition has entered another event or terminated.',
          status: StoryEngineStatus.terminated,
        );
      },
    );

    test('pending automatic transition precedes continue event validation', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _automatic),
          StoryEventContinuedStep(eventId: _ghost),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        r'$.history.steps[1]',
        'An explicit continue cannot occur before the preceding synchronous '
            'transition has entered another event or terminated.',
        status: StoryEngineStatus.terminated,
      );
    });

    test('choice without active entry precedes missing event validation', () {
      _reject(
        [
          StoryChoiceSelectedStep(eventId: _ghost, choiceId: _missingChoice),
          StoryEventEnteredStep(eventId: _start),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        r'$.history.steps[0]',
        'Runtime action for ghost does not follow that event as the latest '
            'committed event entry.',
      );
    });

    test('continue without active entry precedes missing event validation', () {
      _reject(
        [
          StoryEventContinuedStep(eventId: _ghost),
          StoryEventEnteredStep(eventId: _start),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        r'$.history.steps[0]',
        'Runtime action for ghost does not follow that event as the latest '
            'committed event entry.',
      );
    });

    test('choice mode precedes checking the selected choice owner', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _pause),
          StoryChoiceSelectedStep(eventId: _pause, choiceId: _finish),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.historyActionModeMismatch,
        r'$.history.steps[1].eventId',
        'History selects a choice from event pause, but that event is no '
            'longer a valid interactive event.',
        status: StoryEngineStatus.terminated,
      );
    });

    test(
      'continue rejects an interactive event before final status checks',
      () {
        _reject(
          [
            StoryEventEnteredStep(eventId: _start),
            StoryEventContinuedStep(eventId: _start),
          ],
          StoryRuntimeSnapshotCompatibilityIssue.historyActionModeMismatch,
          r'$.history.steps[1].eventId',
          'History continues event start, but that event is no longer a valid '
              'continuation event.',
          status: StoryEngineStatus.terminated,
        );
      },
    );

    test('unknown choice preserves its precise issue and field path', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _start),
          StoryChoiceSelectedStep(eventId: _start, choiceId: _missingChoice),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.missingChoice,
        r'$.history.steps[1].choiceId',
        'Choice missing_choice no longer belongs to event start.',
      );
    });

    test('missing choice transition precedes terminal compatibility', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _start),
          StoryChoiceSelectedStep(eventId: _start, choiceId: _broken),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
        r'$.history.steps[1].choiceId',
        'Choice broken no longer has a transition that could have produced '
            'the persisted history.',
        status: StoryEngineStatus.terminated,
      );
    });

    test('non-terminated trace cannot stop after a synchronous choice', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _start),
          StoryChoiceSelectedStep(eventId: _start, choiceId: _forward),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        r'$.history',
        'A non-terminated snapshot cannot end while a synchronous transition '
            'still requires an event entry or terminal result.',
      );
    });

    test('unterminated continuation retains the same completion error', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _pause),
          StoryEventContinuedStep(eventId: _pause),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.invalidHistorySequence,
        r'$.history',
        'A non-terminated snapshot cannot end while a synchronous transition '
            'still requires an event entry or terminal result.',
        status: StoryEngineStatus.awaitingContinue,
      );
    });

    test('terminated trace with no transition uses the status path', () {
      _reject(
        [StoryEventEnteredStep(eventId: _start)],
        StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
        r'$.status',
        _terminalMessage,
        status: StoryEngineStatus.terminated,
      );
    });

    test(
      'terminated trace after an event-targeting choice uses choice path',
      () {
        _reject(
          [
            StoryEventEnteredStep(eventId: _start),
            StoryChoiceSelectedStep(eventId: _start, choiceId: _forward),
          ],
          StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          r'$.history.steps[1].choiceId',
          _terminalMessage,
          status: StoryEngineStatus.terminated,
        );
      },
    );

    test(
      'terminated trace after an event-targeting continue uses event path',
      () {
        _reject(
          [
            StoryEventEnteredStep(eventId: _pause),
            StoryEventContinuedStep(eventId: _pause),
          ],
          StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
          r'$.history.steps[1].eventId',
          _terminalMessage,
          status: StoryEngineStatus.terminated,
        );
      },
    );

    test('unreachable entered event is rejected before completion', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _start),
          StoryEventEnteredStep(eventId: _end),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.historyTransitionMismatch,
        r'$.history.steps[1].eventId',
        'History enters event end, but the preceding committed transition '
            'cannot structurally reach that event.',
        status: StoryEngineStatus.terminated,
      );
    });

    test('missing entered event precedes structural reachability', () {
      _reject(
        [
          StoryEventEnteredStep(eventId: _start),
          StoryEventEnteredStep(eventId: _ghost),
          StoryEventEnteredStep(eventId: _start),
        ],
        StoryRuntimeSnapshotCompatibilityIssue.missingEvent,
        r'$.history.steps[1].eventId',
        'Persisted event ghost no longer exists in the supplied project.',
      );
    });

    test(
      'automatic host-selected root, continue, choice and termination restore',
      () {
        final project = _project();
        final snapshot = _snapshot(project, [
          StoryEventEnteredStep(eventId: _automatic),
          StoryEventEnteredStep(eventId: _pause),
          StoryEventContinuedStep(eventId: _pause),
          StoryEventEnteredStep(eventId: _start),
          StoryChoiceSelectedStep(eventId: _start, choiceId: _finish),
        ], status: StoryEngineStatus.terminated);
        final codec = StoryRuntimeSnapshotCodec();
        final before = codec.encodeJson(snapshot);

        const StoryRuntimeSnapshotValidator().validate(
          snapshot: snapshot,
          project: project,
        );
        final restored = StoryEngine.restore(
          project: project,
          snapshot: snapshot,
        );

        expect(codec.encodeJson(snapshot), before);
        expect(restored.createSnapshot(), snapshot);
        expect(restored.status, StoryEngineStatus.terminated);
      },
    );

    test('empty not-started history still validates', () {
      final project = _project();
      final snapshot = StoryEngine(project: project).createSnapshot();
      expect(
        () => const StoryRuntimeSnapshotValidator().validate(
          snapshot: snapshot,
          project: project,
        ),
        returnsNormally,
      );
    });
  });
}

final _start = StoryEventId('start');
final _pause = StoryEventId('pause');
final _automatic = StoryEventId('automatic');
final _end = StoryEventId('end');
final _ghost = StoryEventId('ghost');
final _forward = StoryChoiceId('forward');
final _finish = StoryChoiceId('finish');
final _broken = StoryChoiceId('broken');
final _missingChoice = StoryChoiceId('missing_choice');

const _terminalMessage =
    'Snapshot is terminated, but the final committed history position has no '
    'authored transition that can structurally terminate.';

StoryProject _project() => StoryProject(
  id: StoryProjectId('history_validation'),
  entryEventId: _start,
  events: [
    StoryEvent(
      id: _start,
      choices: [
        StoryChoice(
          id: _forward,
          transition: StoryEventTransition(destinationEventId: _pause),
        ),
        StoryChoice(id: _finish, transition: const StoryTerminalTransition()),
        StoryChoice(id: _broken),
      ],
    ),
    StoryEvent(
      id: _pause,
      continuationTransition: StoryEventTransition(destinationEventId: _start),
    ),
    StoryEvent(
      id: _automatic,
      automaticTransition: StoryEventTransition(destinationEventId: _pause),
    ),
    StoryEvent(id: _end, automaticTransition: const StoryTerminalTransition()),
  ],
);

StoryRuntimeSnapshot _snapshot(
  StoryProject project,
  List<StoryRuntimeStep> steps, {
  StoryEngineStatus status = StoryEngineStatus.awaitingChoice,
}) => StoryRuntimeSnapshot(
  projectId: project.id,
  status: status,
  state: StoryState.initial(project.stateSchema),
  currentEventId: steps.whereType<StoryEventEnteredStep>().last.eventId,
  history: StoryRuntimeHistory(steps: steps),
  randomState: StoryRuntimeRandomState(
    algorithmId: 'story_engine.lcg32',
    algorithmVersion: 1,
    stateWords: const [17, 17],
  ),
  maxAutomaticTransitions: 10,
);

void _reject(
  List<StoryRuntimeStep> steps,
  StoryRuntimeSnapshotCompatibilityIssue issue,
  String path,
  String message, {
  StoryEngineStatus status = StoryEngineStatus.awaitingChoice,
}) {
  final project = _project();
  final snapshot = _snapshot(project, steps, status: status);
  expect(
    () => const StoryRuntimeSnapshotValidator().validate(
      snapshot: snapshot,
      project: project,
    ),
    throwsA(
      isA<StoryRuntimeSnapshotCompatibilityException>()
          .having((error) => error.issue, 'issue', issue)
          .having((error) => error.path, 'path', path)
          .having((error) => error.message, 'message', message),
    ),
  );
}
