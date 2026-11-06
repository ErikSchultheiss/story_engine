# Story Format platform-neutrality audit — Stage 8A

Stage 8A audits frozen Story Format v1 against the revised engine-neutral
architecture. The audit verdict is:

**PASS for the authored data contract.** Story Format v1 is already
language-neutral in its serialized model and does not need a representation
change for authoring tools to target an engine-neutral ecosystem.

**NOT YET a complete multi-runtime conformance specification.** Several edge
behaviors that the Dart reference implementation currently supplies implicitly
must be specified independently before a native C#, C++, GDScript, or other
runtime can claim exact conformance.

No Story Format v1 field, token, path, ordering rule, fixture, or semantic
meaning is changed by Stage 8A.

## 1. Scope and audit method

The audit reviewed the public Story Format v1 specification, the public format
model, deterministic codec, bundle layout, canonical fixtures, architecture
freeze decisions, scalar value model, condition/effect/transition vocabulary,
and the current seeded runtime RNG boundary.

The audit asks four separate questions:

1. Is serialized authored data expressible without Dart types or source code?
2. Can another language reconstruct the same logical authored project?
3. Which exact reader/writer edge behaviors are still underspecified for
   independent implementations?
4. Which future ecosystem requirements genuinely need a new format version or
   another explicitly versioned contract rather than being smuggled into v1?

Runtime execution order was intentionally not re-specified by the Stage 8A
audit. It is now specified separately in
[RUNTIME_SEMANTICS_V1.md](RUNTIME_SEMANTICS_V1.md), preserving the authored-format
boundary. Exact cross-runtime random-route parity remains outside Story Format
and is now specified separately by
[DETERMINISTIC_RANDOM_V1.md](DETERMINISTIC_RANDOM_V1.md).

## 2. Platform-neutrality verdict by Story Format domain

### 2.1 Format identity and version — PASS

`story_engine.story_format` is a serialized protocol identifier, not a Dart
class or package-version dependency. `formatVersion` is an independent authored
format compatibility axis.

The historical `story_engine` name in the format ID is frozen branding of the
v1 protocol. It does not require an implementation to use Dart or the
`story_engine` Dart API.

### 2.2 Logical bundle and paths — PASS

The format is a logical mapping of portable forward-slash relative paths to
UTF-8 JSON text. It does not prescribe filesystem APIs, archive technology,
databases, package resources, Unity assets, Unreal UObjects, or another host
storage mechanism.

Event file paths are derived from stable ASCII event IDs through lower-case,
unpadded RFC 4648 Base32. Because machine IDs are ASCII, path derivation has no
host-language Unicode dependency.

### 2.3 Stable identities and aliases — PASS

Machine IDs and aliases have explicit ASCII lexical rules. They are serialized
as opaque strings and do not depend on Dart object identity, enum ordinals,
hash codes, memory addresses, or source-language identifiers.

### 2.4 Scalar authored state — PASS WITH CONFORMANCE CLARIFICATIONS REQUIRED

The serialized scalar categories are protocol tokens:

- `boolean`
- `integer`
- `number`
- `string`

They are not Dart `bool`, `int`, `double`, or `String` type names. Integer range
is already bounded to the cross-platform exact range
`-9007199254740991..9007199254740991`, and non-finite numbers are invalid.

Stage 8B now defines the runtime Number domain and comparison/effect semantics
as finite IEEE-754 binary64 with ordinary numerical signed-zero relations.
Reader/writer conformance work still must make these format details explicit:

- how a JSON reader distinguishes an `integer` payload from a `number` payload
  when the surrounding JSON library exposes only one numeric abstraction;
- whether integer lexical forms using a decimal point or exponent are accepted
  or rejected by a v1 reader;
- canonical JSON spelling for finite numbers, including integral-valued
  numbers, exponent notation, and negative zero.

These are specification/conformance gaps, not permission to mutate v1 data
silently.

### 2.5 Presentation strings — PASS WITH UNICODE CLARIFICATIONS REQUIRED

Presentation and string-state values are plain JSON strings and carry no Dart
object representation. Story Format v1 intentionally performs no localization,
markup, or rich-text interpretation in the core format.

Cross-language canonical writers still need a defined policy for JSON escaping,
Unicode scalar validity, and normalization. The current format does not state
that authored text is normalized, and Stage 8A does not add normalization.
Independent implementations must not normalize visible text silently.

### 2.6 Conditions — PASS

Conditions use frozen declarative `kind` and operator tokens, stable variable
IDs, typed scalar literals, and ordered child lists. No condition contains a
Dart closure, function pointer, class name, or executable source.

Exact evaluation behavior, type mismatch behavior, short-circuiting, and
unset-state semantics are now specified by Runtime Semantics Core Revision 1.

### 2.7 Effects — PASS

Effects are declarative data describing scalar state changes. Their serialized
form contains stable IDs and typed values only. Effect execution code is not
stored in Story Format v1.

Effect ordering and numeric execution semantics are now specified independently
in Runtime Semantics Core Revision 1.

### 2.8 Transitions — PASS

Direct, conditional, weighted, and terminal transitions are represented by
language-neutral discriminator tokens and ordered data. Weighted transitions
store positive integer weights rather than RNG objects or host-language random
callbacks.

Story Format therefore describes weighted intent without embedding the random
algorithm. Exact random selection behavior belongs to the runtime conformance
contract.

### 2.9 Organization metadata — PASS

Groups and tags are generic authoring concepts. They do not imply Dart widget
hierarchy, chapters, Unity scenes, Unreal levels, Godot nodes, or runtime
control flow.

### 2.10 Opaque v1 extensions — PASS FOR THEIR CURRENT NON-SEMANTIC ROLE

`extensions.json` is language-neutral JSON data attached through stable targets
and namespaces. It contains no executable source or host-language objects.

This mechanism is deliberately **non-semantic** in v1. It must not be
reinterpreted later as executable custom conditions/actions without an explicit
new contract. Stage 8E therefore cannot simply declare that existing opaque v1
extension payloads suddenly affect runtime behavior.

### 2.11 Runtime persistence separation — PASS

Story Format v1 serializes authored project data, not a running playthrough.
Runtime snapshot identity, RNG state, history, and save compatibility remain a
separate contract. This separation is language-neutral and remains desirable in
a multi-runtime ecosystem.

## 3. No hidden Dart representation in serialized v1 semantics

The audit found no serialized dependency on:

- Dart class names;
- Dart enum names or ordinals;
- Dart closures/callbacks;
- `runtimeType`;
- object identity or hash codes;
- Flutter widgets or framework state;
- `dart:io` filesystem objects;
- package-private `story_engine/src` types;
- in-memory pointers or handles;
- platform save paths.

The Dart implementation naturally uses Dart classes internally. Those classes
are the reference implementation of protocol concepts, not part of the wire
contract.

## 4. Cross-language conformance gaps that do not justify rewriting v1

The following details must be resolved before a second runtime can claim exact
v1 reader/writer conformance. Stage 8B has separated runtime execution semantics
from these representation concerns; Stage 8D should now externalize the
remaining reader/writer behavior through explicit conformance vectors and
format-level rules where existing v1 meaning can be documented without changing
it.

### 4.1 JSON numeric lexical acceptance

The Dart reference decoder currently receives JSON parser results as Dart
numeric values and requires an integer-typed parser result for fields that are
specified as integers. Another JSON library may expose all JSON numbers through
one type or may classify exponent forms differently.

The conformance suite must therefore use explicit vectors for integer fields,
number fields, bounds, exponent forms, overflow, and invalid non-finite results.

### 4.2 Canonical floating-point rendering

V1 requires canonical output but does not fully spell out a language-neutral
finite-number-to-JSON-text algorithm. Independent writers cannot be expected to
produce byte-identical JSON until this is specified and covered by vectors.

### 4.3 Unicode and JSON escaping

Canonical byte equality requires an explicit cross-language rule for escaping
control characters, quotes, backslashes, non-ASCII text, supplementary-plane
characters, and invalid/unpaired surrogate input. Authored text must not be
silently normalized merely because one host language/library does so.

### 4.4 Canonical object-key ordering in opaque payloads

V1 says opaque extension object keys are lexicographically ordered by the
reference writer, but `lexicographic` must be defined in language-neutral terms
before another writer can guarantee byte-identical output for arbitrary Unicode
keys.

Core object field ordering is already explicitly owned by the format and is not
affected by this gap.

### 4.5 Duplicate JSON object member names

Canonical writers never emit duplicate object keys. Reader behavior for a
non-canonical input containing duplicate member names is not currently stated
with enough precision for cross-library conformance. Stage 8D should define and
test one safe behavior rather than inheriting each JSON library's default.

### 4.6 Error identity versus Dart exception types

`StoryFormatCodecException` and `StoryFormatCompatibilityException` are Dart
API types. Other runtimes do not need those class names. Cross-runtime
conformance should compare protocol-level failure categories/locations where
required, not Dart exception implementation identity or message wording.

### 4.7 Canonical writer bytes versus semantic reader compatibility

Two levels must remain distinct:

- a conforming **reader** reconstructs the same v1 authored meaning and handles
  invalid/incompatible inputs according to the specified policy;
- a canonical **writer** additionally emits the specified deterministic paths
  and exact canonical JSON representation.

This distinction lets semantic interoperability be specified cleanly while
byte-exact writer vectors are hardened deliberately.

## 5. Future requirements that cannot be smuggled into frozen v1

The broader ecosystem introduces concepts that Story Format v1 intentionally
does not model. Stage 8A records them now so future stages do not accidentally
reinterpret old v1 fields.

### 5.1 Semantic custom actions and custom conditions

V1 opaque extensions are non-semantic. Stage 8E now defines Extension Schema
contract version 1 for portable declarations of custom actions, conditions,
enums, reference types, and typed parameters. That schema contract deliberately
does not define where runtime-affecting invocations are stored in authored
projects. Invocation data still requires Story Format v2 or a separately
versioned semantic extension profile whose relationship to v1 is unambiguous.

### 5.2 Named entry points and authored orchestration metadata

V1 has at most one `entryEventId`. Host-driven open-world activation, multiple
named entry points, resolver metadata, priority/fallback declarations, or other
authored orchestration concepts are not present in v1.

Stage 8G now defines host-driven entry/session semantics in runtime APIs without
adding authored fields to v1. A future authoring/wire-format decision may still
choose to persist named entry-point metadata, but any new serialized core data
must follow normal format-version evolution rather than being inferred from
existing v1 fields.

### 5.3 Module/index metadata for large projects

V1 stores a single project manifest plus per-event files and optional
organization/extensions. It does not define independently versioned narrative
modules, module dependencies, global indexes, lazy-loading metadata, or runtime
bundle manifests.

Stage 8H/8K must keep the readable authoring format separate from any optimized
shipping bundle and decide whether authoring-level module metadata requires a
future Story Format version.

### 5.4 Runtime capability requirements

V1 does not declare required runtime capabilities or semantic extension
versions. Stage 8M now adds this through the explicitly versioned compatibility
contract; a runtime must never silently downgrade unsupported semantics.

### 5.5 Stable presentation-unit identity

V1 gives stable identity to events and choices but not to individual dialogue
lines/subtitle units below those entities. Stage 8N now defines stable
presentation-unit identity and source revision through the separate
`open_story.presentation_identity_catalog` contract. If that identity is later
serialized in the authored Story Format source of truth, it is format evolution,
not a reinterpretation of existing presentation strings.

### 5.6 Suspendable host actions

V1 has no runtime-affecting host-action request construct. Stage 8I now defines
the deterministic suspend/resume protocol independently of authored storage.
Any authored declaration that causes such a request must still use a future
explicit semantic representation rather than executable data hidden in opaque
metadata.

## 6. Requirements that belong outside Story Format versioning

Several Stage 8 foundations are essential to the ecosystem but do not, by
themselves, require Story Format v2:

- the language-neutral runtime execution semantics specification (8B);
- exact cross-runtime RNG algorithm/selection parity (8C);
- shared input/expected-output conformance fixtures and report format (8D);
- language-neutral Extension Schema declarations and schema codec semantics
  (8E);
- Studio's use of the public Dart runtime as a reference implementation while
  authoring language-neutral data (8F);
- Stage 8G host-driven entry/session APIs that do not add authored v1 fields;
- optimized compiled runtime bundles that are derived artifacts rather than the
  authoring source of truth (8K);
- host/editor integration APIs and source-control providers.

## 7. Exact seeded route parity decision and Stage 8C resolution

The ecosystem requirement is now explicit:

> Given the same conforming Story Format project, the same runtime-relevant
> initial state, the same input trace, the same RNG algorithm/version, and the
> same seed, Dart, C#, C++, Godot, and other conforming runtimes must select the
> exact same random route.

Stage 8C therefore specifies the algorithm and weighted-selection procedure in
language-neutral terms and publishes reference vectors. "Seeded" without an
algorithm contract is not sufficient.

The already-versioned Dart RNG (`story_engine.lcg32`, algorithm version 1) is
now standardized by the separate deterministic-random profile. Dart source is
reference implementation evidence; the public specification is normative.

## 8. Stage 8A invariants

The following rules are frozen for the next stages:

1. An authoring application may use Flutter/Dart internally without making authored projects Dart-specific.
2. Story Format is the language-neutral authored-project boundary.
3. `story_engine` is the Dart reference runtime, not the only intended runtime.
4. Frozen Story Format v1 is not modified merely to make the new architecture
   look cleaner.
5. Dart-specific API types are never serialized as authored semantics.
6. Unknown v1 core semantics remain strict; opaque metadata is not executable.
7. Cross-runtime ambiguities are resolved through explicit specifications and
   conformance vectors, never by assuming another language behaves like Dart.
8. Future authored capabilities that cannot be represented honestly by v1 use
   a new format/profile contract with explicit compatibility/migration policy.
9. Same seed + same inputs means the same random route across conforming
   runtimes that implement the same deterministic-random profile.

## 9. Stage 8A closeout

Stage 8A is complete when:

- this audit is retained as architecture evidence;
- regression tests protect the engine-neutral boundary and prevent premature
  Stage 8 features from being injected into frozen v1;
- the public package documentation identifies Story Format as the
  language-neutral contract and `story_engine` as the Dart reference runtime;
- downstream authoring-tool status documentation no longer describes Stage 7 as deferred;
- the Stage 8C exact-route-parity decision is recorded without implementing
  Stage 8C early.

With those conditions met, the next planned work is **Stage 8B — Runtime
semantics specification**.
