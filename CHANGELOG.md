# Changelog

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
