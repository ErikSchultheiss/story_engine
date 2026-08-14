import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 6C error and validation ergonomics', () {
    test('every engine-owned validation code has actionable guidance', () {
      final projectId = StoryProjectId('stage6c_diagnostics');
      final location = StoryDiagnosticLocation.project(
        projectId: projectId,
        path: const [StoryDiagnosticPathSegment.field('entryEventId')],
      );

      for (final code in _engineOwnedCodes) {
        final diagnostic = StoryDiagnostic(
          code: code,
          severity: StoryDiagnosticSeverity.error,
          message: 'Synthetic Stage 6C diagnostic.',
          location: location,
        );

        expect(
          diagnostic.suggestion,
          isNotNull,
          reason: '${code.value} should help a developer repair the problem.',
        );
        expect(diagnostic.suggestion!.trim(), isNotEmpty);
      }
    });

    test('diagnostic formatting preserves structured identity and adds help', () {
      final projectId = StoryProjectId('stage6c_format');
      final eventId = StoryEventId('event_gate');
      final choiceId = StoryChoiceId('choice_open');
      final location = StoryDiagnosticLocation.choice(
        projectId: projectId,
        eventId: eventId,
        choiceId: choiceId,
        path: const [
          StoryDiagnosticPathSegment.field('events'),
          StoryDiagnosticPathSegment.index(2),
          StoryDiagnosticPathSegment.field('choices'),
          StoryDiagnosticPathSegment.index(1),
          StoryDiagnosticPathSegment.field('transition'),
        ],
      );
      final diagnostic = StoryDiagnostic(
        code: StoryDiagnosticCode.structureChoiceMissingTransition,
        severity: StoryDiagnosticSeverity.error,
        message: 'Choice has no transition.',
        location: location,
        references: [StoryDiagnosticReference.choice(choiceId)],
      );

      expect(
        location.displayString,
        'choice choice_open in event event_gate @ '
        'events[2].choices[1].transition',
      );
      expect(
        diagnostic.format(),
        contains('ERROR [structure.choice_missing_transition]'),
      );
      expect(diagnostic.format(), contains(location.displayString));
      expect(diagnostic.format(), contains('Suggested fix:'));
      expect(
        diagnostic.format(includeSuggestion: false),
        isNot(contains('Suggested fix:')),
      );
    });

    test('validation report exposes concise counts, filtering, and formatting', () {
      final projectId = StoryProjectId('stage6c_report');
      final location = StoryDiagnosticLocation.project(
        projectId: projectId,
        path: const [StoryDiagnosticPathSegment.field('entryEventId')],
      );
      final report = StoryValidationReport(
        projectId: projectId,
        diagnostics: [
          StoryDiagnostic(
            code: StoryDiagnosticCode.structureMissingEntryEvent,
            severity: StoryDiagnosticSeverity.error,
            message: 'Project has no entry event.',
            location: location,
          ),
          StoryDiagnostic(
            code: StoryDiagnosticCode.graphEventCannotReachTermination,
            severity: StoryDiagnosticSeverity.warning,
            message: 'No route to termination.',
            location: StoryDiagnosticLocation.project(
              projectId: projectId,
              path: const [StoryDiagnosticPathSegment.field('events')],
            ),
          ),
          StoryDiagnostic(
            code: StoryDiagnosticCode.presentationEventEmptyText,
            severity: StoryDiagnosticSeverity.information,
            message: 'Presentation text is empty.',
            location: StoryDiagnosticLocation.project(
              projectId: projectId,
              path: const [StoryDiagnosticPathSegment.field('presentation')],
            ),
          ),
        ],
      );

      expect(report.errorCount, 1);
      expect(report.warningCount, 1);
      expect(report.informationCount, 1);
      expect(report.hasErrors, isTrue);
      expect(report.hasWarnings, isTrue);
      expect(report.hasInformation, isTrue);
      expect(report.summary, '1 error, 1 warning, 1 information');
      expect(
        report.diagnosticsFor(StoryDiagnosticCode.structureMissingEntryEvent),
        hasLength(1),
      );
      expect(report.format(), contains('Suggested fix:'));
      expect(
        report.format(includeInformation: false),
        isNot(contains('presentation.event_empty_text')),
      );
    });

    test('public engine exceptions carry structured operation context', () {
      final eventId = StoryEventId('event_current');
      final choiceId = StoryChoiceId('choice_missing');
      final exception = StoryEngineOperationException(
        message: 'Choice is unavailable.',
        operation: 'choose',
        eventId: eventId,
        choiceId: choiceId,
        suggestion: 'Select an available choice.',
      );

      expect(
        exception.contextString,
        'operation=choose, event=event_current, choice=choice_missing',
      );
      expect(exception.toString(), contains('Suggested fix:'));
      expect(exception.toString(), contains('operation=choose'));
    });

    test('public persistence/format failures expose location and recovery help', () {
      const codec = StoryFormatCodecException(
        bundlePath: 'project.json',
        jsonPath: r'$.project.id',
        message: 'Expected a string.',
      );
      const compatibility = StoryFormatCompatibilityException(
        issue: StoryFormatCompatibilityIssue.unsupportedFormatVersion,
        bundlePath: 'project.json',
        jsonPath: r'$.formatVersion',
        message: 'Unsupported version.',
        foundFormatVersion: 99,
      );
      const snapshotFormat = StoryRuntimeSnapshotFormatException(
        r'$.state',
        'Expected an object.',
      );
      const snapshotCompatibility =
          StoryRuntimeSnapshotCompatibilityException(
            issue: StoryRuntimeSnapshotCompatibilityIssue.projectIdMismatch,
            path: r'$.projectId',
            message: 'Different project.',
          );

      expect(codec.location, r'project.json:$.project.id');
      expect(codec.suggestion, isNotEmpty);
      expect(compatibility.location, r'project.json:$.formatVersion');
      expect(compatibility.suggestion, contains('version 99'));
      expect(snapshotFormat.location, r'$.state');
      expect(snapshotFormat.suggestion, isNotEmpty);
      expect(snapshotCompatibility.location, r'$.projectId');
      expect(snapshotCompatibility.suggestion, contains('StoryProject'));
    });

    test('Stage 6C keeps the Stage 6A top-level symbol inventory', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final exports = RegExp(
        r'''export\s+['"][^'"]+['"]\s+show\s+([^;]+);''',
        multiLine: true,
      ).allMatches(barrel);
      final symbols = <String>{
        for (final export in exports)
          ...export
              .group(1)!
              .split(',')
              .map((symbol) => symbol.trim())
              .where((symbol) => symbol.isNotEmpty),
      };

      expect(symbols, hasLength(98));
    });
  });
}

const _engineOwnedCodes = <StoryDiagnosticCode>[
  StoryDiagnosticCode.structureMissingEntryEvent,
  StoryDiagnosticCode.structureEntryEventNotFound,
  StoryDiagnosticCode.identityDuplicateEventId,
  StoryDiagnosticCode.identityDuplicateChoiceId,
  StoryDiagnosticCode.structureChoiceMissingTransition,
  StoryDiagnosticCode.structureEventMissingFlow,
  StoryDiagnosticCode.structureEventAmbiguousFlow,
  StoryDiagnosticCode.referenceMissingTransitionDestination,
  StoryDiagnosticCode.referenceUndeclaredConditionVariable,
  StoryDiagnosticCode.referenceUndeclaredEffectVariable,
  StoryDiagnosticCode.typeConditionOperandMismatch,
  StoryDiagnosticCode.typeConditionOperatorNotSupported,
  StoryDiagnosticCode.typeEffectValueMismatch,
  StoryDiagnosticCode.typeNumericEffectTargetNotNumeric,
  StoryDiagnosticCode.typeNumericEffectAmountMismatch,
  StoryDiagnosticCode.stateReadMayBeUnset,
  StoryDiagnosticCode.stateNumericEffectTargetUnset,
  StoryDiagnosticCode.stateNumericEffectTargetMayBeUnset,
  StoryDiagnosticCode.stateVariableNeverReferenced,
  StoryDiagnosticCode.stateVariableWrittenNeverRead,
  StoryDiagnosticCode.stateVariableReadWithoutInitialization,
  StoryDiagnosticCode.graphUnreachableEvent,
  StoryDiagnosticCode.graphInteractiveCycle,
  StoryDiagnosticCode.graphContinuationCycle,
  StoryDiagnosticCode.graphAutomaticCycle,
  StoryDiagnosticCode.graphMixedCycle,
  StoryDiagnosticCode.graphEventCannotReachTermination,
  StoryDiagnosticCode.presentationChoiceMissingText,
  StoryDiagnosticCode.presentationEventEmptyText,
  StoryDiagnosticCode.presentationContinuationWithoutMeaningfulPresentation,
  StoryDiagnosticCode.presentationAutomaticEventPresentationNotHostVisible,
];
