import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 3 public validation contract', () {
    test('validator can inspect incomplete authored data without runtime use', () {
      final project = StoryProject(
        id: StoryProjectId('project_validation_contract'),
      );

      final report = StoryValidator.validate(project);

      expect(report.projectId, project.id);
      expect(report.diagnostics, hasLength(1));
      expect(report.errors, hasLength(1));
      expect(
        report.errors.single.code,
        StoryDiagnosticCode.structureMissingEntryEvent,
      );
      expect(report.warnings, isEmpty);
      expect(report.information, isEmpty);
      expect(report.hasErrors, isTrue);
      expect(report.isValid, isFalse);
    });

    test('diagnostic identity is independent of message and severity', () {
      final projectId = StoryProjectId('project_validation_identity');
      final eventId = StoryEventId('event_identity');
      final location = StoryDiagnosticLocation.event(
        projectId: projectId,
        eventId: eventId,
        path: const [
          StoryDiagnosticPathSegment.field('events'),
          StoryDiagnosticPathSegment.index(0),
        ],
      );
      const code = StoryDiagnosticCode('test.identity');
      final reference = StoryDiagnosticReference.event(
        StoryEventId('missing_destination'),
      );

      final first = StoryDiagnostic(
        code: code,
        severity: StoryDiagnosticSeverity.error,
        message: 'First wording.',
        location: location,
        references: [reference],
      );
      final second = StoryDiagnostic(
        code: code,
        severity: StoryDiagnosticSeverity.warning,
        message: 'Localized or revised wording.',
        location: location,
        references: [reference],
      );

      expect(first.identity, second.identity);
      expect(first, isNot(second));
    });

    test('structured paths remain machine-readable and numeric', () {
      final projectId = StoryProjectId('project_validation_paths');
      final eventId = StoryEventId('event_path');
      final choiceId = StoryChoiceId('choice_path');
      final location = StoryDiagnosticLocation.transition(
        projectId: projectId,
        eventId: eventId,
        choiceId: choiceId,
        path: const [
          StoryDiagnosticPathSegment.field('events'),
          StoryDiagnosticPathSegment.index(3),
          StoryDiagnosticPathSegment.field('choices'),
          StoryDiagnosticPathSegment.index(1),
          StoryDiagnosticPathSegment.field('transition'),
          StoryDiagnosticPathSegment.field('branches'),
          StoryDiagnosticPathSegment.index(2),
        ],
      );

      expect(
        location.pathString,
        'events[3].choices[1].transition.branches[2]',
      );
      expect(location.kind, StoryDiagnosticLocationKind.transition);
      expect(location.eventId, eventId);
      expect(location.choiceId, choiceId);
    });

    test('diagnostics carry unresolved entity IDs as structured references', () {
      final projectId = StoryProjectId('project_validation_references');
      final eventId = StoryEventId('event_source');
      final missingEventId = StoryEventId('event_missing');
      final undeclaredVariableId = StoryVariableId('variable_missing');
      final location = StoryDiagnosticLocation.transition(
        projectId: projectId,
        eventId: eventId,
        path: const [
          StoryDiagnosticPathSegment.field('events'),
          StoryDiagnosticPathSegment.index(0),
          StoryDiagnosticPathSegment.field('automaticTransition'),
        ],
      );

      final diagnostic = StoryDiagnostic(
        code: const StoryDiagnosticCode('test.references'),
        severity: StoryDiagnosticSeverity.error,
        message: 'Broken references.',
        location: location,
        references: [
          StoryDiagnosticReference.variable(undeclaredVariableId),
          StoryDiagnosticReference.event(missingEventId),
        ],
      );

      expect(
        diagnostic.references,
        [
          StoryDiagnosticReference.event(missingEventId),
          StoryDiagnosticReference.variable(undeclaredVariableId),
        ],
      );
    });

    test('report canonicalizes diagnostic and related-location ordering', () {
      final projectId = StoryProjectId('project_validation_order');
      final event2 = StoryEventId('event_2');
      final event10 = StoryEventId('event_10');
      final variableA = StoryVariableId('variable_a');
      final variableB = StoryVariableId('variable_b');

      final event2Location = StoryDiagnosticLocation.event(
        projectId: projectId,
        eventId: event2,
        path: const [
          StoryDiagnosticPathSegment.field('events'),
          StoryDiagnosticPathSegment.index(2),
        ],
      );
      final event10Location = StoryDiagnosticLocation.event(
        projectId: projectId,
        eventId: event10,
        path: const [
          StoryDiagnosticPathSegment.field('events'),
          StoryDiagnosticPathSegment.index(10),
        ],
      );
      final variableALocation = StoryDiagnosticLocation.variable(
        projectId: projectId,
        variableId: variableA,
      );
      final variableBLocation = StoryDiagnosticLocation.variable(
        projectId: projectId,
        variableId: variableB,
      );

      final later = StoryDiagnostic(
        code: const StoryDiagnosticCode('test.later'),
        severity: StoryDiagnosticSeverity.warning,
        message: 'Later.',
        location: event10Location,
        relatedLocations: [variableBLocation, variableALocation],
      );
      final earlier = StoryDiagnostic(
        code: const StoryDiagnosticCode('test.earlier'),
        severity: StoryDiagnosticSeverity.error,
        message: 'Earlier.',
        location: event2Location,
      );

      final report = StoryValidationReport(
        projectId: projectId,
        diagnostics: [later, earlier],
      );

      expect(report.diagnostics, [earlier, later]);
      expect(later.relatedLocations, [variableALocation, variableBLocation]);
      expect(report.errors, [earlier]);
      expect(report.warnings, [later]);
      expect(report.information, isEmpty);
      expect(report.hasErrors, isTrue);
      expect(report.isValid, isFalse);
    });

    test('report rejects duplicate machine identity', () {
      final projectId = StoryProjectId('project_validation_duplicates');
      final location = StoryDiagnosticLocation.project(projectId: projectId);
      const code = StoryDiagnosticCode('test.duplicate_identity');

      final first = StoryDiagnostic(
        code: code,
        severity: StoryDiagnosticSeverity.error,
        message: 'First.',
        location: location,
      );
      final duplicate = StoryDiagnostic(
        code: code,
        severity: StoryDiagnosticSeverity.warning,
        message: 'Second.',
        location: location,
      );

      expect(
        () => StoryValidationReport(
          projectId: projectId,
          diagnostics: [first, duplicate],
        ),
        throwsArgumentError,
      );
    });

    test('report rejects diagnostics belonging to another project', () {
      final projectId = StoryProjectId('project_validation_report');
      final otherProjectId = StoryProjectId('project_validation_other');
      final diagnostic = StoryDiagnostic(
        code: const StoryDiagnosticCode('test.cross_project'),
        severity: StoryDiagnosticSeverity.error,
        message: 'Wrong project.',
        location: StoryDiagnosticLocation.project(projectId: otherProjectId),
      );

      expect(
        () => StoryValidationReport(
          projectId: projectId,
          diagnostics: [diagnostic],
        ),
        throwsArgumentError,
      );
    });
  });
}
