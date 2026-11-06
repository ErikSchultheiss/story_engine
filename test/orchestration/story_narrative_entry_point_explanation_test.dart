import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StoryNarrativeRuntime entry-point explanations', () {
    test(
      'single-candidate probe distinguishes state rejection and host facts',
      () {
        final allowed = StoryVariableId('allowed');
        final eventId = StoryEventId('eligibility_event');
        final entryId = StoryEntryPointId('eligibility_entry');
        final firstHost = StoryHostConditionKey('first_host');
        final secondHost = StoryHostConditionKey('second_host');
        final runtime = StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('eligibility_project'),
            stateSchema: StoryStateSchema(
              variables: [
                StoryVariableDefinition(
                  id: allowed,
                  type: StoryValueType.boolean,
                  initialValue: const StoryBooleanValue(true),
                ),
              ],
            ),
            events: [_continuationEvent(eventId)],
          ),
          entryPoints: [
            StoryEntryPoint(
              id: entryId,
              eventId: eventId,
              eligibilityCondition: StoryVariableComparisonCondition(
                variableId: allowed,
                operator: StoryComparisonOperator.equal,
                value: const StoryBooleanValue(true),
              ),
              hostConditions: [
                StoryHostConditionRequirement(
                  key: firstHost,
                  schemaNamespace: 'com.example.world',
                  conditionId: 'first_check',
                ),
                StoryHostConditionRequirement(
                  key: secondHost,
                  schemaNamespace: 'com.example.world',
                  conditionId: 'second_check',
                ),
              ],
            ),
          ],
        );

        final mismatch = runtime.explainEntryPointEligibility(
          entryId,
          hostContext: StoryHostContext(
            conditionResults: {firstHost: false, secondHost: true},
          ),
        );
        expect(
          mismatch.status,
          StoryEntryPointCandidateStatus.hostConditionRejected,
        );
        expect(mismatch.eligibilityCondition?.result, isTrue);
        expect(mismatch.evaluatedHostConditions, hasLength(1));
        expect(
          mismatch.evaluatedHostConditions.single.status,
          StoryHostConditionExplanationStatus.mismatched,
        );

        final missing = runtime.explainEntryPointEligibility(
          entryId,
          hostContext: StoryHostContext(conditionResults: {firstHost: true}),
        );
        expect(
          missing.status,
          StoryEntryPointCandidateStatus.hostConditionMissing,
        );
        expect(missing.evaluatedHostConditions, hasLength(2));
        expect(
          missing.evaluatedHostConditions.last.status,
          StoryHostConditionExplanationStatus.missing,
        );
        expect(runtime.history.sessions, isEmpty);
      },
    );

    test(
      'session exposes choice explanations and hides them while awaiting host',
      () {
        final eventId = StoryEventId('session_choice_event');
        final entryId = StoryEntryPointId('session_choice_entry');
        final choiceId = StoryChoiceId('session_choice');
        final runtime = StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('session_choice_project'),
            events: [
              StoryEvent(
                id: eventId,
                choices: [
                  StoryChoice(
                    id: choiceId,
                    transition: const StoryTerminalTransition(),
                  ),
                ],
              ),
            ],
          ),
          entryPoints: [StoryEntryPoint(id: entryId, eventId: eventId)],
        );
        final session = runtime.startSession(entryId);

        expect(session.choiceExplanations.single.choiceId, choiceId);
        session.requestHostAction(
          schemaNamespace: 'com.example.action',
          actionId: 'pause',
        );
        expect(session.choiceExplanations, isEmpty);
      },
    );

    test(
      'resolution explains priority and leaves fallback candidates unevaluated',
      () {
        final lowId = StoryEntryPointId('regular_low');
        final fallbackId = StoryEntryPointId('fallback_middle');
        final highId = StoryEntryPointId('regular_high');
        final lowEvent = StoryEventId('regular_low_event');
        final fallbackEvent = StoryEventId('fallback_middle_event');
        final highEvent = StoryEventId('regular_high_event');
        final runtime = StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('priority_explanation_project'),
            events: [
              _continuationEvent(lowEvent),
              _continuationEvent(fallbackEvent),
              _continuationEvent(highEvent),
            ],
          ),
          entryPoints: [
            StoryEntryPoint(id: lowId, eventId: lowEvent, priority: 1),
            StoryEntryPoint(
              id: fallbackId,
              eventId: fallbackEvent,
              priority: 999,
              isFallback: true,
            ),
            StoryEntryPoint(id: highId, eventId: highEvent, priority: 10),
          ],
        );

        final result = runtime.resolveAndStartSessionWithExplanation();
        final explanation = result.explanation;

        expect(result.session?.entryPoint.id, highId);
        expect(
          explanation.selectionMethod,
          StoryEntryPointSelectionMethod.soleFinalist,
        );
        expect(explanation.selectedEntryPointId, highId);
        expect(explanation.winningFallbackTier, isFalse);
        expect(explanation.winningPriority, 10);
        expect(
          explanation.candidates.map((candidate) => candidate.entryPointId),
          [lowId, fallbackId, highId],
        );
        expect(explanation.candidates.map((candidate) => candidate.status), [
          StoryEntryPointCandidateStatus.eligible,
          StoryEntryPointCandidateStatus.notEvaluated,
          StoryEntryPointCandidateStatus.eligible,
        ]);
        expect(explanation.totalWeight, isNull);
        expect(explanation.sampledWeightOffset, isNull);
      },
    );

    test(
      'weighted explanation records the authoritative draw exactly once',
      () {
        final firstId = StoryEntryPointId('weighted_first');
        final secondId = StoryEntryPointId('weighted_second');
        final firstEvent = StoryEventId('weighted_first_event');
        final secondEvent = StoryEventId('weighted_second_event');
        final project = StoryProject(
          id: StoryProjectId('weighted_explanation_project'),
          events: [
            _continuationEvent(firstEvent),
            _continuationEvent(secondEvent),
          ],
        );

        StoryNarrativeRuntime build() => StoryNarrativeRuntime(
          project: project,
          randomSeed: 0,
          entryPoints: [
            StoryEntryPoint(id: firstId, eventId: firstEvent, weight: 1),
            StoryEntryPoint(id: secondId, eventId: secondEvent, weight: 3),
          ],
        );

        final plain = build().resolveAndStartSession()!;
        final diagnosticRuntime = build();
        final diagnostic = diagnosticRuntime
            .resolveAndStartSessionWithExplanation();
        final explainedSession = diagnostic.session!;
        final explanation = diagnostic.explanation;

        expect(explainedSession.entryPoint.id, plain.entryPoint.id);
        expect(explainedSession.randomSeed, plain.randomSeed);
        expect(explainedSession.entryPoint.id, secondId);
        expect(explainedSession.randomSeed, 2868466484);
        expect(
          explanation.selectionMethod,
          StoryEntryPointSelectionMethod.weightedDraw,
        );
        expect(explanation.selectedEntryPointId, secondId);
        expect(explanation.totalWeight, 4);
        expect(explanation.sampledWeightOffset, 2);
        expect(explanation.finalists.map((finalist) => finalist.entryPointId), [
          firstId,
          secondId,
        ]);
      },
    );

    test(
      'no eligible candidate returns a complete no-selection explanation',
      () {
        final enabled = StoryVariableId('enabled');
        final regularId = StoryEntryPointId('blocked_regular');
        final fallbackId = StoryEntryPointId('blocked_fallback');
        final regularEvent = StoryEventId('blocked_regular_event');
        final fallbackEvent = StoryEventId('blocked_fallback_event');
        final falseCondition = StoryVariableComparisonCondition(
          variableId: enabled,
          operator: StoryComparisonOperator.equal,
          value: const StoryBooleanValue(true),
        );
        final runtime = StoryNarrativeRuntime(
          project: StoryProject(
            id: StoryProjectId('no_selection_explanation_project'),
            stateSchema: StoryStateSchema(
              variables: [
                StoryVariableDefinition(
                  id: enabled,
                  type: StoryValueType.boolean,
                  initialValue: const StoryBooleanValue(false),
                ),
              ],
            ),
            events: [
              _continuationEvent(regularEvent),
              _continuationEvent(fallbackEvent),
            ],
          ),
          entryPoints: [
            StoryEntryPoint(
              id: regularId,
              eventId: regularEvent,
              eligibilityCondition: falseCondition,
            ),
            StoryEntryPoint(
              id: fallbackId,
              eventId: fallbackEvent,
              eligibilityCondition: falseCondition,
              isFallback: true,
            ),
          ],
        );

        final result = runtime.resolveAndStartSessionWithExplanation();

        expect(result.session, isNull);
        expect(
          result.explanation.selectionMethod,
          StoryEntryPointSelectionMethod.none,
        );
        expect(
          result.explanation.candidates.map((candidate) => candidate.status),
          [
            StoryEntryPointCandidateStatus.stateConditionRejected,
            StoryEntryPointCandidateStatus.stateConditionRejected,
          ],
        );
        expect(runtime.history.sessions, isEmpty);
      },
    );

    test('authoritative resolution still rejects missing host facts', () {
      final eventId = StoryEventId('missing_host_event');
      final entryId = StoryEntryPointId('missing_host_entry');
      final key = StoryHostConditionKey('required_fact');
      final runtime = StoryNarrativeRuntime(
        project: StoryProject(
          id: StoryProjectId('missing_host_project'),
          events: [_continuationEvent(eventId)],
        ),
        entryPoints: [
          StoryEntryPoint(
            id: entryId,
            eventId: eventId,
            hostConditions: [
              StoryHostConditionRequirement(
                key: key,
                schemaNamespace: 'com.example.world',
                conditionId: 'required_fact',
              ),
            ],
          ),
        ],
      );

      expect(
        () => runtime.resolveAndStartSessionWithExplanation(),
        throwsA(isA<StoryNarrativeResolutionException>()),
      );
      expect(runtime.history.sessions, isEmpty);
    });
  });
}

StoryEvent _continuationEvent(StoryEventId id) =>
    StoryEvent(id: id, continuationTransition: const StoryTerminalTransition());
