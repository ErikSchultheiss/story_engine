# Runtime Implementer Contract — Revision 1

Stage 8N consolidates production execution constraints that independent
runtimes must preserve around Stage 8B–8M semantics. This document is aimed at
runtime implementers and host integrations; it does not prescribe a Dart/C#/
C++/GDScript API shape.

## 1. One runtime authority, explicit input order

One mutable narrative-runtime instance has one execution authority. Inputs that
may read or commit shared persistent state MUST execute in an explicit
host-authorized order. A runtime MUST NOT derive conflict order from wall-clock
time, thread scheduling, render frames, or network arrival races.

The host may run independent runtime instances or read-only validation/build
work on separate workers. Semantic isolation is required; one UI thread is not.

## 2. Reentrancy

A runtime/session MUST reject unsafe re-entry while it is processing an input.
Host callbacks, observer hooks, or framework notifications MUST NOT synchronously
advance the same runtime again before the current operation returns or fails.

A conforming implementation may use an event loop, actor, queue, mutex, or
thread confinement internally. The portable requirement is serialized semantic
execution, not a particular synchronization primitive.

## 3. Authority and server hosts

Narrative progression is driven by stable explicit inputs: entry-point
activation, choice IDs, continue inputs, and host-action outcomes. The runtime
MUST NOT assume that the local presentation UI is authoritative.

An authoritative server may own the runtime, publish available stable IDs to a
client, validate the returned requested input, establish ordering, and then
advance the runtime. Networking/replication remains host-owned.

## 4. External time and world facts

The narrative core MUST NOT read machine wall-clock time or hidden mutable host
globals. Game time, world state, player position, quest facts, network state,
and similar data enter only through explicit host inputs/condition results.

Given identical project data, narrative state/RNG, explicit host facts, and
ordered inputs, changing the machine wall clock or unrelated process globals
MUST NOT change the narrative result.

The shared Stage 8N `explicit_host_input_vector` fixture freezes this rule.

## 5. Structured runtime observation

A runtime MAY expose structured observation hooks for debuggers, QA logs,
telemetry adapters, profiling, or tests. The reference contract exposes events
corresponding to:

- narrative session started;
- event entered;
- choice presented;
- choice selected;
- host action requested;
- host action completed/failed/cancelled;
- narrative session ended;
- narrative operation error.

Observations contain stable IDs and runtime-local sequence order.
They MUST NOT contain a required wall-clock timestamp.

Observer delivery is non-authoritative. Adding, removing, or breaking an
observer MUST NOT change narrative state, RNG consumption, route selection,
available choices, host-action identity, or success/failure semantics.

The core runtime MUST NOT embed an analytics service, telemetry endpoint,
account identity, network client, or persistence backend. Hosts decide whether
observations are ignored, displayed, logged, or forwarded.

## 6. Observer re-entry

Observer callbacks execute inside the current operation boundary in the Dart
reference implementation. Re-entering the same runtime from such a callback is
therefore rejected by the same reentrancy rule. Other runtimes may dispatch
observations differently, but they MUST preserve narrative semantics and event
order.

## 7. Deterministic observation order

The reference runtime assigns a zero-based runtime-local `sequence` to emitted
observations in emission order. Sequence is diagnostic ordering metadata only;
it is not an authored value, timestamp, persistence token, or cross-process
clock.

Automatic event traversal emits each committed event-entry observation in the
same order as structural runtime history.

## 8. Stage 8O independent implementation proof

Stage 8O now supplies an independent C# runtime spike implemented from the
public semantic specifications and conformance fixtures without relying on
private Dart source. The spike executes all six `runtime-core-v1` foundation
cases and the deterministic-random reference vectors. Differences in native
types or control-flow structure are allowed; observable narrative semantics are
not. See `INDEPENDENT_CSHARP_RUNTIME_SPIKE.md`.
