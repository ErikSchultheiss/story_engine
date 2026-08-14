import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('snapshot RNG implementation is engine-owned deterministic pure Dart', () {
    final source = File(
      'lib/src/runtime/story_seeded_random_source.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:math'")));
    expect(source, isNot(contains('Random(')));
    expect(source, isNot(contains('../persistence/')));
    expect(source, isNot(contains('package:flutter/')));
    expect(source, isNot(contains('package:cyoa_studio/')));
  });

  test('lcg32 v1 snapshot identity and two-word state shape stay explicit', () {
    final source = File(
      'lib/src/runtime/story_seeded_random_source.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("runtimeStateAlgorithmId = 'story_engine.lcg32'"),
    );
    expect(source, contains('runtimeStateAlgorithmVersion = 1'));
    expect(source, contains('runtimeStateWordCount = 2'));
    expect(source, contains('runtimeStateInitialSeedWordIndex = 0'));
    expect(source, contains('runtimeStateCurrentStateWordIndex = 1'));
  });

  test('engine snapshots persist current RNG state rather than seed alone', () {
    final engineSource = File(
      'lib/src/runtime/story_engine.dart',
    ).readAsStringSync();
    final randomSource = File(
      'lib/src/runtime/story_seeded_random_source.dart',
    ).readAsStringSync();

    expect(engineSource, contains('randomState: randomSource.createRuntimeState()'));
    expect(randomSource, contains('stateWords: [_initialSeed, _state]'));
    expect(
      engineSource,
      contains('StorySeededRandomSource.restoreRuntimeState(randomState)'),
    );
  });
}
