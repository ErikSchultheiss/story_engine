# story_engine 0.9.0

0.9.0 is the completed feature baseline, currently being prepared for
publication. It is a pre-1.0 Dart package with frozen, independently versioned
authored and execution contracts. The Dart API can evolve before a separately
approved 1.0 API commitment. This page describes the candidate; it does not
record a completed package upload.

## Included

- Authoritative aggregate narrative capture, JSON encoding/validation and direct
  restore, including retained sessions, shared state, RNG and pending host requests.
- Four executable Pure-Dart integrations: branching core save/load, shared-state
  orchestration, modular loading/host suspension, and reusable authored analysis.
- Optional immutable runtime explanations covering availability, conditional and
  weighted resolution, effects, automatic traversal, rollback and shared commits.
- Reusable references, variable-use and iterative graph analysis with standalone,
  orchestration and module-slice validation contexts.
- Verified module single-flight, selective rollback/history access and measured
  immutable lookup reuse for retained aggregate load paths.
- The frozen six-case foundation corpus plus ten separate finalization hardening
  cases, a standalone report runner and diagnostic retained-save load benchmarks.

The supported root facade exposes 277 top-level symbols. Read the
[API Guide](API_GUIDE.md) and [upgrade notes](UPGRADING_TO_0_9_0.md).

For a first integration, follow the [Quick Start](QUICK_START.md), the
[Forest Gate walkthrough](NARRATIVE_WALKTHROUGH.md) and the
[four-example index](../example/README.md). The core example uses one
`StoryEngine`; the shared-state and modular host-action examples demonstrate
`StoryNarrativeRuntime` authority and its aggregate persistence boundary.

## Compatibility identities

| Boundary | Identity |
| --- | --- |
| Dart package | 0.9.0, pre-1.0 |
| Authored Story Format | `story_engine.story_format` / 1 |
| Runtime semantics | Core Revision 1 |
| Deterministic RNG | `story_engine.lcg32` / 1 |
| Core checkpoint | Format 1 / runtime contract 1 |
| Aggregate checkpoint | Format 1 / runtime contract 1 |
| Host-action protocol | Revision 1 |

A package update does not reinterpret these formats. Existing snapshot
compatibility validation and host-owned content revision/preflight requirements
remain mandatory. Restoration never replays committed effects or redispatches
external host actions.

## Deferred scope

Stage 9E (session-local state/history predicates) is deferred. History compaction,
aggregate content migration and authored host-action nodes also need separately
approved semantics. The independent C# spike proves only the six foundation
cases, not the newer hardening profile or a production second-runtime SDK.

Internal A/B benchmark strategies remain repository diagnostics with a separate
retirement policy. They are not supported consumer configuration.

## Reproducing the package gate

From a dependency-resolved package checkout:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart run tool/conformance/run_conformance.dart --output=build/conformance-foundation.json
dart run tool/conformance/run_conformance.dart --fixture-set=conformance/fixtures/runtime-finalization-v1/fixture-set.json --output=build/conformance-hardening.json
dart doc --validate-links
```

The normal test suite executes all four Pure-Dart example entry points. Generate
Dartdoc after applying the final source; `doc/api/` is generated output and is
excluded from source/publication archives. Serve `doc/api/` with a local HTTP server to use API search and navigation.
Benchmark timing commands should run without concurrent tests.

Before publishing, additionally validate the minimum supported and current
stable SDK, the actual consuming applications, the intended export inventory and
`dart pub publish --dry-run`. Local gates do not themselves publish or certify
all host/platform integrations. Uploads and release tags are explicit maintainer
actions after those checks.

A future 1.0 release needs an approved API compatibility/deprecation policy,
supported-platform and consumer acceptance, migration guidance and a separate
publication/security review.
