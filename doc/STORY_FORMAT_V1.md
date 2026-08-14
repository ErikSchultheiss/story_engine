# Story Format v1

This document is the normative portable authored-project specification for
`story_engine` Story Format version 1.

A conforming implementation can read or write Story Format v1 without using
Dart, Flutter, a particular editor, any internal draft codec, or the runtime-snapshot
format. The Dart package remains the reference implementation and the committed
canonical fixtures remain byte-level conformance examples.

## 1. Scope

Story Format v1 serializes **authored project data**. It does not serialize a
running playthrough.

The format contains:

- project identity and scalar state declarations;
- events and choices;
- presentation text;
- declarative conditions;
- declarative effects;
- declarative transitions;
- optional runtime-neutral authoring groups and tags;
- optional namespaced opaque metadata extensions.

It does not contain:

- current runtime state;
- runtime history;
- RNG state;
- save/checkpoint state;
- Flutter widgets or Dart callbacks;
- filesystem/database policy;
- executable source code;
- mandatory chapters or sections.

Runtime saves use the independently versioned `StoryRuntimeSnapshot` format.

## 2. Format identity and version

Every `project.json` MUST contain:

```json
{
  "formatId": "story_engine.story_format",
  "formatVersion": 1,
  "project": {}
}
```

The frozen identity is `story_engine.story_format`.

The frozen version is `1`.

A reader MUST distinguish an unsupported format identity/version from malformed
current-v1 data. A future incompatible change to the v1 contract MUST use a new
Story Format version and, where supported, a package-owned migration path.
Existing v1 tokens MUST NOT be silently redefined.

## 3. Logical bundle

Story Format v1 is a logical bundle of UTF-8 JSON text files using portable
forward-slash relative paths.

Canonical core layout:

```text
project.json                                  required
events/<stable-event-token>.json              one per event
organization.json                             optional
extensions.json                               optional
```

`organization.json` is omitted when organization metadata is empty.
`extensions.json` is omitted when there are no extension attachments.
An empty project may contain only `project.json`.

Unknown core bundle paths are rejected by the v1 reference reader.

### 3.1 Portable bundle paths

Bundle paths:

- MUST be non-empty;
- MUST be relative;
- MUST use `/`, not `\\`;
- MUST NOT contain empty, `.` or `..` path segments.

### 3.2 Stable event filenames

Event filenames are derived **only** from the exact stable event ID. Aliases,
titles, group placement and authored event order never participate in the path.

The filename token is RFC 4648 Base32 of the ASCII event-ID bytes, using the
lower-case alphabet:

```text
abcdefghijklmnopqrstuvwxyz234567
```

with no `=` padding.

The path is:

```text
events/<base32-token>.json
```

Reference vectors:

```text
event_intro   -> mv3gk3tul5uw45dsn4
Event.Intro:1 -> iv3gk3tufzew45dsn45dc
```

A duplicate event ID cannot be represented as two canonical event files and is
therefore an encoding error.

## 4. Identifier and alias lexical rules

Machine IDs used by projects, events, choices, variables, groups and tags are
stable opaque ASCII tokens.

A machine ID:

- is 1-128 characters;
- starts with an ASCII letter or digit;
- after the first character may contain ASCII letters, digits, `.`, `_`, `:`,
  or `-`.

Equivalent regular expression:

```text
^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$
```

Aliases are optional developer-facing names, never primary identity.

An alias:

- is 1-80 characters;
- starts with a lower-case ASCII letter;
- then contains lower-case ASCII letters, digits, or `_`.

Equivalent regular expression:

```text
^[a-z][a-z0-9_]{0,79}$
```

## 5. Canonical JSON

Canonical `story_engine` writers produce JSON with:

- two-space indentation;
- LF (`\n`) newlines;
- one final newline per file;
- fixed object-field order as shown by the reference implementation/fixtures;
- authored array order where order has semantic or authoring meaning;
- canonical ordering for set-like collections;
- no generated timestamps or package-version noise.

Readers may accept noncanonical whitespace. Re-encoding a successfully decoded
bundle yields canonical v1 output.

JSON object fields that are optional are omitted when absent; they are not
encoded as `null` unless the field is part of an opaque extension payload.

Unknown current-v1 core fields are rejected. Tools that need opaque metadata
MUST use `extensions.json`.

## 6. `project.json`

Canonical shape:

```json
{
  "formatId": "story_engine.story_format",
  "formatVersion": 1,
  "project": {
    "id": "project_id",
    "alias": "optional_alias",
    "stateSchema": {
      "variables": []
    },
    "eventIds": ["event_a", "event_b"],
    "entryEventId": "event_a"
  }
}
```

Root fields are exactly:

```text
formatId
formatVersion
project
```

`project` fields are:

```text
id                 required
alias              optional
stateSchema        required
eventIds           required
entryEventId       optional
```

`eventIds` is authoritative for bundle membership and preserves authored event
order. Directory enumeration is not authored order. Event IDs in this manifest
MUST be unique because each stable event identity owns exactly one canonical
event file.

An entry event may be absent or may temporarily reference a missing event;
`StoryValidator` owns semantic validity.

## 7. State schema and scalar values

`stateSchema` contains one required field:

```json
{
  "variables": []
}
```

Each variable declaration is:

```json
{
  "id": "var_score",
  "alias": "score",
  "type": "integer",
  "initialValue": {"type": "integer", "value": 0}
}
```

Fields:

```text
id            required
alias         optional
type          required
initialValue  optional
```

Frozen scalar type tokens are:

- `boolean`
- `integer`
- `number`
- `string`

Typed scalar literal shapes are:

```json
{"type": "boolean", "value": true}
{"type": "integer", "value": 42}
{"type": "number", "value": 1.5}
{"type": "string", "value": "text"}
```

Variable IDs MUST be unique within the state schema. Non-null variable aliases
MUST also be unique within the variable namespace. When `initialValue` is
present, its scalar `type` MUST exactly match the variable declaration `type`.

Story integers are constrained to the portable exact range
`-9007199254740991..9007199254740991`. Story numbers must be finite; NaN and
infinity are invalid.

## 8. Event files

Each event ID in `project.eventIds` owns one canonical stable-ID event file.

Canonical event shape:

```json
{
  "id": "event_a",
  "alias": "optional_alias",
  "presentation": {
    "title": "Optional title",
    "body": "Optional body"
  },
  "availabilityCondition": {"kind": "variable_is_set", "variableId": "flag"},
  "entryEffects": [],
  "choices": [],
  "continuationTransition": {"kind": "terminal"},
  "automaticTransition": {"kind": "terminal"}
}
```

Fields:

```text
id                      required
alias                   optional
presentation            optional
availabilityCondition   optional
entryEffects            required
choices                 required
continuationTransition  optional
automaticTransition     optional
```

The event ID inside the file MUST match both the manifest ID and the ID-derived
canonical path.

Story Format v1 can preserve temporarily incomplete or ambiguous flow. The
format codec does not enforce the interactive/continuation/automatic runtime
mode rules; `StoryValidator` does.

### 8.1 Event presentation

Event presentation contains one or both of:

```text
title
body
```

An explicitly present empty presentation object with neither field is malformed
v1. The text strings themselves may be empty; authoring-quality diagnostics are
handled separately by `StoryValidator`.

## 9. Choices

A choice is embedded inside its owning event:

```json
{
  "id": "choice_a",
  "alias": "optional_alias",
  "presentation": {"text": "Visible choice"},
  "availabilityCondition": {"kind": "variable_is_set", "variableId": "flag"},
  "effects": [],
  "transition": {"kind": "terminal"}
}
```

Fields:

```text
id                     required
alias                  optional
presentation           optional
availabilityCondition  optional
effects                required
transition             optional
```

Choice presentation, when present, is exactly:

```json
{"text": "Visible choice"}
```

A choice without a transition is persistable incomplete editor work and is
reported later by validation.

## 10. Conditions

Every condition is a JSON object with a frozen `kind` token.

### `all`

```json
{
  "kind": "all",
  "conditions": [
    {"kind": "variable_is_set", "variableId": "flag"}
  ]
}
```

### `any`

```json
{
  "kind": "any",
  "conditions": [
    {"kind": "variable_is_unset", "variableId": "flag"}
  ]
}
```

### `not`

```json
{
  "kind": "not",
  "condition": {"kind": "variable_is_set", "variableId": "flag"}
}
```

### `variable_is_set`

```json
{
  "kind": "variable_is_set",
  "variableId": "flag"
}
```

### `variable_is_unset`

```json
{
  "kind": "variable_is_unset",
  "variableId": "flag"
}
```

### `variable_comparison`

```json
{
  "kind": "variable_comparison",
  "variableId": "score",
  "operator": "greater_than_or_equal",
  "value": {"type": "integer", "value": 10}
}
```

Frozen comparison operator tokens are:

- `equal`
- `not_equal`
- `less_than`
- `less_than_or_equal`
- `greater_than`
- `greater_than_or_equal`

Condition child order is authored order and MUST be preserved. `all` and `any`
MUST contain at least one child condition; absence of a condition represents
unconditional behavior. Ordering comparisons (`less_than`,
`less_than_or_equal`, `greater_than`, `greater_than_or_equal`) are valid only
with `integer` or `number` literal operands. Boolean and string comparisons use
`equal` / `not_equal` only.

## 11. Effects

Every effect is declarative data with a frozen `kind` token.

### `set_variable`

```json
{
  "kind": "set_variable",
  "variableId": "score",
  "value": {"type": "integer", "value": 10}
}
```

### `unset_variable`

```json
{
  "kind": "unset_variable",
  "variableId": "score"
}
```

### `increment_variable`

```json
{
  "kind": "increment_variable",
  "variableId": "score",
  "amount": {"type": "integer", "value": 1}
}
```

### `decrement_variable`

```json
{
  "kind": "decrement_variable",
  "variableId": "score",
  "amount": {"type": "integer", "value": 1}
}
```

Effect-array order is authored execution order and MUST be preserved. Increment
and decrement `amount` values MUST be non-negative `integer` or `number`
literals. Variable/schema compatibility is a semantic validation/runtime
concern; the effect object itself carries only stable variable identity and the
declarative value/amount.

## 12. Transitions

Transitions are the sole authored navigation mechanism.

### `event`

```json
{
  "kind": "event",
  "destinationEventId": "event_b"
}
```

### `conditional`

```json
{
  "kind": "conditional",
  "branches": [
    {
      "condition": {"kind": "variable_is_set", "variableId": "flag"},
      "transition": {"kind": "event", "destinationEventId": "event_b"}
    }
  ],
  "fallback": {"kind": "terminal"}
}
```

Conditional transitions MUST contain at least one branch and MUST contain an
explicit `fallback`. Branch order is authored first-match order and MUST be
preserved.

### `weighted`

```json
{
  "kind": "weighted",
  "options": [
    {"weight": 2, "transition": {"kind": "event", "destinationEventId": "event_b"}},
    {"weight": 1, "transition": {"kind": "terminal"}}
  ]
}
```

Weighted transitions MUST contain at least one option. Weighted option order is
authored order and MUST be preserved. Every weight MUST be a positive integer.
Each individual weight and the combined total MUST be no greater than
`9007199254740991`, preserving exact deterministic integer behavior across Dart
VM and JavaScript-based runtimes.

### `terminal`

```json
{"kind": "terminal"}
```

Unknown transition kinds are errors. A reader MUST NOT silently treat an
unknown transition as terminal, absent, or direct flow.

## 13. `organization.json`

Organization is optional **authoring metadata** and has no runtime control-flow
semantics.

Shape:

```json
{
  "groups": [],
  "tags": []
}
```

### 13.1 Groups

```json
{
  "id": "group_main",
  "alias": "main",
  "label": "Main story",
  "eventIds": ["event_a"],
  "children": []
}
```

Fields:

```text
id        required
alias     optional
label     optional
eventIds  required
children  required
```

Groups form the optional primary organization tree. Group IDs MUST be unique
across the complete tree. Group order, event order, and child-group order are
authored order. An event may appear at most once across the primary group tree.
Events may remain ungrouped.

A group is deliberately generic. It is not a runtime `chapter` or `section`.
Moving an event between groups does not change its event file or runtime flow.

### 13.2 Tags

```json
{
  "id": "tag_secret",
  "alias": "secret",
  "label": "Secret",
  "eventIds": ["event_a", "event_b"]
}
```

Tag IDs MUST be unique within one organization. Tag declarations preserve
authored order. Tag event membership is set-like: duplicate event IDs within a
tag are invalid, and canonical membership is ordered by stable event ID.

Organization references may temporarily point to absent events while editor
work is incomplete; they are preserved for repair rather than pruned.

## 14. `extensions.json`

Opaque extensions are the only v1 mechanism for unknown non-semantic metadata.
They never add executable behavior to the engine.

Shape:

```json
{
  "attachments": [
    {
      "namespace": "com.example.editor_notes",
      "target": {"kind": "event", "id": "event_a"},
      "payload": {"note": "opaque declarative metadata"}
    }
  ]
}
```

Extension namespaces contain at least two lower-case ASCII dot-separated
components. Each component starts with a letter and then contains letters,
digits, `_`, or `-`.

Frozen extension target `kind` tokens are:

- `project`
- `event`
- `choice`
- `variable`
- `group`
- `tag`

A project target is exactly:

```json
{"kind": "project"}
```

Other targets contain `kind` plus stable `id`.

Extension payloads are JSON-shaped declarative data only: null, booleans,
strings, portable integers, finite numbers, arrays, and string-keyed objects.
They cannot contain source code or host-language objects.

Attachments are canonicalized by target kind in this order: `project`, `event`,
`choice`, `variable`, `group`, `tag`; non-project targets then sort by stable ID,
and attachments with the same target sort by namespace. Payload object keys are
canonicalized lexicographically by the reference writer. A given
`(target, namespace)` pair may appear at most once.

Unknown extension namespaces and opaque payload keys are preserved. Unknown
core semantic fields/kinds are **not** extensions and are rejected.

## 15. Incomplete authored work and validation

Successful format decoding does not mean a project is runnable.

A v1 reader may successfully construct authored data containing representable
work-in-progress conditions such as:

- no entry event;
- entry ID pointing to a missing event;
- choice without a transition;
- event with no valid flow;
- temporarily ambiguous event flow;
- transition to a missing destination;
- condition/effect references to undeclared variables;
- dangling group/tag/extension targets.

These are persisted so editors can reopen and repair them. Runtime/authoring
validity is a separate `StoryValidator` concern.

Constructor-impossible values and physical stable-ID collisions are not part of
this incomplete-project guarantee.

## 16. Strict unknown-data behavior

A current-v1 reader MUST reject unknown core fields and unknown semantic
`kind`/operator/type tokens.

This is a safety property. Ignoring an unknown condition, effect or transition
could change authored behavior silently.

Opaque tool metadata belongs under namespaced extensions.

For an unsupported Story Format identity or version, a host should treat the
bundle as incompatible and may route it through a known migration path. It
should not reinterpret unknown core semantics heuristically.

## 17. Migration

Version 1 is the first public Story Format. There is no fictional production
v0.

Future package-owned migrations operate on the whole logical bundle:

```text
Story Format vN bundle
        ↓ deterministic N -> N+1 transform
Story Format vN+1 bundle
```

A multi-version upgrade requires a complete consecutive migration chain before
current-version decoding.

The committed `test/fixtures/story_format_v1/migration_source_v1/` bundle is the
real v1 baseline reserved for the first future migration.

## 18. Determinism and Git churn

The v1 file-ownership contract intentionally bounds unrelated changes:

| Authoring edit | Canonical files expected to change |
| --- | --- |
| event alias/title/body | owning event file |
| choice text | owning event file |
| event reorder | `project.json` |
| project alias | `project.json` |
| group rename/move | `organization.json` |
| tag membership | `organization.json` |
| extension payload | `extensions.json` |
| add one event | `project.json` + one new stable event file |

Event storage remains independent of mutable author-facing names and group
hierarchy.

## 19. Conformance fixtures

Canonical v1 bundles are committed under:

```text
test/fixtures/story_format_v1/
```

The current corpus includes:

- `minimal/`;
- `lantern_mystery/`;
- `incomplete_editor/`;
- `structured_large/`;
- `migration_source_v1/`.

For every canonical fixture:

```text
decode(exact committed bytes)
        ↓
encode
        ↓
exact same paths and JSON bytes
```

The fixtures, this specification, and the reference codec together are the v1
compatibility evidence. If they appear to disagree, changing shipped v1 meaning
requires an explicit architecture decision and normally a new format version;
it must not be resolved by silently changing an existing v1 token.

## 20. Separation from runtime persistence

Story Format v1 and runtime snapshots are independent contracts.

Story Format v1 contains authored definitions. `StoryRuntimeSnapshot` contains
committed playthrough state, runtime history, status and deterministic RNG
state. They have separate:

- format identities;
- version axes;
- codecs;
- validation/compatibility rules;
- migration histories.

Application-specific legacy saves are not Story Format v1 and are not runtime
snapshot v1. Legacy conversion remains the responsibility of explicit host-side adapters.

## 21. Version evolution rule

Story Format v1 is frozen.

The following require a new Story Format version unless they are strictly
compatible opaque-extension behavior:

- renaming/removing a core field;
- changing a frozen semantic token;
- changing collection ordering semantics;
- changing canonical stable event-path derivation;
- changing the meaning of an existing condition/effect/transition;
- making a previously optional core field mandatory in existing v1 data;
- changing strict unknown-core behavior;
- changing organization metadata into runtime control flow.

New public package APIs may be added without changing Story Format version if
they do not alter the serialized v1 contract.
