# Suspendable Host Interaction — Protocol Revision 1

This document defines the Stage 8I language-neutral protocol for narrative work
that must pause while a trusted host performs an external asynchronous action.
Examples include combat, cinematics, shops, minigames, level streaming, and
network-authoritative decisions.

The protocol is deliberately separate from Story Format v1 and from any one
host language. A conforming runtime may expose different class/method names, but
it must preserve the observable lifecycle, identity, payload, resolution, and
snapshot semantics defined here.

## 1. Scope

Protocol Revision 1 defines:

- stable host-action request identity;
- language-neutral action identity and portable scalar arguments;
- an explicit `awaiting_host` session state;
- successful typed completion, explicit failure, and explicit cancellation;
- one-pending-request semantics;
- duplicate/mismatched resolution protection;
- deterministic request-ID allocation that consumes no narrative RNG;
- snapshot/restore behavior while a request is pending;
- the trust boundary between declarative narrative data and host code.

It does not define:

- the future authored Story Format representation that causes an action request;
- registration or discovery of executable host callbacks;
- networking, task scheduling, threads, or platform async primitives;
- wall-clock timeout behavior;
- simultaneous narrative sessions or conflicting state writes (Stage 8J);
- capability negotiation, now defined by `RUNTIME_CAPABILITIES_V1.md`.

## 2. Trust boundary

The narrative runtime owns only deterministic protocol state. The trusted host
owns the actual external operation.

```text
Narrative session
  -> HostActionRequest (data)
  -> session status: awaiting_host

Trusted host
  -> starts/reconciles combat, cinematic, shop, etc.
  -> later returns exactly one explicit outcome

Narrative session
  -> validates outcome against the pending request
  -> leaves awaiting_host
  -> resumes the same previously committed core pause
```

A request or snapshot MUST NOT contain callbacks, Futures/Tasks, thread handles,
Unity GameObjects, Unreal UObjects, sockets, file handles, database connections,
or other host-owned runtime objects.

## 3. Request identity

Every pending action has one stable `HostActionRequestId`.

The Dart reference implementation allocates IDs from a session-local monotonic
ordinal:

```text
host_action_session_7_0
host_action_session_7_1
...
```

A conforming implementation may use another textual representation if its API
contract differs, but cross-runtime conformance fixtures that compare request
identity MUST use the profile-defined representation for that fixture/profile.

For the Dart reference profile:

- allocation is deterministic;
- allocation uses no RNG;
- allocation reads no wall clock;
- the next ordinal is persisted;
- a restored pending request keeps exactly the same ID.

## 4. Request payload

One request identifies:

- schema namespace;
- action member ID;
- named arguments;
- optional successful result type.

Arguments use only portable scalars:

- Boolean;
- portable exact Integer;
- finite binary64 Number;
- String.

Enum/reference arguments are represented by stable strings whose domain meaning
comes from the relevant Extension Schema/reference contract.

The request contains no implementation method/class/callback identity.

## 5. Result types

A request may declare no result value, or one of:

- Boolean;
- Integer;
- Number;
- String;
- enumeration value;
- reference value.

Integer and Number remain distinct. Number results must be finite. A request
with no result type accepts only a successful completion with no value.

Enumeration/reference results are stable non-empty strings at this protocol
layer. Validation against the complete enum/reference catalog belongs to the
schema/integration layer that constructed the request.

## 6. Session lifecycle

Stage 8I composes host suspension over the already committed Core Runtime
Semantics pause. It does not add `awaiting_host` to Story Format v1 or silently
rewrite Core Runtime Semantics Revision 1.

A host-visible narrative session therefore has the composite states:

```text
awaiting_choice
awaiting_continue
awaiting_host
terminated
```

When a request is emitted:

1. the underlying core run MUST already be at a committed host-visible pause;
2. the request is committed as pending;
3. the session exposes `awaiting_host`;
4. the underlying core state/event/history/RNG remain unchanged;
5. choice/continue inputs are rejected until the request resolves.

Only one host action may be pending in one session under Protocol Revision 1.
A second request while one is pending is rejected without mutation.

## 7. Resolution

Exactly one of the following explicit host inputs resolves the current request.

### 7.1 Successful completion

The supplied request ID MUST equal the pending request ID. The result value MUST
exactly match the request's declared successful-result type.

On success, the pending request is cleared and the session returns to the same
committed core pause from which it was suspended.

Protocol Revision 1 does not itself mutate StoryState from the returned result.
A future authored host-action invocation semantic may define how a successful
result feeds subsequent narrative logic. The suspend/resume protocol must not
guess that behavior early.

### 7.2 Failure

Failure is explicit host input carrying the matching request ID, a stable
machine-readable failure code, and a human/debug message. The protocol clears
the pending request and resumes the same core pause.

### 7.3 Cancellation

Cancellation is explicit host input carrying the matching request ID and a
stable machine-readable cancellation code, plus optional text. It also resumes
the same core pause.

### 7.4 Duplicate and mismatched resolution

A resolution with an ID different from the pending request MUST be rejected.
Resolving an already-resolved request MUST be rejected. Neither case may change
state, history, RNG, or the current pending request.

## 8. Timeout policy

The narrative runtime MUST NOT read the wall clock to decide that a host action
has timed out. Timeout policy belongs to the host. If the host decides a timeout
has occurred, it converts that decision into one explicit failure or
cancellation input with the stable request ID.

This preserves deterministic replay and server-authoritative execution.

## 9. Snapshot and restore

A durable suspended-session checkpoint consists of two logically atomic parts:

1. the committed core runtime snapshot;
2. the host-action protocol snapshot.

The protocol snapshot contains only:

- protocol scope/identity information;
- next request ordinal;
- the complete pending request, if any.

A runtime restoring a pending host action MUST NOT automatically dispatch the host action again.
Automatic redispatch could duplicate purchases, combat, network commands,
cinematics, or other external work.

Instead, the host reconciles the stable request ID with its own external state:

```text
restore narrative snapshot
  -> pending request action_123 still exists
  -> host asks/reconstructs whether action_123 is running/completed/cancelled
  -> host supplies exactly one explicit resolution
```

The Dart reference implementation exposes a strict JSON codec for the protocol
snapshot under:

```text
contract: open_story.host_action_protocol_snapshot
contractVersion: 1
```

The existing StoryRuntimeSnapshot wire format remains unchanged by Stage 8I.

When the session is owned by `StoryNarrativeRuntime`, Stage 9A persists this
core+protocol pair inside the complete aggregate runtime checkpoint. The
supported durable orchestration resume path restores the aggregate authority,
not the pending session independently. After aggregate restore, the same stable
request ID is reconciled with external host state exactly as described above.
See `AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md`.

### Runnable aggregate-restore example

For a public-root example that suspends a modular narrative session, saves the
complete orchestration authority, restores the same pending request, and
reconciles its stable ID without redispatch, run:

```text
dart run example/story_narrative_modular_host_action_restore_example.dart
```

The simulated external host dispatch count remains one across restore. The host
resumes narrative execution only after submitting one explicit outcome for the
restored request.

## 10. Host-selected `startAt` restore

Stage 8G made a host-selected event a legitimate beginning of one local run.
Therefore runtime-snapshot validation MUST accept a structurally valid history
whose first entered event is any event in the project, not only
`StoryProject.entryEventId`.

Later history edges remain subject to the same strict structural transition
validation. This is required so an open-world session can be saved while
awaiting host work and restored without rewriting the project entry event.

## 11. Relationship to Extension Schema v1

Extension Schema v1 declares available action identities and parameter types,
but does not embed implementation code. Protocol Revision 1 carries a request
for such an action without changing that trust boundary.

Extension Schema v1 does not yet declare async result schemas. The host-action
protocol therefore defines the portable result-type vocabulary needed for
suspension. A later schema revision/profile may reference this vocabulary rather
than inventing incompatible completion semantics.

## 12. Story Format v1 remains frozen

Story Format v1 has no runtime-affecting host-action invocation node. Stage 8I
does not reinterpret opaque extension metadata as executable behavior and does
not add host-action fields to Story Format v1.

A future authored representation that causes a request requires an explicit
Story Format version or versioned semantic extension profile.

## 13. Stage boundary

Stage 8I freezes the suspend/resume protocol and proves the Dart reference
implementation can preserve a pending request across snapshot/restore without
serializing host-engine internals.

Stage 8J now defines simultaneous-session representation, persistent/session
state ownership, atomic conflicting writes, threading/reentrancy rules, worker
independence, and authority/input-driven execution. See
`SESSION_EXECUTION_V1.md`. Stage 8K now defines the runtime build/content
pipeline contract.
