import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 5E incomplete/forward compatibility contract', () {
    test('public API exposes structured format incompatibility', () {
      const error = StoryFormatCompatibilityException(
        issue: StoryFormatCompatibilityIssue.unsupportedFormatVersion,
        bundlePath: 'project.json',
        jsonPath: r'$.formatVersion',
        message: 'test',
        foundFormatId: StoryFormatMetadata.currentFormatId,
        foundFormatVersion: 2,
      );

      expect(error.issue, StoryFormatCompatibilityIssue.unsupportedFormatVersion);
      expect(error.foundFormatVersion, 2);
    });

    test('format codec checks identity/version before v1-only fields', () {
      final source = File(
        'lib/src/format/codec/story_format_codec.dart',
      ).readAsStringSync();

      final versionCheck = source.indexOf(
        'StoryFormatCompatibilityIssue.unsupportedFormatVersion',
      );
      final rootAllowOnly = source.indexOf(
        "const {'formatId', 'formatVersion', 'project'}",
      );

      expect(versionCheck, greaterThanOrEqualTo(0));
      expect(rootAllowOnly, greaterThan(versionCheck));
    });

    test('compatibility model stays authored-format-only and JSON independent', () {
      final source = File(
        'lib/src/format/story_format_compatibility.dart',
      ).readAsStringSync();

      for (final forbidden in const [
        'dart:convert',
        'dart:io',
        '../runtime/',
        '../persistence/',
        '../serialization/',
        '../validation/',
        'package:flutter/',
        'StoryRuntimeSnapshot',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('public barrel exposes compatibility contract', () {
      final barrel = File('lib/story_engine.dart').readAsStringSync();

      expect(
        barrel,
        contains("export 'src/format/story_format_compatibility.dart' show"),
      );
    });
  });
}
