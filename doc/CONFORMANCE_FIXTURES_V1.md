# Runtime Conformance Fixtures — Foundation Version 1

Status: normative fixture and report contract for the Runtime Semantics Core
Revision 1 conformance foundation.

This document defines the language-neutral files used to prove that independent
runtime implementations agree on observable narrative behavior. It complements,
but does not replace:

- Story Format v1 for authored project data;
- Runtime Semantics Core Revision 1 for execution behavior; and
- `story_engine.lcg32` version 1 for exact seeded randomness.

A shared JSON schema is not sufficient for runtime interoperability. A
conforming implementation must execute the same inputs and produce the same
observable outputs.

## 1. Foundation profile

The first fixture profile is identified as:

```text
runtime-core-v1
```

The Stage 8D foundation profile requires:

```text
Story Format:               story_engine.story_format / 1
Runtime Semantics:          Core Revision 1
Deterministic random:       story_engine.lcg32 / 1
Fixture contract version:   1
```

Future profiles may add capabilities without silently changing this profile.

## 2. Fixture-set layout

A fixture set is ordinary files and directories:

```text
conformance/
  fixtures/
    runtime-core-v1/
      fixture-set.json
      lantern-mystery/
        project.story/
          project.json
          events/
            ...
        cases/
          canonical-good/
            initial_state.json
            input_trace.json
            expected_trace.json
            expected_final_state.json
            expected_history.json
          ...
```

`project.story/` is a normal Story Format v1 logical bundle represented as a
directory. The conformance files around it are not Story Format files and do
not alter Story Format v1.

A case may share one project bundle with other cases. All fixture paths use `/`
as the logical separator when stored inside JSON.

## 3. Fixture-set manifest

`fixture-set.json` has format identity:

```json
{
  "formatId": "open_story.conformance_fixture_set",
  "formatVersion": 1
}
```

The required fields are:

- `fixtureSetId` — stable identity of the committed fixture set;
- `profile` — conformance profile required by every listed case;
- `contracts` — exact Story Format, Runtime Semantics, and deterministic-random
  versions required by the set;
- `cases` — authored-order case descriptors.

Each case descriptor contains:

- `caseId` — stable case identity within the fixture set;
- `path` — directory containing the case files;
- `projectPath` — directory containing the Story Format project bundle;
- `description` — short human-readable purpose;
- `features` — non-semantic coverage labels useful to implementers.

Case order is informative. Implementations may execute cases in any order; one
case MUST NOT depend on runtime state left by another case.

## 4. Initial state

`initial_state.json` has format identity:

```text
open_story.conformance_state / 1
```

Two modes are defined.

### 4.1 Project defaults

```json
{
  "formatId": "open_story.conformance_state",
  "formatVersion": 1,
  "mode": "projectDefaults"
}
```

The runtime starts from the initial values declared by the Story Format
project. Declared variables without initial values are unset.

### 4.2 Explicit state

```json
{
  "formatId": "open_story.conformance_state",
  "formatVersion": 1,
  "mode": "explicit",
  "values": [
    {
      "variableId": "var_score",
      "state": "set",
      "value": {"type": "integer", "value": 4}
    },
    {
      "variableId": "var_alarm",
      "state": "unset"
    }
  ]
}
```

For `explicit` mode:

- every project state-schema variable MUST appear exactly once;
- entries MUST follow the authored variable order from the project schema;
- `state: set` MUST carry one Story Format scalar value object with exactly the
  declared type;
- `state: unset` MUST NOT carry `value`;
- no undeclared variable may appear.

This explicit representation avoids treating JSON `null` as a Story scalar.
Unset remains a distinct state condition.

## 5. Input trace

`input_trace.json` has format identity:

```text
open_story.conformance_input_trace / 1
```

It contains an explicit deterministic-random configuration and an ordered
`inputs` array.

The foundation profile defines three input kinds:

```json
{"kind": "start"}
{"kind": "choose", "choiceId": "choice_id"}
{"kind": "continue"}
```

Rules:

1. `start` MUST be the first input and MUST occur exactly once.
2. `start` uses `initial_state.json` for its initial story state.
3. `choose` supplies one stable authored choice ID.
4. `continue` supplies no additional payload.
5. Inputs are applied sequentially and synchronously according to Runtime
   Semantics Core Revision 1.
6. A foundation fixture describes successful execution. Invalid-operation and
   failure vectors may be added by later fixture profiles without changing the
   successful-case meaning defined here.

The `random` object identifies the exact algorithm/version and seed. A runtime
MUST reject the case as unsupported rather than substitute a different random
algorithm while claiming conformance.

## 6. Expected trace

`expected_trace.json` has format identity:

```text
open_story.conformance_expected_trace / 1
```

It contains one `observations` entry after every successfully applied input.
Each observation contains:

- `afterInputIndex` — zero-based index in `input_trace.json.inputs`;
- `status` — `awaitingChoice`, `awaitingContinue`, or `terminated`;
- `currentEventId` — current authored event after the input commits;
- `availableChoiceIds` — available choice IDs in authored order, or an empty
  array when the runtime is not awaiting a choice.

Automatic event chains fully resolve before the observation is captured. This
makes an observation a host-visible committed boundary, not an internal
micro-step trace.

The Stage 8D foundation does not place timestamps, wall-clock duration,
implementation type names, stack traces, memory addresses, or platform objects
in expected traces.

## 7. Expected final state

`expected_final_state.json` uses the same
`open_story.conformance_state / 1` representation as an explicit initial state.
Its mode MUST be `explicit`, and every state-schema variable appears exactly
once in authored order.

A conforming runtime compares Story scalar values by the semantics of Runtime
Semantics Core Revision 1. JSON parser host types do not redefine Story Integer
or Story Number semantics.

## 8. Expected history

`expected_history.json` has format identity:

```text
open_story.conformance_history / 1
```

The `steps` array is the exact ordered committed structural history. Foundation
step kinds are:

```json
{"kind": "eventEntered", "eventId": "event_id"}
{"kind": "choiceSelected", "eventId": "event_id", "choiceId": "choice_id"}
{"kind": "eventContinued", "eventId": "event_id"}
```

Repeated event entries are repeated in the array. Automatic events are present
as `eventEntered` steps even though no host input directly selected them.
Termination does not synthesize an extra history step.

## 9. Pass/fail rule

A case passes only if all of the following match exactly:

1. the project bundle is supported and can be executed under the declared
   profile;
2. every input commits successfully;
3. every post-input expected observation matches;
4. final story state, including set/unset status and scalar types, matches;
5. ordered structural history matches;
6. deterministic weighted choices therefore produce the expected route.

An implementation MUST NOT normalize away a mismatch and still report `pass`.
For example, reordering available choices, treating unset as false, or choosing
a different seeded weighted branch is a conformance failure.

## 10. Conformance report format

A machine-readable report has identity:

```text
open_story.conformance_report / 1
```

Required top-level fields are:

```json
{
  "formatId": "open_story.conformance_report",
  "formatVersion": 1,
  "profile": "runtime-core-v1",
  "fixtureSetId": "runtime-core-v1-foundation",
  "implementation": {},
  "summary": {},
  "results": []
}
```

### 10.1 Implementation object

Required fields:

- `name` — implementation/product name;
- `version` — implementation version string;
- `language` — implementation language/runtime ecosystem;
- `runtimeSemantics.coreRevision` — implemented core revision;
- `randomProfiles` — algorithm ID/version pairs supported for this run.

These fields describe the implementation. They do not alter fixture semantics.

### 10.2 Summary object

Required non-negative integer fields:

- `total`;
- `passed`;
- `failed`;
- `skipped`.

They MUST satisfy:

```text
total = passed + failed + skipped
```

A skipped case is not a pass.

### 10.3 Result object

Every fixture case appears exactly once in `results`, using the case IDs from
`fixture-set.json`.

A result contains:

```json
{
  "caseId": "lantern-mystery/canonical-good",
  "status": "pass",
  "failures": []
}
```

`status` is one of:

```text
pass
fail
skipped
```

For `pass`, `failures` MUST be empty.

For `fail`, `failures` contains one or more structured records:

```json
{
  "kind": "traceMismatch",
  "path": "$.observations[3].availableChoiceIds",
  "expected": ["choice_a", "choice_b"],
  "actual": ["choice_b", "choice_a"],
  "message": "Available choices differ from the fixture."
}
```

Foundation failure `kind` values are:

```text
unsupportedContract
projectLoadFailure
inputFailure
traceMismatch
finalStateMismatch
historyMismatch
runnerFailure
```

`path`, `expected`, and `actual` are optional when no meaningful JSON-like
value exists. `message` is required.

For `skipped`, `failures` contains at least one `unsupportedContract` record
explaining which declared profile requirement is unavailable.

A runner crash or unexpected harness exception MUST NOT be reported as a pass;
it is a `runnerFailure` or a process-level failure that prevents a valid report.

## 11. Foundation fixture corpus

The initial `runtime-core-v1-foundation` fixture set uses one canonical Story
Format v1 project and six independent runs:

- canonical good route;
- immediate neutral route preserving unset state;
- deterministic weighted safe route;
- deterministic weighted collapse route;
- cold route exercising continuation, Number effects, repeated entry, and
  automatic weighted flow;
- explicit low-trust initial state exercising conditional fallback behavior.

The project bundle is intentionally duplicated into the public conformance
corpus and regression-tested against the existing canonical Story Format v1
golden. This prevents the conformance project from drifting silently while
keeping the fixture set self-contained for non-Dart implementers.

## 12. What version 1 does not define

The Stage 8D foundation does not yet define:

- custom extension action/condition conformance;
- asynchronous host-action suspension;
- open-world entry resolution or narrative sessions;
- modular/lazy project loading;
- runtime capability negotiation is now covered separately by the Stage 8M
  `conformance/capabilities/profile-v1/` reference vectors;
- portable runtime snapshot interchange;
- performance thresholds;
- invalid-project or invalid-operation fixture profiles.

Those concerns belong to later ecosystem stages. They must not be inferred from
absence in the foundation fixtures.

## 13. Compatibility rule

Committed foundation vectors are golden behavioral contracts. Corrections that
would change an expected successful result require an explicit compatibility
review. A runtime implementation must not rewrite expected outputs to make its
own divergent behavior pass.

New fixtures may be appended to the fixture set when they exercise behavior
already defined by the same contracts. A semantic contract change requires an
appropriate new semantics revision, random profile, fixture profile, or format
version rather than silently redefining existing vectors.
