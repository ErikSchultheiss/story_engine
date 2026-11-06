# Runtime finalization conformance profile v1

The `runtime-finalization-v1` profile adds ten data-only behavioral cases to
`conformance/fixtures/runtime-finalization-v1/`. It requires Core Semantics
Revision 1, Story Format v1 and `story_engine.lcg32` v1, together with the existing
core/aggregate snapshot, session and host-action contracts. It changes no authored
format, runtime semantics, RNG algorithm or snapshot versions.

The six `runtime-core-v1-foundation` cases and their expectations remain frozen.
Passing this new profile is a separate claim. The independent C# spike currently
covers only the six foundation cases; it does not implement this profile.

## Running and reporting

From the package root, with Dart dependencies available:

```sh
dart run tool/conformance/run_conformance.dart --output=build/conformance-foundation.json
dart run tool/conformance/run_conformance.dart --fixture-set=conformance/fixtures/runtime-finalization-v1/fixture-set.json --output=build/conformance-hardening.json
```

Without `--output`, stdout contains the report JSON. Both use the report shape
and failure records from [Conformance fixtures v1](CONFORMANCE_FIXTURES_V1.md).
Exit status is 0 only when every case passes, 1 for any failed/skipped case, and
2 for an invalid manifest, unusable output destination or process-level harness
failure. Unsupported declared profiles/contracts are skipped, never passed.
Malformed, empty or duplicate-ID manifests are rejected. Input exceptions in the
foundation profile are `inputFailure`; unexpected harness failures never become
successful results. Golden comparisons preserve list order, scalar types, unset
values and all expected fields; reports identify the first differing JSON path
for each comparison.

The runner is package tooling using the public facade. It is not a new runtime
API, a capability negotiation service, or a certification of arbitrary content.
The runnable tools, corpora and portable tests ship in both the public source
mirror and the Pub package.

## Command verification

The ordinary test suite executes the same `runConformanceCli` command function
used by the executable, with captured output/error sinks and real fixture/report
files. It checks argument handling, report contents, file output, failure/skip
statuses and invalid destinations. The executable assigns the returned status
to the process exit code. This function is tooling, not part of the runtime
package's public facade.

These tests do not start a new Dart VM per command assertion: repeated source
compilation and process/stream startup can exceed a test deadline independently
of fixture behavior, particularly during a full concurrent suite. Actual process
exit/output behavior should additionally be checked with the standalone runner
commands above. Keep startup timing out of the semantic conformance contract.

## Case coverage

| Case | Pinned behavior |
| --- | --- |
| `effect-rng-rollback` | Failed weighted destination rolls back effects, history and RNG; a subsequent successful draw selects the expected branch. |
| `malformed-branch` | A malformed scalar comparison in a selected conditional branch rejects the whole input. |
| `short-circuit` | A decisive availability operand skips the malformed later operand. |
| `restore-random` | Core JSON round trip preserves the pause, complete checkpoint, future weighted result and continuation history. |
| `automatic-guard` | A bounded automatic loop rejects activation without publishing entry effects or history. |
| `malformed-entry` | Malformed event availability rejects activation; a short-circuited availability condition remains executable. |
| `shared-propagation` | Shared commits reach unfinished and host-suspended siblings; terminated sessions retain historical state; aggregate restoration emits no replay. |
| `host-suspension` | Stable request identity survives restore; core input is blocked; wrong/stale results reject; completion resumes the previous pause once. |
| `failed-activation` | Rejected session activation preserves shared state, session allocation and orchestration RNG. |
| `late-invalid-restore` | Unknown originating entry identity and malformed RNG data in the second retained session reject aggregate JSON load; the valid save still resumes. |

The project intentionally contains semantically malformed conditions and an
automatic loop to exercise runtime rejection. Do not treat this fixture project
as an example of validated publishable content.

## Input document

Each case has `input_trace.json` and `expected_trace.json`, alongside a shared,
self-contained `project.story` bundle. The manifest retains the existing fixture
set shape and selects `runtime-finalization-v1`.

The input identity is `open_story.conformance_hardening_input_trace` / 1. Required
fields are `runtime` (`core` or `narrative`), `random` (algorithm ID/version and
seed), `maxAutomaticTransitions`, and ordered nonempty `inputs`. Narrative inputs
also supply ordered `entryPoints` with `id` and `eventId`.

Core input kinds are `start`, `startAt` (`eventId`), `choose` (`choiceId`),
`continue`, and `restore`. Narrative kinds are `startSession` (`entryPointId`),
`choose` (`sessionIndex`, `choiceId`), `continue` (`sessionIndex`), `requestHost`
(`sessionIndex`), `completeHost` (`sessionIndex`, `requestId`, `value`), `restore`,
and `restoreInvalid` (`path`, `value`).

`requestHost` is a harness instruction for a boolean result with namespace
`org.example.conformance`, action `approve`, and arguments `{"subject":"portable"}`.
It is not an authored host-action node. `restore` captures the complete current
checkpoint, serializes to JSON, decodes/validates it against the same immutable
project and entries, then directly restores a new runtime. No authored logic or
past observations may replay. For `restoreInvalid`, mutate the existing field
specified by the string/index `path` in the canonical aggregate JSON document
before decode. A rejected candidate must leave the current runtime untouched.
The aggregate JSON shape follows [Narrative runtime persistence](NARRATIVE_RUNTIME_PERSISTENCE_V1.md).

## Observation document

The expectation identity is `open_story.conformance_hardening_expected_trace` / 1.
Its ordered `observations` have:

- `afterInputIndex`, `outcome` (`committed` or `rejected`), nullable `error`, and
  `checkpointUnchanged`;
- for core: lifecycle `status`, `currentEventId`, ordered `availableChoiceIds`,
  nullable tagged explicit `state`, and tagged complete `history`;
- for narrative: tagged `persistentState`, its revision, `nextSessionIndex`,
  ordered `activeSessionIndexes`, and ordered retained `sessions`;
- each retained session: index, originating entry identity, composite status,
  current event, available choices, tagged state/history, next request ordinal
  and nullable pending request (ID, namespace, action and arguments);
- a successful narrative restore additionally records `observationsReplayed: 0`.

State/history use the foundation profile's tagged representations. Termination
retains the most recently entered event ID. Pending sessions expose no choices.
A terminated retained session is absent from active membership but remains in
the checkpoint with its historical state.

`checkpointUnchanged` compares the entire canonical durable checkpoint, including
RNG state, guard, history, shared values, allocation and host protocol data. For
aggregate comparisons only `nextObservationSequence` is excluded: subscribed
error observations legitimately advance that telemetry cursor on rejection.
Successful JSON restore itself preserves even that cursor. Observers are live
host configuration; a restore attaches a counting observer to detect replay.

Portable rejection categories are `executionRejected`, `operationRejected`,
`conditionRejected`, `hostProtocolRejected`, `snapshotCompatibility`, and
`snapshotFormat`. Category mapping follows the public exception boundary. For
example, a wrong host result supplied through a narrative session is wrapped as
an operation rejection. Error prose and Dart stack traces are not goldens.
An unrecognized exception or input is a harness failure, not an expected rejection.

## Independent golden derivation

Expectations were authored from the frozen contracts, not captured from runner
output. The nested successful transition uses weights 1 and 4. LCG32 `nextInt`
combines two 32-bit draws into its exact 53-bit candidate. For seed 0, the first
two candidates are 4208240217827634 and 3649183176807220, sampling offsets 4
and 0 for range 5. Thus the first core result is `done_b`; accidentally retaining
a failed draw would instead select `done_a`.

Explicit aggregate activation allocates session seeds 1196435762 and 2868466484.
Their first local range-5 samples are 0 and 2, selecting `done_a` and `done_b`.
Choice effects add 1 before resolution; destination entry effects add 10 or 20.
Shared-state revision increases once per net-changing committed input. These
facts determine the literal state/history expectations and future branch checks.

Expected files are behavioral goldens. Do not regenerate them to hide a runtime
mismatch. New semantics require a separately reviewed contract/profile change.
This profile defines no performance threshold, filesystem/content loading
semantics, external host side effects, or additional extension-node behavior.
