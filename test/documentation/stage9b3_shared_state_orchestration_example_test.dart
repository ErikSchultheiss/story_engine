import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../../example/story_narrative_shared_state_example.dart' as example;

void main() {
  group('Stage 9B3 shared-state orchestration example', () {
    test('example stays on the public orchestration package boundary', () {
      final source = File(
        'example/story_narrative_shared_state_example.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("import 'package:story_engine/story_engine.dart';"),
      );
      expect(source, isNot(contains('package:story_engine/src/')));
      expect(source, isNot(contains('package:flutter/')));
      expect(source, isNot(contains('dart:io')));
      expect(source, contains('StoryNarrativeRuntime('));
      expect(source, contains('StoryNarrativeChoiceInput('));
      expect(source, contains('runtime.applyInput('));
      expect(source, isNot(contains('StoryRuntimeSnapshotCodec')));
      expect(source, isNot(contains('StoryNarrativeRuntimeSnapshotCodec')));
      expect(source, isNot(contains('requestHostAction(')));
      expect(source, isNot(contains('StoryFormatCodec')));
    });

    test('project validates with both orchestration roots', () {
      final project = example.buildSharedStateExampleProject();
      final entryPoints = example.buildSharedStateExampleEntryPoints();
      final report = StoryValidator.validate(
        project,
        additionalEntryEventIds: entryPoints.map((entry) => entry.eventId),
      );

      expect(report.hasErrors, isFalse, reason: report.format());
      expect(report.hasWarnings, isFalse, reason: report.format());
      expect(entryPoints, hasLength(2));
    });

    test('two sessions observe shared committed state in authority order', () {
      final project = example.buildSharedStateExampleProject();
      final entryPoints = example.buildSharedStateExampleEntryPoints();
      final runtime = StoryNarrativeRuntime(
        project: project,
        entryPoints: entryPoints,
      );

      final gatekeeper = runtime.startSession(StoryEntryPointId('gatekeeper'));
      final traveler = runtime.startSession(StoryEntryPointId('traveler'));
      final gateOpen = StoryVariableId('gate_open');

      expect(runtime.activeSessions, [gatekeeper, traveler]);
      expect(runtime.persistentStateRevision, 0);
      expect(runtime.persistentState.rawValueOf(gateOpen), isFalse);
      expect(traveler.state.rawValueOf(gateOpen), isFalse);
      expect(traveler.availableChoices.map((choice) => choice.id.value), [
        'wait',
      ]);

      runtime.applyInput(
        StoryNarrativeChoiceInput(
          sessionIndex: gatekeeper.index,
          choiceId: StoryChoiceId('open_gate'),
        ),
      );

      expect(gatekeeper.isTerminated, isTrue);
      expect(runtime.activeSessions, [traveler]);
      expect(runtime.persistentStateRevision, 1);
      expect(runtime.persistentState.rawValueOf(gateOpen), isTrue);
      expect(traveler.state.rawValueOf(gateOpen), isTrue);
      expect(traveler.availableChoices.map((choice) => choice.id.value), [
        'enter_city',
        'wait',
      ]);

      runtime.applyInput(
        StoryNarrativeChoiceInput(
          sessionIndex: traveler.index,
          choiceId: StoryChoiceId('enter_city'),
        ),
      );

      expect(traveler.isTerminated, isTrue);
      expect(runtime.activeSessions, isEmpty);
      expect(runtime.persistentStateRevision, 1);
      expect(gatekeeper.history.eventRoute, [
        StoryEventId('gatekeeper_conversation'),
      ]);
      expect(traveler.history.eventRoute, [
        StoryEventId('traveler_conversation'),
      ]);
    });

    test('script demonstrates propagation before the sibling input', () {
      final output = <Object?>[];

      example.runSharedStateExample(log: output.add);
      final text = output.join('\n');

      final start = text.indexOf('Active sessions: 0, 1');
      final beforeState = text.indexOf('Traveler sees gate_open = false');
      final beforeChoices = text.indexOf(
        'Traveler choices before gate opens: wait',
      );
      final authority = text.indexOf('After authority input: open_gate');
      final persistent = text.indexOf('Persistent gate_open = true');
      final afterState = text.indexOf('Traveler sees gate_open = true');
      final afterChoices = text.indexOf(
        'Traveler choices after gate opens: enter_city, wait',
      );
      final finish = text.indexOf('Traveler entered the city.');

      expect(text, contains('Validation: 0 errors, 0 warnings'));
      expect(start, greaterThanOrEqualTo(0));
      expect(beforeState, greaterThan(start));
      expect(beforeChoices, greaterThan(beforeState));
      expect(authority, greaterThan(beforeChoices));
      expect(persistent, greaterThan(authority));
      expect(afterState, greaterThan(persistent));
      expect(afterChoices, greaterThan(afterState));
      expect(finish, greaterThan(afterChoices));
      expect(text, contains('Persistent revision: 0'));
      expect(text, contains('Persistent revision: 1'));
      expect(text, endsWith('Active sessions: '));
    });

    test(
      'documentation identifies Example 2 without mixing in persistence',
      () {
        final exampleReadme = File('example/README.md').readAsStringSync();
        final integrationPath = File(
          'doc/INTEGRATION_PATH.md',
        ).readAsStringSync();
        final apiGuide = File('doc/API_GUIDE.md').readAsStringSync();
        final quickStart = File('doc/QUICK_START.md').readAsStringSync();
        final readme = File('README.md').readAsStringSync();

        for (final text in <String>[
          exampleReadme,
          integrationPath,
          apiGuide,
          quickStart,
          readme,
        ]) {
          expect(text, contains('story_narrative_shared_state_example.dart'));
        }

        expect(
          exampleReadme,
          contains('Example 2 — shared persistent world state'),
        );
        expect(integrationPath, contains('Stage 9B3 freezes'));
        expect(apiGuide, contains('shared-state orchestration example'));
        expect(quickStart, contains('shared-state orchestration example'));
        expect(readme, contains('Shared-state orchestration example'));
      },
    );
  });
}
