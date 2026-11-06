import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    '1C suggestion lookup accepts an equal reconstructed diagnostic code',
    () {
      final original = StoryDiagnosticCode.structureMissingEntryEvent;
      final rebuilt = StoryDiagnosticCode(original.value);
      expect(identical(rebuilt, original), isFalse);
      expect(
        _diagnostic(rebuilt).suggestion,
        'Set StoryProject.entryEventId to the ID of an authored event.',
      );
      expect(_diagnostic(rebuilt).suggestion, _diagnostic(original).suggestion);
    },
  );

  test('1C condition and effect references retain their shared guidance', () {
    for (final code in [
      StoryDiagnosticCode.referenceUndeclaredConditionVariable,
      StoryDiagnosticCode.referenceUndeclaredEffectVariable,
    ]) {
      expect(
        _diagnostic(code).suggestion,
        'Declare the referenced variable in StoryStateSchema or update the '
        'authored reference.',
      );
    }
  });

  test('1C interactive and mixed cycles retain their shared guidance', () {
    for (final code in [
      StoryDiagnosticCode.graphInteractiveCycle,
      StoryDiagnosticCode.graphMixedCycle,
    ]) {
      expect(
        _diagnostic(code).suggestion,
        'Review the cycle and keep it only if repeated traversal is intentional.',
      );
    }
  });

  test('1C final presentation mapping retains its complete text', () {
    expect(
      _diagnostic(
        StoryDiagnosticCode
            .presentationAutomaticEventPresentationNotHostVisible,
      ).suggestion,
      'Move user-visible content to a host-visible event, or remove the '
      'unused automatic-event presentation.',
    );
  });

  test('1C extension codes retain null guidance and stable rendering', () {
    final diagnostic = _diagnostic(
      const StoryDiagnosticCode('extension.example'),
    );
    expect(diagnostic.suggestion, isNull);
    expect(diagnostic.format(), diagnostic.format(includeSuggestion: false));
  });
}

StoryDiagnostic _diagnostic(StoryDiagnosticCode code) => StoryDiagnostic(
  code: code,
  severity: StoryDiagnosticSeverity.warning,
  message: 'Example diagnostic.',
  location: StoryDiagnosticLocation.project(
    projectId: StoryProjectId('suggestion_test'),
  ),
);
