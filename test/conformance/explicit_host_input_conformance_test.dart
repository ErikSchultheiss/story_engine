import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    'explicit host facts, not wall-clock/global noise, determine resolution',
    () {
      final vector =
          jsonDecode(
                File(
                  'conformance/authority/input-v1/explicit-host-facts.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(vector['contract'], 'open_story.explicit_host_input_vector');
      expect(vector['contractVersion'], 1);

      final condition = vector['condition'] as Map<String, dynamic>;
      final key = StoryHostConditionKey(condition['key'] as String);
      final requirementBase = (
        key: key,
        namespace: condition['schemaNamespace'] as String,
        conditionId: condition['conditionId'] as String,
      );

      final actualByCase = <String, String>{};
      for (final rawCase in vector['cases'] as List<dynamic>) {
        final caseData = rawCase as Map<String, dynamic>;
        final runtime = _runtime(
          key: requirementBase.key,
          schemaNamespace: requirementBase.namespace,
          conditionId: requirementBase.conditionId,
        );
        final session = runtime.resolveAndStartSession(
          hostContext: StoryHostContext(
            conditionResults: {key: caseData['explicitResult'] as bool},
          ),
        );
        final actual = session!.entryPoint.id.value;
        actualByCase[caseData['caseId'] as String] = actual;
        expect(actual, caseData['expectedEntryPointId']);
      }

      expect(
        actualByCase['night_environment_a'],
        actualByCase['night_environment_b'],
      );
      expect(
        actualByCase['night_environment_a'],
        isNot(actualByCase['day_explicit_input']),
      );
    },
  );
}

StoryNarrativeRuntime _runtime({
  required StoryHostConditionKey key,
  required String schemaNamespace,
  required String conditionId,
}) {
  final dayEventId = StoryEventId('evt_day');
  final nightEventId = StoryEventId('evt_night');
  final project = StoryProject(
    id: StoryProjectId('project_explicit_inputs'),
    entryEventId: dayEventId,
    events: [
      StoryEvent(
        id: dayEventId,
        continuationTransition: const StoryTerminalTransition(),
      ),
      StoryEvent(
        id: nightEventId,
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
  return StoryNarrativeRuntime(
    project: project,
    entryPoints: [
      StoryEntryPoint(
        id: StoryEntryPointId('entry_day'),
        eventId: dayEventId,
        hostConditions: [
          StoryHostConditionRequirement(
            key: key,
            schemaNamespace: schemaNamespace,
            conditionId: conditionId,
            expected: false,
          ),
        ],
      ),
      StoryEntryPoint(
        id: StoryEntryPointId('entry_night'),
        eventId: nightEventId,
        hostConditions: [
          StoryHostConditionRequirement(
            key: key,
            schemaNamespace: schemaNamespace,
            conditionId: conditionId,
          ),
        ],
      ),
    ],
  );
}
