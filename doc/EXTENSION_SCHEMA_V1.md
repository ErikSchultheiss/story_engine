# Extension Schema — Contract Version 1

Status: **Stage 8E normative ecosystem contract.**

Extension Schema v1 defines how a producer describes custom narrative actions,
custom conditions, enums, and host-owned reference types as portable data. The
contract is language-neutral and host-engine-neutral. It does **not** contain
Dart, C#, C++, GDScript, Blueprint graphs, callbacks, reflection names, object
pointers, or any other executable implementation detail.

This contract is separate from frozen Story Format v1. Story Format v1's
`extensions.json` remains an opaque metadata-preservation mechanism and does not
become executable merely because an Extension Schema exists.

## 1. Contract identity and versioning

An Extension Schema v1 document is a JSON object with:

```json
{
  "contract": "open_story.extension_schema",
  "contractVersion": 1,
  "namespace": "com.example.rpg",
  "schemaVersion": 3,
  "enums": [],
  "referenceTypes": [],
  "actions": [],
  "conditions": []
}
```

`contractVersion` versions this ecosystem wire contract. `schemaVersion` is a
positive, producer-controlled revision of one named schema and is independent
from Story Format versions, runtime package versions, and the Extension Schema
contract version. Capability/range negotiation across schema revisions is Stage
8M work; Stage 8E does not invent implicit compatibility between revisions.

A namespace contains at least two lower-case ASCII dot-separated components.
Each component starts with a letter and then contains only lower-case letters,
digits, `_`, or `-`. Producers should use a collision-resistant namespace they
control, normally reverse-domain style.

## 2. Security and trust boundary

**A schema is data, not code.** Opening a story project or an Extension Schema
must not execute host logic.

The safe trust split is:

```text
untrusted / portable data
  Story project
  Extension Schema
  reference catalogs
           |
           v
trusted host integration
  implementation registry
  game/application code
```

A host implementation registry may map a declared semantic identity such as:

```text
(com.example.rpg, schemaVersion 3, action, start_combat)
```

to trusted code. That mapping is deliberately absent from the schema document.
The schema never names a Dart function, C# method, C++ symbol, Godot script, or
Blueprint asset that a loader should invoke automatically.

## 3. Stable identifiers

Action IDs, condition IDs, enum IDs, enum-value IDs, reference-type IDs, and
parameter names use:

```text
[a-z][a-z0-9_]*
```

These are stable machine identities within their declared scope. Human labels
belong in metadata and may change without changing semantic identity.

## 4. Parameter type system

Stage 8E deliberately keeps the extension parameter domain small and portable:

| Kind | Meaning |
|---|---|
| `boolean` | Boolean |
| `integer` | exact integer in `[-(2^53-1), +(2^53-1)]` |
| `number` | finite IEEE-754 binary64 Number |
| `string` | Unicode string |
| `enum` | stable value ID from a declared enum |
| `reference` | opaque string identity from a host-owned reference domain |

Types are encoded as objects:

```json
{ "kind": "boolean" }
{ "kind": "integer" }
{ "kind": "number" }
{ "kind": "string" }
{ "kind": "enum", "enumId": "combat_mode" }
{ "kind": "reference", "referenceTypeId": "enemy" }
```

Integer and Number are distinct. A Number default is encoded as a JSON number
that decodes as a non-integer finite binary64 value in implementations that
preserve this distinction. Cross-language JSON lexical canonicalization remains
a conformance concern identified by Stage 8A; implementations must not silently
coerce the declared semantic type.

Stage 8E does not add arbitrary nested object/list parameter types. Rich game
objects remain host-owned references, and richer generic value structures require
separate design evidence rather than one host game's convenience.

## 5. Parameters

Each action/condition parameter contains:

```json
{
  "name": "mode",
  "type": { "kind": "enum", "enumId": "combat_mode" },
  "required": false,
  "default": "normal"
}
```

Rules:

- parameter names are unique within their action or condition;
- `required` is mandatory and Boolean;
- required parameters do not declare defaults;
- optional parameters may omit `default`;
- a default must exactly match the declared semantic type;
- enum defaults must name a value declared by the referenced enum;
- reference defaults are non-empty opaque strings;
- unknown fields are rejected by the v1 codec rather than guessed.

`null` is not a parameter value in Extension Schema v1. Absence is represented
by an omitted optional argument. This avoids creating a second unset/null model
before such semantics are demonstrated to be useful.

## 6. Enums

An enum declares a stable ID and at least one stable value:

```json
{
  "id": "combat_mode",
  "values": [
    { "id": "normal" },
    { "id": "ambush" }
  ]
}
```

Value order is authored/editor order, not semantic precedence. Enum IDs are
unique per schema; values are unique per enum.

## 7. Reference types

A reference type declares a safe host-owned identity domain:

```json
{
  "id": "enemy",
  "metadata": { "label": "Enemy" }
}
```

A schema does **not** embed the referenced host objects. A separate reference
catalog may later let an authoring tool offer pickers for `ancient_dragon`,
`queen_alveria`, `castle_cellar`, and similar stable host IDs. Catalog transport,
freshness, and large-catalog indexing are separate integration concerns.

A runtime receives the declared string identity and lets trusted host code
resolve it. The narrative core must not deserialize arbitrary game-engine
objects from project data.

## 8. Actions

An action declares an ID, typed parameters, and optional metadata:

```json
{
  "id": "start_combat",
  "parameters": [
    {
      "name": "enemy",
      "type": { "kind": "reference", "referenceTypeId": "enemy" },
      "required": true
    }
  ]
}
```

Stage 8E defines the declaration only. Stage 8I now defines asynchronous
suspension, typed completion/failure/cancellation, and pending-request snapshot
behavior in the separate Host Interaction Protocol Revision 1. It still does not
turn Extension Schema documents into executable callback registrations.

## 9. Conditions

A condition declares an ID and typed parameters. Its semantic result is Boolean:

```json
{
  "id": "enemy_defeated",
  "parameters": [
    {
      "name": "enemy",
      "type": { "kind": "reference", "referenceTypeId": "enemy" },
      "required": true
    }
  ]
}
```

The schema never contains the implementation that computes the Boolean result.
Condition implementations must remain observational/side-effect-free from the
narrative runtime's point of view. Explicit host/world inputs and authority
rules are refined by later Stage 8 contracts.

## 10. Metadata

Schema documents and members may carry:

```json
{
  "metadata": {
    "label": "Start Combat",
    "helpText": "Ask the host to begin combat.",
    "editor": {
      "category": "Gameplay",
      "icon": "swords"
    }
  }
}
```

`label` and `helpText` are human-facing. `editor` is optional portable
JSON-shaped metadata. Editor metadata is explicitly **non-semantic**: changing
or ignoring it must not alter narrative execution.

The `editor` value may contain null, Boolean, portable Integer, finite Number,
String, arrays, and string-keyed objects. Executable values are forbidden.

## 11. Schema validation

A v1 schema is invalid when, among other cases:

- the contract identity/version is unsupported;
- the namespace or a machine identifier is malformed;
- IDs duplicate within their scope;
- an enum has no values;
- a parameter references an undeclared enum/reference type;
- a default has the wrong type;
- an enum default is outside its enum;
- a portable integer is outside `±(2^53-1)`;
- a Number is non-finite;
- required fields are absent; or
- unknown semantic fields appear in a v1 object.

Strict schema parsing is intentional. Forward evolution happens through an
explicit contract version rather than by making runtimes silently interpret
unknown semantics differently.

## 12. Safe unknown-extension behavior

The ecosystem distinguishes **opaque metadata** from **semantic extension
requests**.

### 12.1 Unknown opaque Story Format v1 attachment

Story Format v1 already permits namespaced opaque metadata. A conforming v1
format tool preserves that attachment according to the frozen v1 rules. The
core does not execute it.

### 12.2 Unknown semantic namespace/member

If authored narrative semantics request an action or condition whose namespace,
schema revision, member, or required parameter contract is unavailable, a
runtime/tool must report incompatibility or validation failure.

It is forbidden to:

- silently treat an unknown action as a no-op;
- silently treat an unknown condition as `false` or `true`;
- guess a similarly named member;
- invoke code named by untrusted project/schema data; or
- silently downgrade to a different schema revision.

Stage 8M now defines the exact capability-reporting/version-range mechanism
in `RUNTIME_CAPABILITIES_V1.md`. **Silent semantic fallback remains forbidden by
Stage 8E and is now also a target-compatibility rule.**

## 13. Relationship to Story Format v1

Story Format v1 is frozen and contains no semantic `customAction` or
`customCondition` node. Extension Schema v1 therefore does not change the v1
wire representation.

A future Story Format version or explicitly versioned semantic extension profile
may define how authored action/condition invocations are represented. When that
happens, an invocation must identify enough information to resolve a declared
schema member without embedding host-language implementation details.

Until such a representation is standardized, opaque `extensions.json` payloads
must **not** be interpreted as executable action/condition calls.

## 14. Relationship to runtime implementations

The Dart reference package exposes data models and a strict JSON codec for this
schema contract so tools can parse/validate schemas without executing host code.
Other runtimes may use completely different language APIs as long as they honor
the same wire/data semantics.

Host implementation registration, invocation, suspend/resume, simultaneous
sessions, capability negotiation, and external reference catalogs remain
separate layers. Stage 8G uses schema-oriented condition identities only to
label explicit host-computed Boolean facts for entry resolution; it still does
not register or execute host condition code.

## 15. Reference example

The public source repository includes:

```text
conformance/extensions/schema-v1/com.example.rpg.schema.json
```

It demonstrates actions, conditions, enums, references, defaults, and editor
metadata using data only. It is reference material for future Studio and runtime
integration work; it is not part of Story Format v1.

## 16. Stage boundary

Stage 8E freezes the **declaration/trust contract** needed before detailed editor
architecture is defined. Stage 8F may now specify how a Flutter/Dart authoring
application loads these schemas while persisting only language-neutral project
data and using public runtime APIs.

Stage 8G now owns host-driven entry activation, persistent/session runtime
boundaries, and explicit host-world Boolean facts used by entry resolution.
Later stages still own:

- 8I — suspendable host action request/completion semantics, now defined by
  `HOST_ACTION_PROTOCOL_V1.md`;
- 8J — simultaneous-session concurrency and conflicting-write semantics;
- 8M — capability reporting and extension-version negotiation, now defined by
  `RUNTIME_CAPABILITIES_V1.md`.
