# Changelog

## 0.9.1

- Reject nonportable Story Format and runtime-bundle paths, including Windows
  drive paths, alternate data streams, and reserved device names.
- Reject cyclic extension payloads and payloads deeper than 128 nested
  containers. Story Format decoding reports a codec error.
- Reject values outside 0–255 when hashing or building runtime-bundle artifacts.
- Make the repository's Flutter example contract test work with LF and CRLF.

Custom paths and extension payloads accepted by earlier versions may now
need adjustment. Canonical event and module paths, hashes of valid bytes,
and the existing Story Format and snapshot versions are unchanged.

## 0.9.0

- Finalize the independently versioned Story Format v1, core runtime semantics,
  deterministic LCG32 randomness, and checkpoint contracts.
- Add aggregate save and restore, simultaneous sessions, suspendable host actions,
  and optional execution traces.
- Add reusable authored analysis, validation contexts, conformance tooling, and
  four runnable Pure-Dart examples.

See the [0.9.0 release scope](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RELEASE_0_9_0.md)
and [development history](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/DEVELOPMENT_HISTORY_0_9_0.md).

## 0.1.0-alpha.1

First public alpha release of `story_engine`.

- Pure-Dart runtime for declarative interactive narrative and event systems.
- Deterministic story traversal with direct, conditional, weighted, and terminal transitions.
- Typed scalar story state with declarative conditions and effects.
- Static project validation with stable diagnostic codes, locations, severity, and repair guidance.
- Deterministic runtime snapshot capture, JSON persistence, compatibility validation, and restore.
- Frozen Story Format v1 authored-project contract with deterministic encode/decode behavior.
- Public API exposed only through `package:story_engine/story_engine.dart`; implementation details remain under `lib/src/`.
- Pure-Dart and downstream Flutter examples.
- Reproducible 100/500/1,000-event regression and performance workloads.

The Dart package API is intentionally pre-1.0 and may still evolve between alpha releases. Story Format v1 is versioned independently and remains a frozen compatibility contract.
