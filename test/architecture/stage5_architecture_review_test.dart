import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 5H Story Format v1 architecture review', () {
    test('format identity and compatibility vocabulary are frozen', () {
      expect(
        StoryFormatMetadata.currentFormatId,
        'story_engine.story_format',
      );
      expect(StoryFormatMetadata.currentFormatVersion, 1);
      expect(
        StoryFormatCompatibilityIssue.values
            .map((issue) => issue.name)
            .toList(),
        const [
          'unsupportedFormatIdentity',
          'unsupportedFormatVersion',
        ],
      );
    });

    test('public Story Format API surface remains deliberate', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();
      final actual = _exportPattern
          .allMatches(barrel)
          .map((match) => match.group(1)!)
          .where((path) => path.startsWith('src/format/'))
          .toList()
        ..sort();
      final expected = [..._expectedPublicFormatLibraries]..sort();

      expect(actual, expected);
      expect(barrel, isNot(contains('story_format_migrations.dart')));
      expect(barrel, isNot(contains('story_project_draft_codec.dart')));
    });

    test('portable v1 bundle paths and event storage token are frozen', () {
      expect(StoryFormatBundleLayout.projectPath, 'project.json');
      expect(StoryFormatBundleLayout.eventsDirectory, 'events');
      expect(
        StoryFormatBundleLayout.organizationPath,
        'organization.json',
      );
      expect(StoryFormatBundleLayout.extensionsPath, 'extensions.json');

      expect(
        StoryFormatBundleLayout.eventPath(StoryEventId('event_intro')),
        'events/mv3gk3tul5uw45dsn4.json',
      );
      expect(
        StoryFormatBundleLayout.eventPath(StoryEventId('Event.Intro:1')),
        'events/iv3gk3tufzew45dsn45dc.json',
      );
    });

    test('normative spec and reference codec agree on frozen tokens', () {
      final specification = File('doc/STORY_FORMAT_V1.md').readAsStringSync();
      final codec = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();

      expect(specification, contains('story_engine.story_format'));
      expect(specification, contains('Story Format v1 is frozen.'));

      for (final token in _frozenSemanticTokens) {
        expect(
          specification,
          contains('`$token`'),
          reason: 'The normative v1 specification must document $token.',
        );
        expect(
          codec,
          contains("'$token'"),
          reason: 'The reference codec must retain frozen token $token.',
        );
      }
    });

    test('all canonical v1 fixtures remain byte-exact round trips', () {
      final codec = StoryFormatCodec();

      for (final fixtureName in _canonicalFixtureNames) {
        final bundle = _loadBundle(
          'test/fixtures/story_format_v1/$fixtureName',
        );
        final decoded = codec.decode(bundle);

        expect(
          decoded.metadata,
          const StoryFormatMetadata.current(),
          reason: '$fixtureName must remain a current Story Format v1 bundle.',
        );
        expect(
          codec.encode(decoded),
          bundle,
          reason: '$fixtureName must remain byte/path canonical.',
        );
      }
    });

    test('authored format remains separate from snapshot and draft formats', () {
      final storyFormatCodec = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();
      final snapshotCodec = File(
        'lib/src/persistence/story_runtime_snapshot_codec.dart',
      ).readAsStringSync();
      final draftCodec = File(
        'lib/src/serialization/story_project_draft_codec.dart',
      ).readAsStringSync();

      expect(
        storyFormatCodec,
        isNot(contains('story_engine_runtime_snapshot')),
      );
      expect(
        snapshotCodec,
        isNot(contains('story_engine.story_format')),
      );
      expect(draftCodec, contains('revision'));
      expect(draftCodec, isNot(contains('StoryFormatCodec')));
    });

    test('organization remains runtime-neutral and chapter/section-free', () {
      final formatSources = Directory('lib/src/format')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      final projectSource = File(
        'lib/src/model/story_project.dart',
      ).readAsStringSync();

      expect(formatSources, isNot(contains('class StoryFormatChapter')));
      expect(formatSources, isNot(contains('class StoryFormatSection')));
      expect(projectSource, isNot(contains('StoryFormatOrganization')));
      expect(projectSource, isNot(contains('StoryFormatGroup')));
      expect(projectSource, isNot(contains('StoryFormatTag')));
    });

    test('third-party specification covers the complete v1 implementation boundary', () {
      final specification = File('doc/STORY_FORMAT_V1.md').readAsStringSync();

      for (final heading in _requiredSpecificationHeadings) {
        expect(
          specification,
          contains(heading),
          reason: 'The normative v1 specification is missing $heading.',
        );
      }
    });
  });
}

StoryFormatBundle _loadBundle(String directoryPath) {
  final root = Directory(directoryPath);
  final files = <String, String>{};

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) {
      continue;
    }
    final relativePath = entity.path
        .substring(root.path.length + 1)
        .replaceAll('\\', '/');
    files[relativePath] = entity.readAsStringSync();
  }

  return StoryFormatBundle(files: files);
}

final _exportPattern = RegExp(r'''export\s+['"]([^'"]+)['"]''');

const _expectedPublicFormatLibraries = <String>[
  'src/format/story_format_bundle.dart',
  'src/format/story_format_bundle_layout.dart',
  'src/format/codec/story_format_codec.dart',
  'src/format/story_format_compatibility.dart',
  'src/format/story_format_document.dart',
  'src/format/story_format_extension_attachment.dart',
  'src/format/story_format_extension_namespace.dart',
  'src/format/story_format_extension_payload.dart',
  'src/format/story_format_extension_target.dart',
  'src/format/story_format_group.dart',
  'src/format/story_format_group_id.dart',
  'src/format/story_format_metadata.dart',
  'src/format/story_format_organization.dart',
  'src/format/story_format_tag.dart',
  'src/format/story_format_tag_id.dart',
];

const _frozenSemanticTokens = <String>[
  'boolean',
  'integer',
  'number',
  'string',
  'equal',
  'not_equal',
  'less_than',
  'less_than_or_equal',
  'greater_than',
  'greater_than_or_equal',
  'all',
  'any',
  'not',
  'variable_is_set',
  'variable_is_unset',
  'variable_comparison',
  'set_variable',
  'unset_variable',
  'increment_variable',
  'decrement_variable',
  'event',
  'conditional',
  'weighted',
  'terminal',
  'project',
  'choice',
  'variable',
  'group',
  'tag',
];

const _canonicalFixtureNames = <String>[
  'minimal',
  'lantern_mystery',
  'incomplete_editor',
  'structured_large',
  'migration_source_v1',
];

const _requiredSpecificationHeadings = <String>[
  '## 2. Format identity and version',
  '## 3. Logical bundle',
  '## 4. Identifier and alias lexical rules',
  '## 5. Canonical JSON',
  '## 6. `project.json`',
  '## 7. State schema and scalar values',
  '## 8. Event files',
  '## 9. Choices',
  '## 10. Conditions',
  '## 11. Effects',
  '## 12. Transitions',
  '## 13. `organization.json`',
  '## 14. `extensions.json`',
  '## 15. Incomplete authored work and validation',
  '## 16. Strict unknown-data behavior',
  '## 17. Migration',
  '## 18. Determinism and Git churn',
  '## 19. Conformance fixtures',
  '## 20. Separation from runtime persistence',
  '## 21. Version evolution rule',
];
