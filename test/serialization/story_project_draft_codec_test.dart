import 'package:story_engine/src/serialization/story_project_draft_codec.dart';
import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  const codec = StoryProjectDraftCodec();

  test('complex authored project round-trips through draft data', () {
    final project = _complexProject();

    final encoded = codec.encode(project);
    final decoded = codec.decode(encoded);

    expect(codec.encode(decoded), equals(encoded));
    expect(decoded.id, project.id);
    expect(decoded.alias, project.alias);
    expect(decoded.entryEventId, project.entryEventId);
    expect(decoded.stateSchema, project.stateSchema);
    expect(decoded.events, hasLength(2));
    expect(
      decoded.events.first.presentation?.title,
      const StoryText('Serialization Start'),
    );
    expect(
      decoded.events.first.choices.single.presentation?.text,
      const StoryText('Continue'),
    );
    expect(decoded.events.last.continuationTransition, isNotNull);
    expect(decoded.events.last.automaticTransition, isNull);
  });

  test('draft JSON is deterministic for identical authored data', () {
    final project = _complexProject();

    final first = codec.encodeJson(project);
    final second = codec.encodeJson(project);
    final afterRoundTrip = codec.encodeJson(codec.decodeJson(first));

    expect(second, first);
    expect(afterRoundTrip, first);
    expect(first, contains('"documentType":"story_engine_project_draft"'));
    expect(first, contains('"draftRevision":3'));
  });

  test('complete Lantern Mystery fixture round-trips deterministically', () {
    final project = LanternMysteryFixture.buildProject();

    final encoded = codec.encodeJson(project);
    final decoded = codec.decodeJson(encoded);

    expect(codec.encodeJson(decoded), encoded);
    expect(decoded.id, LanternMysteryFixture.projectId);
    expect(decoded.events, hasLength(12));
    expect(
      decoded.events.expand((event) => event.choices),
      hasLength(22),
    );
  });

  test('incomplete editor data round-trips without runtime validation', () {
    final project = StoryProject(
      id: StoryProjectId('project_incomplete'),
      events: [
        StoryEvent(
          id: StoryEventId('evt_draft'),
          choices: [StoryChoice(id: StoryChoiceId('choice_draft'))],
        ),
      ],
    );

    final decoded = codec.decode(codec.encode(project));

    expect(decoded.entryEventId, isNull);
    expect(decoded.events.single.choices.single.transition, isNull);
  });

  test('all scalar value variants round-trip without coercion', () {
    final project = StoryProject(
      id: StoryProjectId('project_values'),
      stateSchema: StoryStateSchema(
        variables: [
          StoryVariableDefinition(
            id: StoryVariableId('var_bool'),
            type: StoryValueType.boolean,
            initialValue: const StoryBooleanValue(true),
          ),
          StoryVariableDefinition(
            id: StoryVariableId('var_int'),
            type: StoryValueType.integer,
            initialValue: StoryIntegerValue(7),
          ),
          StoryVariableDefinition(
            id: StoryVariableId('var_number'),
            type: StoryValueType.number,
            initialValue: StoryNumberValue(7.0),
          ),
          StoryVariableDefinition(
            id: StoryVariableId('var_string'),
            type: StoryValueType.string,
            initialValue: const StoryStringValue('seven'),
          ),
        ],
      ),
    );

    final decoded = codec.decodeJson(codec.encodeJson(project));
    final definitions = decoded.stateSchema.variables;

    expect(definitions[0].initialValue, const StoryBooleanValue(true));
    expect(definitions[1].initialValue, StoryIntegerValue(7));
    expect(definitions[2].initialValue, StoryNumberValue(7.0));
    expect(definitions[3].initialValue, const StoryStringValue('seven'));
  });

  test('unknown top-level fields are rejected rather than discarded', () {
    final encoded = codec.encode(_complexProject());
    encoded['futureField'] = 'must-not-be-lost';

    expect(
      () => codec.decode(encoded),
      throwsA(
        isA<StoryDraftSerializationException>().having(
          (error) => error.path,
          'path',
          r'$.futureField',
        ),
      ),
    );
  });

  test('unknown nested condition kind is rejected explicitly', () {
    final encoded = codec.encode(_complexProject());
    final project = encoded['project']! as Map<String, Object?>;
    final events = project['events']! as List<Object?>;
    final firstEvent = events.first as Map<String, Object?>;
    final condition =
        firstEvent['availabilityCondition']! as Map<String, Object?>;
    condition['kind'] = 'futureCondition';

    expect(
      () => codec.decode(encoded),
      throwsA(
        isA<StoryDraftSerializationException>().having(
          (error) => error.message,
          'message',
          contains('Unknown condition kind'),
        ),
      ),
    );
  });

  test('unsupported draft revision fails before project decoding', () {
    final encoded = codec.encode(_complexProject());
    encoded['draftRevision'] = 4;

    expect(
      () => codec.decode(encoded),
      throwsA(
        isA<StoryDraftSerializationException>().having(
          (error) => error.path,
          'path',
          r'$.draftRevision',
        ),
      ),
    );
  });

  test('draft revision 1 remains readable with presentation absent', () {
    final encoded = codec.encode(_complexProject());
    encoded['draftRevision'] = 1;
    final project = encoded['project']! as Map<String, Object?>;
    final events = project['events']! as List<Object?>;
    for (final eventValue in events) {
      final event = eventValue! as Map<String, Object?>;
      event.remove('presentation');
      event.remove('continuationTransition');
      final choices = event['choices']! as List<Object?>;
      for (final choiceValue in choices) {
        final choice = choiceValue! as Map<String, Object?>;
        choice.remove('presentation');
      }
    }

    final decoded = codec.decode(encoded);

    expect(decoded.events.first.presentation, isNull);
    expect(decoded.events.first.choices.single.presentation, isNull);
  });

  test('revision 1 rejects revision 2 presentation fields', () {
    final encoded = codec.encode(_complexProject());
    encoded['draftRevision'] = 1;
    final project = encoded['project']! as Map<String, Object?>;
    final events = project['events']! as List<Object?>;
    for (final eventValue in events) {
      final event = eventValue! as Map<String, Object?>;
      event.remove('continuationTransition');
    }

    expect(
      () => codec.decode(encoded),
      throwsA(
        isA<StoryDraftSerializationException>().having(
          (error) => error.path,
          'path',
          r'$.project.events[0].presentation',
        ),
      ),
    );
  });

  test('draft revision 2 remains readable with continuation absent', () {
    final encoded = codec.encode(_complexProject());
    encoded['draftRevision'] = 2;
    final project = encoded['project']! as Map<String, Object?>;
    final events = project['events']! as List<Object?>;
    for (final eventValue in events) {
      final event = eventValue! as Map<String, Object?>;
      event.remove('continuationTransition');
    }

    final decoded = codec.decode(encoded);

    expect(decoded.events.last.continuationTransition, isNull);
    expect(decoded.events.last.presentation?.title, const StoryText('Destination'));
  });

  test('revision 2 rejects revision 3 continuation fields', () {
    final encoded = codec.encode(_complexProject());
    encoded['draftRevision'] = 2;

    expect(
      () => codec.decode(encoded),
      throwsA(
        isA<StoryDraftSerializationException>().having(
          (error) => error.path,
          'path',
          r'$.project.events[1].continuationTransition',
        ),
      ),
    );
  });

  test('malformed JSON is wrapped in draft serialization error', () {
    expect(
      () => codec.decodeJson('{not json'),
      throwsA(isA<StoryDraftSerializationException>()),
    );
  });
}

StoryProject _complexProject() {
  final trustId = StoryVariableId('var_trust');
  final hasKeyId = StoryVariableId('var_has_key');
  final startId = StoryEventId('evt_start');
  final destinationId = StoryEventId('evt_destination');

  return StoryProject(
    id: StoryProjectId('project_serialization'),
    alias: StoryAlias('serialization_fixture'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: trustId,
          alias: StoryAlias('mara_trust'),
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(50),
        ),
        StoryVariableDefinition(
          id: hasKeyId,
          alias: StoryAlias('has_key'),
          type: StoryValueType.boolean,
        ),
      ],
    ),
    entryEventId: startId,
    events: [
      StoryEvent(
        id: startId,
        alias: StoryAlias('start'),
        presentation: StoryEventPresentation(
          title: const StoryText('Serialization Start'),
          body: const StoryText('Draft presentation round-trip.'),
        ),
        availabilityCondition: StoryVariableComparisonCondition(
          variableId: trustId,
          operator: StoryComparisonOperator.greaterThanOrEqual,
          value: StoryIntegerValue(0),
        ),
        entryEffects: [
          StoryIncrementVariableEffect(
            variableId: trustId,
            amount: StoryIntegerValue(1),
          ),
        ],
        choices: [
          StoryChoice(
            id: StoryChoiceId('choice_continue'),
            alias: StoryAlias('continue_story'),
            presentation: const StoryChoicePresentation(
              text: StoryText('Continue'),
            ),
            availabilityCondition: StoryAnyCondition([
              StoryVariableIsUnsetCondition(variableId: hasKeyId),
              StoryNotCondition(
                StoryVariableComparisonCondition(
                  variableId: trustId,
                  operator: StoryComparisonOperator.lessThan,
                  value: StoryIntegerValue(10),
                ),
              ),
            ]),
            effects: [
              StorySetVariableEffect(
                variableId: hasKeyId,
                value: const StoryBooleanValue(true),
              ),
              StoryDecrementVariableEffect(
                variableId: trustId,
                amount: StoryIntegerValue(2),
              ),
            ],
            transition: StoryConditionalTransition(
              branches: [
                StoryConditionalTransitionBranch(
                  condition: StoryVariableIsSetCondition(variableId: hasKeyId),
                  transition: StoryWeightedTransition(
                    options: [
                      StoryWeightedTransitionOption(
                        weight: 3,
                        transition: StoryEventTransition(
                          destinationEventId: destinationId,
                        ),
                      ),
                      StoryWeightedTransitionOption(
                        weight: 1,
                        transition: const StoryTerminalTransition(),
                      ),
                    ],
                  ),
                ),
              ],
              fallback: const StoryTerminalTransition(),
            ),
          ),
        ],
      ),
      StoryEvent(
        id: destinationId,
        alias: StoryAlias('destination'),
        presentation: StoryEventPresentation(
          title: const StoryText('Destination'),
        ),
        entryEffects: [StoryUnsetVariableEffect(variableId: hasKeyId)],
        continuationTransition: const StoryTerminalTransition(),
      ),
    ],
  );
}
