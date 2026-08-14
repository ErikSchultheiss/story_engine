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
