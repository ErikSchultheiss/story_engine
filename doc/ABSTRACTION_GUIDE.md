# story_engine Abstraction Guide

This guide answers one question: **which public abstraction do I need for the
thing I am trying to build?** It is a navigation aid, not a new semantic
contract. Exact behavior remains in the linked normative documents.

Consumer code should import only:

```dart
import 'package:story_engine/story_engine.dart';
```

If you are new to the package, follow [INTEGRATION_PATH.md](INTEGRATION_PATH.md)
first. Use this guide when the public vocabulary starts to overlap.

## 1. Fast decision table

| I need to... | Start with | What it represents |
| --- | --- | --- |
| Execute one authored narrative | `StoryProject` + `StoryEngine` | Executable semantic project + one local runtime playthrough |
| Preserve authored organization/extensions losslessly | `StoryFormatDocument` | Project plus runtime-neutral authoring metadata |
| Encode/decode portable authored data | `StoryFormatBundle` + `StoryFormatCodec` | Logical path-to-JSON Story Format container; not filesystem I/O |
| Split a large project into loadable pieces | `StoryProjectIndex` + `StoryNarrativeModule` + `StoryModuleCache` | Lightweight global index + independently loadable event bodies |
| Let the host choose when/where narrative starts | `StoryEntryPoint` + `StoryNarrativeRuntime` | Host-driven activation declarations + orchestration authority |
| Keep multiple conversations alive | `StoryNarrativeSession` under one `StoryNarrativeRuntime` | One retained local run per activation under shared authority |
| Pause narrative for external host work | `StoryHostActionRequest` / host-action protocol | Stable data-only request/outcome protocol; not host code |
| Declare what a project/export requires | `StoryRuntimeCapabilityProfile` | Required feature and extension-schema revisions |
| Report what a target runtime supports | `StoryRuntimeCapabilities` | Supported feature revisions and extension-schema versions |
| Version shipped content and check save compatibility | `StoryContentReleaseManifest` + `StorySaveContentBinding` | Release/module identity + revisions referenced by a save |
| Package deterministic compiled runtime artifacts | `StoryRuntimeBundle` | Derived hashed shipping artifact; Story Format remains authored source |

Choose by ownership: authored semantics, runtime execution, modular loading,
host orchestration, external work, compatibility, or release identity.

## 2. Relationship map

```text
StoryProject
  +-> StoryEngine -> StoryRuntimeSnapshot
  +-> StoryFormatDocument -> StoryFormatCodec -> StoryFormatBundle
  +-> StoryProjectIndex -> StoryNarrativeModule(s)
          |                    |
          |                    +-> StoryModuleCache -> StoryProject slice
          |
          +-> StoryEntryPoint(s) -> StoryNarrativeRuntime
                                       |
                                       +-> StoryNarrativeSession(s)
                                       |      +-> StoryHostActionRequest (optional)
                                       |
                                       +-> StoryNarrativeRuntimeSnapshot

Compatibility / shipping
  StoryRuntimeCapabilityProfile <-> StoryRuntimeCapabilities
  StoryRuntimeBundle ... StoryContentReleaseManifest -> StorySaveContentBinding
```

The arrows show composition or normal integration direction, not inheritance.
Several values can coexist because they solve different problems.

## 3. Authored data: project, document, and bundles

Story Format persists authored data; runtime snapshots persist execution state.

**`StoryProject`** is the executable semantic definition: project identity,
scalar state schema, events, choices, and optional core entry event.
`StoryValidator` validates it and `StoryEngine` executes it. A `StoryProject` is
not a portable file/archive format.

**`StoryFormatDocument`** is the lossless authored document form for editors and
tools that must retain runtime-neutral organization and opaque extension
metadata around the project.

**`StoryFormatBundle`** is the logical path-to-JSON-text container produced or
consumed by `StoryFormatCodec`. It deliberately does not choose directory,
archive, database, or network storage policy.

**`StoryRuntimeBundle`** is different: it packages already-compiled,
deterministic runtime artifacts with hashes/manifest identity. It is derived
shipping output and does not replace Story Format as editable authored source.

See [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) and
[RUNTIME_BUNDLE_BUILD_V1.md](RUNTIME_BUNDLE_BUILD_V1.md).

## 4. Modular loading: index and module

**`StoryProjectIndex`** keeps lightweight project/module/event identity and
cross-module reference data resident. **`StoryNarrativeModule`** contains a
loadable set of event bodies. **`StoryModuleCache`** loads/verifies modules via a
host-provided loader and can materialize an entry point's dependency closure as
an ordinary `StoryProject` slice.

Modules are a loading and packaging boundary, not a second execution model.
See [MODULAR_PROJECT_LOADING_V1.md](MODULAR_PROJECT_LOADING_V1.md).

## 5. Orchestration: entry point, runtime, and session

**`StoryEntryPoint`** is a host-visible activation declaration. It identifies an
event and can participate in eligibility, host-fact requirements, fallback,
priority, and deterministic weighted resolution. An entry point is **not** an
active conversation or the current event.

**`StoryNarrativeRuntime`** is the shared orchestration authority for entry
resolution, multiple retained sessions, shared persistent scalar state,
serialized narrative input, orchestration randomness, and aggregate
persistence.

**`StoryNarrativeSession`** is one activation's retained local core-engine run,
with stable session identity, local event/history/RNG state, originating entry
point, and optional host-action protocol state. Multiple unfinished sessions can
coexist while successful persistent-state commits propagate through the owning
runtime's serialized authority.

See [SESSION_EXECUTION_V1.md](SESSION_EXECUTION_V1.md) and
[AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md).

## 6. External work: host actions

Use the host-action protocol when narrative must pause for work the engine does
not own. A `StoryHostActionRequest` carries stable correlation identity,
namespaced action identity, portable scalar arguments, and optional result
typing. It is data, not a callback, Future, network client, or serialized host
implementation.

A pending request can survive aggregate restoration, but restore **does not
redispatch external work**. The host reconciles the stable request ID with its
external system and submits one completion, failure, or cancellation.

See [HOST_ACTION_PROTOCOL_V1.md](HOST_ACTION_PROTOCOL_V1.md) and Example 3 in
[../example/README.md](../example/README.md).

## 7. Compatibility: capability profile vs target capabilities

**`StoryRuntimeCapabilityProfile`** declares what a project/export requires.
**`StoryRuntimeCapabilities`** reports what a target runtime supports.
`StoryRuntimeCompatibilityEvaluator` compares them and reports structured
issues; runtime version strings are diagnostic metadata, not a compatibility
shortcut.

Capabilities answer **"can this target runtime execute the required
semantics?"** Content-release compatibility answers a different question about
whether saved progress matches content revisions.

See [RUNTIME_CAPABILITIES_V1.md](RUNTIME_CAPABILITIES_V1.md).

## 8. Content identity: release vs save binding

**`StoryContentReleaseManifest`** describes one shipped content release with
release/module labels, exact module hashes, dependencies, and explicitly safe
older revisions.

**`StorySaveContentBinding`** is save-specific: it records the content/module
revisions referenced by the committed route represented by that save. Aggregate
narrative saves can derive one binding across all retained session snapshots.

`StorySaveContentCompatibilityEvaluator` returns `exact`, `compatible`,
`migrationRequired`, `fallbackRequired`, or `incompatible`; it does not guess
compatibility from version ordering.

See [CONTENT_VERSIONING_V1.md](CONTENT_VERSIONING_V1.md) and, when orchestration
owns execution,
[AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md).

## 9. Common pairs that should not be collapsed

| Do not conflate | Why |
| --- | --- |
| `StoryProject` / `StoryRuntimeSnapshot` | Authored executable semantics / one committed runtime checkpoint |
| `StoryFormatDocument` / `StoryFormatBundle` | Lossless authored document model / logical encoded container |
| `StoryFormatBundle` / `StoryRuntimeBundle` | Portable authored data / derived deterministic runtime packaging |
| `StoryProjectIndex` / `StoryNarrativeModule` | Global lightweight reference metadata / loadable event bodies |
| `StoryEntryPoint` / `StoryNarrativeSession` | Activation declaration / retained local run |
| `StoryNarrativeSession` / `StoryNarrativeRuntime` | Local traversal state / cross-session authority and shared state |
| `StoryRuntimeCapabilityProfile` / `StoryRuntimeCapabilities` | Requirements / target support report |
| `StoryContentReleaseManifest` / `StorySaveContentBinding` | Shipped content identity / revisions a particular save depends on |
| `StoryHostActionRequest` / external host work | Stable protocol data / host-owned side effect and reconciliation |

## 10. Smallest coherent stacks

**Core local story**

```text
StoryProject -> StoryValidator -> StoryEngine -> StoryRuntimeSnapshot
```

Run `example/story_engine_example.dart`.

**Host-driven multi-session narrative**

```text
StoryProject + StoryEntryPoint(s)
  -> StoryNarrativeRuntime -> StoryNarrativeSession(s)
  -> StoryNarrativeRuntimeSnapshot
```

Run `example/story_narrative_shared_state_example.dart`.

**Large modular narrative with external work**

```text
StoryProjectIndex + StoryNarrativeModule(s)
  -> StoryModuleCache -> StoryProject slice
  -> StoryNarrativeRuntime -> StoryNarrativeSession
  -> StoryHostActionRequest -> aggregate restore + host reconciliation
```

Run `example/story_narrative_modular_host_action_restore_example.dart`.

Add capability negotiation, runtime bundles, content-release compatibility, or
Story Format interoperability only when the host actually needs those
boundaries.

## 11. Where to go next

- [INTEGRATION_PATH.md](INTEGRATION_PATH.md) — canonical onboarding order.
- [QUICK_START.md](QUICK_START.md) — first `StoryEngine` integration.
- [API_GUIDE.md](API_GUIDE.md) — workflows, errors, and complete public symbol
  index.
- [../example/README.md](../example/README.md) — three runnable Pure-Dart
  examples.
- The narrower contracts linked above — exact semantics after you have chosen
  the abstraction you need.
