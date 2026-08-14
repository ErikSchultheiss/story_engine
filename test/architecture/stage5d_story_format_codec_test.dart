import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 5D Story Format public codec', () {
    test('public barrel exposes logical bundle and codec', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains("export 'src/format/story_format_bundle.dart' show"),
      );
      expect(
        barrel,
        contains("export 'src/format/codec/story_format_codec.dart' show"),
      );
      expect(barrel, isNot(contains('StoryProjectDraftCodec')));
      expect(barrel, isNot(contains('serialization/')));
    });

    test('codec remains pure Dart and independent of runtime persistence', () {
      final source = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();

      expect(source, contains("import 'dart:convert';"));
      for (final forbidden in const [
        'dart:io',
        'package:flutter/',
        '../../runtime/',
        '../../persistence/',
        '../../serialization/',
        '../../validation/',
        'StoryRuntimeSnapshot',
        'StoryProjectDraftCodec',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('v1 tokens are explicit rather than Dart enum-name serialization', () {
      final source = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();

      for (final token in const [
        "'variable_is_set'",
        "'variable_is_unset'",
        "'variable_comparison'",
        "'set_variable'",
        "'unset_variable'",
        "'increment_variable'",
        "'decrement_variable'",
        "'not_equal'",
        "'less_than_or_equal'",
        "'greater_than_or_equal'",
        "'conditional'",
        "'weighted'",
        "'terminal'",
      ]) {
        expect(source, contains(token), reason: token);
      }
      expect(RegExp(r'\.name\b').hasMatch(source), isFalse);

      final metadataSource = File(
        'lib/src/format/story_format_metadata.dart',
      ).readAsStringSync();
      expect(metadataSource, contains("'story_engine.story_format'"));
    });

    test('codec operates on logical bundles rather than filesystem IO', () {
      const codec = StoryFormatCodec();
      final document = StoryFormatDocument(
        project: StoryProject(id: StoryProjectId('project_stage5d_public')),
      );

      final bundle = codec.encode(document);
      final decoded = codec.decode(bundle);

      expect(bundle, isA<StoryFormatBundle>());
      expect(decoded.project.id, document.project.id);
      expect(bundle.files.keys, ['project.json']);
    });

    test('authored and runtime persistence formats remain independent', () {
      final storyFormatSource = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();
      final storyFormatMetadataSource = File(
        'lib/src/format/story_format_metadata.dart',
      ).readAsStringSync();
      final snapshotSource = File(
        'lib/src/persistence/story_runtime_snapshot_codec.dart',
      ).readAsStringSync();

      expect(
        storyFormatMetadataSource,
        contains("'story_engine.story_format'"),
      );
      expect(
        storyFormatSource,
        isNot(contains('story_engine_runtime_snapshot')),
      );
      expect(
        storyFormatMetadataSource,
        isNot(contains('story_engine_runtime_snapshot')),
      );
      expect(snapshotSource, contains('story_engine_runtime_snapshot'));
      expect(snapshotSource, isNot(contains('story_engine.story_format')));
    });
  });
}
