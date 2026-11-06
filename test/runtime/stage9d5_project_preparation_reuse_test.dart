import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 9D5 prepared restore reuse', () {
    test('public restore preserves exact committed checkpoint', () {
      final fixture = _fixture();
      final source = StoryEngine(project: fixture.project, randomSeed: 0x9d5)
        ..start();
      source.choose(fixture.loopChoiceId);
      final snapshot = source.createSnapshot();

      final restored = StoryEngine.restore(
        project: fixture.project,
        snapshot: snapshot,
      );

      expect(restored.createSnapshot(), snapshot);
      expect(source.createSnapshot(), snapshot);
    });

    test('public restore preserves validation error ordering', () {
      final fixture = _fixture();
      final validSnapshot = StoryEngine(
        project: fixture.project,
      ).createSnapshot();
      final invalidSnapshot = StoryRuntimeSnapshot(
        metadata: const StoryRuntimeSnapshotMetadata(formatVersion: 999),
        projectId: validSnapshot.projectId,
        status: validSnapshot.status,
        state: validSnapshot.state,
        currentEventId: validSnapshot.currentEventId,
        history: validSnapshot.history,
        randomState: validSnapshot.randomState,
        maxAutomaticTransitions: validSnapshot.maxAutomaticTransitions,
      );
      final event = fixture.project.events.first;
      final duplicateProject = StoryProject(
        id: fixture.project.id,
        events: <StoryEvent>[event, event],
        entryEventId: event.id,
      );

      expect(
        () => StoryEngine.restore(
          project: duplicateProject,
          snapshot: invalidSnapshot,
        ),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.unsupportedFormatVersion,
          ),
        ),
      );
    });

    test('public restore keeps duplicate-event compatibility diagnostics', () {
      final fixture = _fixture();
      final snapshot = StoryEngine(project: fixture.project).createSnapshot();
      final event = fixture.project.events.first;
      final duplicateProject = StoryProject(
        id: fixture.project.id,
        events: <StoryEvent>[event, event],
        entryEventId: event.id,
      );

      expect(
        () =>
            StoryEngine.restore(project: duplicateProject, snapshot: snapshot),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.duplicateProjectEventId,
          ),
        ),
      );
    });

    test('public restore keeps duplicate-choice compatibility diagnostics', () {
      final fixture = _fixture();
      final snapshot = StoryEngine(project: fixture.project).createSnapshot();
      final eventId = fixture.project.events.first.id;
      final duplicateChoiceId = StoryChoiceId('duplicate_choice');
      final duplicateProject = StoryProject(
        id: fixture.project.id,
        events: <StoryEvent>[
          StoryEvent(
            id: eventId,
            choices: <StoryChoice>[
              StoryChoice(
                id: duplicateChoiceId,
                transition: const StoryTerminalTransition(),
              ),
              StoryChoice(
                id: duplicateChoiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
        entryEventId: eventId,
      );

      expect(
        () =>
            StoryEngine.restore(project: duplicateProject, snapshot: snapshot),
        throwsA(
          isA<StoryRuntimeSnapshotCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryRuntimeSnapshotCompatibilityIssue.duplicateProjectChoiceId,
          ),
        ),
      );
    });
  });
}

_Fixture _fixture() {
  final eventId = StoryEventId('stage9d5_event');
  final loopChoiceId = StoryChoiceId('stage9d5_loop_choice');
  return _Fixture(
    project: StoryProject(
      id: StoryProjectId('stage9d5_project'),
      events: <StoryEvent>[
        StoryEvent(
          id: eventId,
          choices: <StoryChoice>[
            StoryChoice(
              id: loopChoiceId,
              transition: StoryEventTransition(destinationEventId: eventId),
            ),
          ],
        ),
      ],
      entryEventId: eventId,
    ),
    loopChoiceId: loopChoiceId,
  );
}

final class _Fixture {
  const _Fixture({required this.project, required this.loopChoiceId});

  final StoryProject project;
  final StoryChoiceId loopChoiceId;
}
