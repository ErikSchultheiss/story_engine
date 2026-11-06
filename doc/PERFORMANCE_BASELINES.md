# Performance baselines

This document establishes reproducible **workloads and measurement procedure** for
`story_engine`. It deliberately does not make wall-clock milliseconds part of
the package's correctness contract: Dart VM/JIT warm-up, CPU model, power mode,
OS load, and CI virtualization can move absolute timings substantially without
a package regression.

The normal test suite therefore enforces deterministic behavior, bounded
forward progress, canonical persistence, and exact structural workload sizes.
The benchmark runner records timings for comparison on the same machine/SDK.

## Standard structural workloads

The deterministic structured generator defines three publication baselines:

| Profile | Events | Choices | Variables |
| --- | ---: | ---: | ---: |
| small | 100 | 389 | 25 |
| medium | 500 | 1,949 | 100 |
| large | 1,000 | 4,876 | 250 |

These counts are regression-tested. Changing them is an intentional benchmark
contract change, not an incidental generator edit.

The large profile also produces exactly 1,001 Story Format files: one
`project.json` plus one stable event file per event.

## What the benchmark measures

`benchmark/performance_baseline.dart` measures median elapsed
microseconds for:

1. `StoryValidator.validate(project)`;
2. Story Format `encodeProject`;
3. Story Format `decodeProject`;
4. deterministic primary-route runtime traversal to termination;
5. runtime-snapshot JSON encoding;
6. runtime-snapshot JSON decoding/compatibility validation; and
7. `StoryEngine.restore` from the decoded snapshot.

It also records authored event/choice/variable counts, logical bundle file
count and UTF-8 byte size, and completed route event/choice counts.

The synthetic fixture itself is built outside the measured operations because
fixture generation is test infrastructure, not package consumer work.

## Run the standard baseline

From `story_engine/`:

```text
dart run benchmark/performance_baseline.dart
```

The default uses three samples per standard workload and reports the median.
Increase sampling when making a performance-sensitive change:

```text
dart run benchmark/performance_baseline.dart --samples=7
```

For machine-readable output:

```text
dart run benchmark/performance_baseline.dart --samples=7 --json
```

## Opt-in stress workload

A larger randomized fixture is available without making every `dart test` run
pay its cost:

```text
dart run benchmark/performance_baseline.dart --stress-events=5000
```

Stress measurement defaults to one sample. It can be increased explicitly:

```text
dart run benchmark/performance_baseline.dart \
  --stress-events=5000 \
  --stress-samples=3 \
  --json
```

The stress project is deterministic for a fixed event count and benchmark
version. Its variable count scales with the requested event count, bounded to
80..1,000 variables.

## How to compare results

For a meaningful before/after comparison:

- use the same machine;
- use the same Dart SDK and run mode;
- keep power/thermal conditions reasonably similar;
- use several samples, not one timing;
- compare medians rather than the fastest sample;
- compare the emitted structural/byte metrics too, so faster timings are not
  accidentally explained by a smaller workload.

A sustained approximately 2x regression in a standard-profile median should be
investigated, but it is deliberately **not** an automatic test failure. If a
future release has stable dedicated benchmark infrastructure, hardware-specific
budgets can be layered on top without contaminating portable correctness tests.

## First recorded developer-workstation baseline

The first recorded developer-workstation reading was captured on **2026-08-14** using
the default three-sample median run. The benchmark output did not record the
exact SDK/CPU metadata, so these numbers are a historical same-workstation
reference rather than portable targets. Future comparison runs should capture
SDK and machine details alongside the JSON output.

| Profile | Validate | Format encode | Format decode | Runtime traverse | Snapshot encode | Snapshot decode | Snapshot restore | Bundle bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| small | 14,843 us | 7,918 us | 12,462 us | 1,114 us | 746 us | 1,008 us | 484 us | 410,778 |
| medium | 147,612 us | 33,434 us | 39,860 us | 8,083 us | 1,413 us | 4,320 us | 1,861 us | 2,068,979 |
| large | 799,894 us | 84,599 us | 97,614 us | 26,280 us | 2,301 us | 6,737 us | 3,518 us | 5,276,149 |

Completed-route observations were 100 events / 98 choices for small, 496 /
484 for medium, and 991 / 967 for large. Nothing in this reference becomes a
portable pass/fail threshold.

## Correctness/scale gates that remain mandatory

`dart test` still fails if the scale regression suite detects semantic regressions, including:

- the standard workload sizes changing unexpectedly;
- 1,000-event validation producing errors;
- Story Format losing canonical encode/decode parity;
- the large project failing to terminate through the primary route;
- snapshot JSON/restore losing committed status/state/event/history;
- seeded randomized projects failing the complete public workflow; or
- representable malformed-project diagnostics disappearing at 500-event scale.

Performance observations never replace these deterministic correctness gates.

## Stage 9C6 explainability overhead

Narrative explainability is opt-in and must not penalize ordinary execution with
hidden duplicate evaluation. Stage 9C6 therefore provides a paired benchmark:

```text
dart run benchmark/stage9c6_explainability_overhead.dart --samples=11 --sessions=200
```

For machine-readable output:

```text
dart run benchmark/stage9c6_explainability_overhead.dart \
  --samples=11 \
  --sessions=200 \
  --json
```

The runner warms both paths, then measures the same deterministic multi-session
workload once with no debug adapter and once with a collecting
`StoryNarrativeDebugAdapter`. It reports both median timings and the
`diagnosticsOn / diagnosticsOff` ratio. The final aggregate snapshots must be
identical or the benchmark fails before reporting a valid comparison.

As with the main performance baseline, Stage 9C6 intentionally defines no hard
portable wall-clock threshold. Compare results on the same machine and Dart SDK.
A surprising increase should be investigated, but stable performance budgets
belong to Stage 9D6 after broader profiling establishes representative scaling
behavior.


## Stage 9D1 reproducible benchmark harness

Stage 9D1 adds `benchmark/stage9d1_benchmark_harness.dart` as the reusable
profiling foundation for the Stage 9D scaling work. It complements the older
Stage 6G subsystem baseline and the focused Stage 9C6 explainability comparison;
it does not replace either historical measurement.

The default run measures two deterministic workloads:

| Case | Default workload | Purpose |
| --- | --- | --- |
| Core runtime primary route | medium structured synthetic project | Keep a representative single-engine traversal in every Stage 9D profile run. |
| Narrative active sessions | 10 sessions × 24 continuations | Exercise simultaneous retained sessions and controlled history without yet mixing in shared-state propagation. |

Run it from `story_engine/`:

```text
dart run benchmark/stage9d1_benchmark_harness.dart
```

For a higher-sample same-machine baseline:

```text
dart run benchmark/stage9d1_benchmark_harness.dart \
  --samples=15 \
  --warmups=5
```

The workload dimensions are configurable without changing the harness:

```text
dart run benchmark/stage9d1_benchmark_harness.dart \
  --core-profile=large \
  --narrative-sessions=50 \
  --narrative-continuations=250
```

For machine-readable output:

```text
dart run benchmark/stage9d1_benchmark_harness.dart --json
```

### Stage 9D1 measurement procedure

The harness deliberately makes the measurement boundary explicit:

- deterministic fixture preparation occurs **outside the timed region**;
- warm-up iterations occur before measured samples;
- multiple cases use **rotating case order** between samples so one case does
  not systematically pay the same process-order/JIT/cache effects;
- all raw elapsed-microsecond samples are retained;
- median, p25, p75, minimum, and maximum are reported rather than hiding
  dispersion behind one number;
- Dart/OS/executable/logical-processor metadata accompanies JSON output; and
- every sample must reproduce the same **semantic fingerprint** and structural
  metrics or the benchmark aborts instead of reporting incomparable timings.

Fingerprint generation and structural reporting also happen after the stopwatch
has stopped. A performance-sensitive change must therefore make the same story
state/history/session result before its timing is considered meaningful.

### Allocation measurement boundary

The stable Dart command-line APIs used by this repository do not expose
reliable **per-workload allocation counts**. `ProcessInfo.currentRss` and
`ProcessInfo.maxRss` are process-resident-memory observations, not allocated-byte
counters: they mix heap capacity, generated/runtime code, allocator behavior,
and earlier benchmark cases.

Stage 9D1 therefore reports the per-workload allocation metric as
`unavailable_portably` rather than mislabeling RSS as allocations. This is an
explicit measurement limitation. A VM-service-backed allocation collector may
be added later if it can be invoked and interpreted reproducibly; until then,
wall time plus deterministic structural metrics are the portable baseline.

### Relationship to later Stage 9D substages

9D1 establishes the measurement method only. It does **not** draw scaling
conclusions or justify an optimization. Stage 9D2 owns the 1/10/50-session and
short-to-very-long-history matrix. Stage 9D3 owns shared-persistent-state
propagation measurements. Stage 9D5 may optimize only demonstrated bottlenecks,
and Stage 9D6 owns relative/growth-shape regression budgets.

## Stage 9D2 session/history retention matrix

Stage 9D2 uses the Stage 9D1 harness to measure the approved **1 / 10 / 50**
session matrix across **short / medium / long / very-long** retained histories,
for both **active and completed** retained sessions.

The fixed retained continuation depths are:

| History profile | Continuations per session |
| --- | ---: |
| short | 8 |
| medium | 32 |
| long | 128 |
| very-long (`very_long` in machine IDs) | 512 |

For every one of the 24 semantic matrix points, three operations are timed
separately:

| Phase | Timed operation | Why it is separate |
| --- | --- | --- |
| execute/retain | construct the runtime, start sessions, and advance their histories | Measures normal execution/history-growth cost. |
| snapshot capture | `StoryNarrativeRuntime.createSnapshot()` on an already-prepared runtime | Isolates aggregate checkpoint construction from story execution. |
| snapshot encoding | deterministic JSON encoding of an already-captured aggregate snapshot | Isolates serialization cost from checkpoint construction. |

Completed scenarios perform one additional terminal continuation per session.
Those sessions leave `activeSessions` but remain retained in runtime history and
aggregate snapshots. The matrix therefore compares the current retention
semantics rather than deleting completed history before measurement.

The synthetic fixture uses empty shared persistent state and performs no state
mutation, so sibling-engine reconstruction is excluded from these measurements
and remains isolated for Stage 9D3.

Run the complete matrix from `story_engine/`:

```text
dart run benchmark/stage9d2_session_history_retention.dart
```

The default is 5 measured samples and 2 warm-ups per case. For a higher-sample
same-machine run:

```text
dart run benchmark/stage9d2_session_history_retention.dart \
  --samples=9 \
  --warmups=3
```

For all raw samples, IQR summaries, fingerprints, structural metrics, and
environment metadata:

```text
dart run benchmark/stage9d2_session_history_retention.dart --json
```

### What to compare

For each lifecycle/history/session-count point, compare all three medians and the
structural metrics together. In particular:

- execution growth shows the cost of building and advancing retained history;
- snapshot capture growth shows the cost of materializing aggregate checkpoint
  data from retained sessions;
- snapshot encoding growth shows serialization cost for that checkpoint; and
- `aggregateSnapshotUtf8Bytes` shows durable persistence-size growth.

Snapshot UTF-8 bytes are **not** a heap-memory or allocation measurement. The
Stage 9D1 allocation limitation remains explicit because stable Dart CLI APIs do
not expose reliable per-workload allocated-byte counts.

Stage 9D2 deliberately defines no portable timing threshold. The matrix is
evidence for the Stage 9D5 optimization decision. Stage 9D3 first isolates
shared-persistent-state propagation so history/session retention is not blamed
for costs caused by sibling-engine reconstruction.


## Stage 9D3 shared persistent-state propagation

Stage 9D3 isolates the cost that Stage 9D2 deliberately excluded: rebuilding
active sibling engines after one session commits changed shared persistent
state. It measures both the repeated unit operation and the complete serialized
authority commit.

The benchmark uses **1 / 10 / 50** active sessions. One session is the
source-only/no-sibling baseline; 10 and 50 sessions require 9 and 49 sibling
rebuilds. History depth is **8 / 64 / 256 continuations per session**. Authored
project size grows independently through three profiles:

| Project profile | Unreachable padding events/choices | Initialized state variables |
| --- | ---: | ---: |
| compact | 0 | 1 |
| medium | 512 | 64 |
| large | 2,048 | 256 |

The unreachable padding events are valid authored content but are not traversed
by the measured sessions. They therefore increase project lookup/restore
validation work without silently increasing retained history depth.

### Two complementary measurements

For each project/history pair, Stage 9D3 first times a **single sibling rebuild**:

1. capture one committed core runtime snapshot;
2. substitute the newly committed shared `StoryState`; and
3. call the normal validated `StoryEngine.restore(...)` path.

It then times the end-to-end shared persistent-state commit for every session
count. The source session continues into an event whose entry effect increments
one shared counter. `StoryNarrativeRuntime` must synchronously prepare every
sibling replacement before the new global state/revision becomes authoritative.

Run the complete profile from `story_engine/`:

```text
dart run benchmark/stage9d3_shared_state_propagation.dart
```

The default is 5 measured samples and 2 warm-ups per case. For machine-readable
raw samples, IQR summaries, fingerprints, metrics, and environment metadata:

```text
dart run benchmark/stage9d3_shared_state_propagation.dart --json
```

A higher-sample same-machine run can use:

```text
dart run benchmark/stage9d3_shared_state_propagation.dart \
  --samples=9 \
  --warmups=3
```

### What to compare

Compare the matching single-rebuild median with the 1-, 10-, and 50-session
commit medians for the same project/history profile. In particular:

- the 1-session commit exposes the state-mutation/source-operation baseline;
- the single rebuild shows how project size and history depth affect one
  correctness-first sibling replacement;
- 10/50-session growth shows whether total propagation approximately follows
  the 9/49 repeated rebuilds or has additional orchestration cost; and
- structural metrics verify the same authored size, retained history, session
  count, persistent revision, and shared-state result on every sample.

Stage 9D3 defines no portable timing threshold. Its result is a decision input
for Stage 9D5. If repeated rebuild/validation is materially costly, prefer
reusable immutable/prepared project indexes or another structural optimization.
**Do not optimize by weakening restore validation.**


### First recorded Stage 9D3 result

The first recorded Stage 9D3 developer-workstation run used Dart 3.13.1 on
Windows x64 with five measured samples and two warm-ups per case. These values
are same-machine evidence, not portable thresholds.

Single validated sibling-rebuild medians:

| Project | Short | Medium | Long |
| --- | ---: | ---: | ---: |
| compact | 48 us | 94 us | 414 us |
| medium | 688 us | 648 us | 764 us |
| large | 2,056 us | 2,126 us | 2,416 us |

End-to-end shared-state commit medians:

| Project/history | 1 session | 10 sessions | 50 sessions |
| --- | ---: | ---: | ---: |
| compact / short | 17 us | 166 us | 810 us |
| compact / medium | 23 us | 887 us | 4,444 us |
| compact / long | 40 us | 3,192 us | 17,215 us |
| medium / short | 40 us | 5,003 us | 26,310 us |
| medium / medium | 43 us | 5,319 us | 29,107 us |
| medium / long | 72 us | 6,943 us | 37,300 us |
| large / short | 109 us | 18,913 us | 107,947 us |
| large / medium | 110 us | 19,626 us | 113,040 us |
| large / long | 139 us | 21,061 us | 115,777 us |

The 10/50-session growth is explained closely by repeating the independently
measured validated sibling rebuild. In the large project, for example, the
50-session incremental cost after subtracting the source-only baseline is about
2.20–2.36 ms per sibling, compared with direct rebuild medians of
2.06–2.42 ms. This identifies repeated validated sibling restoration as the
dominant propagation term rather than general orchestration overhead.

The Stage 9D3 decision is therefore to carry shared-state propagation into 9D5
as a demonstrated structural-optimization candidate while preserving all restore
validation.


## Stage 9D4 closeout — benchmark hygiene carried into Stage 9D5

Stage 9D4 does not redefine or rerun the Stage 9D2/9D3 historical benchmark
workloads. Their JSON outputs remain historical evidence under the definitions
that produced them. Before accepting smaller Stage 9D5 before/after gains, the
measurement fixtures must be tightened rather than silently comparing a changed
timer boundary against those old numbers.

Source review after the initial 9D2/9D3 runs identified verification work inside
some timed workload functions. `runStage9dRetentionWorkload` queries runtime
history while timing the execute/retain phase, and `runStage9dPropagationCommit`
checks revision/state/session visibility inside the timed commit function. These
checks are valuable correctness gates but should be moved outside the measured
operation for fresh Stage 9D5 baselines. The existing large-project sibling
restore finding is too large and independently reproduced by the single-rebuild
unit to be plausibly explained away by those checks, but their contribution has
not been measured separately.

The first matrices also intentionally served bottleneck discovery rather than
perfect factor isolation. Longer history profiles use longer authored chains,
and the project profiles vary authored events/choices and state-variable counts
together. Stage 9D5 should therefore supplement—not rewrite—the historical
evidence with fixed-project repeatable-loop histories, prepared histories outside
timing, independent authored-structure/state-schema variation, and phase timing
for project preparation, snapshot validation, and reconstruction. Initialization
or preparation cost must be reported alongside repeated-operation savings.

Fingerprint stability proves deterministic repeatability, not independent
semantic correctness. Optimization acceptance must continue to compare exact
checkpoint state/history/RNG/metadata, source-engine immutability, intended
shared-state substitution, pending host-action identity, rollback/no-replay, and
restore-then-continue parity. `siblingRebuildCount` in the historical 9D3 report
is an expected workload count (`sessionCount - 1`), not instrumentation of
internal restore calls.

Five samples/two warm-ups were sufficient to discover the large bottlenecks.
Smaller Stage 9D5 improvements should use stronger same-machine repetition and
better deterministic order balancing. The current synchronous Stage 9D harness
also must not be reused unchanged to time asynchronous module I/O.

## Stage 9D5 clean before/after optimization gate

Stage 9D5 does not compare a changed timer boundary directly against the
historical 9D2/9D3 JSON. Before production optimization, run:

```text
dart run benchmark/stage9d5_optimization_baseline.dart
dart run benchmark/stage9d5_optimization_baseline.dart --json > stage9d5-before.json
```

The v1 gate freezes three complementary workload groups:

1. **Validated restore** — one exact `StoryEngine.restore` call after project,
   engine, history, and checkpoint construction are complete outside timing.
2. **Shared-state propagation** — one authoritative `counter: 0 -> 1` source
   commit after all sessions and histories are prepared; exact source/sibling
   checkpoint parity is checked only after timing.
3. **Fixed-project history increment** — exactly 16 additional loop choices
   after 32/128/512 choices are already retained, comparing direct core runtime
   with narrative orchestration on the same two-event project.

History and authored structure are now separable. Every restore/propagation
profile uses the same two-event executable loop; `short` (8) and `long` (256)
change only retained history. Authored profiles vary event-heavy, choice-heavy,
state-heavy, and combined-large structures independently where practical.

The intended Stage 9D5 workflow is strict: retain the first JSON from the current
unoptimized runtime, then rerun this **same benchmark definition** after one
production change on the same machine and Dart SDK. Initialization/preparation
costs remain visible as separate design considerations and must not be described
as eliminated merely because they are outside the repeated-operation stopwatch.

Restore validation remains mandatory. Fingerprints and exact parity checks cover
source immutability, metadata, state, current event, history, RNG state, and
runtime configuration after the stopwatch stops. The historical 9D2/9D3 files
remain valid bottleneck-discovery evidence under their original definitions.


### First clean Stage 9D5 before dataset

The first frozen `stage9d5-before.json` run used Dart 3.13.1 on Windows x64,
with 9 measured samples and 3 warm-ups per case. It is the same-machine before
dataset for the first Stage 9D5 production optimization.

Validated restore medians:

| Project profile | Short history | Long history |
| --- | ---: | ---: |
| compact | 23 us | 152 us |
| event-heavy | 1,513 us | 1,632 us |
| choice-heavy | 996 us | 1,134 us |
| state-heavy | 78 us | 222 us |
| combined-large | 2,363 us | 2,703 us |

50-session shared-state propagation medians:

| Project profile | Short history | Long history |
| --- | ---: | ---: |
| compact | 520 us | 8,807 us |
| event-heavy | 86,643 us | 89,833 us |
| choice-heavy | 53,298 us | 60,329 us |
| state-heavy | 4,365 us | 13,551 us |
| combined-large | 136,002 us | 134,570 us |

The event-heavy and choice-heavy profiles are dramatically more expensive than
the state-heavy profile at the same history/session counts. The combined-large
profile is approximately the sum of those dominant authored-structure costs.
This justifies reusing immutable project-derived event/choice preparation as the
first 9D5 production optimization.

The fixed-project 16-choice history window remains a separate signal:

| Existing loop choices | Direct core | Narrative session |
| --- | ---: | ---: |
| 32 | 6 us | 75 us |
| 128 | 3 us | 169 us |
| 512 | 3 us | 542 us |

Because the direct core operation stays essentially flat while narrative-session
cost grows with retained history, the before dataset also preserves a second,
independent long-history orchestration candidate. It is not changed by the
project-preparation optimization and must be evaluated separately after the
first before/after comparison.

### Stage 9D5 project-preparation optimization under test

ADR 0148 records the first production change. Public restore now builds one
exact-project preparation and reuses its event/choice indexes for validation and
reconstruction. `StoryNarrativeRuntime` lazily caches that preparation for
sibling rebuilds, so one shared-state commit no longer rescans the same authored
project for every sibling.

The benchmark definition is intentionally unchanged. Rerun it after the patch on
the same machine/SDK and retain the result as
`stage9d5-after-project-preparation.json`. Preparation cost is still paid once
inside the first state-changing propagation that needs siblings; it has not been
made invisible by moving it into fixture setup.

## Stage 9D5 accepted project-preparation result and history follow-up

The first clean Stage 9D5 before/after comparison accepted exact-project
preparation reuse for sibling restoration. On the recorded Dart 3.13.1 / Windows
workstation, representative 50-session short-history propagation medians changed
from 86.643 ms to 1.535 ms (event-heavy), 53.298 ms to 1.990 ms (choice-heavy),
and 136.002 ms to 8.507 ms (combined-large), with matching semantic fingerprints
and structural metrics.

The same after-project-preparation run becomes the frozen before dataset for the
independent history-materialization optimization. Its fixed 16-choice narrative
windows measured 77 us after 32 prepared choices, 171 us after 128, and 553 us
after 512, while direct core windows measured 6/3/4 us. The Stage 9D5 history
change must use the unchanged benchmark and preserve all semantic fingerprints.



### Stage 9D5 history optimization A/B isolation

Two unconditional-lazy after-runs reproduced the intended fixed-history
narrative improvement: the accepted 77/171/553 us medians after 32/128/512
prepared choices fell to approximately 10--11 us while direct-core controls
remained about 3--6 us and semantic fingerprints stayed unchanged. Selected
long-history multi-session propagation cases also measured slower repeatedly,
but the later hybrid run showed broad movement in unrelated standalone restore
controls. The available runs therefore do not prove that the lazy checkpoint is
the direct cause of the propagation movement.

Keep the unchanged v1 baseline as the end-to-end acceptance gate. For causal
isolation, use the separate diagnostic runner:

```text
dart run benchmark/stage9d5_history_ab_isolation.dart --variant=A --json
```

The variants are:

| Variant | Rollback preparation | Observation history access |
| --- | --- | --- |
| A | eager immutable snapshot | copied public history |
| B | eager immutable snapshot | indexed committed suffix |
| C | lazy O(1) checkpoint | copied public history |
| D | lazy O(1) checkpoint | indexed committed suffix |
| E | lazy checkpoint; materialize only before actual shared propagation | indexed committed suffix |
| H | rejected cardinality-based hybrid comparator | indexed committed suffix |

Each A/B/C/D run includes a standalone restore control; unchanged-state fixed
16-choice windows with 1/2/50 active sessions; natural history buildup versus
restore from an identical prebuilt aggregate checkpoint; and focused
compact/long/50 plus combined-large/long/50 propagation with sibling project
preparation cold versus explicitly prewarmed.

Use the Windows fresh-process driver for acceptance evidence:

```text
.\tool\stage9d5\run_history_ab_isolation.ps1
```

The default performs three rounds with alternating A/B/C/D process order,
seven measured samples and two warm-ups per process. It records source hashes,
Dart version, optional Git revision, and one JSON report per process under
`build/stage9d5_ab/`. Nine within-process samples are not treated as a substitute
for these independent process-level comparisons.

The A/B runner is diagnostic only. Do not use it to replace the unchanged
`stage9d5_optimization_baseline.dart`, and do not freeze the current hybrid as a
permanent architecture rule until the A/B evidence and rollback hardening are
reviewed.

#### Stage 9D5 selective rollback follow-up

Fresh-process A/B isolation established that eager rollback preparation is the
primary source of history-depth scaling and copied-history observation is a
secondary source. The provisional hybrid reintroduces eager rollback cost as
soon as multiple sessions are active, even when the source operation does not
change shared state. A diagnostic E variant now tests lazy+indexed execution
with pre-propagation snapshot materialization only after an actual shared-state
change. This remains evidence gathering; the normal runtime default is not
changed by the diagnostic patch.

A six-round fresh-process confirmation showed that E retains the lazy+indexed
history advantage but still trails eager+indexed B primarily in the
`combined_large` restored propagation cases. Source review found that the first
E implementation performed the structural `StoryState` changed comparison
twice: once before `_commitPersistentState` to decide whether to materialize,
and again inside `_commitPersistentState`. The diagnostic E implementation now
uses a pre-sibling-propagation hook invoked only after `_commitPersistentState`
has made its single authoritative changed-state decision. This removes that
confound before any production policy is selected.


### Stage 9D5 history optimization closeout

Fresh-process A/B isolation established two independent costs: eager rollback
snapshot preparation is the dominant retained-history multiplier, and copying
the full public history for observation adds a secondary multiplier. The
cardinality-based hybrid was rejected because it restored eager snapshot cost to
unchanged-state operations whenever multiple sessions were active.

The final selective E candidate captures the O(1) checkpoint before execution,
uses indexed committed-history suffix observation, and materializes the immutable
pre-operation snapshot only after `_commitPersistentState` has established one
actual shared-state change and immediately before sibling preparation. The final
six-round B/D/E confirmation used seven samples and two warm-ups per fresh Dart
process with unchanged benchmark/engine source hashes. Across the eight targeted
50-session propagation cases, the process-level median E/B ratio was about 1.02;
for 50-session unchanged-state history windows E remained essentially equal to
fully lazy+indexed D while reducing eager+indexed B costs by roughly 65--94%
depending on retained-history depth/preparation mode.

The restored combined-large `first` and `warm` subcases moved strongly in
opposite directions between otherwise comparable runs, and B/D controls also
showed process-level drift there. Stage 9D5 therefore does not encode either
subcase as a special policy rule. The aggregate evidence, semantic fingerprints,
rollback tests, and simpler semantics support selective E as the production
default. The A/B runner remains diagnostic-only; Stage 9D6 should set regression
budgets from the final production path rather than from any temporary strategy.

## Stage 9D6 relative performance regression budgets

Stage 9D6 keeps all 46 Stage 9D5 acceptance cases intact and, after 9D6A,
adds 36 versioned workloads that protect the exact optimization boundaries the
original gate could not distinguish.

The live gate is:

```text
dart run benchmark/stage9d6_performance_regression_gate.dart
```

The Windows helper writes a UTF-8 report directly under `build/stage9d6/`:

```text
.\tool\stage9d6\run_performance_regression_gate.ps1
```

The timing-free semantic baseline now identifies semantic/source/report schemas,
timing-contract version and stopwatch-boundary identity. The 46 frozen cases
retain exact accepted fingerprints/workloads/metrics. The 36 new cases retain
exact workload/metric contracts; every prewarmed propagation case must also
finish with the same semantic fingerprint as its frozen cold counterpart.

Protected ratios are:

| Signal | Maximum accepted ratio |
| --- | ---: |
| Frozen narrative retained-history depth growth | 2.50 |
| Frozen narrative/direct-core fixed-window overhead | 8.00 |
| Frozen single-session long/short history growth | 2.00 |
| Multi-session unchanged-state history depth growth (s2 and s50) | 2.50 |
| Project-heavy prepared-sibling cost / standalone restore | 0.40 |
| **Prewarmed** late/early per-sibling session-count slope | 2.50 |

The session-scaling formula no longer uses the cold propagation points. New
prewarmed s1/s10/s50 cases construct exact project-derived restore preparation
outside the timer at every point, so fixed preparation cost cannot inflate only
the early slope and hide superlinear sibling work.

The 2.50 ceiling is calibrated against three accepted-runtime evidence runs after
the prewarmed formula was introduced. The event-heavy/long s50 case repeatedly
showed a mixed distribution: a fast regime near linear scaling and a slower
regime that reached about a 2.09 slope ratio, with one conservative evidence
range extending to about 2.14. The previous 1.60 value belonged to the invalid
cold formula, while 2.00 still cut through repeatedly observed accepted-runtime
evidence. The 2.50 limit therefore provides about 20% headroom above the worst
observed slow mode while retaining substantial separation from quadratic sibling
growth (~6.44 under this formula).

Small denominator floors remain for timer quantization, but they are explicitly
part of the mathematical contract and can impose conditional absolute ceilings
when a denominator falls below its floor. Stage 9D6 therefore does not claim
complete machine-speed invariance.

The evaluator uses timing evidence ranges and returns **PASS**, **FAIL**, or
**INCONCLUSIVE**. Non-positive/unusable timings are INCONCLUSIVE. A budget whose
range straddles its threshold is also INCONCLUSIVE and requires a repeat. A
budget whose complete evidence range exceeds its threshold is FAIL. p75/p25
dispersion and detected mixed timing regimes remain visible as advisories and
expand the evidence range when appropriate. Mixed-regime detection requires
credible support on both sides (at least 20% and two observations per cluster)
plus both a 1.30x boundary gap and 1.45x cluster-median separation, preventing a
small pair of high observations from being promoted to a second regime.

The portable `dart test` suite validates these rules with synthetic timings and
never asserts live wall-clock duration. The live JSON additionally records Git
revision when available, working-tree state when detectable, execution mode,
Dart/OS information, schemas, and timing-contract version.


### Stage 9D6B production-path assurance

The final correctness closeout does not retune the accepted budgets. Instead it
exercises the default selective rollback path directly with assertion-only,
non-exported fault instrumentation. A three-session test fails propagation after
one sibling replacement has already been prepared and requires exact restoration
of source state/history/RNG/event/status, unchanged sibling snapshots, unchanged
persistent authority/revision, unchanged active-session order, and exact aggregate
checkpoint equality. A second test perturbs only the rollback snapshot project ID
and requires `projectIdMismatch`, proving the exceptional path still goes through
validated `StoryEngine.restore(...)`.

All retained Stage 9D5 A/B/C/D/E/H strategies also run successful-commit and
post-preparation-failure parity checks. They remain diagnostic evidence tooling,
not supported consumer policies; ADR 0153 defines their eventual removal criteria.

The first Stage 9D6B closeout run on 21 September 2026 used 21 measured samples
and 5 warm-ups on Dart 3.13.1 / Windows x64. Analyzer and all 1,055 ordinary
tests were green, the semantic/contract baseline passed, and all 25 budgets
passed. The event-heavy/long prewarmed scaling check was 1.649 with evidence
[1.011, 1.715] against the 2.50 ceiling. Its remaining mixed-regime advisory did
not make the result ambiguous. That run accepted the runtime and performance
budgets.

A final semantic-baseline follow-up then pinned exact accepted fingerprints for
the six 9D6-owned unchanged-state history cases. The exact fingerprint-pinned
revision was revalidated on 21 September 2026: `dart analyze` was green, all
1,056 ordinary tests passed, the semantic/contract baseline passed, and all 25
budgets passed in another 21-sample / 5-warm-up gate. The event-heavy/long
prewarmed scaling check was 1.641 with evidence [1.033, 2.138] against the 2.50
ceiling. Stage 9D6B, Stage 9D6, and Stage 9D are therefore complete / accepted.


## Finalization Stage 4: aggregate JSON load path

[Aggregate load-path benchmark](AGGREGATE_LOAD_PATH_BENCHMARK.md) adds a separate
three-scenario diagnostic for complete JSON decode plus aggregate restore. It
records raw timings and semantic fingerprints for retained sessions, histories
and host suspension. Immutable lookup reuse was adopted after measuring a
material reduction on larger saves; all compatibility checks remain active. The
Stage 9D6 baseline, thresholds and workload definitions are unchanged.
