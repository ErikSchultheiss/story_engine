# story_engine Integration Path

This document is the navigation map for a new `story_engine` consumer. It does
not define new runtime semantics. Its job is to keep the package's increasingly
broad API/documentation surface in one deliberate learning order.

All consumer Dart code should import only:

```dart
import 'package:story_engine/story_engine.dart';
```

## 1. Canonical onboarding order

### Step 1 — Learn the core path

Start with [QUICK_START.md](QUICK_START.md). Build or load one `StoryProject`,
validate it, start one `StoryEngine`, inspect presentation/choices, and submit
explicit choice/continue input.

Do this even if the final application is a large game or server. The
orchestration layer delegates local traversal to the same core engine semantics.

### Step 2 — Run the executable core example

Run from the package root:

```text
dart run example/story_engine_example.dart
```

The example is intentionally small and scripted. It demonstrates a branching
project, validation, one deterministic `StoryEngine` run, scalar state, core
snapshot JSON encode/decode, restore, and continuation. Story Format is kept
separate from this first runtime example. See [../example/README.md](../example/README.md).

Follow [A lantern at the Forest Gate](NARRATIVE_WALKTHROUGH.md) for the
player-facing passages and their mapping to conditions, effects and the
committed checkpoint.

A repository checkout also contains `example/flutter_story_app/`, which maps the
same core path to Flutter widgets and host-owned storage policy. It is a UI host
example, not a different engine contract.

### Step 3 — Decide who owns execution

If the public vocabulary is the blocker, use
[ABSTRACTION_GUIDE.md](ABSTRACTION_GUIDE.md) first. It separates the roles of
project/document/bundle/module/entry point/session/capability/content release/
host action without requiring every normative contract up front. Then use
[API_GUIDE.md](API_GUIDE.md) after the core path is familiar.

Stay with `StoryEngine` when one local narrative run is the execution authority.
Its durable checkpoint is `StoryRuntimeSnapshot`.

Use `StoryNarrativeRuntime` when the host needs one or more orchestration
responsibilities:

- activation through stable named/resolved entry points;
- multiple unfinished narrative sessions;
- shared persistent narrative state across sessions;
- explicit host-world facts during entry resolution;
- suspendable host actions with stable request identity;
- serialized host-authoritative narrative input across sessions.

`StoryNarrativeRuntime` is not a more convenient alias for `StoryEngine`; it is
the higher-level authority around retained core-engine sessions.

If that authority is needed, run the minimal shared-state example before adding
persistence or host actions:

```text
dart run example/story_narrative_shared_state_example.dart
```

It starts two independent conversations, submits their choices through
`StoryNarrativeRuntime.applyInput(...)`, and shows a successful scalar state
commit propagating to the still-active sibling session.

### Step 4 — Match persistence to the execution authority

For standalone `StoryEngine`, use the core `StoryRuntimeSnapshot` codec/restore
path shown by the Pure-Dart example.

For `StoryNarrativeRuntime`, read
[AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)
before implementing storage. The durable checkpoint is the aggregate
`StoryNarrativeRuntimeSnapshot` plus its companion content binding when content
release/versioning is used. Retained `StoryNarrativeSessionSnapshot` values are
components of that checkpoint and are not independently restored then reassembled
by the host.

### Step 5 — Run the suspended-host-action restore example

When the host also needs modular loading or external work, run:

```text
dart run example/story_narrative_modular_host_action_restore_example.dart
```

The example materializes one entry point's module dependency closure, suspends
that session on a stable host-action request, encodes the aggregate runtime,
restores it, and reconciles the existing request ID. Restore does not redispatch
the external operation; the host submits one explicit outcome after it knows the
external result.

### Step 6 — Add only the advanced contracts you use

Before opening several narrow contracts at once, use
[ABSTRACTION_GUIDE.md](ABSTRACTION_GUIDE.md) as the compact "which abstraction
do I need?" map. After choosing the runtime authority, persistence model, and
other boundaries you actually need, continue into the narrower contracts:

- [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) — portable authored-project
  interoperability;
- [OPEN_WORLD_ORCHESTRATION_V1.md](OPEN_WORLD_ORCHESTRATION_V1.md) — entry
  resolution and local narrative-session semantics;
- [SESSION_EXECUTION_V1.md](SESSION_EXECUTION_V1.md) — current multi-session,
  shared-state, serialized-authority semantics;
- [HOST_ACTION_PROTOCOL_V1.md](HOST_ACTION_PROTOCOL_V1.md) — suspend/resume of
  external host work;
- [MODULAR_PROJECT_LOADING_V1.md](MODULAR_PROJECT_LOADING_V1.md) — indexed,
  storage-neutral module loading;
- [RUNTIME_BUNDLE_BUILD_V1.md](RUNTIME_BUNDLE_BUILD_V1.md) — deterministic
  derived runtime bundles;
- [CONTENT_VERSIONING_V1.md](CONTENT_VERSIONING_V1.md) — release identity,
  patching, save binding, migration/fallback decisions;
- [RUNTIME_CAPABILITIES_V1.md](RUNTIME_CAPABILITIES_V1.md) — capability and
  extension compatibility;
- [CONFORMANCE_FIXTURES_V1.md](CONFORMANCE_FIXTURES_V1.md) and the runtime
  semantics/randomness contracts — independent-runtime conformance work.

## 2. Responsibility map

| Surface | Primary responsibility | Not the place to start for |
| --- | --- | --- |
| `README.md` | Package orientation, boundaries, canonical path | Detailed member semantics |
| `QUICK_START.md` | First validated `StoryEngine` integration | Multi-session orchestration |
| `NARRATIVE_WALKTHROUGH.md` | Player passages mapped to authored rules and core save/restore | New semantics or a larger sample story |
| `example/authored_analysis_and_validation.dart` | Static reference/graph analysis and module-slice validation | Runtime-state reachability or external module bodies |
| `example/story_engine_example.dart` | Minimal branching core save/load lifecycle | Story Format or omnibus advanced-feature demo |
| `example/story_narrative_shared_state_example.dart` | Minimal multi-session shared-state authority | Aggregate persistence or host-action restoration |
| `example/story_narrative_modular_host_action_restore_example.dart` | Modular loading + suspended host action + aggregate restore/reconciliation | Story Format or real storage/network policy |
| `example/flutter_story_app/` | Downstream UI/host mapping of the core lifecycle | Orchestration architecture |
| `ABSTRACTION_GUIDE.md` | Compact relationship/selection map for overlapping public concepts | Member-level signatures or normative semantics |
| `API_GUIDE.md` | Public concepts, workflows, errors, API index | Normative cross-runtime semantics |
| `AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md` | Durable `StoryNarrativeRuntime` save/load | Standalone core-engine persistence |
| Narrow feature contracts | Exact semantics for the selected advanced capability | General onboarding |
| Generated Dartdoc | Exact declarations/members/signatures | Learning the integration order |

## 3. Current executable-example coverage

Stage 9B2 freezes `example/story_engine_example.dart` as **Example 1**: the
minimal branching `StoryEngine` save/load lifecycle. Stage 9B3 freezes
`example/story_narrative_shared_state_example.dart` as **Example 2**: two
independent conversations sharing committed persistent world state through one
serialized `StoryNarrativeRuntime` authority. Stage 9B4 freezes
`example/story_narrative_modular_host_action_restore_example.dart` as
**Example 3**: one modular session suspended on external host work, saved as an
aggregate runtime, restored without redispatch, and resumed by reconciling the
stable request ID. **Example 4**,
`example/authored_analysis_and_validation.dart`, demonstrates reusable authored
references, structural graph queries and module-slice validation. The
repository-only Flutter example maps the core authority
to widgets and host-owned persistence policy.

The four Pure-Dart examples intentionally remain separate. A new consumer can
learn core execution, then multi-session authority, then the modular
host-action/aggregate-restore composition without first understanding every
advanced subsystem at once. The authored-analysis example is an independent
tooling path; it does not execute a runtime playthrough.

Stage 9B6 closes the integration-experience loop: the normal root test suite
executes the actual `main()` entry point of all four canonical Pure-Dart examples
and scans the complete hand-written example tree for engine imports that bypass the
public package facade. The repository-only Flutter app retains its independent
Flutter analyze/test gate instead of turning the pure-Dart package suite into a
Flutter SDK requirement.

## 4. Common wrong turns

Do not:

- import `package:story_engine/src/...`;
- begin from the complete API symbol index and guess which layer should own
  execution;
- treat Story Format files as runtime snapshots or vice versa;
- use `StoryNarrativeSessionSnapshot` as a manual aggregate-restore API;
- redispatch a restored pending host action instead of reconciling its stable
  request ID with the external host system;
- let a Flutter/storage/network framework become part of engine semantics;
- interpret historical Stage 8G one-active-session proving language as the
  current `StoryNarrativeRuntime` cardinality rule.

The default path is deliberately conservative: prove the core integration first,
then adopt only the higher-level contracts the host actually needs.
