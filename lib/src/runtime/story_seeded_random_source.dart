import '../state/story_value.dart';
import '../transition/story_transition_resolver.dart';
import 'story_runtime_snapshot.dart';

/// Internal deterministic pseudo-random source owned by one StoryEngine run.
///
/// The generator uses a 32-bit linear-congruential state and combines two
/// draws into an exact 53-bit candidate when resolving larger integer ranges.
/// Arithmetic remains inside the portable exact integer domain used by the
/// engine, including Dart-to-JavaScript runtimes.
final class StorySeededRandomSource implements StoryRandomSource {
  StorySeededRandomSource.fromSeed(int seed)
    : _initialSeed = _validateSeed(seed),
      _state = _validateSeed(seed);

  StorySeededRandomSource._fromState({
    required int initialSeed,
    required int state,
  }) : _initialSeed = _validateSeed(initialSeed),
       _state = _validateSeed(state);

  /// Stable runtime-snapshot identity of the deterministic RNG algorithm.
  ///
  /// Stage 4D freezes this ID/version pair as part of runtime-snapshot
  /// compatibility. Future algorithm changes must use a new algorithm ID or
  /// increment [runtimeStateAlgorithmVersion]; they must never silently change
  /// the sequence produced by this contract.
  static const String runtimeStateAlgorithmId = 'story_engine.lcg32';
  static const int runtimeStateAlgorithmVersion = 1;

  /// Number and meaning of state words for `story_engine.lcg32` version 1.
  ///
  /// Word 0 is the original seed and word 1 is the current 32-bit LCG state.
  /// Both are persisted because the current state controls future output while
  /// the original seed remains public runtime provenance through
  /// `StoryEngine.randomSeed`.
  static const int runtimeStateWordCount = 2;
  static const int runtimeStateInitialSeedWordIndex = 0;
  static const int runtimeStateCurrentStateWordIndex = 1;

  static const int maxSeed = 4294967295;
  static const int _modulus = 4294967296;
  static const int _multiplier = 1664525;
  static const int _increment = 1013904223;
  static const int _highPartRange = 2097152; // 2^21
  static const int _exact53Range = 9007199254740992; // 2^53

  final int _initialSeed;
  int _state;

  int get initialSeed => _initialSeed;

  StorySeededRandomSource copy() => StorySeededRandomSource._fromState(
    initialSeed: _initialSeed,
    state: _state,
  );

  /// Captures the complete deterministic state needed to resume this stream.
  ///
  /// The first state word preserves the original construction seed as runtime
  /// provenance; the second is the current LCG state that controls future
  /// random output. Callers treat both words as opaque through
  /// [StoryRuntimeRandomState].
  StoryRuntimeRandomState createRuntimeState() => StoryRuntimeRandomState(
    algorithmId: runtimeStateAlgorithmId,
    algorithmVersion: runtimeStateAlgorithmVersion,
    stateWords: [_initialSeed, _state],
  );

  /// Validates one persisted state against the frozen RNG snapshot contract.
  static void validateRuntimeState(StoryRuntimeRandomState runtimeState) {
    if (runtimeState.algorithmId != runtimeStateAlgorithmId) {
      throw StorySeededRandomStateException(
        message: 'Unsupported random algorithm ${runtimeState.algorithmId}.',
      );
    }
    if (runtimeState.algorithmVersion != runtimeStateAlgorithmVersion) {
      throw StorySeededRandomStateException(
        message:
            'Unsupported $runtimeStateAlgorithmId algorithm version '
            '${runtimeState.algorithmVersion}.',
      );
    }
    if (runtimeState.stateWords.length != runtimeStateWordCount) {
      throw StorySeededRandomStateException(
        message:
            '$runtimeStateAlgorithmId v$runtimeStateAlgorithmVersion '
            'requires exactly $runtimeStateWordCount state words.',
      );
    }

    final initialSeed =
        runtimeState.stateWords[runtimeStateInitialSeedWordIndex];
    final state = runtimeState.stateWords[runtimeStateCurrentStateWordIndex];
    if (initialSeed > maxSeed || state > maxSeed) {
      throw StorySeededRandomStateException(
        message:
            '$runtimeStateAlgorithmId state words must be within '
            '0..$maxSeed.',
      );
    }
  }

  /// Recreates a deterministic stream from one compatible persisted state.
  static StorySeededRandomSource restoreRuntimeState(
    StoryRuntimeRandomState runtimeState,
  ) {
    validateRuntimeState(runtimeState);

    return StorySeededRandomSource._fromState(
      initialSeed: runtimeState.stateWords[runtimeStateInitialSeedWordIndex],
      state: runtimeState.stateWords[runtimeStateCurrentStateWordIndex],
    );
  }

  @override
  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0 ||
        maxExclusive > StoryIntegerValue.maxPortableValue) {
      throw ArgumentError.value(
        maxExclusive,
        'maxExclusive',
        'Random bounds must be within 1..'
            '${StoryIntegerValue.maxPortableValue}.',
      );
    }

    final acceptanceLimit = _exact53Range - (_exact53Range % maxExclusive);

    while (true) {
      final candidate = _nextExact53();
      if (candidate < acceptanceLimit) {
        return candidate % maxExclusive;
      }
    }
  }

  int _nextExact53() {
    final high21 = _nextUint32() % _highPartRange;
    final low32 = _nextUint32();
    return high21 * _modulus + low32;
  }

  int _nextUint32() {
    _state = (_multiplier * _state + _increment) % _modulus;
    return _state;
  }
}

/// Internal incompatibility raised when persisted random state cannot be
/// interpreted by the current seeded runtime implementation.
final class StorySeededRandomStateException implements Exception {
  const StorySeededRandomStateException({required this.message});

  final String message;

  @override
  String toString() => 'StorySeededRandomStateException: $message';
}

int _validateSeed(int seed) {
  if (seed < 0 || seed > StorySeededRandomSource.maxSeed) {
    throw ArgumentError.value(
      seed,
      'randomSeed',
      'StoryEngine randomSeed must be within 0..'
          '${StorySeededRandomSource.maxSeed}.',
    );
  }
  return seed;
}
