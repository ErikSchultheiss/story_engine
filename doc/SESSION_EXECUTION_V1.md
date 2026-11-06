# Narrative Session Execution — Contract Revision 1

Stage 8J defines how multiple narrative sessions share persistent narrative
state without turning the runtime into a lock-heavy multithreaded game engine.
This contract builds on Core Runtime Semantics Revision 1, Open-World Narrative
Orchestration Revision 1, and Suspendable Host Interaction Protocol Revision 1.

The portable rule is:

> Multiple sessions may be logically active at once, but all operations that
> read or commit shared persistent narrative state are serialized by one explicit narrative execution authority.

The host determines input order. The runtime MUST NOT derive authority or
conflict order from wall-clock time, scheduler timing, UI callbacks, or network
arrival races.

## 1. Scope

Revision 1 defines:

- multiple simultaneously active narrative sessions;
- persistent/global narrative state ownership;
- session-local execution state;
- host-owned world facts;
- atomic persistent-state commits and conflicting-write order;
- session re-entry/thread-confinement rules;
- independent worker-safe operations where state is not shared;
- explicit time/world input requirements;
- UI-neutral and server-authoritative input submission.

Revision 1 does not define:

- networking or replication transport;
- distributed consensus;
- database locking;
- arbitrary authored session-local scalar variables;
- thread-safe mutation of one runtime instance from many threads;
- wall-clock timeout policy;
- game-world authority rules beyond explicit narrative inputs.

## 2. State ownership

### 2.1 Persistent/global narrative state

All scalar variables in the current `StoryProject.stateSchema` remain
persistent/global narrative state.

There is one committed `StoryState` per `StoryNarrativeRuntime`. Its value is
the authoritative narrative state shared by all active sessions owned by that
runtime.

A successful state-changing input commits a new immutable `StoryState`
atomically. A failed input commits nothing.

### 2.2 Session-local state

The following remain local to one `StoryNarrativeSession`:

- current event;
- core runtime lifecycle status;
- available-choice context;
- `StoryRuntimeHistory`;
- session RNG stream;
- pending host-action protocol state;
- entry-point identity and session activation index.

Revision 1 deliberately does not invent a second authored
`sessionLocalVariables` schema. If a future use case justifies authored local
variables, that requires an explicit portable contract rather than an implicit
Dart-only map.

### 2.3 Host-owned world facts

Game time, player position, quest-system state, weather, network facts, world
simulation objects, and other mutable external facts remain host-owned.

They MUST enter narrative decisions through explicit inputs such as
`StoryHostContext` condition results or future versioned host-input contracts.
The core runtime MUST NOT call `DateTime.now()`, inspect process globals, query a
game singleton, or otherwise read hidden mutable world state.

For example, a game may evaluate `GameTime.hour >= 20` in trusted host code and
supply the explicit result for a declared host condition. The narrative runtime
does not read the machine clock.

## 3. Multiple active sessions

`StoryNarrativeRuntime` may own zero, one, or many unfinished sessions.

Sessions retain deterministic activation indexes. The runtime exposes the
ordered active set independently from historical completed sessions.

Logical simultaneity does not mean simultaneous mutation. A foreground NPC
conversation, companion banter, and a radio event may all remain active, but
shared-state operations still cross one serialized commit boundary.

A session suspended in `awaitingHost` does not block unrelated sessions from
receiving inputs.

## 4. Serialized execution authority

One `StoryNarrativeRuntime` is one execution authority for its persistent state.

For every input that may observe or modify shared state:

1. the authority identifies the target session by stable session index;
2. the runtime verifies that the target is still active;
3. the input executes synchronously against the latest committed persistent
   state visible to that session;
4. the complete operation either succeeds or fails transactionally;
5. on success, any new persistent state is committed atomically;
6. sibling active sessions receive the same committed persistent state before
   the operation boundary is released;
7. only then may the next shared-state input execute.

A runtime instance MUST reject unsafe re-entry while an operation is already
processing. Host code must submit the next input only after the prior operation
returns successfully or throws.

## 5. Conflicting writes

Revision 1 does not attempt nondeterministic parallel merging.

If two active sessions write the same persistent variable, their effects are
applied in the explicit authority input order.

Example:

```text
persistent mood = neutral

input 1 -> session A sets mood = angry
commit 1 -> mood = angry

input 2 -> session B sets mood = calm
commit 2 -> mood = calm
```

The second input executes against the state committed by the first input. This
is deterministic ordered serialization, not scheduler-dependent last-writer
wins.

If two inputs truly arrive concurrently at a server or host boundary, the host
must establish an authoritative order before invoking the runtime. Networking
and queue policy remain outside `story_engine`.

## 6. Atomic propagation

A persistent-state commit and propagation to sibling active sessions are one
logical atomic boundary.

A runtime MUST NOT expose a state where the global `persistentState` has
advanced while only some active sessions have received the corresponding
persistent state.

The Dart reference implementation prepares all sibling session replacements
before committing the global state/revision and then swaps the prepared views
as one synchronous operation.

Completed sessions are historical snapshots and are not rewritten by later
persistent-state changes.

## 7. Persistent-state revision

The Dart reference runtime exposes a monotonic `persistentStateRevision` for
observation/debugging. It advances only when committed persistent state changes.

This revision is not a timestamp, synchronization primitive, or distributed
version vector. Stage 9A now versions revision continuity as part of the
aggregate orchestration checkpoint so a restored logical runtime does not move
backward observationally. See `NARRATIVE_RUNTIME_PERSISTENCE_V1.md`.

## 8. Host actions and simultaneous sessions

A session waiting on `HostActionRequest` remains logically active.

Its pending host operation is session-local. Another session may continue and
commit persistent state while the first waits. The waiting session receives the
new committed persistent state without redispatching or otherwise changing its
pending host request.

Resolving the host action later resumes the same session-local core pause as
specified by Host Interaction Protocol Revision 1.

## 9. Input-driven authority API

Narrative progression is defined by stable machine-ID inputs, not by UI
callbacks.

The Dart reference runtime provides `StoryNarrativeInput` data objects for:

- choice selection;
- explicit continue;
- host-action completion;
- host-action failure;
- host-action cancellation.

`StoryNarrativeRuntime.applyInput(...)` routes one such input to its target
session by deterministic session index.

A Flutter widget may construct these inputs. So may a replay harness, CLI,
dedicated server, or replicated authoritative host. The runtime does not know
which one supplied the input.

## 10. Server-authoritative execution

A server-authoritative host can therefore use the following model:

```text
authoritative host/server
  -> start/resolve narrative session
  -> receive available stable choice IDs
  -> replicate presentation/IDs to client
  -> client returns requested stable input ID
  -> server validates authority/order
  -> server calls applyInput(...)
  -> narrative runtime validates and commits
  -> resulting state/presentation replicated by host
```

`story_engine` does not implement sockets, RPC, client prediction, rollback
netcode, authentication, or replication. Those are host responsibilities.

## 11. Threading and workers

A single runtime/session instance is thread-confined to one execution authority.
Conforming implementations MUST NOT permit two operations to mutate the same
runtime instance concurrently.

This does not prohibit parallelism elsewhere. Independent runtime instances,
independent validation jobs, conformance runs, module loading/build work, and
other operations that do not share mutable runtime authority may run on separate
workers when their host implementation can do so safely.

The important compatibility requirement is semantic isolation, not a mandate
for one process or one UI thread.

## 12. Determinism and external time

The same project, initial state, RNG state, explicit host facts, and ordered
input sequence must produce the same narrative result regardless of:

- machine wall-clock time;
- render frame timing;
- UI framework;
- worker scheduling;
- network transport used to deliver already-authorized inputs.

No hidden mutable global may affect core narrative semantics.

## 13. Persistence boundary

Stage 8J did not introduce a multi-session save wire format. Stage 8I's
per-session checkpoint remains the suspendable-session primitive.

Stage 9A now defines the aggregate orchestration checkpoint in
`NARRATIVE_RUNTIME_PERSISTENCE_V1.md`. It preserves the committed persistent
state and revision, retained session identities/checkpoints, orchestration RNG
state, session-local RNG/history/status, pending host actions, runtime
configuration/identity cursors, and companion content compatibility data needed
for deterministic continuation.

The aggregate format must not serialize locks, threads, sockets, UI objects,
observers, loaders, host implementations, or other host-engine internals.

When a session belongs to a `StoryNarrativeRuntime`, its local
`StoryNarrativeSessionSnapshot` is a component of that aggregate checkpoint.
Hosts MUST NOT treat a collection of independently restored session/core
snapshots as a substitute for restoring the orchestration authority. Only the
aggregate checkpoint preserves the shared-state revision, orchestration RNG,
allocation/observation cursors, retained ordering, and validated active-session
membership required for deterministic continuation. The standalone
`StoryEngine` snapshot/restore path remains valid outside orchestration.

See `AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md` for the supported host lifecycle.

## 14. Story Format v1 remains frozen

No Stage 8J execution-authority or concurrency concept becomes a Story Format v1
field. In particular v1 gains no:

- thread IDs;
- locks;
- session queues;
- timestamps;
- server/client role flags;
- persistent-state revision fields;
- session-local variable schema.

The authored format remains declarative and language-neutral.

## 15. Stage boundary

Stage 8J freezes shared-state ownership, serialized multi-session execution,
explicit input authority, re-entry/threading rules, and host-owned external-fact
boundaries.

Stage 8K now defines the deterministic source-format to compiled/indexed
runtime-bundle build pipeline. Stage 8N now consolidates these threading,
reentrancy, explicit-input, and authority rules in
`RUNTIME_IMPLEMENTER_CONTRACT_V1.md` and adds non-authoritative structured
observation hooks. Stage 8O now provides the independent C# second-runtime
proof required before Stage 9; Stage 8P follows before the Stage 9 shell.

## Choice presentation and the aggregate commit boundary

Choice availability is fallible authored logic. After core start, choose, or
continue succeeds, an orchestration operation prepares the destination's choice
presentation before publishing shared persistent state or success observations.
The operation delivers the prepared choices (and, when requested, their
explanations) without evaluating the conditions a second time.

If that preparation fails, a failed start allocates no retained session and
consumes no committed orchestration RNG/session identity. A failed choose or
continue restores the source through the validated core restore path; shared
state, sibling sessions, host requests, active-session order, and execution RNG
remain at the previous committed boundary. Failure observations may advance the
observation sequence, as other failed serialized operations do.

Success and failure diagnostic callbacks both run while the same serialized
execution guard is held. Reentrant authority operations and aggregate snapshot
capture remain rejected until the operation has returned or thrown. Callback
exceptions remain isolated from the authoritative result.
