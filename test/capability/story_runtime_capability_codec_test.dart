import 'dart:convert';
import 'dart:io';

import 'package:story_engine/story_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Stage 8M runtime capability codecs', () {
    const profileCodec = StoryRuntimeCapabilityProfileCodec();
    const capabilitiesCodec = StoryRuntimeCapabilitiesCodec();

    test('reference profile and supported runtime round-trip canonically', () {
      final profileSource = File(
        'conformance/capabilities/profile-v1/project-requirements.json',
      ).readAsStringSync();
      final runtimeSource = File(
        'conformance/capabilities/profile-v1/runtime-supported.json',
      ).readAsStringSync();

      final profile = profileCodec.decode(profileSource);
      final capabilities = capabilitiesCodec.decode(runtimeSource);

      expect(profileCodec.encode(profile), profileSource);
      expect(capabilitiesCodec.encode(capabilities), runtimeSource);
      expect(
        StoryRuntimeCompatibilityEvaluator.evaluate(
          profile: profile,
          capabilities: capabilities,
        ).isCompatible,
        isTrue,
      );
    });

    test('unsupported vector has the exact language-neutral issue sequence', () {
      final profile = profileCodec.decode(
        File(
          'conformance/capabilities/profile-v1/project-requirements.json',
        ).readAsStringSync(),
      );
      final capabilities = capabilitiesCodec.decode(
        File(
          'conformance/capabilities/profile-v1/runtime-unsupported.json',
        ).readAsStringSync(),
      );
      final expected =
          (jsonDecode(
                    File(
                      'conformance/capabilities/profile-v1/expected-unsupported-issues.json',
                    ).readAsStringSync(),
                  )
                  as List<Object?>)
              .cast<String>();

      final report = StoryRuntimeCompatibilityEvaluator.evaluate(
        profile: profile,
        capabilities: capabilities,
      );

      expect(
        report.issues.map((issue) => '${issue.code.name}:${issue.subject}'),
        expected,
      );
    });

    test('unknown fields and wrong contracts are rejected', () {
      expect(
        () => profileCodec.decode('''
{
  "contract": "open_story.runtime_capability_profile",
  "contractVersion": 1,
  "profileId": "bad",
  "profileVersion": 1,
  "requiredFeatures": [],
  "requiredExtensions": [],
  "surprise": true
}
'''),
        throwsA(isA<StoryRuntimeCapabilityFormatException>()),
      );
      expect(
        () => capabilitiesCodec.decode('''
{
  "contract": "open_story.not_capabilities",
  "contractVersion": 1,
  "runtimeId": "bad",
  "runtimeVersion": "1",
  "features": [],
  "extensions": []
}
'''),
        throwsA(isA<StoryRuntimeCapabilityFormatException>()),
      );
    });
  });
}
