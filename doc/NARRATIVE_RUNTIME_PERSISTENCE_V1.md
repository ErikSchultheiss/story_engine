# Narrative Runtime Persistence — Contract Revision 1

Stage 9A defines the durable checkpoint contract for one complete
`StoryNarrativeRuntime`. It builds on Core Runtime Semantics Revision 1,
Suspendable Host Interaction Protocol Revision 1, Narrative Session Execution
Revision 1, and the Stage 8L content compatibility contracts.

The portable rule is:

> One aggregate narrative checkpoint is one logically atomic continuation of
> the orchestration runtime. Restoring it must resume the same committed state,
> sessions, host-action suspensions, deterministic random streams, and public
> identity cursors without replaying already committed work.

The aggregate contract wraps the existing per-session `StoryRuntimeSnapshot`.
It does not replace or reinterpret that frozen core snapshot contract.

## 1. Scope

Revision 1 defines:

- the complete durable state of one narrative orchestration runtime;
- the boundary between aggregate checkpoint data and host-owned dependencies;
- ordering and identity rules for retained sessions;
- shared persistent-state and revision continuity;
- orchestration RNG continuity and future session-seed continuity;
- pending host-action checkpoint semantics;
- aggregate restore preconditions and validation invariants;
- atomic persistence expectations for snapshot plus content compatibility data;
- failure behavior before a restored runtime becomes observable.

Revision 1 does not define:

- a Story Format v1 change;
- persistence of Flutter/UI objects, callbacks, Futures, threads, sockets, or
  host service instances;
- persistence of executable module loaders or module-cache contents;
- automatic restart/re-dispatch of external host work;
- networking, replication, distributed locking, or database transactions;
- authored session-local scalar variables;
- a history-retention/archival policy for completed sessions.

## 2. Aggregate checkpoint is the authority

A durable orchestration save MUST be captured at a completed serialized runtime
operation boundary. No narrative transaction may be in progress.

The checkpoint represents one logical runtime, not a bag of unrelated session
saves. Restoring individual `StoryNarrativeSessionSnapshot` values into newly
constructed runtimes is not an equivalent persistence path because that would
lose shared-state authority, orchestration RNG position, session allocation
identity, runtime configuration, and aggregate compatibility metadata.

Revision 1 therefore defines one aggregate snapshot as the authoritative
runtime checkpoint.

## 3. Durable aggregate state

An aggregate checkpoint MUST preserve enough data to reconstruct the following
without replay.

### 3.1 Aggregate compatibility metadata

The aggregate representation has its own versioned metadata, independent from:

- package semantic version;
- Story Format version;
- the existing `StoryRuntimeSnapshot` format version;
- the host-action protocol snapshot version.

At minimum the metadata identifies the aggregate persisted-data shape and the
orchestration/runtime contract required to resume it safely. Unsupported newer
metadata MUST fail as an explicit compatibility error rather than being guessed
or silently downgraded.

### 3.2 Project and content identity

The checkpoint MUST identify the logical `StoryProjectId` to which the runtime
belongs.

Exact release/module compatibility remains a companion save-binding concern,
not authored runtime state embedded into `StoryRuntimeSnapshot`. When a host
uses Stage 8K/8L modular release content, the durable save consists logically of
both:

1. the aggregate narrative runtime snapshot; and
2. content compatibility data binding every module revision required by every
   retained session and its current/history state.

Those two parts MUST be persisted atomically by the host. Stage 9A6 implements
the aggregate content-binding path through
`StorySaveContentBinding.fromRetainedSessionSnapshots(...)`. The binding is
computed from every retained session's core checkpoint and remains a companion
object rather than becoming part of the aggregate runtime snapshot.

### 3.3 Shared persistent narrative state

The aggregate snapshot MUST preserve the runtime's committed persistent
`StoryState` exactly.

This is the authority for shared scalar narrative state after restore. Session
snapshots MUST be compatible with this same committed state according to the
aggregate validation rules. Restoration MUST NOT derive the global state by
replaying session history or effects.

### 3.4 Persistent-state revision

The current `persistentStateRevision` MUST be preserved.

The revision remains observational metadata rather than authored story state or
a distributed synchronization token. Stage 9A nevertheless versions it as part
of aggregate checkpoint equivalence so a restored Dart runtime does not appear
to move backward to revision zero.

### 3.5 Runtime configuration required by future sessions

The aggregate checkpoint MUST preserve runtime configuration that affects
future execution even when no session currently exists. Revision 1 includes:

- `maxAutomaticTransitions`;
- the complete orchestration deterministic random state, including its original
  seed provenance and current state.

The public `randomSeed` is derivable from the orchestration random state and
need not be redundantly authoritative if the concrete snapshot model exposes it
only through that state.

### 3.6 Session allocation identity and ordering

Every retained session has one stable non-negative activation index.

The aggregate snapshot MUST preserve:

- retained sessions in deterministic activation order;
- every session index;
- the identity of the next session index to allocate.

Revision 1 retains completed sessions as well as unfinished sessions because
`sessionByIndex(...)`, runtime history, observation correlation, and future
session identity all currently depend on that retained ordered collection.

The initial implementation may enforce contiguous indexes beginning at zero,
but the aggregate contract still treats the next allocation identity as durable
state. A later history-retention feature must not silently reuse a previously
allocated session index.

### 3.7 One retained session checkpoint

For every retained session, the aggregate checkpoint MUST preserve exactly:

- `sessionIndex`;
- `entryPointId`;
- the complete existing `StoryRuntimeSnapshot`;
- the complete `StoryHostActionProtocolSnapshot`.

The session's composite host-visible status is represented by the combination
of core runtime status and host-action protocol state. It does not need a second
redundant authoritative status field. If an encoding includes a convenience
status value, validation MUST prove that it agrees with those authoritative
parts.

The entry-point declaration itself remains restore configuration supplied by
the host, like the `StoryProject`; the checkpoint stores stable identity rather
than executable host behavior.

### 3.8 Observation sequence continuity

Observers themselves are never persisted. However, an implementation exposing
a deterministic runtime-local observation sequence MUST preserve the next
observation sequence cursor across aggregate restore.

For the Dart reference runtime this means `_observationSequence` is checkpoint
metadata even though observations are non-authoritative. A host that attaches a
new observer after restore receives future observations with continuing
sequence identities rather than identities reused from the beginning of the
logical runtime.

This cursor MUST NOT affect story state, history, RNG, eligibility, transition
selection, or host-action identity.

## 3.9 Concrete Stage 9A2 snapshot model

Stage 9A2 materializes this contract as two public data-only values:

- `StoryNarrativeRuntimeSnapshotMetadata`, carrying aggregate format and
  orchestration-contract versions; and
- `StoryNarrativeRuntimeSnapshot`, carrying `projectId`, `persistentState`,
  `persistentStateRevision`, `orchestrationRandomState`,
  `maxAutomaticTransitions`, `nextSessionIndex`,
  `nextObservationSequence`, and the ordered retained `sessions`.

The existing `StoryNarrativeSessionSnapshot` is the retained-session element
and continues to carry `sessionIndex`, `entryPointId`, `runtimeSnapshot`, and
`hostActionSnapshot`.

The aggregate constructor owns an immutable copy of the retained-session list
and performs only local scalar/value-shape checks. Stage 9A3 remains the single
authority for cross-object compatibility and semantic validation. In
particular, constructing this data model does not prove session ordering,
project identity consistency, active/completed consistency, host-action scope,
or shared-state equality.

The concrete model intentionally does not persist a redundant top-level
`randomSeed`: the versioned `orchestrationRandomState` contains original seed
provenance and current stream state, interpreted only by the matching RNG
implementation.

## 4. State intentionally not persisted

An aggregate snapshot MUST NOT serialize live host/runtime implementation
objects. In particular it excludes:

- `StoryNarrativeObserver` instances;
- callbacks, closures, Futures, Streams, threads, isolates, timers, or locks;
- Flutter widgets, contexts, controllers, or other UI state;
- host service implementations and external operation handles;
- `StoryModuleLoader` implementations;
- module-cache contents or in-flight module-load Futures;
- sockets, database connections, file handles, process state, or wall-clock
  timestamps;
- `_executionInProgress` or any transaction-local temporary state;
- host-condition results from earlier entry resolutions;
- external state of a pending combat/cinematic/shop/network operation.

Restore dependencies such as the `StoryProject`, entry-point declarations,
content release/index data, module loader, and observers are supplied again by
the host and validated where the relevant contract provides identity data.

## 5. Active and completed session derivation

The aggregate representation does not require a separately authoritative
`activeSessionIndexes` list.

A retained session is unfinished when its composite session status is not
`terminated`. The runtime reconstructs `activeSessions` in retained activation
order from the validated session checkpoints.

A session with a pending host action is active even though the underlying core
runtime remains at its previously committed choice/continue pause.

A completed session remains a historical retained session and MUST NOT be
rewritten to the aggregate persistent state during restoration or after later
persistent-state commits.

## 6. Deterministic random continuity

The orchestration RNG stream is distinct from every session RNG stream.

The aggregate checkpoint MUST preserve the orchestration stream with the same
versioned random-state contract used by the deterministic runtime. Each
`StoryRuntimeSnapshot` independently preserves its own session stream.

Restore MUST NOT consume either stream merely to reconstruct objects.

Given the same explicit host inputs after a checkpoint, an uninterrupted run
and a restore-then-continue run MUST produce:

- the same next weighted entry-point choice;
- the same next per-session seed allocation;
- the same subsequent session-local random results;
- the same final state/history/status.

## 7. Pending host actions

The session checkpoint keeps the complete `StoryHostActionProtocolSnapshot`,
including the next request ordinal and the pending request, if any.

Restoring a pending request MUST:

- preserve the same request ID and payload;
- preserve the same next request ordinal;
- expose the same `awaitingHost` composite session status;
- keep the underlying core pause/state/history/RNG unchanged;
- NOT emit a new request;
- NOT invoke or redispatch host work automatically.

A restored runtime MUST NOT automatically dispatch the host action again.

The host reconciles the restored request ID with its own external operation and
then supplies exactly one explicit completion, failure, or cancellation input.

## 8. Required restore dependencies

Aggregate restore receives host-owned dependencies rather than deserializing
implementations. At minimum the host supplies:

- the compatible `StoryProject`;
- the complete compatible entry-point declarations in declaration order;
- any observers to attach to the restored runtime;
- content/index/release/module-loading dependencies required by the chosen
  integration path.

The host MUST provide compatible orchestration entry-point declarations. Stage
9A6 content binding preflights release/module identity separately; aggregate
restore still validates every retained entry-point identity and origin against
the supplied configuration. A restore API must not silently invent missing
entry points or replace an unknown retained entry point with a fallback.

## 9. Aggregate validation invariants

Validation MUST complete before a restored runtime becomes observable or any
external host action can be dispatched.

Revision 1 requires at least the following invariants.

### 9.1 Aggregate identity

- metadata versions are supported;
- project identity matches the supplied project;
- aggregate `StoryState.schema` is compatible with the supplied project state
  schema;
- `maxAutomaticTransitions` is valid;
- orchestration random state uses a supported algorithm/version/shape;
- persistent-state revision, next session index, and observation cursor are
  non-negative portable integers.

### 9.2 Session collection

- session indexes are unique and strictly increasing in retained order;
- initial Revision 1 snapshots use contiguous session indexes beginning at 0;
- next session index is greater than every retained index and, for the initial
  no-compaction implementation, equals retained session count;
- every retained `entryPointId` exists in supplied restore configuration;
- every session runtime snapshot has the aggregate project identity;
- every session core snapshot independently passes existing
  `StoryRuntimeSnapshotValidator` validation;
- every retained session snapshot uses the aggregate runtime's
  `maxAutomaticTransitions` value;
- every host-action snapshot independently passes its existing protocol/codec
  validation.

### 9.3 Session/status consistency

- a terminated core runtime cannot have a pending host action;
- a pending host action may exist only over a committed host-visible core pause;
- the host-action protocol scope matches the session identity convention used
  by the Dart runtime (`session_<index>` in Revision 1);
- retained active/completed derivation is unambiguous;
- no session is restored from `StoryEngineStatus.notStarted` because a
  `StoryNarrativeSession` represents a successfully activated local run.

### 9.4 Shared-state consistency

All unfinished session snapshots MUST represent the same committed persistent
scalar `StoryState` as the aggregate runtime snapshot.

Completed sessions are historical snapshots and MAY contain the persistent
state that existed when they terminated. They are not rewritten by later shared
state commits and therefore are exempt from equality with the aggregate current
state.

This distinction preserves the existing Stage 8J atomic propagation rule while
retaining historical completed sessions faithfully.

### 9.5 Entry-point/session origin consistency

For each retained session:

- the stored `entryPointId` resolves to a supplied entry point;
- that entry point targets an event present in the supplied project;
- the first entered event in the session runtime history equals the entry
  point's target event.

Restore validates origin identity; it does not re-evaluate the entry point's
current eligibility or host conditions. Re-evaluation could reject a session
that was valid when it originally started and would amount to replaying
activation logic.

### 9.6 Concrete Stage 9A3 validator

Stage 9A3 materializes these invariants as
`StoryNarrativeRuntimeSnapshotValidator`. Validation accepts the immutable
aggregate snapshot plus the host-supplied `StoryProject` and entry-point
configuration. It is side-effect free and performs no restoration.

Aggregate failures use
`StoryNarrativeRuntimeSnapshotCompatibilityException` with a stable
`StoryNarrativeRuntimeSnapshotCompatibilityIssue` and machine-oriented path.
Each retained core checkpoint is validated by the existing
`StoryRuntimeSnapshotValidator`; a nested core incompatibility is preserved as
the aggregate exception's cause rather than reimplementing core history, state,
or random compatibility rules.

Local `StoryHostActionProtocolSnapshot` construction/decoding already enforces
scope syntax, request ordinals, and pending-request identity within one protocol
snapshot. The aggregate validator additionally enforces the cross-object
`session_<index>` scope convention and lifecycle compatibility of pending work.

The aggregate persistent state follows the existing scalar compatibility rule:
every persisted set value must still be declared with the same scalar type in
the supplied project. Alias, declaration-order, and initial-value-only changes
do not by themselves invalidate a checkpoint.

### 9.7 Concrete Stage 9A4 codec

Stage 9A4 materializes the aggregate persisted representation as
`StoryNarrativeRuntimeSnapshotCodec`. The codec emits document type
`story_engine_narrative_runtime_snapshot` with aggregate `formatVersion` and
`runtimeContractVersion` metadata independent from Story Format v1, package
semantic versioning, core runtime-snapshot versions, and host-action snapshot
versions.

The canonical format stores project identity, current shared persistent state,
`persistentStateRevision`, orchestration random state,
`maxAutomaticTransitions`, the next session/observation cursors, and retained
sessions in activation order. Each retained session envelope embeds the
existing deterministic `StoryRuntimeSnapshotCodec` document and
`StoryHostActionProtocolSnapshotCodec` document rather than duplicating or
redefining either nested contract.

Decode requires the host-supplied `StoryProject` and entry-point declarations.
Malformed representation failures use
`StoryNarrativeRuntimeSnapshotFormatException`; otherwise well-formed
compatibility failures use the existing
`StoryNarrativeRuntimeSnapshotCompatibilityException`. Full aggregate semantic
validation completes before decode returns. Unknown fields are rejected, and
nested core/protocol failures retain their original causes under aggregate
session paths.

Aggregate raw-document migrations run through the package-internal
`StoryNarrativeRuntimeSnapshotMigrationPipeline` before current-version decode.
Revision 1 has no built-in migration step yet; future format changes must add
deterministic consecutive N -> N+1 transformations at this seam rather than
branching restore semantics.

The codec performs no narrative execution, runtime restoration, random draw,
observer emission, or host-action dispatch. Stage 9A5 remains the sole owner of
aggregate runtime capture/rehydration.

### 9.8 Concrete Stage 9A5 runtime capture and restore

Stage 9A5 materializes aggregate runtime checkpoint capture through
`StoryNarrativeRuntime.createSnapshot()` and direct rehydration through
`StoryNarrativeRuntime.restore(...)`.

Capture is permitted only at a completed serialized-operation boundary. It
copies the current shared persistent state/revision, orchestration random state,
automatic-transition limit, next session and observation cursors, and every
retained session checkpoint in activation order. Capture consumes no random
values and emits no observations.

Restore first runs `StoryNarrativeRuntimeSnapshotValidator` against the supplied
project and entry-point declarations. It then restores the orchestration random
source directly from the aggregate random state, recreates the shared state
against the supplied project schema, restores each core `StoryEngine` from its
existing runtime checkpoint, restores each `StoryHostActionProtocol` from its
protocol checkpoint, reconstructs retained sessions with their original indexes
and entry points, and derives active-session membership from restored core
status. Completed sessions retain their historical session-local state.

Caller-supplied observers are attached only after the private runtime/session
graph is coherent. Rehydration emits no replay observations and does not invoke
`startSession(...)`, `resolveAndStartSession(...)`, entry effects, transitions,
random draws, or host-action dispatch. Future observation sequence IDs continue
from the saved cursor, pending host requests retain their stable request IDs, and
the next session allocation continues from the saved session cursor.

Stage 9A5 intentionally does not add aggregate content/save binding; Stage 9A6
owns release/module compatibility binding. Exhaustive uninterrupted-versus-
restore continuation parity remains the Stage 9A7 regression gate.

### 9.9 Concrete Stage 9A6 aggregate content binding

Stage 9A6 reuses the existing `StorySaveContentBinding` wire contract rather
than embedding content-release identity in `StoryNarrativeRuntimeSnapshot`.
Hosts derive one companion binding with
`StorySaveContentBinding.fromRetainedSessionSnapshots(...)`, supplying the
aggregate `projectId` and each retained session's core `StoryRuntimeSnapshot` in
retained-session order.

Binding derivation is deterministic and includes:

- every module owning an event in every retained session's committed history;
- every module owning a retained session's current event;
- each referenced module's declared dependency closure;
- completed as well as unfinished retained sessions;
- each module revision at most once, in first-reference/dependency traversal
  order.

Unrelated project modules are intentionally omitted. An aggregate with no
retained sessions carries an empty module-revision list while still binding the
project, content release, and exact runtime-bundle identity.

The existing `StorySaveContentBindingCodec` remains the wire adapter, and
`StorySaveContentCompatibilityEvaluator` remains the compatibility preflight.
Therefore aggregate saves use the same explicit categories as Stage 8L:
`exact`, `compatible`, `migrationRequired`, `fallbackRequired`, and
`incompatible`. Version labels never imply safety. A migration or fallback
result remains an explicit host decision; Stage 9A6 does not silently rewrite
or restart a checkpoint.

Content preflight happens before aggregate restore when a host supports mutable
content releases. A result of `exact` or `compatible` permits the host to
continue to ordinary aggregate/project validation; it does not bypass
`StoryNarrativeRuntimeSnapshotValidator` or core snapshot validation. For
`migrationRequired`, the host must apply an explicit migration path before
restore. `fallbackRequired` is a separate recovery decision and MUST NOT be
presented as restoration of the old aggregate run.

The aggregate snapshot and content binding remain two data objects/codecs and
MUST be persisted atomically as one logical save revision. Stage 9A6 does not
change Story Format v1, the aggregate snapshot wire format, or the core runtime
snapshot format.

### 9.10 Concrete Stage 9A7 deterministic restoration parity

Stage 9A7 freezes aggregate restoration as an executable equivalence property,
not merely a successful decode/constructor path. The canonical regression
matrix compares an uninterrupted `StoryNarrativeRuntime` with a runtime that is
checkpointed, encoded through `StoryNarrativeRuntimeSnapshotCodec`, decoded,
and restored before both branches receive the same future inputs.

Parity requires canonical aggregate checkpoints to remain byte-for-byte equal
after every compared future operation. The matrix additionally compares public
active-session membership, session lifecycle/current-event/available-choice
views, pending host-action identity, and the suffix of structured observations
including their persisted sequence IDs.

Revision 1 parity coverage includes at least:

- multiple simultaneously active sessions plus retained completed history;
- shared persistent-state commits and propagation into unfinished siblings while
  completed sessions retain their historical state;
- weighted entry-point resolution and exact next-session seed/index allocation;
- local session RNG continuation through a weighted core transition;
- pending host-action restoration with no replay, followed independently by
  successful completion, explicit failure, and explicit cancellation;
- continued host-action request ordinal allocation after a restored pending
  request resolves;
- restore-then-continue behavior through termination;
- repeated encode/decode/restore cycles with no checkpoint drift.

Passing these tests establishes deterministic continuation equivalence for the
implemented Stage 9A runtime contract. It does not make observers authoritative,
perform external host work during restore, or weaken the separate content
compatibility preflight defined by Stage 9A6.

### 9.11 Concrete Stage 9A8 public save/load lifecycle

Stage 9A8 closes the implementation sequence by defining one supported public
durable-resume lifecycle for `StoryNarrativeRuntime`. The consumer-facing form
is documented in `AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md` and is normative with
respect to the authority boundary established by this contract.

The ordinary save path is:

1. capture one aggregate checkpoint at a completed serialized-operation
   boundary;
2. derive the companion aggregate `StorySaveContentBinding` when the integration
   uses Stage 8L content releases;
3. encode both values through their existing deterministic codecs;
4. persist the aggregate snapshot plus companion binding atomically as one
   host-owned logical save revision.

The ordinary load path is:

1. read one matching logical save revision;
2. decode/evaluate the content binding when present;
3. proceed only for `exact` or `compatible` content results;
4. decode and fully validate the aggregate checkpoint against the supplied
   project and complete entry-point configuration;
5. restore only through `StoryNarrativeRuntime.restore(...)`;
6. reconcile any restored pending host actions by stable request ID without
   redispatch;
7. continue through explicit authoritative inputs.

`migrationRequired`, `fallbackRequired`, and `incompatible` are stop conditions
for the ordinary aggregate-resume path. Revision 1 does not define a one-call
aggregate migration API. A future or host-owned approved migration must produce
a coherent aggregate checkpoint and matching content binding before the normal
validation/restore path can resume. `fallbackRequired` represents a new
host-selected recovery run, not restoration of the old aggregate checkpoint.

A retained `StoryNarrativeSessionSnapshot` is an atomic component checkpoint,
not a supported substitute for aggregate restoration. Independently restoring
session/core/protocol values cannot recreate orchestration RNG continuation,
shared persistent-state authority/revision, allocation and observation cursors,
retained-session ordering, active membership, or cross-session validation.
Standalone `StoryEngine` persistence remains a separate valid path for hosts
that are not using `StoryNarrativeRuntime`.

The package does not define storage transactions. If aggregate snapshot and
content binding are encoded separately, the host storage layer MUST prevent an
intentional/torn pairing of different logical save revisions. A failure in
capture, content preflight, aggregate decode, aggregate validation, or restore
MUST leave the ordinary resume path without publishing a partial runtime or
dispatching external host work.

## 10. Restore semantics

A conforming aggregate restore behaves as rehydration, not execution.

Conceptually it MUST:

1. decode data without invoking narrative behavior;
2. validate aggregate metadata and all cross-object invariants;
3. validate project/content compatibility;
4. reconstruct the orchestration RNG directly from persisted state;
5. reconstruct every core `StoryEngine` directly from its runtime snapshot;
6. reconstruct every host-action protocol directly from its protocol snapshot;
7. reconstruct retained sessions with their exact indexes and entry-point
   identities;
8. derive the active-session collection without replaying activation;
9. restore persistent state/revision, next-session identity, runtime
   configuration, and observation cursor;
10. attach the newly supplied observers only after the runtime is coherent;
11. publish/return the restored runtime.

Restore MUST NOT call normal `startSession(...)` or
`resolveAndStartSession(...)` to recreate retained sessions.

Restore MUST NOT replay:

- entry effects;
- selected choices;
- continuation transitions;
- automatic transitions;
- RNG draws;
- host-action requests or resolutions;
- observer events representing already committed work.

## 11. Failure atomicity

Malformed or incompatible aggregate data MUST fail before the caller receives a
partially restored runtime.

Restore failure MUST NOT:

- mutate a live existing runtime;
- dispatch host actions;
- emit narrative observations through caller-supplied observers;
- consume caller-visible narrative RNG;
- partially install sessions into an object that is then returned.

The implementation may construct private temporary objects during validation,
but failure must remain externally atomic.

## 12. Persistence atomicity at the host boundary

When a durable save includes both aggregate runtime data and a content/save
binding, the host MUST treat them as one atomic logical save revision.

A host must not intentionally combine:

- aggregate snapshot from save revision N; and
- content binding from save revision N-1.

The package may expose separate data objects/codecs to preserve architectural
boundaries. Storage transaction/file-replacement/database mechanics remain host
responsibilities.

The same rule applies inside one session: its core runtime snapshot and
host-action protocol snapshot are one logical checkpoint and must not be mixed
from different moments.

## 13. Story Format v1 remains frozen

Aggregate persistence is runtime/save infrastructure. Story Format v1 gains no
fields for:

- persistent-state revision;
- session indexes;
- runtime RNG state;
- pending host actions;
- observation sequence;
- aggregate snapshot versions;
- locks, threads, host callbacks, or module loaders.

The existing `StoryRuntimeSnapshot` representation also remains unchanged.
Stage 9A introduces a separate versioned aggregate layer around existing
runtime/session checkpoint primitives.

## 14. Stage 9A completion

Stage 9A1 froze this contract before aggregate runtime code was added.

The implementation sequence completed in order:

- Stage 9A2: immutable aggregate/session snapshot model;
- Stage 9A3: aggregate validation;
- Stage 9A4: deterministic versioned codec;
- Stage 9A5: `StoryNarrativeRuntime.createSnapshot()` and restore;
- Stage 9A6: aggregate content/save binding (completed);
- Stage 9A7: deterministic restoration-parity coverage (completed);
- Stage 9A8: public save/load lifecycle documentation (completed).

With Stage 9A8 complete, Stage 9A exits with one aggregate authority model,
validated/versioned persistence, no-replay restore, content binding, deterministic
parity coverage, and one documented host save/load lifecycle. Stage 9B may now
build runnable consumer integrations on this stable persistence boundary.

Stage 9A1 originally provided a dedicated executable expected-red implementation gate for
the then-not-yet-existing aggregate model/codec/restore surface. It is intentionally
outside default `dart test` discovery so the ordinary regression suite remains
green between substages. The explicit implementation gate is now green after
9A2, 9A4, and 9A5; it must not be weakened or bypassed in later work.
