import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  const codec = StoryFormatCodec();
  group('Story Format v1 incomplete editor behavior', () {
    test('missing entry and incomplete choice survive round-trip', () {
      final eventId = StoryEventId('event_5e_incomplete');
      final choiceId = StoryChoiceId('choice_5e_incomplete');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_5e_incomplete'),
          events: [
            StoryEvent(
              id: eventId,
              choices: [StoryChoice(id: choiceId)],
            ),
          ],
        ),
      );

      final decoded = codec.decode(codec.encode(document));
      final report = StoryValidator.validate(decoded.project);

      expect(decoded.project.entryEventId, isNull);
      expect(decoded.project.events.single.id, eventId);
      expect(decoded.project.events.single.choices.single.id, choiceId);
      expect(decoded.project.events.single.choices.single.transition, isNull);
      expect(
        report.errors.map((diagnostic) => diagnostic.code),
        containsAll([
          StoryDiagnosticCode.structureMissingEntryEvent,
          StoryDiagnosticCode.structureChoiceMissingTransition,
        ]),
      );
    });

    test(
      'missing entry reference survives round-trip for validator repair',
      () {
        final missingEntryId = StoryEventId('event_5e_missing_entry');
        final document = StoryFormatDocument(
          project: StoryProject(
            id: StoryProjectId('project_5e_missing_entry'),
            entryEventId: missingEntryId,
          ),
        );

        final decoded = codec.decode(codec.encode(document));
        final report = StoryValidator.validate(decoded.project);

        expect(decoded.project.entryEventId, missingEntryId);
        expect(
          report.errors.map((diagnostic) => diagnostic.code),
          contains(StoryDiagnosticCode.structureEntryEventNotFound),
        );
      },
    );

    test('event with no flow survives round-trip for validator repair', () {
      final eventId = StoryEventId('event_5e_missing_flow');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_5e_missing_flow'),
          entryEventId: eventId,
          events: [StoryEvent(id: eventId)],
        ),
      );

      final decoded = codec.decode(codec.encode(document));
      final report = StoryValidator.validate(decoded.project);

      expect(decoded.project.events.single.id, eventId);
      expect(
        report.errors.map((diagnostic) => diagnostic.code),
        contains(StoryDiagnosticCode.structureEventMissingFlow),
      );
    });

    test('ambiguous event flow survives round-trip for validator repair', () {
      final eventId = StoryEventId('event_5e_ambiguous');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_5e_ambiguous'),
          entryEventId: eventId,
          events: [
            StoryEvent(
              id: eventId,
              choices: [
                StoryChoice(
                  id: StoryChoiceId('choice_5e_ambiguous'),
                  transition: const StoryTerminalTransition(),
                ),
              ],
              continuationTransition: const StoryTerminalTransition(),
            ),
          ],
        ),
      );

      final decoded = codec.decode(codec.encode(document));
      final report = StoryValidator.validate(decoded.project);

      expect(decoded.project.events.single.choices, hasLength(1));
      expect(decoded.project.events.single.continuationTransition, isNotNull);
      expect(
        report.errors.map((diagnostic) => diagnostic.code),
        contains(StoryDiagnosticCode.structureEventAmbiguousFlow),
      );
    });

    test('unresolved semantic references survive for StoryValidator', () {
      final entryId = StoryEventId('event_5e_reference_entry');
      final missingEventId = StoryEventId('event_5e_reference_missing');
      final missingVariableId = StoryVariableId(
        'variable_5e_reference_missing',
      );
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_5e_references'),
          entryEventId: entryId,
          events: [
            StoryEvent(
              id: entryId,
              choices: [
                StoryChoice(
                  id: StoryChoiceId('choice_5e_references'),
                  availabilityCondition: StoryVariableIsSetCondition(
                    variableId: missingVariableId,
                  ),
                  effects: [
                    StoryUnsetVariableEffect(variableId: missingVariableId),
                  ],
                  transition: StoryEventTransition(
                    destinationEventId: missingEventId,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final decoded = codec.decode(codec.encode(document));
      final report = StoryValidator.validate(decoded.project);
      final codes = report.errors.map((diagnostic) => diagnostic.code).toSet();

      expect(
        (decoded.project.events.single.choices.single.transition
                as StoryEventTransition)
            .destinationEventId,
        missingEventId,
      );
      expect(
        codes,
        containsAll({
          StoryDiagnosticCode.referenceMissingTransitionDestination,
          StoryDiagnosticCode.referenceUndeclaredConditionVariable,
          StoryDiagnosticCode.referenceUndeclaredEffectVariable,
        }),
      );
    });

    test('runtime-neutral dangling organization references are preserved', () {
      final missingEventId = StoryEventId('event_5e_organization_missing');
      final groupId = StoryFormatGroupId('group_5e_dangling');
      final tagId = StoryFormatTagId('tag_5e_dangling');
      final document = StoryFormatDocument(
        project: StoryProject(id: StoryProjectId('project_5e_organization')),
        organization: StoryFormatOrganization(
          groups: [
            StoryFormatGroup(id: groupId, eventIds: [missingEventId]),
          ],
          tags: [
            StoryFormatTag(id: tagId, eventIds: [missingEventId]),
          ],
        ),
      );

      final decoded = codec.decode(codec.encode(document));

      expect(decoded.organization.groups.single.eventIds, [missingEventId]);
      expect(decoded.organization.tags.single.eventIds, [missingEventId]);
    });

    test('dangling opaque extension targets are preserved losslessly', () {
      final missingEventId = StoryEventId('event_5e_extension_missing');
      final missingChoiceId = StoryChoiceId('choice_5e_extension_missing');
      final missingVariableId = StoryVariableId(
        'variable_5e_extension_missing',
      );
      final missingGroupId = StoryFormatGroupId('group_5e_extension_missing');
      final missingTagId = StoryFormatTagId('tag_5e_extension_missing');
      final namespace = StoryFormatExtensionNamespace('com.example.future_ui');
      StoryFormatExtensionAttachment attachment(
        StoryFormatExtensionTarget target,
        String name,
      ) => StoryFormatExtensionAttachment(
        namespace: namespace,
        target: target,
        payload: StoryFormatExtensionPayload({
          'name': name,
          'future': {
            'enabled': true,
            'values': [1, 2, 3],
          },
        }),
      );

      final document = StoryFormatDocument(
        project: StoryProject(id: StoryProjectId('project_5e_extensions')),
        extensions: [
          attachment(StoryFormatEventExtensionTarget(missingEventId), 'event'),
          attachment(
            StoryFormatChoiceExtensionTarget(missingChoiceId),
            'choice',
          ),
          attachment(
            StoryFormatVariableExtensionTarget(missingVariableId),
            'variable',
          ),
          attachment(StoryFormatGroupExtensionTarget(missingGroupId), 'group'),
          attachment(StoryFormatTagExtensionTarget(missingTagId), 'tag'),
        ],
      );

      final decoded = codec.decode(codec.encode(document));

      expect(decoded.extensions, unorderedEquals(document.extensions));
      expect(codec.encode(decoded), codec.encode(document));
    });
  });

  group('Story Format v1 forward compatibility behavior', () {
    test('unsupported identity is a compatibility failure', () {
      final source = _minimalManifest(
        formatId: 'com.example.other_story_format',
        formatVersion: 1,
        extraRootField: true,
      );

      expect(
        () => codec.decode(StoryFormatBundle(files: {'project.json': source})),
        throwsA(
          isA<StoryFormatCompatibilityException>()
              .having(
                (error) => error.issue,
                'issue',
                StoryFormatCompatibilityIssue.unsupportedFormatIdentity,
              )
              .having(
                (error) => error.foundFormatId,
                'foundFormatId',
                'com.example.other_story_format',
              ),
        ),
      );
    });

    test('future version wins over future unknown root fields', () {
      final source = _minimalManifest(
        formatId: StoryFormatMetadata.currentFormatId,
        formatVersion: 2,
        extraRootField: true,
      );

      expect(
        () => codec.decode(StoryFormatBundle(files: {'project.json': source})),
        throwsA(
          isA<StoryFormatCompatibilityException>()
              .having(
                (error) => error.issue,
                'issue',
                StoryFormatCompatibilityIssue.unsupportedFormatVersion,
              )
              .having(
                (error) => error.foundFormatVersion,
                'foundFormatVersion',
                2,
              ),
        ),
      );
    });

    test('unknown core fields remain errors for a document claiming v1', () {
      final source = _minimalManifest(
        formatId: StoryFormatMetadata.currentFormatId,
        formatVersion: StoryFormatMetadata.currentFormatVersion,
        extraRootField: true,
      );

      expect(
        () => codec.decode(StoryFormatBundle(files: {'project.json': source})),
        throwsA(isA<StoryFormatCodecException>()),
      );
    });

    test('constructor-impossible current-v1 values remain codec failures', () {
      final source =
          '{\n'
          '  "formatId": "story_engine.story_format",\n'
          '  "formatVersion": 1,\n'
          '  "project": {\n'
          '    "id": "invalid project id",\n'
          '    "stateSchema": {"variables": []},\n'
          '    "eventIds": []\n'
          '  }\n'
          '}\n';

      expect(
        () => codec.decode(StoryFormatBundle(files: {'project.json': source})),
        throwsA(isA<StoryFormatCodecException>()),
      );
    });

    test('duplicate stable event IDs remain an encoding boundary failure', () {
      final duplicateId = StoryEventId('event_5e_duplicate_storage');
      final document = StoryFormatDocument(
        project: StoryProject(
          id: StoryProjectId('project_5e_duplicate_storage'),
          events: [
            StoryEvent(id: duplicateId),
            StoryEvent(id: duplicateId),
          ],
        ),
      );

      expect(
        () => codec.encode(document),
        throwsA(isA<StoryFormatCodecException>()),
      );
    });
  });
}

String _minimalManifest({
  required String formatId,
  required int formatVersion,
  required bool extraRootField,
}) =>
    '{\n'
    '  "formatId": "$formatId",\n'
    '  "formatVersion": $formatVersion,\n'
    '${extraRootField ? '  "futureRootField": {"enabled": true},\n' : ''}'
    '  "project": {\n'
    '    "id": "project_5e_compatibility",\n'
    '    "stateSchema": {"variables": []},\n'
    '    "eventIds": []\n'
    '  }\n'
    '}\n';
