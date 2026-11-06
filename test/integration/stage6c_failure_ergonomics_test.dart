import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 6C consumer failure ergonomics', () {
    test(
      'validation report is actionable without knowing internal validators',
      () {
        final project = StoryProject(
          id: StoryProjectId('stage6c_invalid_project'),
          events: [
            StoryEvent(
              id: StoryEventId('event_orphan'),
              automaticTransition: const StoryTerminalTransition(),
            ),
          ],
        );

        final report = StoryValidator.validate(project);

        expect(report.isValid, isFalse);
        expect(report.summary, startsWith('1 error'));
        final diagnostic = report
            .diagnosticsFor(StoryDiagnosticCode.structureMissingEntryEvent)
            .single;
        expect(diagnostic.suggestion, contains('entryEventId'));
        expect(report.format(), contains('structure.missing_entry_event'));
        expect(report.format(), contains('Suggested fix:'));
      },
    );

    test('invalid choice selection reports operation and authored IDs', () {
      final eventId = StoryEventId('event_start');
      final validChoiceId = StoryChoiceId('choice_valid');
      final missingChoiceId = StoryChoiceId('choice_missing');
      final project = StoryProject(
        id: StoryProjectId('stage6c_runtime_context'),
        entryEventId: eventId,
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: validChoiceId,
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project)..start();

      expect(
        () => engine.choose(missingChoiceId),
        throwsA(
          isA<StoryEngineOperationException>()
              .having((error) => error.operation, 'operation', 'choose')
              .having((error) => error.eventId, 'eventId', eventId)
              .having((error) => error.choiceId, 'choiceId', missingChoiceId)
              .having(
                (error) => error.suggestion,
                'suggestion',
                contains('availableChoices'),
              ),
        ),
      );
    });

    test('runtime authored failure keeps cause plus operation context', () {
      final variableId = StoryVariableId('trust');
      final eventId = StoryEventId('event_start');
      final choiceId = StoryChoiceId('choice_bad_condition');
      final project = StoryProject(
        id: StoryProjectId('stage6c_runtime_cause'),
        entryEventId: eventId,
        stateSchema: StoryStateSchema(
          variables: [
            StoryVariableDefinition(
              id: variableId,
              type: StoryValueType.integer,
              initialValue: StoryIntegerValue(1),
            ),
          ],
        ),
        events: [
          StoryEvent(
            id: eventId,
            choices: [
              StoryChoice(
                id: choiceId,
                availabilityCondition: StoryVariableComparisonCondition(
                  variableId: variableId,
                  operator: StoryComparisonOperator.equal,
                  value: const StoryStringValue('wrong type'),
                ),
                transition: const StoryTerminalTransition(),
              ),
            ],
          ),
        ],
      );
      final engine = StoryEngine(project: project)..start();

      expect(
        () => engine.availableChoices,
        throwsA(
          isA<StoryEngineExecutionException>()
              .having(
                (error) => error.operation,
                'operation',
                'availableChoices',
              )
              .having((error) => error.eventId, 'eventId', eventId)
              .having(
                (error) => error.cause,
                'cause',
                isA<StoryConditionEvaluationException>(),
              )
              .having((error) => error.suggestion, 'suggestion', isNotEmpty),
        ),
      );
    });
  });
}
