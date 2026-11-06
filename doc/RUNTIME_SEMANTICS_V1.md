# Runtime Semantics — Core Revision 1

This document is the implementation-independent execution specification for the
core narrative semantics currently implemented by `story_engine` and
representable by Story Format v1.

It defines **behavior**, not Dart API shape. A conforming runtime may use C#,
C++, GDScript, Rust, JavaScript, another language, different class names, or no
class hierarchy at all. Conformance depends on producing the same semantic
results from the same valid authored data, runtime-relevant initial state, input
trace, and deterministic-random inputs.

Core Revision 1 is intentionally independent from:

- the `story_engine` package version;
- Story Format version 1;
- the runtime snapshot format version;
- any future machine-readable runtime capability/profile version.

Story Format v1 remains the authored-data contract. This document specifies how
its current executable core is interpreted once a project has been decoded.
Core Revision 1 does **not** add a field to frozen Story Format v1.

The Dart reference snapshot contract already labels its compatible execution
baseline as `runtimeContractVersion: 1`. Stage 8B gives that baseline an
implementation-independent written definition. Other runtimes do not need to
adopt the Dart snapshot representation in order to implement Core Revision 1.

## 1. Scope

Core Revision 1 specifies:

- runtime lifecycle and committed state;
- the four portable scalar state categories;
- set versus unset state;
- condition evaluation;
- effect execution;
- interactive, continuation, and automatic event modes;
- event-entry and choice/continue execution order;
- direct, conditional, weighted, and terminal transitions;
- structural runtime history relevant to deterministic replay;
- transactional commit/rollback behavior;
- implementation-independent runtime failure categories.

It does not yet specify:

- Story Format JSON lexical/canonical writer details;
- the exact cross-language pseudorandom-number algorithm or bounded-integer
  implementation, which is specified by the companion deterministic-random
  profile;
- the external conformance-fixture/report format (Stage 8D);
- semantic custom actions or custom conditions (Stage 8E);
- host-driven entry-point resolution and narrative-session orchestration,
  specified separately by the Open-World Narrative Orchestration Revision 1
  companion contract;
- modular loading;
- suspendable host actions, specified separately by the Suspendable Host
  Interaction Protocol Revision 1 companion contract;
- concurrency or capability negotiation;
- filesystem, database, networking, UI, analytics, or localization policy.

## 2. Normative interpretation

The words **MUST**, **MUST NOT**, **SHOULD**, and **MAY** describe conformance
requirements in this document.

A runtime is conforming to Core Revision 1 only for features it claims to
implement. It MUST NOT silently substitute different semantics for the core
features described here.

Dart exception class names, method names, enum names, and implementation
objects are not protocol identity. Where this specification defines a failure
category, another runtime may expose its own native error type as long as the
semantic category and rollback behavior agree.

## 3. Runtime inputs and committed runtime state

One core run is driven by:

1. one authored project;
2. one initial story state;
3. an ordered host input trace (choice selections and explicit continues);
4. one deterministic random stream/configuration where weighted transitions
   are encountered;
5. runtime guard configuration such as an automatic-transition budget.

The committed runtime state consists of the semantic equivalents of:

- lifecycle status;
- current story-state values;
- current event identity, when any;
- committed structural runtime history;
- deterministic random-stream state;
- execution-affecting runtime guard configuration.

A runtime operation MUST expose either its complete successful result or the
previous committed runtime state. Partial execution state is never committed.

## 4. Scalar story state

### 4.1 Schema and variable identity

Every state variable is declared by a stable variable identity and exactly one
scalar type. During one core run, the state schema is fixed.

A state is a mapping from declared variable identities to either:

- one value of the variable's exact declared type; or
- **unset**.

An undeclared variable is not the same thing as a declared-but-unset variable.
Accessing an undeclared variable through authored runtime logic is invalid.

### 4.2 Portable scalar categories

Core Revision 1 supports exactly these scalar categories:

| Category | Semantic domain |
| --- | --- |
| Boolean | `true` or `false` |
| Integer | exact integer in `-9007199254740991..9007199254740991` |
| Number | finite IEEE-754 binary64 value |
| String | exact text sequence; no implicit normalization or case folding |

Integer and Number are distinct types even when they represent the same
mathematical value. `65` as an Integer is not type-compatible with `65.0` as a
Number. Runtimes MUST NOT coerce between the two categories during condition or
effect execution.

Number values MUST be finite. NaN and positive/negative infinity are outside the
portable state domain. Binary64 subnormal values and signed zero are finite and
therefore valid.

### 4.3 Number equality and ordering

Number comparisons use ordinary finite IEEE-754 numerical relations rather
than a host-language-specific *total ordering* helper.

Consequently:

- `+0.0` and `-0.0` compare equal;
- neither signed zero is less than or greater than the other;
- all other finite Number values compare by numerical value;
- NaN behavior is irrelevant because NaN is not a valid Story Number.

This rule is normative because some host-language comparison helpers impose an
extra total order that distinguishes the two signed-zero representations. Such
helpers MUST NOT leak into authored narrative semantics.

### 4.4 String equality

String equality compares the exact decoded text sequence. A runtime MUST NOT
perform Unicode normalization, locale-sensitive comparison, case folding, or
whitespace rewriting as part of core story semantics.

The acceptance/rejection of malformed JSON Unicode input and canonical JSON
escaping are Story Format reader/writer conformance concerns rather than runtime
execution semantics.

### 4.5 Initial state

If the host does not supply an explicit initial state, the runtime starts from
all authored variable initial values; declarations without an initial value are
unset.

If the host supplies an explicit initial state, that state is a complete
runtime-state input, not a patch over authored defaults:

- every supplied variable MUST be declared;
- every supplied value MUST exactly match the declared type;
- omitted declared variables remain unset even if the schema declares an
  authored default;
- extra undeclared variables are invalid.

A runtime API may represent this contract differently, but it MUST preserve the
same resulting state.

## 5. Lifecycle

Core Revision 1 has four lifecycle states:

### `not_started`

No start operation has successfully committed. There is no current event and no
committed story state for the run.

### `awaiting_choice`

The current event is interactive. Its entry has successfully committed, and the
runtime is waiting for the host to submit one currently available choice
identity.

### `awaiting_continue`

The current event is a continuation event. Its entry has successfully
committed, and the runtime is waiting for an explicit continue input.

### `terminated`

An explicit terminal transition has been resolved successfully. Story state,
history, and the last entered event remain inspectable, but the core run accepts
no further choice or continue input.

A core run may be started only once. A fresh run requires a fresh runtime/session
instance. The companion open-world orchestration contract now defines a
higher-level coordinator that creates fresh local sessions while carrying
persistent narrative state across them.

## 6. Event flow modes

A runnable entered event MUST have exactly one of these three flow modes.
Presentation data does not determine flow mode.

### 6.1 Interactive

An event is interactive when:

- it contains one or more authored choices;
- it has no continuation transition; and
- it has no automatic transition.

After successful event entry, the runtime pauses in `awaiting_choice`.

The event remains interactive even if every authored choice is currently hidden
by its availability condition. In that case the available-choice list is empty
and the runtime remains paused; the runtime MUST NOT infer termination or choose
a hidden option automatically.

### 6.2 Continuation

An event is a continuation event when:

- it has no authored choices;
- it has one continuation transition; and
- it has no automatic transition.

After successful event entry, the runtime pauses in `awaiting_continue`.
The continuation transition is not resolved until an explicit continue input is
accepted.

### 6.3 Automatic

An event is automatic when:

- it has no authored choices;
- it has no continuation transition; and
- it has one automatic transition.

An automatic event never creates a host-visible pause merely because it has
presentation data. After its entry effects, its transition is resolved
synchronously and traversal continues until a choice pause, continue pause,
termination, or failure is reached.

### 6.4 Incomplete or ambiguous flow

An event with zero flow modes is non-runnable. An event with more than one flow
mode is ambiguous. Both are authored-configuration failures when the event is
entered.

Authoring tools may preserve such incomplete data. The execution runtime MUST
NOT guess the intended flow mode.

## 7. Event entry semantics

Whenever traversal attempts to enter event `E`, the runtime performs these
steps in order within the current transaction:

1. Resolve `E` by stable event identity. A missing event is a configuration
   failure.
2. Confirm that `E` has exactly one valid flow mode.
3. Evaluate `E`'s availability condition, if present, against the **incoming
   state before entry effects**.
4. If the availability condition is false, fail the operation. The runtime does
   not skip the event, search for an alternative, or apply its entry effects.
5. Record a pending `event_entered(E)` history step.
6. Make `E` the transaction's current event.
7. Apply `E`'s entry effects sequentially in authored order.
8. Continue according to the event's flow mode:
   - interactive: pause at `awaiting_choice`;
   - continuation: pause at `awaiting_continue`;
   - automatic: resolve its automatic transition immediately.

The `event_entered` history step becomes visible only if the complete host
operation commits successfully.

## 8. Choice availability and selection

### 8.1 Availability query

Choice availability is meaningful only while the runtime is
`awaiting_choice`.

Choices are considered in authored order. A choice without an availability
condition is available. A choice with a condition is available exactly when
that condition evaluates to true against the current committed story state.

Choice availability is evaluated **after** the current event's entry effects,
because those effects have already committed when the interactive pause is
reached.

Availability queries are read-only: they MUST NOT consume randomness, mutate
state, change history, or change lifecycle status.

Outside `awaiting_choice`, the semantic available-choice set is empty.

### 8.2 Choice selection

When the host submits choice identity `C`, the runtime MUST reject the input
without mutation unless all of the following are true:

- lifecycle is `awaiting_choice`;
- `C` belongs to the current event;
- `C` is currently available;
- `C` has a transition.

If accepted, one transactional choice operation proceeds in this exact order:

1. record a pending `choice_selected(currentEvent, C)` history step;
2. apply `C`'s effects sequentially in authored order;
3. resolve `C`'s transition against the **post-choice-effect state**;
4. if the result is an event destination, enter that event using Section 7;
5. if the result is terminal, set lifecycle to `terminated`.

A destination event's availability condition therefore observes all successful
choice effects before its own entry effects.

## 9. Explicit continuation

A continue input is valid only while lifecycle is `awaiting_continue`.

If accepted, one transactional continuation operation proceeds in this exact
order:

1. record a pending `event_continued(currentEvent)` history step;
2. resolve the current event's continuation transition against the state that
   already includes the current event's entry effects;
3. if the result is an event destination, enter that event using Section 7;
4. if the result is terminal, set lifecycle to `terminated`.

A continue input in another lifecycle state is an operation failure and MUST
NOT mutate committed runtime state.

## 10. Condition semantics

Conditions are pure predicates. They MUST NOT mutate story state, history,
random state, lifecycle, or host state.

### 10.1 `all`

Evaluate children in authored order. Stop immediately at the first false child
and return false. If every child is true, return true.

Because evaluation short-circuits, children after the first false result are
not evaluated and therefore cannot produce an evaluation failure during that
operation.

An empty `all` condition is invalid authored data; unconditional behavior is
represented by absence of a condition.

### 10.2 `any`

Evaluate children in authored order. Stop immediately at the first true child
and return true. If every child is false, return false.

Children after the first true result are not evaluated.

An empty `any` condition is invalid authored data.

### 10.3 `not`

Evaluate the single child exactly once and return its Boolean negation.

### 10.4 `variable_is_set` / `variable_is_unset`

The referenced variable MUST be declared.

- `variable_is_set` is true exactly when the variable currently has a value.
- `variable_is_unset` is true exactly when the declared variable currently has
  no value.

An undeclared reference is an execution failure, not false.

### 10.5 `variable_comparison`

The referenced variable MUST be declared and the literal operand type MUST
exactly equal the variable's declared type. There is no Integer/Number
coercion.

If the variable is currently unset, **every scalar comparison returns false**,
including `not_equal`. Authors must use `variable_is_unset` when unset itself is
the intended predicate.

For a set variable:

- Boolean: `equal`, `not_equal` only;
- String: `equal`, `not_equal` only, using exact text equality;
- Integer: equality and ordering by exact integer value;
- Number: equality and ordering by the finite binary64 numerical rules in
  Section 4.3.

Using an unsupported operator/type combination is invalid authored logic and
MUST fail rather than being coerced to false.

## 11. Effect semantics

Effects mutate only story state in Core Revision 1. They do not navigate and do
not invoke arbitrary host code.

An effect list is executed sequentially in authored order. Each later effect
observes the state produced by all earlier effects in the same list.

### 11.1 `set_variable`

The target variable MUST be declared. The new value type MUST exactly equal the
declared variable type. On success, the variable becomes set to that value.

### 11.2 `unset_variable`

The target variable MUST be declared. On success, the variable becomes unset.
Unsetting an already-unset declared variable is valid and remains unset.

### 11.3 `increment_variable` / `decrement_variable`

The target variable MUST:

- be declared;
- be Integer or Number;
- currently be set.

The amount MUST be non-negative and have the exact same scalar type as the
target variable.

For Integer variables, calculate exact mathematical addition/subtraction and
then require the result to remain inside
`-9007199254740991..9007199254740991`. A runtime MUST NOT wrap, clamp, saturate,
or silently convert an out-of-range result.

For Number variables, addition/subtraction uses IEEE-754 binary64 arithmetic.
Each resulting story value MUST be finite. Overflow to infinity or any other
non-finite result is an execution failure. A runtime MUST NOT clamp the result.

## 12. Transition semantics

Transition resolution does not itself mutate story state.

### 12.1 Direct event transition

Resolve to the referenced destination event identity. The destination is then
entered according to Section 7. A missing destination is a configuration
failure.

Direct transitions consume no randomness.

### 12.2 Terminal transition

Resolve to termination. A terminal transition has no destination event and
consumes no randomness.

### 12.3 Conditional transition

Evaluate branches in authored order against the current story state.

- Select the first branch whose condition evaluates true.
- Stop evaluating later branches once one branch has matched.
- Resolve the selected branch's nested transition recursively.
- If no branch matches, resolve the mandatory fallback recursively.

A conditional transition therefore always selects either one authored branch
or its fallback when its authored logic is valid.

Conditional selection consumes no randomness except randomness encountered in
a nested weighted transition that is actually reached.

### 12.4 Weighted transition

Let the positive authored option weights be `w[0]..w[n-1]` in authored order,
and let `T` be their exact integer sum. Every weight MUST be positive and no
individual weight or total `T` may exceed `9007199254740991`, preserving the
portable exact-integer domain used by Core Revision 1.

Resolving one weighted transition:

1. consumes exactly one deterministic random integer `r` satisfying
   `0 <= r < T`;
2. maps options to contiguous half-open intervals in authored order:
   - option 0 owns `[0, w[0])`;
   - option 1 owns `[w[0], w[0] + w[1])`;
   - and so on;
3. selects the unique option whose interval contains `r`;
4. recursively resolves that option's transition.

A nested weighted transition consumes another random integer only if execution
actually reaches that nested transition.

The companion [Deterministic Randomness — `story_engine.lcg32` Version 1](DETERMINISTIC_RANDOM_V1.md) specification defines how the deterministic random
stream produces `r`. Core Revision 1 freezes the draw count and interval
selection; the random profile freezes the exact bounded sample sequence.

## 13. Automatic traversal guard

A runtime MUST protect one synchronous host operation from an unbounded
automatic-event cycle.

The exact automatic-transition budget may be runtime configuration rather than
a universal hard-coded constant. For deterministic conformance runs, the budget
is part of the execution configuration and MUST be held equal across runtimes.

If the budget is exceeded before a pause or termination is reached, execution
fails and the entire host operation rolls back, including state, history, and
random-stream consumption.

A runtime MUST NOT treat guard exhaustion as successful termination.

## 14. Structural runtime history

Core Revision 1 defines an ordered structural history with three semantic step
kinds:

- `event_entered(eventId)`;
- `choice_selected(eventId, choiceId)`;
- `event_continued(eventId)`.

History contains stable authored identities only. It has no implicit timestamp,
wall-clock dependency, presentation text, state copy, or host object.

Successful ordering follows execution order:

- starting a run records the entry event and any automatically entered events;
- selecting a choice records `choice_selected` before any destination
  `event_entered` steps;
- continuing records `event_continued` before any destination `event_entered`
  steps;
- automatic transitions add event-entry steps but no synthetic choice/continue
  step;
- terminal transition resolution adds no separate terminal-history step.

Repeated event entries are recorded repeatedly. Derived visited-event sets and
occurrence counts are computed from committed `event_entered` steps.

History steps produced inside a failed transaction MUST NOT become committed.

## 15. Transactionality and rollback

`start`, accepted choice selection, and accepted explicit continue are atomic
runtime operations.

The transaction includes at least:

- scalar story state;
- lifecycle status;
- current event;
- structural history additions;
- deterministic random-stream state;
- automatic-transition progress for that operation.

If any condition, effect, transition, destination entry, or automatic traversal
step fails before the operation completes, the runtime MUST restore the exact
committed state that existed before the operation began.

In particular:

- failed `start` leaves the run `not_started` and does not consume randomness;
- failed choice selection leaves the prior choice pause intact;
- failed continuation leaves the prior continue pause intact;
- choice/entry effects from a failed operation are not visible;
- history additions from a failed operation are not visible;
- random draws from a failed operation are not committed.

Read-only availability inspection does not create a transaction because it does
not mutate committed runtime state.

## 16. Runtime failure categories

Conforming implementations do not need identical exception class names or
message wording. They MUST, however, preserve these semantic distinctions and
must never silently repair malformed executable logic.

### 16.1 Configuration failure

Authored executable structure is missing, contradictory, or references a
required authored entity that cannot be resolved. Examples include:

- duplicate event identities;
- duplicate choice identities where global choice identity is required;
- missing entry event configuration;
- entry identity that does not resolve to an event;
- entered event with zero or multiple flow modes;
- selected choice with no transition;
- direct transition to a missing event.

### 16.2 Operation failure

The host submits an input that is invalid for the current committed lifecycle or
current event. Examples include:

- starting an already-started run;
- choosing before start, during a continue pause, or after termination;
- continuing before start, during a choice pause, or after termination;
- submitting a choice not owned by the current event;
- submitting a currently unavailable choice;
- supplying an incompatible explicit initial state.

### 16.3 Execution failure

Runtime evaluation of addressable authored logic cannot produce a valid
semantic result. Examples include:

- entering an event whose availability condition is false;
- condition/effect reference to an undeclared variable;
- condition/effect scalar type mismatch;
- invalid ordering comparison;
- increment/decrement of an unset or non-numeric variable;
- integer result outside the portable range;
- Number result becoming non-finite;
- deterministic random source returning a value outside the required sampled
  range;
- automatic traversal budget exhaustion.

All three failure categories are non-successful operations and therefore obey
the rollback rules in Section 15.

Malformed/unsupported Story Format decoding is a format-reader failure and is
outside these runtime categories until a logical project has been decoded.

## 17. Termination semantics

Termination is explicit. It occurs only when a terminal transition is
successfully resolved.

The runtime MUST NOT infer termination from:

- an event with no valid flow mode;
- an interactive event with zero currently available choices;
- a missing destination;
- a false event-availability condition;
- an unknown transition kind;
- automatic guard exhaustion.

On successful termination:

- lifecycle becomes `terminated`;
- all effects that occurred earlier in the successful transaction remain
  committed;
- history accumulated by the successful transaction remains committed;
- the current event remains the last successfully entered event from which the
  terminal transition was ultimately resolved;
- no synthetic terminal event is entered;
- the available-choice set is empty;
- further choice/continue inputs are operation failures.

## 18. Validation versus execution

Static validation SHOULD detect invalid authored logic before production
execution whenever possible. Validation and runtime semantics remain separate:

- validation does not execute the story;
- the runtime does not assume validation has already occurred;
- a runtime MUST still reject invalid logic deterministically if it is reached;
- validation diagnostics do not redefine the execution order in this document.

## 19. Deterministic external facts

Core Revision 1 has no implicit access to wall-clock time, operating-system
locale, network state, player position, process globals, or other mutable host
facts.

Any future host/world fact that influences narrative logic must enter through an
explicit, versioned host/context contract. Hidden reads are incompatible with
deterministic cross-runtime conformance.

## 20. Stage 8B invariants

The following rules are frozen as the Core Revision 1 behavioral baseline for
subsequent Stage 8 work:

1. Story Format data and runtime behavior are separate versioned concerns.
2. Event availability is evaluated before entry effects.
3. Entry effects precede the event pause or automatic-transition resolution.
4. Choice effects precede choice-transition resolution.
5. Continuation transitions observe state after event entry effects.
6. Conditions and effects are deterministic and have no hidden host side
   effects.
7. Integer and Number never coerce implicitly.
8. Unset is not a scalar value; scalar comparisons against unset are false,
   including `not_equal`.
9. Boolean composition and conditional transitions short-circuit in authored
   order.
10. Number ordering is ordinary finite binary64 numerical ordering; signed zero
    is not given a Dart-specific total-order distinction.
11. Weighted transitions consume one bounded integer draw per weighted node
    actually reached and map it to authored-order half-open intervals.
12. Termination is explicit and never inferred from malformed/dead-end data.
13. `start`, choice selection, and continue are atomic across state, history,
    lifecycle, current event, and random-stream state.
14. Configuration, host-operation, and runtime-execution failures remain
    semantically distinct even when host languages expose different native
    exception types.
15. Core execution never reads wall-clock time or hidden mutable host globals.

The deterministic-random profile MUST preserve the execution order and random-
draw consumption rules defined here. Stage 8D may externalize these semantics
as language-neutral conformance vectors, but it MUST NOT reinterpret either
contract.
