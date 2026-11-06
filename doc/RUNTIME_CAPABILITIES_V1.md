# Runtime Capability and Extension Compatibility — Revision 1

Status: Stage 8M normative ecosystem contract.

This document defines how a portable narrative project/export declares the
semantic runtime features and Extension Schema revisions it requires, how a
runtime reports what it actually implements, and how tools determine whether a
target can execute the project without changing its meaning.

The capability contract is separate from frozen Story Format v1. It is also
separate from runtime/package version strings. A runtime being newer does not
make an unsupported semantic capability compatible.

## 1. Design goals

The contract MUST:

- remain language-, engine-, UI-, and platform-neutral;
- make unsupported semantic features explicit before execution/export;
- version Extension Schema namespaces independently from runtime packages;
- produce deterministic structured diagnostics;
- permit new capabilities without silently redefining older ones; and
- fail visibly rather than silently downgrading narrative semantics.

The contract MUST NOT:

- infer support from Dart/C#/C++/GDScript type names;
- infer compatibility from package/runtime semantic-version ordering;
- silently remove unsupported effects, conditions, host actions, sessions, or
  module behavior;
- reinterpret an unknown feature as a known similarly named feature; or
- treat a missing extension implementation as a no-op/false condition.

## 2. Two wire contracts

Stage 8M defines two deterministic JSON contracts.

Project/export requirements:

```json
{
  "contract": "open_story.runtime_capability_profile",
  "contractVersion": 1,
  "profileId": "example_rpg",
  "profileVersion": 1,
  "requiredFeatures": [],
  "requiredExtensions": []
}
```

Runtime report:

```json
{
  "contract": "open_story.runtime_capabilities",
  "contractVersion": 1,
  "runtimeId": "example_runtime",
  "runtimeVersion": "2.4.0",
  "features": [],
  "extensions": []
}
```

`contractVersion` versions the JSON contract. `profileVersion` versions one
named requirements profile. `runtimeVersion` is opaque diagnostic information;
it is not used to decide semantic compatibility.

## 3. Runtime feature identities

A runtime feature ID is a stable lower-case portable token. Feature IDs describe
semantic behavior, not implementation modules or UI features.

Stage 8 capabilities are described with revision 1 identities such as:

```text
runtime_core
deterministic_random
host_actions
narrative_sessions
modular_loading
runtime_bundles
content_versioning
runtime_observability
```

These names identify contracts already specified elsewhere. A future ecosystem
revision may add further feature IDs. It MUST NOT silently change the semantics
of an existing `(featureId, revision)` pair.

Feature revision numbers are positive portable integers. They are independent
from package versions and Story Format versions.

## 4. Project capability profiles

A `open_story.runtime_capability_profile` document contains:

- `profileId` — opaque reusable profile identity;
- `profileVersion` — positive producer-controlled profile revision;
- `requiredFeatures` — feature ID plus minimum and optional maximum revision;
- `requiredExtensions` — extension namespace plus minimum and optional maximum
  schema version.

Lists are canonically ordered by feature ID/namespace for deterministic encoding.
Duplicate feature IDs or extension namespaces are invalid.

A requirement with no maximum accepts any reported revision/version greater
than or equal to the minimum. A requirement with a maximum accepts only the
inclusive range.

A producer that needs an exact revision/version sets minimum and maximum to the
same value.

## 5. Runtime capability reports

A `open_story.runtime_capabilities` document contains:

- `runtimeId` — stable implementation identity;
- `runtimeVersion` — opaque implementation/package version for diagnostics;
- `features` — exact implemented revision for each reported feature;
- `extensions` — exact implemented `schemaVersion` for each extension
  namespace.

Reporting a feature means the runtime claims to implement that exact semantic
revision. It does not mean the runtime merely exposes a similarly named API.

Reporting an extension namespace means the trusted host integration actually
implements the declared schema semantics at the reported schema version. Merely
being able to parse an Extension Schema document is not sufficient.

## 6. Extension Schema version negotiation

Extension Schema v1 already defines a producer-controlled positive
`schemaVersion` independently from the wire `contractVersion`.

Stage 8M makes that revision negotiable.

Example project requirement:

```json
{
  "namespace": "com.example.combat",
  "minimumSchemaVersion": 2,
  "maximumSchemaVersion": 4
}
```

Example runtime capability:

```json
{
  "namespace": "com.example.combat",
  "schemaVersion": 3
}
```

This target is compatible for that namespace. Version 1 is below the minimum;
version 5 is above the explicitly allowed maximum.

A project may deliberately omit `maximumSchemaVersion` when later revisions are
contractually acceptable. That decision belongs to the project/profile producer,
not to the compatibility evaluator.

## 7. Deterministic compatibility evaluation

For every required feature, the evaluator performs exactly one of:

1. missing feature;
2. revision below minimum;
3. revision above maximum; or
4. compatible.

For every required extension namespace, it performs exactly one of:

1. missing extension;
2. schema version below minimum;
3. schema version above maximum; or
4. compatible.

Diagnostics are emitted in the profile's canonical feature order followed by
canonical extension namespace order. Stable issue-code tokens are:

```text
missingFeature
featureRevisionBelowMinimum
featureRevisionAboveMaximum
missingExtension
extensionVersionBelowMinimum
extensionVersionAboveMaximum
```

A structured diagnostic should retain the subject identity, required minimum,
optional allowed maximum, and runtime-reported actual revision/version when one
exists. UI text must not be the only machine-readable compatibility signal.

Extra runtime capabilities/extensions do not make an otherwise compatible
profile incompatible.

An unknown **required** feature/extension is not optional. If the runtime does
not report it, compatibility fails.

## 8. No silent semantic downgrade

A compatibility evaluator is diagnostic. It MUST NOT transform the project to
make the target appear compatible.

If a project requires `host_actions` and the runtime does not support that
feature, the evaluator MUST report incompatibility. It MUST NOT:

- delete the host action;
- treat it as already completed;
- replace it with a no-op;
- change a condition result;
- choose an alternate transition; or
- export a semantically different project while reporting success.

An authoring/build tool may offer an explicit user-driven project edit or
migration, but the resulting project/profile is a new reviewed artifact and
must be evaluated again.

## 9. Relationship to Story Format

Story Format v1 remains frozen and does not gain capability fields in Stage 8M.
The capability profile is a separate companion/export contract.

A future Story Format version may choose to bind requirements directly into its
root contract. If so, that is a versioned format change with migration rules; it
is not retroactively interpreted as Story Format v1 behavior.

## 10. Relationship to Extension Schema v1

Stage 8M does not change `open_story.extension_schema` contract version 1.
It gives the existing producer-controlled `schemaVersion` field an explicit
cross-runtime negotiation role.

Unknown semantic extension behavior remains governed by Extension Schema v1:
missing required namespaces/members are errors rather than silent no-ops or
Boolean guesses.

## 11. Relationship to runtime bundles and content releases

Stage 8K runtime bundles and Stage 8L content releases may be accompanied by a
capability profile, but their existing v1 manifests are not modified by Stage
8M.

A shipping pipeline may bind/profile/hash these artifacts in a future versioned
container or manifest contract. Stage 8M freezes compatibility semantics first.

## 12. Authoring/export diagnostics

An authoring tool can evaluate the selected target runtime before export or
playtesting and present structured issues such as:

```text
Missing feature: host_actions
Feature revision too low: modular_loading requires >= 1
Missing extension: com.example.combat
Extension version too high: com.example.quest allows <= 3
```

The tool should identify the requirement and target runtime, explain the
supported/required version where useful, and block an export mode that promises
semantic compatibility when the report contains errors.

The contract does not prescribe UI wording, layout, or product gating.

## 13. Security and trust

Capability reports are declarations by a runtime/host integration. They do not
install code, grant trust, or execute schema content.

Opening a project/profile remains a data operation. Installing/enabling a host
runtime/plugin remains a separate code-trust decision.

## 14. Cross-runtime implementation rule

Independent runtimes may expose different native APIs, but they must agree on:

- feature IDs/revisions they claim;
- Extension Schema version requirements/capabilities;
- inclusive range evaluation;
- missing/too-low/too-high outcomes; and
- the no-silent-downgrade rule.

The Stage 8O independent C# spike can therefore consume the same capability
fixtures without importing Dart implementation knowledge.

## 15. Stage boundary

Stage 8M freezes runtime feature/capability profiles, extension-schema version
negotiation, runtime reporting, and deterministic target diagnostics.

Stage 8N now defines production presentation identity, source-control provider
neutrality, structured runtime observability, and the implementer-facing authority/
threading contract. The Dart reference runtime reports `runtime_observability`
revision 1 when these hooks are available. Stage 8O now independently pressures
the language-neutral contracts in C#; Stage 8P adoption/migration architecture
remains the final Stage 8 gate before serious Stage 9 authoring-shell work.
