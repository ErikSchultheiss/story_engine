# Independent C# Runtime Spike — Stage 8O Proof

Status: completed architecture/conformance proof. This document records the
scope and interpretation of the Stage 8O second-runtime spike. It does not
standardize a production C# SDK API and does not commit the ecosystem to the
prototype's internal class structure.

## 1. Purpose

The engine-neutral strategy is only credible if the written Story Format,
runtime-semantics, deterministic-random, and conformance contracts are
sufficient for an implementation that does not depend on Dart runtime source.
Stage 8O therefore introduces a deliberately small C# implementation as an
independent pressure test.

The spike MUST be implemented from the language-neutral specifications and
shared fixture data. It MUST NOT use private Dart implementation details as a
semantic oracle, and it MUST NOT be produced as a line-by-line source port.

If an independently written implementation requires undocumented Dart behavior
to reproduce a committed fixture, that is specification feedback. The correct
response is to clarify/version the language-neutral contract, not to encode a
hidden Dart special case in C#.

## 2. Deliberately non-production status

The Stage 8O implementation is:

- independent of Unity;
- independent of Flutter and Dart source;
- a console conformance harness rather than a game-engine plugin;
- dependency-light and intentionally small;
- permitted to use prototype-native names and internal structures; and
- disposable or substantially redesignable after the proof.

It is NOT:

- the future production Unity SDK;
- a commitment to the final C# public API;
- a replacement for the Dart reference runtime;
- a portable-snapshot implementation;
- an implementation of every Stage 8E–8N capability; or
- permission to redefine a committed conformance vector.

A later production C# runtime may reuse concepts where appropriate, but it must
be designed as a supported SDK rather than treating this spike's implementation
details as compatibility obligations.

## 3. Implemented proof profile

The spike implements the minimum executable core required by the committed
`runtime-core-v1-foundation` corpus:

- Story Format v1 fixture loading;
- Boolean, Integer, Number, String, and unset scalar state;
- project-default and explicit initial state;
- `all`, `any`, `not`, set/unset, and scalar comparison conditions;
- set/unset/increment/decrement effects in authored order;
- direct, conditional, weighted, and terminal transitions;
- interactive, continuation, and automatic event modes;
- `story_engine.lcg32` algorithm version 1;
- structural runtime history; and
- explicit termination.

The runner executes all six foundation cases from the same committed fixture
set used by the Dart reference implementation:

1. `lantern-mystery/canonical-good`;
2. `lantern-mystery/immediate-neutral`;
3. `lantern-mystery/weighted-safe`;
4. `lantern-mystery/weighted-collapse`;
5. `lantern-mystery/cold-route`; and
6. `lantern-mystery/low-trust-fallback`.

It also checks the deterministic-random reference sequences, exact-53 candidate
construction, bounded sampling, and the rejection-sampling vector before the
whole-runtime cases are accepted.

## 4. Shared-input rule

The spike reads the existing committed files under:

```text
conformance/fixtures/runtime-core-v1/
```

It does not maintain a C#-specific copy of expected traces or final results.
The same fixture manifest, Story Format project, initial state, input traces,
expected observations, expected final states, and expected histories are the
cross-runtime source of truth.

A passing spike MUST emit an `open_story.conformance_report / 1` result in which
every listed foundation case is `pass`. Rewriting fixture expectations to match
the spike is forbidden.

## 5. Independence boundary

The spike lives outside the `story_engine` Dart package in the combined
development workspace. C# source MUST NOT import, parse, generate from, or copy
private `lib/src` implementation code.

Using the public documents is required. Reading the data-only fixture corpus is
required. Native C#/.NET representations and control-flow structures are an
implementation choice as long as observable semantics agree.

The spike intentionally has no `UnityEngine` dependency and no NuGet package
dependencies. This isolates the semantic proof from editor APIs, asset import,
Unity lifecycle behavior, or SDK packaging concerns.

## 6. What the proof does and does not establish

A successful run establishes that the current core contracts are independently
implementable for the behavior exercised by the foundation corpus. In
particular, the same explicit seed reaches the same weighted branch and the
same authored inputs produce equivalent observable trace/state/history results.

It does not prove that every future or unexercised edge case is specified
perfectly. New ambiguity found later still requires contract review. It also
does not claim Stage 8E+ orchestration, asynchronous host actions, modular
loading, content patching, capabilities, presentation identity, or observability
are already implemented by the C# spike.

## 7. Stage 9 hard gate

Stage 8O is a hard architecture gate: serious Stage 9 authoring-shell work that
relies on engine-neutral execution assumptions must not begin until this second
runtime can build and pass the selected shared conformance profile.

Stage 8P follows the second-runtime proof and freezes the adoption/migration
boundary. Production Unity/Godot/Unreal SDK work remains later roadmap work.
