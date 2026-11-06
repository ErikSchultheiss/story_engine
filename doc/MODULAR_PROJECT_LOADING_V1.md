# Modular/Indexed Project Loading — Contract Revision 1

This document defines the Stage 8H contract for large narrative projects whose
complete event corpus should not need to remain materialized in memory at once.
It builds on the host-driven orchestration model from
`OPEN_WORLD_ORCHESTRATION_V1.md` and does **not** modify frozen Story Format v1.

The central separation is:

```text
AUTHORING SOURCE / BUILD INPUT
        |
        v
LIGHTWEIGHT PROJECT INDEX
  project identity + global state schema
  module metadata + event ownership
  entry points + outbound references
        |
        +-------------------------------+
        |                               |
        v                               v
MODULE A                           MODULE N
independent event bodies          independent event bodies
        |                               |
        +---------------+---------------+
                        v
             VERIFIED MODULE CACHE
                        |
                        v
             MATERIALIZED PROJECT SLICE
                        |
                        v
               existing StoryEngine
```

A runtime MAY still load a complete small project eagerly. Modular loading is a
scalability capability, not a requirement imposed on every story.

## 1. Scope

Revision 1 defines:

- stable module identity independent from event identity;
- a lightweight whole-project index;
- global event-to-module ownership;
- index-visible entry-point metadata;
- index-visible outbound event-reference summaries;
- explicit module dependencies for cross-module execution;
- whole-project reference/index validation without event bodies;
- verification of a loaded module against its advertised index summary;
- storage-neutral module loading;
- bounded caching, prefetching, and eviction semantics;
- deterministic dependency-closure materialization;
- executable `StoryProject` slices for the existing reference runtime.

It does not yet define:

- a Story Format v2 module layout;
- the compiled/binary shipping-bundle byte profile itself (Stage 8K defines the surrounding bundle contract);
- patch/DLC module-version compatibility (defined in Stage 8L);
- runtime capability negotiation, now defined by `RUNTIME_CAPABILITIES_V1.md`;
- a network/CDN/addressable/pak/file/database storage technology;
- automatic background streaming policy;
- hot replacement of event bodies inside an active session.

## 2. Stable identity

`StoryModuleId` identifies one independently loadable content unit.

Event identity remains project-global and stable. Moving event `evt_blacksmith`
from `module_village` to `module_companions` MUST NOT require changing the event
ID or references that target it.

Module identity therefore answers **where the body is loaded from**, not **what
the event is**.

## 3. Lightweight project index

A `StoryProjectIndex` contains the semantic equivalents of:

- project ID;
- global scalar state schema;
- optional conventional default entry event;
- ordered module descriptors;
- ordered global event index entries;
- Stage 8G entry-point metadata.

Each `StoryEventIndexEntry` contains:

- stable event ID;
- owning module ID;
- unique outbound event IDs in first-authored-reference order.

The index MUST be usable without loading event bodies. A host can therefore map
an entry point or event ID to the required module in memory proportional to the
index rather than the complete narrative text/content corpus.

The index is derived/runtime/build metadata. It does not replace the readable
authoring source of truth.

## 4. Module boundaries and dependencies

A `StoryNarrativeModule` contains:

- logical project ID;
- stable module ID;
- event bodies owned by that module.

Project-global state schema and entry-point metadata are not copied into every
module.

When an event in module A references an event in module B, module A MUST declare
module B as a dependency in the global index. The target event must also exist
in the global event index.

Dependencies MAY form cycles. Loading a dependency closure MUST visit each
module at most once.

A module MAY declare dependencies beyond those strictly required by transition
references, for example to permit host/build preloading policy. Extra declared
dependencies do not change narrative semantics.

## 5. Validation without loading all event bodies

Stage 8H separates validation into two layers.

### 5.1 Whole-project index/reference validation

`StoryModuleValidator.validateIndex(...)` operates only on lightweight metadata
and reports at least:

- duplicate module IDs;
- duplicate event IDs;
- duplicate entry-point IDs;
- missing event-owner modules;
- missing module dependencies;
- self/duplicate module dependencies;
- missing conventional default entry events;
- entry points targeting unindexed events;
- outbound references targeting unindexed events;
- cross-module references whose source module omitted the target module
  dependency.

This allows whole-project identity/reference validation even when no event body
is loaded.

### 5.2 Loaded module/index parity

Before a module becomes trusted runtime content, its project/module identity,
event set, and each event's outbound-reference summary MUST match the global
index.

A stale index paired with changed module bodies is therefore an explicit load
failure rather than a source of silent runtime divergence.

After a dependency closure is materialized as an ordinary `StoryProject`, the
existing `StoryValidator` remains the semantic validator for that executable
slice. Stage 8H does not create a second competing condition/effect/type
validator.

## 6. Storage-neutral loading

`StoryModuleLoader` is deliberately an abstraction. The contract does not
assume whether module bytes/objects originate from:

- local files;
- an engine asset database;
- a packed archive;
- addressables/resources;
- an application database;
- a remote content system;
- an in-memory test fixture.

The Dart reference API returns `Future<StoryNarrativeModule>` so host I/O may
complete asynchronously. Other runtime languages should expose an idiomatic
equivalent.

Load completion timing and physical storage are operational facts, not
narrative inputs. They MUST NOT alter choice availability, transition selection,
state commits, or deterministic RNG results.

## 7. Cache semantics

`StoryModuleCache` is a bounded verified cache above `StoryModuleLoader`.

Revision 1 uses least-recently-used retention plus per-cache single-flight
for pending loads. These are implementation policies, not narrative semantics.
In particular:

- a cache hit MUST expose the same verified module data as a load;
- concurrent misses for equal stable module IDs in the same cache MUST share
  one load-plus-verification operation rather than invoke the loader repeatedly;
- requests for different module IDs remain independently asynchronous and MUST
  NOT be serialized through a global queue or lock;
- prefetch MUST be semantically equivalent to loading later on demand and uses
  the same single-flight path as direct loading/materialization;
- only a successfully verified body enters the completed LRU cache;
- loader, returned-ID, or verification failure MUST remove the pending flight,
  leave no completed body, and permit a later retry;
- all waiters on one pending flight observe the same verified module object or
  the same normalized load exception object;
- eviction MUST discard only completed cached bodies, never persistent
  StoryState, orchestration RNG, session history, stable identity, index
  metadata, or an already-started load;
- evicting an ID that exists only as a pending flight returns false, and
  `clear()` likewise leaves pending flights running;
- a request arriving while a flight remains pending joins it, even if `evict`
  or `clear()` was called after that flight began;
- a successful pending load MAY populate the completed cache after `evict` or
  `clear()`, subject to the normal LRU capacity policy;
- capacity limits completed retained bodies, not outstanding host I/O;
- different completion orders may change which completed bodies remain resident
  under LRU pressure, but every waiter still receives its verified result;
- reloading an evicted unchanged module MUST produce the same narrative
  behavior; and
- an invalid/mismatched loaded module MUST NOT enter the verified cache.

Pending flights are instance-local and keyed by stable `StoryModuleId`; caches
bound to different indexes/loaders do not share pending work. Hosts remain
responsible for completion/cancellation policy inside their loader. A loader
that never completes can therefore leave one pending flight reachable as long
as its cache remains reachable; Revision 1 does not add timeout or cancellation
semantics.

The cache registers a same-ID flight before invoking host loader code. This
allows synchronous, non-awaited same-ID reentry to join the existing flight.
A loader MUST NOT await a cache request whose completion depends on that same
loader invocation (directly or through a circular loader-request chain), because
single-flight cannot resolve self-waiting. This host-I/O limitation is distinct
from authored cyclic module dependencies, which deterministic dependency-closure
traversal continues to support.

A host may choose another caching policy in another implementation as long as
those semantic invariants hold.

## 8. Dependency-closure materialization

For Revision 1, an executable slice rooted at module M contains M and the
transitive closure of its declared dependencies.

Traversal is deterministic depth-first order following each module's dependency
order and visiting each module at most once. The order is useful for
reproducibility/debugging; event execution itself continues to use stable IDs and
Runtime Semantics Core Revision 1.

`StoryModuleCache.materializeProjectForEvent(...)` and
`materializeProjectForEntryPoint(...)` produce ordinary derived `StoryProject`
objects. The requested event becomes the derived slice's default entry so
existing `StoryValidator`/`StoryEngine.start()` workflows can be reused.

The materialized project is a runtime view, **not** a rewritten authored
project. It must never be persisted back as though it were the complete source.

## 9. Interaction with Stage 8G orchestration

Stage 8G entry-point selection requires only entry-point metadata, persistent
narrative state, explicit host facts, and orchestration RNG. Event bodies are not
needed until an entry has been selected.

A large host can therefore:

1. keep the lightweight index resident;
2. resolve/select an entry point;
3. map its event ID to a module through the index;
4. load/materialize only that module's dependency closure;
5. start the local session with existing Runtime Semantics;
6. later evict inactive module bodies without changing persistent narrative
   state.

Stage 8H intentionally does not replace `StoryNarrativeRuntime` with a new
partially loaded event engine. The existing runtime remains the semantic
reference; modular loading prepares bounded complete slices for it.

### Runnable integration example

For a minimal public-root example that materializes one entry-point dependency
closure and then uses that derived slice inside a suspended/restored
`StoryNarrativeRuntime`, run:

```text
dart run example/story_narrative_modular_host_action_restore_example.dart
```

The example keeps module loading operational: restoring the aggregate runtime
recovers narrative/protocol state and does not redispatch the external host
action.

## 10. Small-project behavior

Lazy loading is optional. A moderate-sized or smaller project can continue
to use one ordinary fully materialized `StoryProject` if that is simpler and
fast enough.

No conforming authoring tool or runtime should force module management onto
small projects merely because large-project support exists.

## 11. Large-corpus target

The Stage 8H deterministic stress fixture represents:

- 100 modules;
- 5,000 independent dialogues;
- 10,000 indexed events;
- 5,000 indexed entry points.

Resolving/materializing one target dialogue module loads 100 event bodies, not
the 10,000-event corpus. This is an architectural scaling proof, not a fixed
maximum or minimum supported project size.

## 12. Story Format and future runtime bundles

Story Format v1 remains unchanged. Stage 8H freezes semantic/API constraints
that make modular loading possible; it does not retrofit module fields into the
frozen format.

Stage 8K now defines the separate compiled/indexed runtime-bundle concept. That
representation may encode this index and module structure efficiently
without becoming the canonical human-readable authoring format.

## 13. Conformance requirements

A conforming modular implementation must preserve:

1. stable project/event/module identity;
2. unloaded whole-project reference/index validation;
3. loaded module/index parity checks;
4. deterministic dependency-closure membership;
5. semantic equivalence across cache hit, demand load, prefetch, eviction, and
   reload;
6. unchanged Runtime Semantics and deterministic RNG behavior for the same
   materialized content and inputs;
7. explicit failure for missing/mismatched required content rather than silent
   fallback.

Stage 8I now builds on this foundation with the separate suspendable host
interaction protocol; Stage 8J now defines session concurrency/state ownership;
module I/O itself remains an infrastructure concern and does not become a host
action encoded into narrative semantics.
