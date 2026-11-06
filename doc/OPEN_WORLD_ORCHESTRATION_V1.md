# Open-World Narrative Orchestration — Contract Revision 1

This document defines the Stage 8G host-driven narrative orchestration model.
It is an implementation-independent behavioral contract above Runtime Semantics
Core Revision 1. It does **not** modify frozen Story Format v1 and does not
freeze a serialized entry-point file format.

The central separation is:

```text
HOST WORLD
  decides where/when narrative should be requested
        |
        v
ENTRY-POINT RESOLUTION
  persistent narrative state + explicit host facts
        |
        v
NARRATIVE SESSION
  local event traversal through Runtime Semantics Core Revision 1
        |
        v
SESSION TERMINATES
  control returns to host world
```

A large host game therefore does not need one enormous graph in which every
NPC, location, quest, tutorial, or systemic event points directly to every
other possible narrative encounter.

> **Current integration note:** this document remains the base entry-resolution
> and local-session contract. Current `StoryNarrativeRuntime` integrations also
> use `SESSION_EXECUTION_V1.md` for multi-session/shared-state authority and
> `AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md` for durable runtime persistence. The
> original Stage 8G one-active-session proving constraint is not the current
> runtime-wide cardinality rule.

## 1. Scope

Revision 1 defines:

- host-selected activation by stable named entry point;
- deterministic resolver-selected activation;
- conditions, priority, fallback, and weighted tie-breaking;
- explicit host-world condition results;
- persistent scalar narrative state across sessions;
- session-local traversal status/history/randomness;
- deterministic RNG isolation between orchestration and local sessions;
- termination as return of control to the host;
- the original Stage 8G one-active-session proving rule, with current
  runtime-wide multi-session authority specified by `SESSION_EXECUTION_V1.md`.

This base contract does not define:

- a serialized entry-point authoring format;
- Story Format v2 fields;
- modular/indexed content loading, specified by Stage 8H;
- suspendable host actions (Stage 8I);
- simultaneous/concurrent-session authority and conflicting writes, specified
  by `SESSION_EXECUTION_V1.md`;
- compiled runtime bundles (Stage 8K);
- content patch/save compatibility (defined in Stage 8L);
- capability/version negotiation, now defined by `RUNTIME_CAPABILITIES_V1.md`.

## 2. Host-world navigation versus narrative-local traversal

The host application owns world traversal. It decides that a player interacted
with an NPC, entered a location, crossed a quest threshold, opened a management
screen, or otherwise reached a point where narrative content may run.

The narrative runtime owns only local narrative execution after activation.
A completed dialogue is not required to contain a transition to the next NPC
that the player might meet later.

Consequently, session termination means **return control to the host**, not
"the entire game's narrative is permanently finished".

## 3. Entry-point identity

An entry point has a stable machine identity separate from the event it targets.
Multiple entry points MAY target the same event if their orchestration metadata
differs.

An entry point contains the semantic equivalents of:

- entry-point ID;
- destination event ID;
- optional core StoryCondition over persistent narrative state;
- zero or more explicit host-condition requirements;
- integer priority;
- positive integer weight;
- regular/fallback classification.

Revision 1 intentionally does not specify how this metadata is serialized.
Story Format v1 remains frozen.

## 4. Direct named activation

A host MAY request one specific entry-point ID. The runtime MUST:

1. reject an unknown entry-point ID;
2. evaluate the entry point's eligibility against current persistent state and
   supplied host facts;
3. reject an ineligible named entry rather than bypassing its rules;
4. start a fresh local runtime at the entry point's destination event;
5. use current persistent narrative state as that session's starting state.

No transition edge from a previous session is required. The fallback flag is a
resolver classification only; a host that explicitly names a fallback entry may
still activate it when that entry is eligible.

The Dart reference runtime exposes `StoryEngine.startAt(...)` as the minimal
local-runtime primitive used by the higher-level session coordinator. `start()`
continues to use `StoryProject.entryEventId` and retains its existing behavior.

## 5. Resolver-selected activation

Resolver selection is deterministic for the same project metadata, persistent
state, host facts, and orchestration RNG state.

### 5.1 Eligibility

Entry points are considered in declaration order. For each candidate:

1. evaluate its optional core StoryCondition against persistent StoryState;
2. if that is false, the entry is ineligible and its host requirements need not
   be evaluated;
3. otherwise evaluate host-condition requirements in declaration order;
4. a missing required host result is an error, **not** implicit false;
5. every supplied result must equal the requirement's expected Boolean value.

Host requirements are conjunctive in Revision 1. Richer expression trees are
not invented here; a host may expose a higher-level declared condition through
Extension Schema when appropriate.

### 5.2 Fallback

The resolver first collects eligible **regular** entry points.

Fallback entry points are considered only if no regular entry point is
eligible. A fallback entry therefore never competes against an eligible regular
entry, regardless of its priority or weight.

### 5.3 Priority

Within the selected regular/fallback tier, only candidates with the greatest
integer priority remain.

Priority is deterministic ranking, not probability.

### 5.4 Weighted tie-breaking

If exactly one highest-priority candidate remains, it is selected without an
entry-resolution random draw.

If multiple candidates remain, their positive weights are accumulated in
declaration order. One deterministic bounded integer is sampled in
`[0, totalWeight)` using the `story_engine.lcg32` version 1 deterministic-random
profile, and the first authored half-open weight interval containing the sample
wins.

The total winning-tier weight MUST remain inside the portable Story Integer
range.

## 6. Explicit host-world conditions

Narrative orchestration MUST NOT silently query host globals such as:

- player position;
- quest manager state;
- world time;
- network state;
- combat objects;
- engine singletons;
- operating-system or wall-clock state.

A host-owned condition requirement instead identifies a language-neutral
Extension Schema namespace/condition/argument set and a stable host-condition
key. The trusted host implementation evaluates that request and passes the
Boolean result explicitly for the activation operation.

This keeps the narrative contract deterministic and prevents the entire host
world simulation from being copied into StoryState merely so dialogue
eligibility can be checked.

Missing explicit results are incompatibility/execution errors rather than
silent false values, consistent with Extension Schema v1's no-silent-fallback
rule. If one host-condition key is reused by multiple entry points, it MUST
identify the same namespace, condition ID, and argument values everywhere. The
required expected Boolean may differ so the same explicit fact can be tested
positively or negatively.

## 7. Persistent versus session-local state

### 7.1 Persistent scalar narrative state

All scalar variables in the current StoryProject state schema are persistent in
Revision 1. A successful session operation commits its resulting StoryState back
to the owning narrative runtime, and the next session starts from that state.

Revision 1 does **not** invent a second authored "session local variable"
schema. If generic use cases later justify such a domain, it requires an
explicit contract rather than an implicit naming convention.

### 7.2 Session-local traversal state

Each narrative session owns its local:

- current event;
- lifecycle status;
- available choices;
- Runtime Semantics Core Revision 1 history;
- deterministic local random stream;
- automatic-transition budget/execution state.

These facts do not become the next session's current event/status/history by
accident.

## 8. History scope

Core `StoryRuntimeHistory` is session-local.

The higher-level narrative runtime preserves an ordered list of session-history
records containing at least:

- deterministic session index;
- entry-point ID;
- entry event ID;
- session random-seed provenance;
- session status;
- local structural runtime history.

A flattened event route MAY be exposed as a convenience view, but session
boundaries remain the source of truth.

Future history-derived conditions MUST explicitly define whether they inspect
session-local or persistent/cross-session history. Revision 1 does not silently
change existing core conditions to inspect global history.

## 9. RNG scope across sessions

Revision 1 uses two deterministic scopes:

1. **orchestration stream** — owned by the higher-level narrative runtime and
   used for weighted entry resolution plus per-session seed allocation;
2. **session stream** — a fresh `story_engine.lcg32` v1 stream owned by one
   local session.

After an entry point has been resolved, the orchestration stream allocates the
session seed with one bounded draw in `[0, 2^32)`.

This isolation is intentional: adding/removing random decisions inside one NPC
dialogue MUST NOT perturb the resolver's random choice among unrelated entry
points in a later host-world encounter.

A failed activation MUST NOT commit orchestration RNG advancement. Successful
activation commits both the resolution draw (when any) and session-seed draw.

Aggregate narrative persistence preserves the orchestration stream's exact
algorithm/state rather than reconstructing it from session count; see
`AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md` and
`NARRATIVE_RUNTIME_PERSISTENCE_V1.md`.

## 10. Session lifecycle and authority

The original Stage 8G proving implementation permitted at most one active
narrative session per `StoryNarrativeRuntime` instance. That historical
simplification is superseded for current integrations by the multi-session
execution-authority contract in `SESSION_EXECUTION_V1.md`.

The host supplies explicit input IDs to the intended session. The narrative
runtime validates and advances serialized authoritative operations according to
Core Revision 1 plus the session-execution contract. The model does not assume a
Flutter widget, local UI thread, client authority, or a specific game engine.

## 11. Validation roots

Classic Story Format v1 validation still uses `StoryProject.entryEventId` as the
ordinary project root. Host-driven projects may additionally supply the event
IDs targeted by orchestration entry points as **additional graph roots** when
calling the reference validator.

Additional roots affect graph reachability/cycle/termination analysis only.
They do not mutate the authored project, suppress unrelated structural errors,
or become serialized Story Format v1 fields.

This prevents intentionally independent NPC/dialogue modules from being
reported as unreachable merely because they are activated by the host rather
than by a transition from the default project entry.

## 12. Compatibility with Story Format v1

Story Format v1 remains unchanged.

In particular, Revision 1 does not add serialized fields such as:

- `entryPoints`;
- `priority`;
- `fallback`;
- `hostConditions`;
- `narrativeSession`;
- `orchestrationRandomState`.

The Dart API types introduced in Stage 8G are a reference implementation of the
orchestration semantics, not an assertion that Dart object layout is the
portable wire format.

## 13. Stage 8G proving ground

The reference tests include a synthetic open-world project with forty unrelated
NPC dialogue entry points. The project retains an ordinary default entry for
classic validation/runtime compatibility, but the host resolver selects a
different local entry directly without all-to-all graph edges. A separate test
also proves `StoryEngine.startAt(...)` can activate an existing event even when
the project has no default entry.

Additional tests prove:

- direct host-selected activation;
- persistent state across sessions;
- regular/fallback separation;
- priority before weighting;
- explicit host facts;
- exact seeded weighted selection/session seed vectors;
- session RNG isolation from later entry resolution;
- the original Stage 8G one-active-session proving constraint (with current
  multi-session behavior covered by `SESSION_EXECUTION_V1.md`).

## 14. Forward boundary

Stage 8H now defines modular/indexed loading around these semantics without
requiring every entry target/event body to remain permanently materialized.
The entry-point contract therefore depends on stable IDs and metadata, not on
in-memory object pointers or a monolithic graph. See
`MODULAR_PROJECT_LOADING_V1.md` for that loading contract. Stage 8I now adds
the companion suspendable host-interaction protocol in
`HOST_ACTION_PROTOCOL_V1.md`; Stage 8J now owns the concurrency/state-conflict contract in `SESSION_EXECUTION_V1.md`.
