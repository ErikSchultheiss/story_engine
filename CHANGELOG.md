# Changelog

## 0.9.0 — prepublication candidate

This entry describes the prepared 0.9.0 baseline, not a completed publication.
The Dart API remains pre-1.0; Story Format and execution contracts keep their
independent version identities.

- Finalize the required Stage 9 feature baseline with independently frozen Story
  Format v1, Core Semantics Revision 1, LCG32 v1 and checkpoint-v1 contracts.
- Add authoritative aggregate save/restore, host-suspended and simultaneous
  sessions, four executable integrations, and complete optional explanations.
- Add reusable authored analysis and explicit standalone/orchestration/module
  validation contexts with iterative graph algorithms and precise locations.
- Harden transactional rollback, retained-session load paths and public exports;
  add ten portable conformance cases, a standalone runner and measured load
  profiling alongside the unchanged foundation corpus and performance budgets.
- Refresh release identity, documentation/API generation, package gates and
  upgrade guidance. Stage 9E and further semantic extensions remain deferred;
  0.9.0 does not promise a stable 1.0 Dart API.
- Improve onboarding with a runtime selector, a story-led Forest Gate
  walkthrough and four examples with commands, visible outcomes and next
  reading links.

See [release scope](doc/RELEASE_0_9_0.md) and
[upgrade notes](doc/UPGRADING_TO_0_9_0.md).

### Development history

#### Finalization Stage 3 — Reusable analysis and validation

- Add immutable public authored reference, variable-use and structural graph
  analysis with precise typed locations, explicit roots, possible termination,
  cyclic regions and incomplete boundaries.
- Share traversal between reference/state-use/graph validators, module reference
  verification and Studio's reachability bridge.
- Add standalone, orchestration and module-slice validation contexts; retain the
  existing default and legacy graph-only additional roots.
- Analyze shared-state activations conservatively and validate explicit context
  roots without imposing a default entry event.
- Replace recursive cycle discovery with iterative graph traversal.

- Finalization Stage 2 adds opt-in complete execution traces for conditional and
  weighted transitions, event availability, effect attempts, and automatic
  traversal, retaining completed failure prefixes without changing authority.
- The narrative debug adapter adds aggregate-outcome execution traces and
  revision-ordered shared-state commit explanations with net variable deltas
  and propagated sibling identities. Existing lifecycle/save/wire contracts,
  ordinary execution, and effect-only APIs remain compatible.

- Finalization Stage 1 prepares destination choices before aggregate commits,
  rolls back failed presentation through validated restore, and keeps failure
  effect callbacks under the serialized guard with aggregate rollback outcomes.
- Finalization Stage 1 separates repository-only architecture/documentation
  checks from portable public tests, retains required codec reference fixtures
  in the Pub archive, and treats the nested Flutter example as its own analyzer
  package. Public API and wire-format versions remain unchanged.

- Stage 9D6B adds behavior-driven production-path assurance for selective rollback: failure is injected only after a real sibling replacement has been prepared, exact source/sibling/shared-authority rollback and validated `StoryEngine.restore(...)` are proved directly, retained A/B/C/D/E/H strategies gain semantic/rollback parity coverage, and the assertion-only probe remains internal/non-exported.
- Stage 9D6A hardens the performance regression gate while preserving all 46 frozen Stage 9D5 cases: 36 versioned workloads now protect multi-session unchanged-state history and comparable prewarmed session scaling, schema/timing-boundary identities and run provenance are explicit, denominator-floor effects are documented, and PASS/FAIL/INCONCLUSIVE evidence handling prevents unusable or materially ambiguous timing data from producing a false verdict.
- Stage 9D5 accepts selective lazy rollback plus indexed committed-history observation after same-revision fresh-process A/B isolation: ordinary operations keep an O(1) checkpoint, an immutable rollback snapshot is materialized only after an actual shared-state change and immediately before sibling propagation, rollback still restores through validated `StoryEngine.restore(...)`, and the diagnostic A/B seam remains internal repository tooling.
- Stage 9D5 applies its first measured optimization candidate: validated restore now reuses immutable event/choice project preparation within a restore, and shared-state sibling rebuilds lazily reuse one exact-project preparation per narrative runtime while all snapshot/state/history/RNG validation remains mandatory.
- Stage 9D5 begins with a clean before/after optimization gate: fixed-loop histories decouple retained history from authored project size, project profiles separate event/choice/state dimensions, restore/propagation correctness checks run outside timing, and a fixed 16-choice history window isolates long-history execution before any production optimization is accepted.
- Stage 9D4 adds instance-local single-flight to `StoryModuleCache`: concurrent same-module misses share one load-plus-verification operation, different modules remain parallel, failures cleanly retry, and completed-body-only eviction semantics remain intact. It also closes the stale Stage 9D3 architecture assertions and records benchmark-hygiene requirements for later 9D5 before/after measurements.
- Stage 9D3 adds deterministic shared-persistent-state propagation profiling, including a single sibling snapshot/restore rebuild unit and a 1/10/50-session matrix across growing project and retained-history sizes, without changing production restore validation or runtime semantics. The first recorded matrix confirms repeated validated sibling restoration as the dominant propagation cost for larger projects/many active sessions, so a structural optimization is carried into Stage 9D5 while validation remains mandatory.
- Stage 9D2 adds the fixed 1/10/50-session × short/medium/long/very-long-history × active/completed retention matrix, with execution, aggregate snapshot capture, and snapshot encoding timed separately while preserving deterministic semantic fingerprints and structural evidence.
- Stage 9D1 adds a reusable deterministic benchmark harness with fixture setup
  outside timed regions, warm-up, rotating case order, raw-sample/median/IQR
  reporting, semantic fingerprints, environment metadata, configurable core
  and simultaneous-session workloads, and explicit allocation-measurement
  limitations rather than machine-specific timing assertions.
- Stage 9C6 adds deterministic diagnostics-off/on semantic-neutrality coverage
  for aggregate snapshots, RNG/session identity, host-action IDs, lifecycle
  observations, and exception behavior, plus an opt-in same-machine benchmark
  for explainability overhead without introducing flaky CI timing thresholds.
- Stage 8O independent-runtime proof: added a Unity-independent C# conformance
  spike in the combined development workspace that implements Runtime Semantics
  Core Revision 1 from the public specifications and consumes all six shared
  `runtime-core-v1` foundation fixtures plus deterministic-random reference
  vectors. The prototype is explicitly not a production C# SDK or public API
  compatibility commitment.

- Stage 8N adds stable presentation-unit/source-revision identity through a
  separate portable sidecar contract while keeping Story Format v1 unchanged.
- Adds structured non-authoritative narrative observer events plus a consolidated
  implementer contract for serialized authority, reentrancy, explicit host facts,
  worker independence, and server-authoritative execution assumptions.
- Adds shared explicit-host-input conformance vectors proving wall-clock and
  hidden-global harness noise cannot alter deterministic narrative resolution.
- Stage 8M adds portable runtime capability profiles/reports with explicit
  semantic feature revisions and independent Extension Schema version ranges.
- Adds deterministic target-compatibility diagnostics and a strict no-silent-
  downgrade rule while keeping Story Format v1 and existing bundle/release
  contracts unchanged.
- Stage 8L adds explicit content-release/module revision identity, deterministic
  transport-neutral patch manifests, and save-content bindings layered over
  unchanged Stage 8K runtime bundles.
- Adds exact-hash/explicit compatibility evaluation plus declarative event/choice
  redirects and safe fallback policy for save restoration across content
  revisions; patch transport/CDN/platform delivery remains host-owned.
- Stage 8K defines deterministic runtime bundles as derived shipping artifacts
  separate from the open Story Format authoring source of truth.
- Adds SHA-256 artifact hashes, canonical bundle manifests/identities, Stage 8H
  module-set alignment, a reference packager, and integrity verification while
  deliberately deferring the final compiled module encoding/compiler.
- Stage 8J permits multiple logically active narrative sessions while keeping
  shared persistent StoryState under one serialized deterministic authority.
- Adds explicit UI-neutral/server-authoritative narrative input objects, atomic
  sibling-session state propagation, persistent-state revision observation, and
  re-entry/thread-confinement rules without changing Story Format v1.
- Stage 8I defines the suspendable host-action protocol with stable request IDs,
  portable scalar payloads/results, explicit success/failure/cancellation, and
  one-pending-request re-entry protection.
- Adds `StoryNarrativeSessionStatus.awaitingHost`, combined session checkpoint
  data, and a strict host-action protocol snapshot codec; restore preserves the
  same pending request without automatically redispatching host work.
- Corrects runtime-snapshot compatibility for Stage 8G host-selected `startAt`
  runs while keeping Story Format v1 and the existing runtime-snapshot wire
  representation unchanged.
- Stage 8H adds a lightweight global project index plus independently loadable
  narrative modules for large-corpus runtime consumers.
- Adds storage-neutral module loading, index/body verification, bounded LRU
  caching, prefetch/eviction, and dependency-closure project materialization.
- Adds unloaded cross-module reference validation and a deterministic
  100-module / 10,000-event stress fixture while keeping Story Format v1
  unchanged.
- Stage 8G adds host-driven narrative orchestration with stable entry points,
  deterministic condition/priority/fallback/weighted resolution, persistent
  scalar state across local sessions, and explicit host-world condition inputs.
- Adds `StoryNarrativeRuntime` / `StoryNarrativeSession` plus
  `StoryEngine.startAt(...)` so unrelated local narrative flows do not require
  graph edges from previously executed content.
- Separates orchestration RNG from per-session RNG so random decisions inside
  one session cannot perturb later unrelated entry resolution; Story Format v1
  remains unchanged.
- Stage 8E adds `open_story.extension_schema` contract version 1 for
  language-neutral custom actions, conditions, enums, reference types, typed
  parameters, and non-semantic editor metadata.
- Adds public immutable schema models plus a strict deterministic JSON codec;
  schemas remain data only and contain no host callback or implementation code.
- Freezes safe unknown semantic behavior: missing namespaces/members are
  validation/compatibility failures rather than silent action no-ops or Boolean
  condition fallbacks; frozen Story Format v1 remains unchanged.
- Stage 8D adds the public `runtime-core-v1` language-neutral conformance
  fixture foundation, including six complete input/expected-output narrative
  runs derived from the canonical Story Format v1 reference project.
- Defines `open_story.conformance_report` version 1 with per-case pass/fail/
  skipped results and structured mismatch categories.
- Adds a Dart reference conformance runner using only the public package API;
  Story Format v1, Runtime Semantics Core Revision 1, and the deterministic RNG
  profile remain unchanged.
- Stage 8C freezes `story_engine.lcg32` version 1 as the exact cross-runtime
  deterministic-random profile, including seed/state semantics, LCG recurrence,
  exact-53 candidate construction, unbiased bounded rejection sampling, and
  weighted-route integration.
- Adds public algorithm documentation plus machine-readable reference vectors
  for raw state evolution, bounded samples, rejection consumption, and weighted
  selection across representative seeds.
- Preserves existing Dart seeded routes, runtime snapshot compatibility, and
  frozen Story Format v1 without a production RNG behavior change.
- Stage 8B publishes language-neutral Runtime Semantics Core Revision 1 for
  state/unset behavior, event flow, conditions/effects, transitions, history,
  termination, failure categories, and transactional rollback.
- Corrects Number ordering so `-0.0` and `+0.0` use ordinary finite IEEE-754
  numerical relations rather than Dart's `num.compareTo` total-order
  distinction.
- Freezes weighted-transition draw consumption and interval mapping separately
  from the exact seeded RNG algorithm/sampling profile.
- Stage 8A audits Story Format v1 as the language-neutral authored-project
  contract for the wider open multi-runtime narrative ecosystem.
- Records cross-language JSON/canonicalization gaps that must be resolved by
  runtime semantics and conformance work without silently changing frozen v1.
- Records exact seeded random-route parity across conforming runtimes as a hard
  requirement, fulfilled by the Stage 8C deterministic-random profile.
- Adds architecture regression coverage proving Stage 8A leaves canonical v1
  fixtures and serialized semantics unchanged.

- Stage 9D5 diagnostic follow-up: add selective variant E (lazy checkpoint +
  indexed history; materialize rollback only after an actual shared-state
  change before multi-session propagation) and a fresh-process B/D/E driver.
  This variant was diagnostic-only at introduction; the later Stage 9D5 closeout accepts the selective policy as the normal runtime default.
- Stage 9D5 selective-isolation refinement: route E's pre-propagation
  snapshot hook through the existing `_commitPersistentState` changed-state
  decision so the diagnostic candidate does not perform a second structural
  `StoryState` equality scan before the same commit. Production default is
  was still unchanged at that experiment point; the later six-round confirmation supports promoting E to the normal runtime default.

## 0.1.0-alpha.1

First public alpha release of `story_engine`.

- Pure-Dart runtime for declarative interactive narrative and event systems.
- Deterministic story traversal with direct, conditional, weighted, and terminal transitions.
- Typed scalar story state with declarative conditions and effects.
- Static project validation with stable diagnostic codes, locations, severity, and repair guidance.
- Deterministic runtime snapshot capture, JSON persistence, compatibility validation, and restore.
- Frozen Story Format v1 authored-project contract with deterministic encode/decode behavior.
- Public API exposed only through `package:story_engine/story_engine.dart`; implementation details remain under `lib/src/`.
- Pure-Dart and downstream Flutter examples.
- Reproducible 100/500/1,000-event regression and performance workloads.

The Dart package API is intentionally pre-1.0 and may still evolve between alpha releases. Story Format v1 is versioned independently and remains a frozen compatibility contract.
