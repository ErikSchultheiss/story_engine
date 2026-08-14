import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 6A public API and package boundary', () {
    test('consumer API remains available through the root package library', () {
      final project = StoryProject(id: StoryProjectId('stage6a_smoke'));
      final report = StoryValidator.validate(project);

      expect(project.id.value, 'stage6a_smoke');
      expect(report.projectId, project.id);
    });

    test('every root export is symbol-pinned with show', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final directives = _exportDirectivePattern.allMatches(barrel).toList();
      final exportKeywordCount = RegExp(r'\bexport\s+').allMatches(barrel).length;

      expect(directives, hasLength(exportKeywordCount));

      final actualSymbols = <String>{};
      for (final directive in directives) {
        final symbols = directive
            .group(2)!
            .split(',')
            .map((symbol) => symbol.trim())
            .where((symbol) => symbol.isNotEmpty);
        for (final symbol in symbols) {
          expect(
            actualSymbols.add(symbol),
            isTrue,
            reason: 'A public symbol must be exported from one canonical '
                'library only: $symbol',
          );
        }
      }

      expect(actualSymbols, unorderedEquals(_approvedPublicSymbols));
    });

    test('implementation-only libraries remain outside the public barrel', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      for (final path in _implementationOnlyLibraries) {
        expect(
          barrel,
          isNot(contains("'$path'")),
          reason: '$path is implementation machinery, not package API.',
        );
      }

      expect(
        barrel,
        isNot(contains('StoryStateMutation')),
        reason: 'Mutable state evolution remains internal to the engine.',
      );
    });

    test('production code composes internally without package self-imports', () {
      final violations = <String>[];

      for (final entity in Directory('lib/src').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains("package:story_engine/story_engine.dart") ||
            source.contains('package:story_engine/src/')) {
          violations.add(entity.path.replaceAll('\\', '/'));
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Package implementation should use relative internal imports '
            'instead of depending back on its consumer-facing library.\n'
            '${violations.join('\n')}',
      );
    });

    test('direct src imports in tests are an explicit white-box allowlist', () {
      final actual = <String>{};
      final importPattern = RegExp(
        r'''import\s+['"]package:story_engine/(src/[^'"]+)['"]''',
      );

      for (final entity in Directory('test').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        final testPath = entity.path.replaceAll('\\', '/');
        for (final match in importPattern.allMatches(source)) {
          actual.add('$testPath -> ${match.group(1)}');
        }
      }

      expect(actual, unorderedEquals(_approvedWhiteBoxTestImports));
    });
  });
}

final _exportDirectivePattern = RegExp(
  r'''export\s+['"]([^'"]+)['"]\s+show\s+([^;]+);''',
  multiLine: true,
);

const _approvedPublicSymbols = <String>{
  'StoryAlias',
  'StoryAllCondition',
  'StoryAnyCondition',
  'StoryBooleanValue',
  'StoryChoice',
  'StoryChoiceId',
  'StoryChoicePresentation',
  'StoryChoiceSelectedStep',
  'StoryComparisonOperator',
  'StoryCondition',
  'StoryConditionContext',
  'StoryConditionEvaluationException',
  'StoryConditionEvaluator',
  'StoryConditionalTransition',
  'StoryConditionalTransitionBranch',
  'StoryDecrementVariableEffect',
  'StoryDiagnostic',
  'StoryDiagnosticCode',
  'StoryDiagnosticFieldPathSegment',
  'StoryDiagnosticIdentity',
  'StoryDiagnosticIndexPathSegment',
  'StoryDiagnosticLocation',
  'StoryDiagnosticLocationKind',
  'StoryDiagnosticPathSegment',
  'StoryDiagnosticReference',
  'StoryDiagnosticReferenceKind',
  'StoryDiagnosticSeverity',
  'StoryEffect',
  'StoryEngine',
  'StoryEngineConfigurationException',
  'StoryEngineException',
  'StoryEngineExecutionException',
  'StoryEngineOperationException',
  'StoryEngineStatus',
  'StoryEvent',
  'StoryEventContinuedStep',
  'StoryEventEnteredStep',
  'StoryEventId',
  'StoryEventPresentation',
  'StoryEventTransition',
  'StoryFormatBundle',
  'StoryFormatBundleLayout',
  'StoryFormatChoiceExtensionTarget',
  'StoryFormatCodec',
  'StoryFormatCodecException',
  'StoryFormatCompatibilityException',
  'StoryFormatCompatibilityIssue',
  'StoryFormatDocument',
  'StoryFormatEventExtensionTarget',
  'StoryFormatExtensionAttachment',
  'StoryFormatExtensionNamespace',
  'StoryFormatExtensionPayload',
  'StoryFormatExtensionTarget',
  'StoryFormatGroup',
  'StoryFormatGroupExtensionTarget',
  'StoryFormatGroupId',
  'StoryFormatMetadata',
  'StoryFormatOrganization',
  'StoryFormatProjectExtensionTarget',
  'StoryFormatTag',
  'StoryFormatTagExtensionTarget',
  'StoryFormatTagId',
  'StoryFormatVariableExtensionTarget',
  'StoryIncrementVariableEffect',
  'StoryIntegerValue',
  'StoryNotCondition',
  'StoryNumberValue',
  'StoryProject',
  'StoryProjectId',
  'StoryRuntimeHistory',
  'StoryRuntimeRandomState',
  'StoryRuntimeSnapshot',
  'StoryRuntimeSnapshotCodec',
  'StoryRuntimeSnapshotCompatibilityException',
  'StoryRuntimeSnapshotCompatibilityIssue',
  'StoryRuntimeSnapshotFormatException',
  'StoryRuntimeSnapshotMetadata',
  'StoryRuntimeSnapshotValidator',
  'StoryRuntimeStep',
  'StorySetVariableEffect',
  'StoryState',
  'StoryStateSchema',
  'StoryStringValue',
  'StoryTerminalTransition',
  'StoryText',
  'StoryTransition',
  'StoryUnsetVariableEffect',
  'StoryValidationReport',
  'StoryValidator',
  'StoryValue',
  'StoryValueType',
  'StoryVariableComparisonCondition',
  'StoryVariableDefinition',
  'StoryVariableId',
  'StoryVariableIsSetCondition',
  'StoryVariableIsUnsetCondition',
  'StoryWeightedTransition',
  'StoryWeightedTransitionOption',
};

const _implementationOnlyLibraries = <String>[
  'src/effect/story_effect_executor.dart',
  'src/format/codec/story_format_migrations.dart',
  'src/model/story_section.dart',
  'src/persistence/story_runtime_snapshot_migrations.dart',
  'src/runtime/story_seeded_random_source.dart',
  'src/serialization/story_project_draft_codec.dart',
  'src/transition/story_transition_resolver.dart',
  'src/validation/story_graph_validator.dart',
  'src/validation/story_presentation_validator.dart',
  'src/validation/story_reference_validator.dart',
  'src/validation/story_semantic_validator.dart',
  'src/validation/story_state_use_validator.dart',
  'src/validation/story_structural_validator.dart',
];

const _approvedWhiteBoxTestImports = <String>{
  'test/effect/story_effect_executor_test.dart -> src/effect/story_effect_executor.dart',
  'test/format/story_format_migrations_test.dart -> src/format/codec/story_format_migrations.dart',
  'test/persistence/story_runtime_snapshot_migrations_test.dart -> src/persistence/story_runtime_snapshot_migrations.dart',
  'test/runtime/story_seeded_random_snapshot_test.dart -> src/runtime/story_seeded_random_source.dart',
  'test/serialization/story_project_draft_codec_test.dart -> src/serialization/story_project_draft_codec.dart',
  'test/state/story_state_test.dart -> src/state/story_state.dart',
  'test/transition/story_transition_resolver_test.dart -> src/transition/story_transition_resolver.dart',
};
