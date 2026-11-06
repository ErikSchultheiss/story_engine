# Pure-Dart examples

These examples are executable steps in the package's canonical integration
path. New consumers should read the [Quick Start](../doc/QUICK_START.md) first,
run the core example second, use the [Abstraction Guide](../doc/ABSTRACTION_GUIDE.md)
when the public concepts overlap, and then use the [API Guide](../doc/API_GUIDE.md)
to decide whether their host also needs
`StoryNarrativeRuntime`.

All four Pure-Dart examples deliberately have no Flutter dependency and
import only:

```dart
import 'package:story_engine/story_engine.dart';
```

## Example 1 — branching core save/load

`story_engine_example.dart` is the executable **core-runtime** step. It remains
focused on one `StoryEngine` run and should not grow into an omnibus Story
Format/orchestration/modular-loading/host-action sample; those concerns have
different responsibilities and persistence rules.

Run it from the `story_engine/` directory:

```text
dart run example/story_engine_example.dart
```

It demonstrates the smallest complete core save/load path:

1. construct a tiny branching `StoryProject`;
2. validate it with `StoryValidator.validate`;
3. start a deterministic `StoryEngine`;
4. inspect the current event and available choices;
5. select a choice that changes scalar story state;
6. capture a committed `StoryRuntimeSnapshot`;
7. encode/decode the snapshot as JSON;
8. restore the `StoryEngine` without replaying the committed choice/effect; and
9. continue the restored run to termination.

The project contains two visible branches at the first event: one enters the
lantern-gated tunnel and one terminates immediately. The scripted walkthrough
selects the tunnel branch so the example can also prove that committed scalar
state survives snapshot restoration.

The walkthrough is scripted rather than stdin-interactive so its output is
reproducible and the same source can be compiled/exercised by the package test
suite. A real CLI, server, Flutter app, or game chooses how to present choices,
collect input, and persist the snapshot JSON.

Expected output includes:

```text
Restored status: awaitingContinue
Restored lantern_lit = true
Finished status: terminated
```

Next: follow [A lantern at the Forest Gate](../doc/NARRATIVE_WALKTHROUGH.md)
for the passages and their authored rules, or the
[Quick Start](../doc/QUICK_START.md) to build your own story.

### Why Story Format is not in this first example

Story Format persists **authored project data**; `StoryRuntimeSnapshot` persists
one **runtime playthrough**. They are intentionally separate contracts. Keeping
Story Format out of this first example makes the core execution/save lifecycle
visible without adding an unrelated storage/interoperability concept.

Use [Story Format v1](../doc/STORY_FORMAT_V1.md) and the Story Format section of
the [Quick Start](../doc/QUICK_START.md) when the host also needs portable authored-project
serialization.

## Example 2 — shared persistent world state

`story_narrative_shared_state_example.dart` is the smallest orchestration
example. It demonstrates two independent local conversations owned by one
`StoryNarrativeRuntime` and one shared persistent scalar world state.

Run it from the package root:

```text
dart run example/story_narrative_shared_state_example.dart
```

The example intentionally keeps persistence and host actions out of scope so
the multi-session authority contract stays visible:

1. build one project with a shared `gate_open` variable;
2. declare separate `gatekeeper` and `traveler` entry points;
3. validate both orchestration roots;
4. start both sessions before either conversation resolves;
5. observe that the traveler initially sees `gate_open == false`;
6. submit the gatekeeper's `open_gate` choice through
   `StoryNarrativeRuntime.applyInput(...)`;
7. observe the committed shared state propagate to the still-active traveler;
8. observe the traveler's newly available `enter_city` choice; and
9. submit the traveler's choice through the same serialized narrative
   authority.

The two sessions keep separate local event histories and local deterministic
runtime streams, while successful scalar state commits are propagated through
the owning `StoryNarrativeRuntime` in explicit authority order. The example does
not model parallel Dart execution or wall-clock ordering; `applyInput(...)`
represents the host/server authority submitting one deterministic input at a
time.

Expected output includes:

```text
Traveler choices before gate opens: wait
Persistent gate_open = true
Traveler choices after gate opens: enter_city, wait
Traveler entered the city.
```

This example deliberately does **not** demonstrate aggregate persistence or
host-action suspension. Those are separate integration concerns; use
`doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md` for durable orchestration persistence
and Example 3 when host-action restoration is also required.

Next: read the [session execution contract](../doc/SESSION_EXECUTION_V1.md) for
authority rules, then [Example 3](#example-3--modular-host-action--aggregate-restore)
and the [aggregate save/load lifecycle](../doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)
when adding durable orchestration persistence.

## Example 3 — modular host action + aggregate restore

`story_narrative_modular_host_action_restore_example.dart` demonstrates one
small composition of indexed module loading, suspendable external host work,
and the Stage 9A aggregate runtime checkpoint.

Run it from the package root:

```text
dart run example/story_narrative_modular_host_action_restore_example.dart
```

The walkthrough deliberately keeps the host/storage implementations tiny:

1. build a `StoryProjectIndex` with one selected dialogue module, one dependency
   module, and one unrelated module;
2. use `StoryModuleCache.materializeProjectForEntryPoint(...)` so only the
   selected dependency closure becomes the executable `StoryProject`;
3. validate the materialized project and start one `StoryNarrativeRuntime`
   session;
4. request stable external host work while the core session is at a committed
   continue pause;
5. dispatch that external request exactly once;
6. capture and JSON-encode the complete `StoryNarrativeRuntimeSnapshot` while
   the request remains pending;
7. decode and restore the aggregate runtime with a fresh observer;
8. verify that the restored session still waits on the same request and that
   restore emitted no replacement host-action request;
9. **reconcile** that stable request ID with the already-dispatched external
   operation instead of issuing it again;
10. submit one explicit `StoryNarrativeHostActionCompletedInput`; and
11. continue into the event supplied by the dependency module and terminate.

The critical rule is that aggregate restore recovers committed protocol state;
it does **not** redispatch external side effects. The host owns external
operation recovery/reconciliation and uses the stable request ID to determine
whether the original work completed, failed, was cancelled, or is still
pending.

This example intentionally omits Story Format, a real persistence backend, and
Stage 8L content-release binding. Integrations that use content releases should
persist the companion `StorySaveContentBinding` atomically with the aggregate
snapshot as described in `doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md`.

Expected output includes:

```text
Host-action requests replayed during restore: 0
External dispatch count after restore: 1
Status after host result: awaitingContinue
Finished status: terminated
```

Next: use the [aggregate save/load lifecycle](../doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)
for host persistence and content preflight, and the
[host-action protocol](../doc/HOST_ACTION_PROTOCOL_V1.md) for external-work outcomes.

## Example 4 — authored analysis and module validation

`authored_analysis_and_validation.dart` demonstrates immutable reference indexes,
structural graph queries and validation of a module slice with a known external
destination. It uses the public API and runs in the example CI contract.

Run it from the package root:

```sh
dart run example/authored_analysis_and_validation.dart
```

Expected output includes:

```text
Module validation errors: 0
Reachable local events: 1
Incomplete boundary: true
```

The module can validate without containing the known external event body.
Graph analysis reports that incomplete boundary rather than claiming the
external destination is a reachable local event. This is authored structural
analysis, not a runtime simulation.

Next: read [Authored analysis and validation](../doc/AUTHORED_ANALYSIS_AND_VALIDATION.md)
for standalone, orchestration and module-slice policies.

## Continuous example verification

The package root test suite executes the actual `main()` entry points of all
four canonical Pure-Dart examples and scans every Dart source under `example/`
for unsupported engine imports. The Stage 9B6 gate is:

```text
dart test test/example/stage9b6_public_examples_ci_test.dart
```

It covers:

- `authored_analysis_and_validation.dart`;
- `story_engine_example.dart`;
- `story_narrative_shared_state_example.dart`; and
- `story_narrative_modular_host_action_restore_example.dart`.

Every `story_engine` import in the example tree must remain on
`package:story_engine/story_engine.dart`; `package:story_engine/src/...` and
relative reaches into the package `lib/` tree fail the gate.

The repository-only Flutter counterpart keeps a separate Flutter package test
context so the root pure-Dart suite does not require a Flutter SDK. Run its own
`flutter analyze` and `flutter test` gates from `flutter_story_app/`.

## When orchestration is not needed

Stay with Example 1 and `StoryEngine` when one local narrative run is the
execution authority. Do not adopt `StoryNarrativeRuntime` merely because it is
the newer/higher-level API.

If the host needs named/resolved entry points, multiple unfinished sessions,
shared persistent narrative state, or suspendable host actions, continue with
`doc/API_GUIDE.md` and `doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md`. Once
`StoryNarrativeRuntime` owns execution, durable persistence is aggregate; do not
restore retained session snapshots independently and reassemble the runtime.

## Flutter counterpart

For the same public core-engine workflow mapped to widgets, user input,
validation presentation, and host-owned save policy, a source-repository
checkout contains `flutter_story_app/`. The Flutter example remains downstream
of this Pure-Dart package and is intentionally excluded from the pub.dev archive;
it does not move Flutter into `story_engine` and is not an orchestration example.

