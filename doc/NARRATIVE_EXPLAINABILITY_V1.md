# Narrative Explainability — Contract Revision 1

Stage 9C adds optional structured explanations for authoring/debugging tools and
advanced hosts. Explanations describe what the runtime actually evaluated or
attempted; they are never an alternative source of narrative authority.

The portable rule is:

> Explanation data observes one real execution/evaluation pass. Collecting,
> formatting, serializing, discarding, or not requesting it must not change the
> narrative result.

Story Format v1 remains unchanged. Stage 9C1 freezes the data model and
stability boundary. Stage 9C2 adds opt-in condition-evaluation instrumentation;
Stage 9C3 integrates choice availability and entry-point resolution; Stage 9C4
integrates actual effect/state-change execution; Stage 9C5 adds the optional
host-oriented observer/debug adapter.

## 1. Scope

Revision 1 defines immutable public data values for:

- condition-evaluation trees, including actual short-circuit shape;
- choice availability;
- entry-point state conditions and explicit host-condition facts;
- entry-point fallback/priority/finalist/weighting resolution;
- authored effect source, operation, before/after values, and transactional
  committed/no-op/rejected/rolled-back outcome.

Revision 1 does not define:

- a Story Format v1 change;
- a persistent engine-owned explanation file/codec format;
- UI labels, localization, prose rendering, tree widgets, colors, or icons;
- a second speculative evaluation pass used only for debugging;
- any requirement that normal consumers request, retain, or understand
  explanation objects.

## 2. Observational-only boundary

Explanation collection is non-authoritative. Narrative execution MUST NOT read
an explanation object to decide state, branching, transition selection,
eligibility, RNG behavior, host-action identity, transaction commit, or error
behavior.

Diagnostics MUST NOT:

- evaluate an authored condition a second time merely to explain it;
- evaluate a child skipped by `ALL`/`ANY` short-circuiting;
- evaluate fallback entry points when the regular tier already has an eligible
  candidate;
- perform an RNG draw when the authoritative resolver did not perform one;
- repeat an RNG draw to reconstruct why a weighted selection happened;
- apply an effect again to reconstruct a before/after value;
- turn a rejected/rolled-back effect into committed state;
- swallow, replace, or reorder authoritative runtime exceptions.

The Stage 9C6 release gate compares diagnostics-off and diagnostics-on runs for
exact narrative-semantic parity.

## 3. Condition explanation model

`StoryConditionExplanation` is a sealed immutable tree whose concrete node
matches the authored condition category. Every completed node records the
Boolean result produced by the actual evaluation pass.

Composite nodes additionally record:

- `authoredChildCount` — number of children in authored data;
- `evaluatedChildren` — only children actually evaluated, in authored order;
- `shortCircuited` — derived from the difference between those counts.

A false `ALL` explanation ends at the first false child. A true `ANY`
explanation ends at the first true child. Skipped authored children are not
invented as false/true explanation nodes.

Variable explanation nodes record the stable variable identity plus the
relevant current/expected scalar values. A null current value means the
variable was unset; it is not a special `StoryValue`.

Stage 9C1 models completed evaluations. Runtime exceptions retain their
existing authoritative exception behavior; later instrumentation may emit
partial diagnostic context separately without converting a failed evaluation
into a Boolean result.

## 4. Choice explanation model

`StoryChoiceExplanation` identifies the owning event and choice and records the
actual availability result.

- No authored availability condition means unconditional availability and a
  null condition explanation.
- An authored condition is represented by the actual
  `StoryConditionExplanation`, and its result must equal choice availability.

The explanation contains no presentation text. An authoring tool or another
host may render localized author-facing text from the structured data.

## 5. Entry-point explanation model

Entry-point explainability has two levels.

### 5.1 Candidate explanation

`StoryEntryPointExplanation` records authored identity/routing metadata plus one
candidate status:

- `eligible`;
- `stateConditionRejected`;
- `hostConditionRejected`;
- `hostConditionMissing`;
- `notEvaluated`.

`notEvaluated` is materially different from rejection. In particular, fallback
entries are `notEvaluated` when a regular entry was already eligible.

State conditions use the same condition-explanation tree. Host requirements use
`StoryHostConditionExplanation`, which records the stable requirement key,
extension namespace/condition ID/arguments, expected result, and the explicit
host result. A missing host fact is represented distinctly from a false
fact through a `hostConditionMissing` candidate explanation. The authoritative
runtime continues to treat a missing required fact as a resolution error rather than a
normal no-selection result. A complete `StoryEntryPointResolutionExplanation`
therefore represents only operations that returned normally.

Host-condition evaluation also preserves actual short-circuit behavior: after
one mismatch, later requirements are not reported as if they were evaluated.

### 5.2 Resolution explanation

`StoryEntryPointResolutionExplanation` records:

- every authored candidate in declaration order;
- the winning regular/fallback tier and priority when selection succeeds;
- finalists in authored order;
- whether selection required no winner, one sole finalist, or a weighted draw;
- the actual total weight/sample only when the authoritative resolver drew;
- the selected entry-point identity.

For a weighted draw, constructor invariants verify that the recorded sample
maps to the recorded selected finalist. For a sole finalist, no sample/total is
present because the authoritative resolver does not consume a resolution RNG
draw in that case.

## 6. Effect/state-change explanation model

`StoryEffectExplanation` identifies the exact authored effect by:

- owner (`eventEntry` or `choice`);
- owning event and optional choice identity;
- zero-based authored effect index;
- variable identity;
- operation (`set`, `unset`, `increment`, `decrement`);
- operation operand where applicable;
- value immediately before the effect;
- value produced by the effect attempt;
- transactional outcome.

Outcomes are deliberately distinct:

- `committed` — the transaction committed and the variable changed;
- `noOp` — the transaction committed but the variable value did not change;
- `rejected` — the effect itself failed before transaction commit;
- `rolledBack` — the effect executed, but a later failure prevented the
  transaction from committing.

`afterValue` describes the effect attempt. It must never be interpreted as
committed state when the outcome is `rejected` or `rolledBack`.

## 7. Contractual fields versus diagnostic presentation

The following are contractual structured meaning for Stage 9C:

- explanation type/kind and result/outcome/status enum semantics;
- stable story identities and authored effect indexes;
- current/expected/operand/before/after scalar values;
- authored order of evaluated children, host requirements, candidates, and
  finalists;
- authored-vs-evaluated counts used to reveal real short-circuiting;
- fallback tier, priority, weights, and actual sampled offset when a draw
  occurred;
- distinction between unavailable/rejected, not evaluated, no-op, rejected,
  rolled back, and committed.

The following remain diagnostic/presentation detail and are not semantic
contracts:

- `toString()` wording or formatting;
- English labels or explanatory prose;
- indentation/tree layout, icons, colors, grouping, sorting, or filtering;
- host log transport, telemetry schema, storage location, or retention period;
- authoring-tool UI structure and localization.

The public Dart explanation model is suitable for host-side structured logging
or serialization because it contains immutable data, stable engine identities,
enums, portable scalar `StoryValue`s, and ordered immutable collections. Stage
9C1 intentionally does not declare those Dart objects to be a long-term
cross-version persisted wire format. A host that persists diagnostic logs owns
and versions its own log representation.

## 8. Relationship to existing diagnostics and observations

Runtime explanations are separate from `StoryDiagnostic` validation findings.

- `StoryDiagnostic` reports static authored-project validation problems.
- Stage 9C explanations report causal data from an actual runtime evaluation or
  transaction attempt.
- `StoryNarrativeObservation` remains the existing non-authoritative lifecycle
  observation stream.

Stage 9C5 bridges explanation values through the optional
`StoryNarrativeDebugAdapter`, while keeping validation findings, lifecycle
observations, and causal explanations as distinct non-authoritative concerns.

## 9. Immutability and ownership

Every explanation object is data-only. Iterable/map inputs are defensively
owned as unmodifiable collections where applicable. Explanation objects contain
no callbacks, observers, engines, mutable `StoryState`, RNG objects, loaders,
platform handles, or UI objects.

Constructors reject internally contradictory records so later instrumentation
cannot accidentally report impossible causal shapes (for example, an `ALL`
trace that evaluates children after the first false result, or a weighted
sample that points at a different finalist than the recorded winner).

## 10. Stage 9C1 historical completion boundary

At the Stage 9C1 closeout, the model-only gate required:

- the immutable explanation vocabulary to be public from
  `package:story_engine/story_engine.dart`;
- the contract above to distinguish stable structured meaning from diagnostic
  presentation detail;
- tests to prove defensive collection ownership and core shape invariants;
- existing validation diagnostics to remain separate;
- condition/effect/runtime execution code to remain behaviorally unchanged at
  that stage boundary.

Stage 9C2 then adds condition explanation collection during the actual
evaluation pass while preserving the evaluator's short-circuit and exception
semantics.

## 11. Stage 9C2 condition-evaluation instrumentation

`StoryConditionEvaluator.evaluateWithExplanation(...)` performs one condition
evaluation and returns the completed `StoryConditionExplanation` produced by
that pass. Its `result` field is the Boolean result of the same evaluation; a
host does not need to call `evaluate(...)` first.

`evaluate(...)` and `evaluateWithExplanation(...)` use the same internal evaluation traversal
and therefore share variable lookup, type validation,
comparison semantics, nesting order, and exception behavior. The diagnostic
path captures current/expected values while they are already being used by the
authoritative evaluation. It does not run a second condition traversal.

For composite conditions, instrumentation does not evaluate skipped children.
A false `ALL` stops after its first false child and a true `ANY` stops after its
first true child. `authoredChildCount` retains the complete authored shape while
`evaluatedChildren` records only the actual evaluation prefix.

Malformed authored logic throws the same `StoryConditionEvaluationException`
as ordinary evaluation. Stage 9C2 models completed Boolean evaluations only; it
does not convert a failed evaluation into a partial success or swallow the
existing exception.

The ordinary `evaluate(...)` path does not retain explanation data and does not
construct explanation objects. This keeps diagnostics opt-in while later 9C
stages can adopt the one-pass path at the specific runtime decision points that
need author-facing explanations.

Stage 9C2 does not wire explanation collection into choice availability,
entry-point resolution, transition selection, `StoryEngine`,
`StoryNarrativeRuntime`, or effect execution. Stage 9C3 adds the choice and
entry-point integrations below; Stage 9C4 adds the effect/state-change
instrumentation described later in this contract.


## 12. Stage 9C3 choice and entry-point instrumentation

`StoryEngine.choiceExplanations` evaluates every authored choice at the current
`awaitingChoice` pause and returns both available and unavailable decisions in
authored order. Each conditioned choice uses the Stage 9C2 one-pass evaluator;
unconditional choices remain available with a null condition explanation.
`StoryNarrativeSession.choiceExplanations` exposes the same diagnostic surface
while an `awaitingHost` session intentionally exposes an empty list, matching
its non-selectable choice surface.

`StoryNarrativeRuntime.explainEntryPointEligibility(...)` is a non-mutating
single-candidate probe. It records the actual state-condition result and the
authored prefix of host requirements inspected. For this diagnostic probe only,
a missing required host fact is returned as `hostConditionMissing`; the
authoritative start/resolution APIs still throw for the same missing input.

`StoryNarrativeRuntime.resolveAndStartSessionWithExplanation(...)` is the
opt-in authoritative resolution path. It resolves and starts using the same
condition evaluations, fallback tier, priority scan, and copied orchestration
RNG transaction that determine the returned session. The resolution
explanation is assembled from that pass: no condition is re-run and no random draw is repeated merely for diagnostics.

When a regular candidate is eligible, fallback candidates are represented as
`notEvaluated`. When no regular candidate is eligible, fallback candidates are
evaluated normally. A sole finalist records no RNG sample; a weighted tie
records the exact total weight and zero-based sample consumed by the resolver.
A normal no-selection result records every evaluated candidate and
`StoryEntryPointSelectionMethod.none`. Missing host facts remain resolution
errors and therefore do not produce a complete resolution explanation.

The existing `availableChoices`, `startSession`, and `resolveAndStartSession` remain diagnostics-off. Explanation collection does not mutate state,
history, RNG, session identity, host-action identity, persistence data, or
Story Format v1.

## 13. Stage 9C4 effect/state-change instrumentation

`StoryEngine.startWithEffectExplanations(...)`,
`startAtWithEffectExplanations(...)`, `chooseWithEffectExplanations(...)`, and
`continueStoryWithEffectExplanations()` are opt-in counterparts to the existing
transactional runtime operations. Each diagnostic operation executes the same authoritative effects exactly once
and returns the `StoryEffectExplanation`
values captured during that transaction.

The effect executor records the value immediately before each authored effect
and the value produced by that same effect attempt. Authored source identity and
zero-based effect index come from the exact event-entry or choice list being
executed; no effect is re-applied merely to reconstruct a delta.

A successful engine transaction finalizes every recorded attempt as either
`committed` when the variable changed or `noOp` when before and after are equal.
If an effect itself fails, it is recorded as `rejected` and earlier successful
attempts in the transaction are `rolledBack`. If all effects execute but a later
transition, event-availability check, automatic-flow guard, or other runtime step
prevents transaction commit, every prior successful effect attempt is likewise
reported as `rolledBack`. The authoritative exception type/order is unchanged.

`StoryEngine.lastEffectExplanations` retains the immutable trace from the most
recent diagnostics-enabled operation, including after a failed diagnostic
transaction so a debugger can inspect rejected/rolled-back attempts after
catching the normal engine exception. Ordinary `start`, `startAt`, `choose`, and
`continueStory` remain diagnostics-off: they clear this diagnostic trace and use
the original effect executor path without constructing explanation objects.

The diagnostic trace is not part of `StoryRuntimeSnapshot`, aggregate narrative
persistence, history, state, RNG, or Story Format v1. Restoring an engine does
not replay or restore diagnostic effect traces. Stage 9C5 adapts these
structured values into an optional observer/debug stream suitable for authoring
tools without making explanation collection authoritative.


## 14. Stage 9C5 observer/debug adapter

`StoryNarrativeDebugAdapter` is the opt-in orchestration bridge from the
structured Stage 9C explanation values to authoring/debug tools. A host attaches
at most one adapter to `StoryNarrativeRuntime` (or to aggregate restore) through
`debugAdapter:` and overrides only the callbacks it needs.

Stage 9C5 introduced these four causal channels (Finalization Stage 2 adds
execution and shared-commit channels in section 16):

- explicit entry-point eligibility explanations from `startSession(...)`;
- completed automatic entry-point resolution explanations from
  `resolveAndStartSession(...)` and its explanation-returning counterpart;
- one immutable batch of choice explanations whenever an owned session reaches
  a committed `awaitingChoice` pause;
- one immutable batch of effect explanations for diagnostics-enabled session
  start/choice/continue transactions.

When no adapter is attached, `StoryNarrativeRuntime` keeps the existing
minimal execution paths: entry eligibility/resolution do not construct
explanations, session start uses `StoryEngine.startAt(...)`, and session
choice/continue use the ordinary engine methods. Attaching an adapter switches
only the corresponding decision/transaction sites to the already-defined Stage
9C2–9C4 explanation-producing paths.

Choice presentation has one additional neutrality rule. With an adapter
attached, the runtime obtains `StoryNarrativeSession.choiceExplanations` once
and derives ordinary `StoryNarrativeChoicePresented` lifecycle observations
from that same result. It does not call `availableChoices` and then re-evaluate
the same choice conditions for diagnostics.

Effect explanations are delivered only after the aggregate persistent-state
commit succeeds. If the underlying engine transaction itself fails, any
rejected/rolled-back trace retained by `StoryEngine.lastEffectExplanations` is
delivered before the unchanged narrative exception propagates. A failed session
startup uses a null session index because no session identity committed.

Adapter callbacks are non-authoritative and exception-isolated. Callback
failures are swallowed and cannot alter state, history, RNG, session identity,
host-action identity, lifecycle observations, or exceptions. The adapter is a
live host dependency and is intentionally absent from core and aggregate
snapshots. Aggregate restore may attach a new adapter, but restoration never
replays historical explanation callbacks.

`StoryNarrativeDebugAdapter` does not own rendering, localization, filesystem
or database persistence, analytics/network transport, or authoring-tool UI state.
Hosts may transform or persist the immutable explanation values in their own
versioned diagnostic format.

Stage 9C5 does not change Story Format v1 and does not make explanation objects
part of narrative correctness. Stage 9C6 is responsible for the broader
semantic-neutrality/performance gate comparing diagnostics-off and
adapter-enabled executions.

## 15. Stage 9C6 semantic-neutrality and performance gate

Diagnostics are semantically neutral only when the same authored inputs and
seed produce the same authoritative execution with explanation capture disabled
and enabled. Stage 9C6 therefore compares more than the final `StoryState`.
Representative orchestration scenarios must preserve:

- deterministic aggregate snapshot JSON at equivalent committed checkpoints;
- selected entry-point identity, session index, and allocated session seed;
- session/core history and persistent-state revisions;
- host-action request identity and pending/completed protocol state;
- the ordered `StoryNarrativeObserver` lifecycle/error stream, including
  runtime-local observation sequence numbers; and
- exception runtime type, message, operation, and underlying cause identity.

The parity suite includes successful weighted entry resolution, condition-driven
choice availability, committed effects, host-action suspension/resumption, and
post-termination operation failure. It also covers missing required host facts
and rejected startup effects so diagnostics cannot silently change failure or
rollback behavior.

The diagnostics-enabled run must actually receive explanation callbacks; parity
is not established by accidentally exercising two diagnostics-off paths.
Explanation callback contents remain non-authoritative and therefore are not
included in the authoritative parity comparison.

### 15.1 Performance measurement

`benchmark/stage9c6_explainability_overhead.dart` measures the same deterministic
multi-session workload with diagnostics disabled and with a
`StoryNarrativeDebugAdapter` attached. It reports median elapsed microseconds
and the diagnostics-on/off ratio, and it verifies that both measured executions
end in the same aggregate snapshot.

Wall-clock performance is deliberately not a portable correctness assertion.
Dart VM warm-up, CPU/power state, operating-system load, and virtualization can
move timings substantially. The normal test suite therefore contains no hard
microsecond or ratio threshold. Compare Stage 9C6 benchmark medians on the same
machine and Dart SDK and investigate overhead that is disproportionate to the
captured explanation volume. Stage 9D6 owns durable performance-regression
budgets after the broader profiling work establishes representative growth
shapes and stable evidence.

With no debug adapter attached, the existing diagnostics-off execution paths
remain in use. Stage 9C6 adds no Story Format v1 field, snapshot field, execution
input, state mutation, RNG draw, host-action identity component, or new runtime
semantic.

## Aggregate rollback diagnostics

Effect explanations delivered by `StoryNarrativeDebugAdapter` describe the
aggregate orchestration outcome. If core effects succeed but destination choice
preparation or shared-state propagation fails, attempted committed/no-op effects
are reported as `rolledBack`; already rejected/rolled-back effects keep their
outcomes. Before/after values describe the attempted operation, not a surviving
shared-state commit. A failed start has no committed session identity, so its
effect callback uses a null session index.

Failure effect callbacks execute under the runtime's serialized guard, before
the corresponding failure observation. They cannot reenter narrative authority
or capture an aggregate checkpoint. Exceptions thrown by a diagnostic adapter
are isolated and do not replace the original operation failure. Enabling a debug
adapter preserves the normal choice-availability exception context when
preparing destination choices fails.

## 16. Finalization Stage 2: complete runtime execution explanations

The opt-in core input methods `startWithExplanations`,
`startAtWithExplanations`, `chooseWithExplanations`, and
`continueStoryWithExplanations` return one immutable
`StoryRuntimeExecutionExplanation`. They execute the input exactly once.
`lastExecutionExplanation` retains the latest opt-in attempt, including its
completed prefix when the authoritative input throws. Ordinary/effect-only
inputs clear that value even when rejected. Restores retain no execution trace.

`StoryRuntimeExecutionOutcome` distinguishes `committed` and `rolledBack`.
The ordered `StoryRuntimeExplanationStep` records contain:

- `StoryEventAvailabilityExplanation`: incoming pre-entry condition and result;
  no authored condition means unconditional availability;
- `StoryRuntimeChoiceExplanation`: actual selected-choice availability;
- `StoryRuntimeEffectExplanation`: the effect attempt at its causal position;
- `StoryEventTraversalExplanation`: an event whose availability and entry
  effects completed, and its choice/continuation/automatic flow mode;
- `StoryAutomaticTraversalExplanation`: the per-input transition count and
  configured limit, including the disallowed guard check that stops a cycle;
- `StoryTransitionBranchExplanation`: each completed conditional branch
  evaluation, preserving composite-condition short-circuit shape;
- `StoryConditionalTransitionExplanation`: first matching branch index or
  fallback, authored/evaluated branch counts, recorded before resolving its
  selected child;
- `StoryWeightedTransitionExplanation`: positive authored weights, total,
  actual sampled offset, and selected option index; and
- `StoryEventTransitionExplanation` / `StoryTerminalTransitionExplanation`:
  the actual selected concrete transition outcome.

Nested locations contain project/event/choice identities and full authored
field/index paths using the existing immutable `StoryDiagnosticLocation` value.
A branch condition points into `branches[index].condition`; its selected child
points into `branches[index].transition`. Weighted selections use
`options[index].transition`; fallback uses `fallback`. Automatic transitions
belong to the current traversed event, not the choice that originally started
that traversal. This reuses location data without converting execution records
into validation findings.

Conditions and RNG are evaluated by the same authoritative resolver as ordinary
execution. Skipped branches produce no condition record. Each encountered
weighted node performs exactly one `nextInt(totalWeight)` call, including a
single-option node; explanations observe that sample and never draw again.
The RNG implementation's existing rejection sampling remains unchanged.

A false event-availability result is retained before entry effects. An exception
while evaluating a condition is not fabricated as false: only previously
completed records survive. Missing destinations and invalid authored flow retain
the earlier causal prefix and their original configuration/execution exception.
Event traversal and before/after values describe attempts when the overall
operation rolls back; they are not persisted committed history.

The debug adapter adds `onExecutionExplanation` and
`onPersistentStateCommitExplanation`. It reports execution only once the
aggregate outcome is known, and changes successful core attempts to rolled-back
traces if presentation or sibling preparation prevents aggregate commit.
Failed startup uses a null session index. Failure traces run before the error
observation under the same execution guard.

`StoryPersistentStateCommitExplanation` reports one actual changed-state revision:
source session index, previous/new revision, `StoryPersistentVariableChange`
deltas in schema order, and propagated sibling indexes in active-session order.
Deltas may include null before/after values for set/unset. Multiple effects on a
variable produce one net commit delta; net-zero/unchanged transactions produce
no revision notification. Failed preparation/propagation produces no notification.
Successful delivery follows effect and execution callbacks and precedes session
progress. These callbacks are opt-in causal channels; the existing lifecycle
observation stream and its sequence numbers remain unchanged.

All new collections are defensively owned and immutable. Diagnostic records
are excluded from core/aggregate save payloads and never restored or replayed.
Their structured meaning is contractual diagnostic data; prose rendering and
host log persistence/versioning remain host concerns. This extension does not
change Story Format v1, save schemas, authored host actions, or narrative inputs.
