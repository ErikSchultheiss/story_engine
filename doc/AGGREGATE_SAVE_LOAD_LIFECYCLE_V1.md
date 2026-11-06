# Aggregate Narrative Save/Load Lifecycle — Revision 1

This document is the consumer-facing lifecycle for durably saving and resuming a
`StoryNarrativeRuntime`. The normative state/invariant details remain in
[Narrative Runtime Persistence — Contract Revision 1](NARRATIVE_RUNTIME_PERSISTENCE_V1.md).

The central rule is:

> A `StoryNarrativeRuntime` is saved and resumed as one aggregate execution
> authority. Retained sessions are checkpoint components, not independently
> restorable substitutes for the aggregate runtime.

A standalone `StoryEngine` may continue to use the core
`StoryRuntimeSnapshot`/`StoryEngine.restore(...)` path. This document applies
when orchestration is owned by `StoryNarrativeRuntime`.

## 1. Canonical save lifecycle

At a completed serialized-operation boundary:

1. Call `StoryNarrativeRuntime.createSnapshot()`.
2. If the host uses Stage 8L content releases, derive one companion
   `StorySaveContentBinding` from every retained session through
   `StorySaveContentBinding.fromRetainedSessionSnapshots(...)`.
3. Encode the aggregate snapshot with `StoryNarrativeRuntimeSnapshotCodec`.
4. Encode the content binding with `StorySaveContentBindingCodec` when that
   binding is part of the integration.
5. Commit the aggregate snapshot and its companion binding atomically as one
   host-owned logical save revision.

The package deliberately does not prescribe files, databases, cloud storage,
transaction APIs, or a storage envelope. If two encoded payloads are persisted,
the host must ensure that readers can never intentionally pair an aggregate
snapshot from one logical revision with a binding from another.

`StoryNarrativeRuntime.createSnapshot()` rejects capture while a serialized
runtime operation is in progress. A rejected capture does not partially create
or publish a new durable save revision.

## 2. Atomicity inside retained sessions

Each retained `StoryNarrativeSessionSnapshot` contains both:

- the committed core `StoryRuntimeSnapshot`; and
- the `StoryHostActionProtocolSnapshot`.

Those values describe one logical session checkpoint. They must not be mixed
from different moments. The aggregate snapshot codec serializes them together
inside the same retained-session envelope.

A pending host action therefore survives with the exact request identity,
payload, protocol scope, and next request ordinal that were committed at the
checkpoint.

## 3. Canonical load lifecycle

A host resumes a durable aggregate save in this order:

1. Read one complete logical save revision. Do not mix independently versioned
   aggregate/binding payloads.
2. If a `StorySaveContentBinding` is present, decode it and run
   `StorySaveContentCompatibilityEvaluator` against the target content release.
3. Continue the ordinary aggregate-resume path only for `exact` or
   `compatible` content results.
4. Decode the aggregate checkpoint with
   `StoryNarrativeRuntimeSnapshotCodec.decodeJson(...)`, supplying the target
   `StoryProject` and complete orchestration entry-point declarations.
5. Restore with `StoryNarrativeRuntime.restore(...)`, supplying any new
   non-authoritative observers only at this boundary.
6. After restore returns, inspect restored sessions for pending host actions.
   Reconcile each stable request ID with the host's external system and submit
   exactly one explicit completion, failure, or cancellation when the host has
   determined the outcome.
7. Continue narrative execution only through ordinary explicit runtime/session
   inputs.

Decode and restore validation happen before a restored runtime is published.
Restore does not replay entry effects, selected choices, automatic/continuation
transitions, random draws, observations, or host-action dispatch.

## 4. Content-preflight outcomes

`StorySaveContentCompatibilityEvaluator` is a preflight, not a restore API.

- `exact` — proceed to aggregate decode/restore.
- `compatible` — proceed to aggregate decode/restore; ordinary aggregate/core
  validation still applies.
- `migrationRequired` — stop the ordinary aggregate-resume path. Revision 1
  does not provide a one-call aggregate migration API. Any approved migration
  must produce a coherent aggregate checkpoint and matching binding before the
  normal decode/restore path resumes. Do not restore sessions independently.
- `fallbackRequired` — do not present the old aggregate run as restored. A host
  may explicitly start a new run at the approved fallback destination according
  to its own recovery UX/policy.
- `incompatible` — do not restore the checkpoint against that content release.

If the integration does not use Stage 8L content-release binding, the host must
still guarantee that the supplied `StoryProject` and entry-point configuration
are the intended compatible authored configuration. Aggregate validation remains
mandatory either way.

## 5. Pending host-action reconciliation

A restored pending request is already committed narrative protocol state.
Restore must not dispatch the external operation again.

The host should:

1. read `StoryNarrativeSession.pendingHostAction`;
2. use its stable `StoryHostActionRequestId` to query or reconstruct external
   operation state;
3. leave the session in `awaitingHost` while the outcome is unknown;
4. submit exactly one `completeHostAction(...)`, `failHostAction(...)`, or
   `cancelHostAction(...)` input once the outcome is known.

If the host has lost the external operation, that is a host recovery decision.
It may explicitly fail or cancel the stable pending request according to
application policy; it must not silently issue a replacement request and treat
that as continuation of the old one.

## 6. Supported restore boundary

There is no supported public workflow that reconstructs a
`StoryNarrativeRuntime` by independently restoring its retained sessions.

Manual per-session restoration cannot reconstruct the complete aggregate
semantics, including:

- current shared persistent state and its revision;
- orchestration RNG continuation;
- next session identity/seed allocation;
- retained-session ordering and active membership;
- completed-session history retained by the authority;
- the next observation sequence;
- cross-session shared-state invariants;
- the relationship between every core checkpoint and pending host-action
  protocol checkpoint.

`StoryNarrativeSession.createSnapshot()` remains useful as the data component
captured by the aggregate runtime and for protocol-focused inspection/testing.
It is not a durable replacement for
`StoryNarrativeRuntime.createSnapshot()`/`StoryNarrativeRuntime.restore(...)`.

## 7. Failure modes and recovery boundary

The normal aggregate-resume path fails closed:

| Failure | Public signal / condition | Required host behavior |
| --- | --- | --- |
| Capture during active serialized operation | `StoryNarrativeOperationException` | Retry only after the operation boundary; do not publish a partial new save. |
| Malformed aggregate JSON/data | `StoryNarrativeRuntimeSnapshotFormatException` | Do not restore; use host recovery/backup policy. |
| Well-formed but incompatible aggregate checkpoint | `StoryNarrativeRuntimeSnapshotCompatibilityException` | Do not restore against that project/configuration. |
| Malformed content binding | `StoryContentContractFormatException` | Do not use the binding to authorize restore. |
| Content `migrationRequired` | Compatibility result | Stop normal restore until an explicit coherent aggregate migration exists. |
| Content `fallbackRequired` | Compatibility result | Treat fallback as a new host-selected recovery run, not a restored checkpoint. |
| Content `incompatible` | Compatibility result | Reject restore for that target release. |
| Unknown external result for restored pending host action | Session remains `awaitingHost` | Reconcile by stable request ID; resolve explicitly later. |
| Torn/mismatched host storage revision | Host storage/envelope failure | Reject the pair; never intentionally combine snapshot/binding revisions. |

A failed aggregate decode/validation/restore must not mutate another live
runtime, emit replay observations, dispatch host work, or expose a partially
reconstructed runtime.

## 8. Runnable pending-host-action example

Run the canonical Stage 9B4 integration from the package root:

```text
dart run example/story_narrative_modular_host_action_restore_example.dart
```

It materializes a bounded modular project slice, dispatches one external host
action, saves while that request is pending, restores through the aggregate
codec/runtime path, and reconciles the same stable request ID. The example is
intentionally explicit that restore does not redispatch external work.

## 9. Minimal package-side sequence

Save-side package calls:

```dart
final aggregateSnapshot = runtime.createSnapshot();

final contentBinding = StorySaveContentBinding.fromRetainedSessionSnapshots(
  projectId: aggregateSnapshot.projectId,
  snapshots: aggregateSnapshot.sessions.map(
    (session) => session.runtimeSnapshot,
  ),
  index: projectIndex,
  release: contentRelease,
);

final snapshotJson = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
  aggregateSnapshot,
);
final bindingJson = const StorySaveContentBindingCodec().encode(contentBinding);

// Persist snapshotJson + bindingJson as one host-owned logical save revision.
```

Load-side package calls after atomically reading that same revision:

```dart
final binding = const StorySaveContentBindingCodec().decode(bindingJson);
final compatibility = const StorySaveContentCompatibilityEvaluator().evaluate(
  binding: binding,
  target: contentRelease,
);

// Proceed only for exact/compatible. Other statuses leave the ordinary
// aggregate-resume path before decode/restore.

final decodedSnapshot = StoryNarrativeRuntimeSnapshotCodec().decodeJson(
  snapshotJson,
  project: project,
  entryPoints: entryPoints,
);
final restoredRuntime = StoryNarrativeRuntime.restore(
  project: project,
  entryPoints: entryPoints,
  snapshot: decodedSnapshot,
  observers: observers,
);
```

The host owns the conditional branch around the compatibility result and the
atomic storage transaction. The engine owns deterministic checkpoint semantics,
validation, and direct rehydration.

## Load-path verification

[Aggregate load-path benchmark](AGGREGATE_LOAD_PATH_BENCHMARK.md) measures the
complete public JSON decode followed by aggregate restore, including retained
history and pending host requests. Aggregate validation/reconstruction reuse
immutable project lookups within each pass; every retained checkpoint still
receives its full compatibility validation before the runtime is exposed. This
internal reuse does not replace the host's content preflight or atomic storage
requirements above.
