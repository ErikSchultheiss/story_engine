import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

import '../fixtures/lantern_mystery_fixture.dart';

void main() {
  const codec = StoryFormatCodec();

  group('StoryFormatCodec', () {
    test('encodes the minimal project manifest canonically', () {
      final bundle = codec.encode(
        StoryFormatDocument(
          project: StoryProject(id: StoryProjectId('project_minimal')),
        ),
      );

      expect(bundle.files.keys, ['project.json']);
      expect(
        bundle.file('project.json'),
        '{\n'
        '  "formatId": "story_engine.story_format",\n'
        '  "formatVersion": 1,\n'
        '  "project": {\n'
        '    "id": "project_minimal",\n'
        '    "stateSchema": {\n'
        '      "variables": []\n'
        '    },\n'
        '    "eventIds": []\n'
        '  }\n'
        '}\n',
      );
    });

    test('encodes event files with frozen v1 discriminator tokens', () {
      final eventId = StoryEventId('event_codec_tokens');
      final variableId = StoryVariableId('var_codec_tokens');
      final choiceId = StoryChoiceId('choice_codec_tokens');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_codec_tokens'),
          stateSchema: StoryStateSchema(
            variables: [
              StoryVariableDefinition(
                id: variableId,
                type: StoryValueType.integer,
                initialValue: StoryIntegerValue(1),
              ),
            ],
          ),
          entryEventId: eventId,
          events: [
            StoryEvent(
              id: eventId,
              availabilityCondition: StoryVariableComparisonCondition(
                variableId: variableId,
                operator: StoryComparisonOperator.greaterThanOrEqual,
                value: StoryIntegerValue(1),
              ),
              entryEffects: [
                StoryIncrementVariableEffect(
                  variableId: variableId,
                  amount: StoryIntegerValue(1),
                ),
              ],
              choices: [
                StoryChoice(
                  id: choiceId,
                  effects: [
                    StorySetVariableEffect(
                      variableId: variableId,
                      value: StoryIntegerValue(3),
                    ),
                  ],
                  transition: const StoryTerminalTransition(),
                ),
              ],
            ),
          ],
        ),
      );

      final source = codec
          .encode(document)
          .file(StoryFormatBundleLayout.eventPath(eventId))!;

      expect(source, contains('"kind": "variable_comparison"'));
      expect(source, contains('"operator": "greater_than_or_equal"'));
      expect(source, contains('"kind": "increment_variable"'));
      expect(source, contains('"kind": "set_variable"'));
      expect(source, contains('"kind": "terminal"'));
      expect(source, isNot(contains('variableComparison')));
      expect(source, isNot(contains('greaterThanOrEqual')));
    });

    test('accepts non-canonical whitespace and re-encodes canonically', () {
      final decoded = codec.decode(
        StoryFormatBundle(
          files: const {
            'project.json':
                '{"formatId":"story_engine.story_format","formatVersion":1,'
                '"project":{"id":"project_compact","stateSchema":'
                '{"variables":[]},"eventIds":[]}}',
          },
        ),
      );

      final canonical = codec.encode(decoded).file('project.json')!;
      expect(canonical, contains('\n  "formatId":'));
      expect(canonical.endsWith('\n'), isTrue);
    });

    test('round-trips every proven authored semantic family', () {
      final document = _comprehensiveDocument();
      final first = codec.encode(document);
      final decoded = codec.decode(first);
      final second = codec.encode(decoded);

      expect(second, first);
      expect(decoded.project.id, document.project.id);
      expect(decoded.project.alias, document.project.alias);
      expect(decoded.project.stateSchema, document.project.stateSchema);
      expect(decoded.project.entryEventId, document.project.entryEventId);
      expect(decoded.project.events.length, document.project.events.length);
      for (var index = 0; index < document.project.events.length; index++) {
        final before = document.project.events[index];
        final after = decoded.project.events[index];
        expect(after.id, before.id);
        expect(after.alias, before.alias);
        expect(after.presentation, before.presentation);
        expect(after.availabilityCondition, before.availabilityCondition);
        expect(after.entryEffects, before.entryEffects);
        expect(after.choices.length, before.choices.length);
        for (
          var choiceIndex = 0;
          choiceIndex < before.choices.length;
          choiceIndex++
        ) {
          final beforeChoice = before.choices[choiceIndex];
          final afterChoice = after.choices[choiceIndex];

          expect(afterChoice.id, beforeChoice.id);
          expect(afterChoice.alias, beforeChoice.alias);
          expect(afterChoice.presentation, beforeChoice.presentation);
          expect(
            afterChoice.availabilityCondition,
            beforeChoice.availabilityCondition,
          );
          expect(afterChoice.effects, beforeChoice.effects);
          expect(afterChoice.transition, beforeChoice.transition);
        }
        expect(after.continuationTransition, before.continuationTransition);
        expect(after.automaticTransition, before.automaticTransition);
      }
      expect(decoded.organization, document.organization);
      expect(decoded.extensions, unorderedEquals(document.extensions));
    });

    test('encoded file order matches the canonical Stage 5C layout', () {
      final document = _comprehensiveDocument();
      final bundle = codec.encode(document);

      expect(
        bundle.files.keys.toList(),
        StoryFormatBundleLayout.canonicalFilePaths(document),
      );
    });

    test('encoding is deterministic across repeated calls', () {
      final document = _comprehensiveDocument();

      final first = codec.encode(document);
      final second = codec.encode(document);
      final third = codec.encode(codec.decode(first));

      expect(second, first);
      expect(third, first);
      for (final source in first.files.values) {
        expect(source.endsWith('\n'), isTrue);
        expect(source, isNot(contains('\r\n')));
      }
    });

    test(
      'extension attachment order is canonical rather than caller order',
      () {
        final project = StoryProject(id: StoryProjectId('project_extensions'));
        final a = StoryFormatExtensionAttachment(
          namespace: StoryFormatExtensionNamespace('com.example.a'),
          target: const StoryFormatProjectExtensionTarget(),
          payload: StoryFormatExtensionPayload({'z': 1, 'a': 2}),
        );
        final b = StoryFormatExtensionAttachment(
          namespace: StoryFormatExtensionNamespace('com.example.b'),
          target: const StoryFormatProjectExtensionTarget(),
          payload: StoryFormatExtensionPayload({'enabled': true}),
        );

        final first = codec.encode(
          StoryFormatDocument(project: project, extensions: [b, a]),
        );
        final second = codec.encode(
          StoryFormatDocument(project: project, extensions: [a, b]),
        );

        expect(first, second);
        final source = first.file('extensions.json')!;
        expect(
          source.indexOf('com.example.a'),
          lessThan(source.indexOf('com.example.b')),
        );
        expect(source.indexOf('"a": 2'), lessThan(source.indexOf('"z": 1')));
      },
    );

    test('authored event order lives in manifest, not event file ordering', () {
      final a = StoryEventId('event_codec_order_a');
      final b = StoryEventId('event_codec_order_b');
      StoryFormatDocument build(List<StoryEventId> order) =>
          StoryFormatDocument(
            project: StoryProject(
              id: StoryProjectId('project_codec_order'),
              events: [for (final id in order) StoryEvent(id: id)],
            ),
          );

      final first = codec.encode(build([b, a]));
      final second = codec.encode(build([a, b]));
      final eventPaths = first.files.keys
          .where((path) => path.startsWith('events/'))
          .toList();

      expect(eventPaths, [...eventPaths]..sort());
      expect(
        first.file(StoryFormatBundleLayout.eventPath(a)),
        second.file(StoryFormatBundleLayout.eventPath(a)),
      );
      expect(
        first.file(StoryFormatBundleLayout.eventPath(b)),
        second.file(StoryFormatBundleLayout.eventPath(b)),
      );
      expect(first.file('project.json'), isNot(second.file('project.json')));
    });

    test(
      'incomplete editor project round-trips without runtime validation',
      () {
        final eventId = StoryEventId('event_codec_incomplete');
        final document = StoryFormatDocument(
          project: StoryProject(
            id: StoryProjectId('project_codec_incomplete'),
            events: [
              StoryEvent(
                id: eventId,
                choices: [
                  StoryChoice(id: StoryChoiceId('choice_codec_incomplete')),
                ],
              ),
            ],
          ),
        );

        final decoded = codec.decode(codec.encode(document));
        final report = StoryValidator.validate(decoded.project);

        expect(decoded.project.entryEventId, isNull);
        expect(decoded.project.events.single.choices.single.transition, isNull);
        expect(report.errors, isNotEmpty);
      },
    );

    test('Lantern Mystery round-trips to identical canonical bundle', () {
      final document = StoryFormatDocument(
        project: LanternMysteryFixture.buildProject(),
      );

      final encoded = codec.encode(document);
      final decoded = codec.decode(encoded);

      expect(codec.encode(decoded), encoded);
      expect(decoded.project.events.length, document.project.events.length);
      expect(decoded.project.stateSchema, document.project.stateSchema);
    });

    test('rejects missing manifest', () {
      expect(
        () => codec.decode(StoryFormatBundle(files: const {})),
        throwsA(
          isA<StoryFormatCodecException>().having(
            (error) => error.bundlePath,
            'bundlePath',
            'project.json',
          ),
        ),
      );
    });

    test('rejects malformed JSON with file location', () {
      expect(
        () => codec.decode(
          StoryFormatBundle(files: const {'project.json': '{not json'}),
        ),
        throwsA(
          isA<StoryFormatCodecException>()
              .having((error) => error.bundlePath, 'bundlePath', 'project.json')
              .having((error) => error.jsonPath, 'jsonPath', r'$'),
        ),
      );
    });

    test('separates unsupported identity/version from malformed v1 data', () {
      final good = codec.encode(
        StoryFormatDocument(
          project: StoryProject(id: StoryProjectId('project_version')),
        ),
      );
      final source = good.file('project.json')!;

      expect(
        () => codec.decode(
          StoryFormatBundle(
            files: {
              'project.json': source.replaceFirst(
                'story_engine.story_format',
                'example.other_format',
              ),
            },
          ),
        ),
        throwsA(
          isA<StoryFormatCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryFormatCompatibilityIssue.unsupportedFormatIdentity,
          ),
        ),
      );
      expect(
        () => codec.decode(
          StoryFormatBundle(
            files: {
              'project.json': source.replaceFirst(
                '"formatVersion": 1',
                '"formatVersion": 2',
              ),
            },
          ),
        ),
        throwsA(
          isA<StoryFormatCompatibilityException>().having(
            (error) => error.issue,
            'issue',
            StoryFormatCompatibilityIssue.unsupportedFormatVersion,
          ),
        ),
      );
    });

    test('rejects unknown core fields and unknown semantic kinds', () {
      final eventId = StoryEventId('event_codec_unknown');
      final encoded = codec.encode(
        StoryFormatDocument(
          project: StoryProject(
            id: StoryProjectId('project_codec_unknown'),
            events: [StoryEvent(id: eventId)],
          ),
        ),
      );
      final eventPath = StoryFormatBundleLayout.eventPath(eventId);

      expect(
        () => codec.decode(
          StoryFormatBundle(
            files: {
              ...encoded.files,
              'project.json': encoded
                  .file('project.json')!
                  .replaceFirst(
                    '"project": {',
                    '"unknown": true,\n  "project": {',
                  ),
            },
          ),
        ),
        throwsA(isA<StoryFormatCodecException>()),
      );

      final withChoice = codec.encode(
        StoryFormatDocument(
          project: StoryProject(
            id: StoryProjectId('project_codec_unknown_kind'),
            events: [
              StoryEvent(
                id: eventId,
                choices: [
                  StoryChoice(
                    id: StoryChoiceId('choice_codec_unknown_kind'),
                    transition: const StoryTerminalTransition(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(
        () => codec.decode(
          StoryFormatBundle(
            files: {
              ...withChoice.files,
              eventPath: withChoice
                  .file(eventPath)!
                  .replaceFirst(
                    '"kind": "terminal"',
                    '"kind": "future_transition"',
                  ),
            },
          ),
        ),
        throwsA(isA<StoryFormatCodecException>()),
      );
    });

    test('rejects missing/mismatched event files and unexpected files', () {
      final eventId = StoryEventId('event_codec_integrity');
      final encoded = codec.encode(
        StoryFormatDocument(
          project: StoryProject(
            id: StoryProjectId('project_codec_integrity'),
            events: [StoryEvent(id: eventId)],
          ),
        ),
      );
      final eventPath = StoryFormatBundleLayout.eventPath(eventId);

      final withoutEvent = Map<String, String>.of(encoded.files)
        ..remove(eventPath);
      expect(
        () => codec.decode(StoryFormatBundle(files: withoutEvent)),
        throwsA(isA<StoryFormatCodecException>()),
      );

      expect(
        () => codec.decode(
          StoryFormatBundle(
            files: {
              ...encoded.files,
              eventPath: encoded
                  .file(eventPath)!
                  .replaceFirst('event_codec_integrity', 'event_codec_other'),
            },
          ),
        ),
        throwsA(isA<StoryFormatCodecException>()),
      );

      expect(
        () => codec.decode(
          StoryFormatBundle(files: {...encoded.files, 'notes.json': '{}\n'}),
        ),
        throwsA(isA<StoryFormatCodecException>()),
      );
    });
  });
}

StoryFormatDocument _comprehensiveDocument() {
  final boolId = StoryVariableId('var_bool');
  final intId = StoryVariableId('var_int');
  final numberId = StoryVariableId('var_number');
  final stringId = StoryVariableId('var_string');
  final entryId = StoryEventId('event_entry');
  final continuationId = StoryEventId('event_continue');
  final automaticId = StoryEventId('event_auto');

  final condition = StoryAllCondition([
    StoryVariableIsSetCondition(variableId: boolId),
    StoryAnyCondition([
      StoryVariableComparisonCondition(
        variableId: intId,
        operator: StoryComparisonOperator.lessThan,
        value: StoryIntegerValue(10),
      ),
      StoryNotCondition(StoryVariableIsUnsetCondition(variableId: stringId)),
    ]),
  ]);

  final nestedTransition = StoryConditionalTransition(
    branches: [
      StoryConditionalTransitionBranch(
        condition: StoryVariableComparisonCondition(
          variableId: numberId,
          operator: StoryComparisonOperator.greaterThan,
          value: StoryNumberValue(0.5),
        ),
        transition: StoryEventTransition(destinationEventId: continuationId),
      ),
    ],
    fallback: StoryWeightedTransition(
      options: [
        StoryWeightedTransitionOption(
          weight: 1,
          transition: StoryEventTransition(destinationEventId: automaticId),
        ),
        StoryWeightedTransitionOption(
          weight: 2,
          transition: const StoryTerminalTransition(),
        ),
      ],
    ),
  );

  final project = StoryProject(
    id: StoryProjectId('project_comprehensive'),
    alias: StoryAlias('comprehensive'),
    stateSchema: StoryStateSchema(
      variables: [
        StoryVariableDefinition(
          id: boolId,
          alias: StoryAlias('flag'),
          type: StoryValueType.boolean,
          initialValue: const StoryBooleanValue(true),
        ),
        StoryVariableDefinition(
          id: intId,
          type: StoryValueType.integer,
          initialValue: StoryIntegerValue(2),
        ),
        StoryVariableDefinition(
          id: numberId,
          type: StoryValueType.number,
          initialValue: StoryNumberValue(1.25),
        ),
        StoryVariableDefinition(
          id: stringId,
          type: StoryValueType.string,
          initialValue: const StoryStringValue('ready'),
        ),
      ],
    ),
    entryEventId: entryId,
    events: [
      StoryEvent(
        id: entryId,
        alias: StoryAlias('entry'),
        presentation: StoryEventPresentation(
          title: const StoryText('Entry'),
          body: const StoryText('Choose a route.'),
        ),
        availabilityCondition: condition,
        entryEffects: [
          StoryUnsetVariableEffect(variableId: boolId),
          StoryIncrementVariableEffect(
            variableId: intId,
            amount: StoryIntegerValue(1),
          ),
          StoryDecrementVariableEffect(
            variableId: numberId,
            amount: StoryNumberValue(0.25),
          ),
        ],
        choices: [
          StoryChoice(
            id: StoryChoiceId('choice_route'),
            alias: StoryAlias('route'),
            presentation: const StoryChoicePresentation(
              text: StoryText('Take the route'),
            ),
            availabilityCondition: StoryVariableIsSetCondition(
              variableId: intId,
            ),
            effects: [
              StorySetVariableEffect(
                variableId: stringId,
                value: const StoryStringValue('chosen'),
              ),
            ],
            transition: nestedTransition,
          ),
        ],
      ),
      StoryEvent(
        id: continuationId,
        presentation: StoryEventPresentation(
          body: const StoryText('Continue.'),
        ),
        continuationTransition: const StoryTerminalTransition(),
      ),
      StoryEvent(
        id: automaticId,
        automaticTransition: const StoryTerminalTransition(),
      ),
    ],
  );

  return StoryFormatDocument(
    project: project,
    organization: StoryFormatOrganization(
      groups: [
        StoryFormatGroup(
          id: StoryFormatGroupId('group_main'),
          alias: StoryAlias('main_group'),
          label: const StoryText('Main'),
          eventIds: [entryId],
          children: [
            StoryFormatGroup(
              id: StoryFormatGroupId('group_followups'),
              eventIds: [continuationId, automaticId],
            ),
          ],
        ),
      ],
      tags: [
        StoryFormatTag(
          id: StoryFormatTagId('tag_flow'),
          alias: StoryAlias('flow'),
          label: const StoryText('Flow'),
          eventIds: [automaticId, entryId],
        ),
      ],
    ),
    extensions: [
      StoryFormatExtensionAttachment(
        namespace: StoryFormatExtensionNamespace('com.example.notes'),
        target: const StoryFormatProjectExtensionTarget(),
        payload: StoryFormatExtensionPayload({
          'author': 'example',
          'flags': [true, false],
          'nested': {'b': 2, 'a': 1},
        }),
      ),
      StoryFormatExtensionAttachment(
        namespace: StoryFormatExtensionNamespace('com.example.event_meta'),
        target: StoryFormatEventExtensionTarget(entryId),
        payload: StoryFormatExtensionPayload({'color': 'blue'}),
      ),
      StoryFormatExtensionAttachment(
        namespace: StoryFormatExtensionNamespace('com.example.group_meta'),
        target: StoryFormatGroupExtensionTarget(
          StoryFormatGroupId('group_main'),
        ),
        payload: StoryFormatExtensionPayload(null),
      ),
    ],
  );
}
