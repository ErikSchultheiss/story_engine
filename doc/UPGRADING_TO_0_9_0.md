# Upgrading to story_engine 0.9.0

Update the dependency and resolve it in the host application's package context:

```yaml
dependencies:
  story_engine: 0.9.0
```

Use a local path dependency while testing an unpublished local candidate. Pin
0.9.0 when it has been published; the package remains pre-1.0. Consumer imports
continue through the supported facade:

```dart
import 'package:story_engine/story_engine.dart';
```

## Choose the persistence authority

A standalone `StoryEngine` still uses `StoryRuntimeSnapshotCodec` and
`StoryEngine.restore`. Its lifecycle/RNG/history remain the checkpoint authority
for that run.

When `StoryNarrativeRuntime` owns shared state and sessions, capture and restore
one `StoryNarrativeRuntimeSnapshot` using its codec and aggregate restore
factory. Do not reconstruct the aggregate by restoring each retained session
independently. See [Aggregate save/load](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md) and
the [modular host-action restore example](../example/story_narrative_modular_host_action_restore_example.dart)
for the executable aggregate checkpoint path. The
[shared-state example](../example/story_narrative_shared_state_example.dart)
focuses on execution authority and intentionally omits persistence.

Pair saves with the intended authored content revision. Run any configured
content-binding preflight before decode/restore. Unchanged format versions do
not make an incompatible content revision safe.

For a restored pending host request, reconcile the stable request ID with the
external system before supplying a typed completion, failure or cancellation.
Restore does not dispatch the external operation again.

## Diagnostics and authored analysis

Ordinary execution remains the minimal path. Opt into execution/condition/
transition explanations or a narrative debug adapter when the host needs richer
diagnostics. Explanation data is immutable and observational; it does not own
runtime state or alter seeded outcomes. Aggregate rollback outcomes should be
used when displaying attempted effects from a failed narrative input.

Use `StoryProjectAnalysis.analyze(project)` for reusable references, variable
uses and graph queries. Keep one immutable analysis with its immutable project
revision rather than recomputing the same structure in each editor view.

The default `StoryValidator.validate(project)` retains standalone assumptions.
Use `StoryValidationContext.orchestration` with declared roots for shared-state
entry flows; use `moduleSlice` with known external destination IDs for partial
modules. These contexts do not waive type, identity or malformed-flow errors.
The legacy additional roots remain graph-only, so they do not replace a context.

## Upgrade checks

1. Run the application's unit/integration tests against the final local package.
2. Resume representative existing core and aggregate saves, continue execution,
   and check future seeded decisions and session/request identities.
3. Exercise pending host requests with success, rejection and stale completions.
4. Verify that source/module validation uses the intended entry/state context.
5. Keep UI, storage, host side effects and source/content version policy in the
   application; replace unsupported direct `src/` imports with public APIs.

The package version change alone requires no Story Format v1 or checkpoint-v1
migration. The [release baseline](RELEASE_0_9_0.md) lists the independent contract
identities and deferred extensions. Frozen fixtures remain regression contracts;
do not rewrite their expected outcomes during an upgrade.

The [example index](../example/README.md) lists all four Pure-Dart integrations
with commands and expected results. New consumers can start with the
[Quick Start](QUICK_START.md) and [Forest Gate walkthrough](NARRATIVE_WALKTHROUGH.md).
