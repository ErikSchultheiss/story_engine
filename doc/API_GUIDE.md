# story_engine API Guide

This guide describes the supported public package surface for the 0.9.0
pre-1.0 release. Member-level signatures and details live in Dartdoc; this document
explains how the public concepts fit together and provides a complete top-level
symbol index.

## Supported import boundary

Consumer code should use exactly the package root:

```dart
import 'package:story_engine/story_engine.dart';
```

`lib/src/` is implementation detail. Direct `package:story_engine/src/...`
imports are unsupported consumer API even if a declaration happens to be
reachable in a source checkout.

The root barrel uses explicit `show` lists, so declarations added to internal
files do not become public accidentally.

## Mental model

The main layers are deliberately separate:

| Layer | Public concepts | Responsibility |
| --- | --- | --- |
| Authored model | `StoryProject`, `StoryEvent`, `StoryChoice` | State schema, conditions, effects and transitions |
| Static validation | `StoryValidator` | Check authored content without executing it |
| Core execution | `StoryEngine`, `StoryState`, `StoryRuntimeSnapshot` | Run and checkpoint one playthrough |
| Host-driven orchestration | `StoryNarrativeRuntime`, `StoryNarrativeSession`, `StoryNarrativeRuntimeSnapshot` | Own retained sessions, shared state and aggregate checkpoints |
| Story Format v1 | `StoryFormatDocument`, `StoryFormatBundle`, `StoryFormatCodec` | Encode and decode portable authored data |

Story Format persists authored data. Core runtime snapshots persist one
`StoryEngine` playthrough. Aggregate narrative snapshots persist one complete
`StoryNarrativeRuntime` execution authority, including its retained sessions
and orchestration state. These are separate contracts and must not be treated as
interchangeable.

## Recommended integration order

Use the public API in this order rather than beginning with the complete symbol
index:

1. Define/load a `StoryProject` and validate it with `StoryValidator`.
2. Learn the core execution contract through `StoryEngine`: inspect the current
   event, submit choice/continue input, and persist a single run with
   `StoryRuntimeSnapshot` when needed.
3. Run `dart run example/story_engine_example.dart` to verify the complete core
   lifecycle. The [Forest Gate walkthrough](NARRATIVE_WALKTHROUGH.md) maps its
   passages and player actions to authored rules and save/restore.
4. Introduce `StoryNarrativeRuntime` only when the host needs orchestration
   responsibilities that a single `StoryEngine` should not own: host-selected
   entry points, multiple unfinished sessions, shared persistent state, explicit
   host facts, or suspendable host actions.
5. Run the shared-state orchestration example with
   `dart run example/story_narrative_shared_state_example.dart` to see two
   independent sessions observe one committed persistent state and receive
   inputs through one serialized narrative authority.
6. Once orchestration owns execution, use the aggregate
   `StoryNarrativeRuntimeSnapshot` lifecycle for durable save/load. Do not
   restore `StoryNarrativeSessionSnapshot` values independently and reassemble
   the runtime.
7. Run
   `dart run example/story_narrative_modular_host_action_restore_example.dart`
   when the integration needs a concrete composition of modular loading,
   suspendable host work, and aggregate restore. The restored pending request is
   reconciled by stable ID; restore does not redispatch external work.
8. Add content-release binding, capability negotiation, or cross-runtime
   contracts only when those concerns are actually present.

See [INTEGRATION_PATH.md](INTEGRATION_PATH.md) for the onboarding/documentation
map. Use [ABSTRACTION_GUIDE.md](ABSTRACTION_GUIDE.md) when you need the compact
relationship between project/document/bundle/module/entry point/session/
capability/content release/host action before reading narrow contracts. See
[AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md) for
the durable orchestration path.

## Authored project model

### `StoryProject`

One authored narrative/event-system definition. It owns:

- project identity;
- scalar state schema;
- ordered events;
- optional entry event.

The model is intentionally permissive enough to represent incomplete editor
work. `StoryValidator` determines whether authored data is valid; `StoryEngine`
rejects invalid structure if execution reaches it.

### `StoryEvent`

The generic executable authored unit. It can represent prose scenes, dialogue
beats, quest events, tutorials, management events, or other narrative/event
logic.

A runnable event uses exactly one flow mode:

- `choices`
- `continuationTransition`
- `automaticTransition`

### `StoryChoice`

An event-owned decision with stable identity, optional presentation/condition,
ordered effects, and a transition.

## Stable identity and presentation

Typed IDs (`StoryProjectId`, `StoryEventId`, `StoryChoiceId`,
`StoryVariableId`) are durable machine references. `StoryAlias` is an optional
readable developer handle and is not primary identity.

`StoryText`, `StoryEventPresentation`, and `StoryChoicePresentation` contain
human-facing source/default-language content. Runtime control flow never depends
on visible text.

## Scalar state

`StoryStateSchema` declares variables using `StoryVariableDefinition` and
`StoryValueType`.

Runtime values are represented by `StoryValue` subclasses:

- `StoryBooleanValue`
- `StoryIntegerValue`
- `StoryNumberValue`
- `StoryStringValue`

Convenience bridges:

```dart
final value = StoryValue.fromRaw(42);

final state = StoryState.fromRawValues(
  schema: project.stateSchema,
  values: {someVariableId: 42},
);

final raw = state.rawValueOf(someVariableId);
```

These conveniences retain schema/type validation. They do not introduce
coercion or mutable state.

## Conditions

Conditions are declarative and side-effect free:

- `StoryAllCondition`
- `StoryAnyCondition`
- `StoryNotCondition`
- `StoryVariableIsSetCondition`
- `StoryVariableIsUnsetCondition`
- `StoryVariableComparisonCondition`

`StoryComparisonOperator` defines scalar comparison operations.

Most applications author conditions as data and let `StoryEngine` evaluate
them. `StoryConditionContext` / `StoryConditionEvaluator` are public for hosts
that need standalone evaluation using the same semantics.

## Effects

Effects mutate scalar story state only as part of engine transactions:

- `StorySetVariableEffect`
- `StoryUnsetVariableEffect`
- `StoryIncrementVariableEffect`
- `StoryDecrementVariableEffect`

Effects do not navigate. The low-level mutable execution machinery is internal;
consumers observe immutable `StoryState` snapshots.

## Narrative explainability data

Stage 9C adds immutable structured explanation values for authoring/debugging
hosts. The model covers actual condition results/short-circuit shape, choice
availability, entry-point eligibility/fallback/priority/weighting decisions,
and authored effect before/after transaction outcomes.

Stage 9C2 instruments standalone condition evaluation. Use
`StoryConditionEvaluator.evaluateWithExplanation(...)` when a host needs both
the actual Boolean result and its causal tree; `explanation.result` is the
result of that same evaluation pass. `ALL` and `ANY` include only children that
were actually evaluated, so skipped children are never re-evaluated merely for
diagnostics. Ordinary `evaluate(...)` remains the minimal path and does not
retain explanation data.

Stage 9C3 integrates decisions. `StoryEngine.choiceExplanations` (also exposed
through `StoryNarrativeSession`) returns one explanation for every authored
choice, including unavailable choices.
`StoryNarrativeRuntime.explainEntryPointEligibility(...)` diagnoses one current
candidate, including missing host facts, without starting a session.
`resolveAndStartSessionWithExplanation(...)` is the opt-in authoritative
resolution/start path: its returned explanation records the actual
fallback/priority/finalist/weighting decision made during the same pass that
selected the returned session.

Stage 9C4 instruments scalar effects during the actual engine transaction.
Use `startWithEffectExplanations(...)`, `startAtWithEffectExplanations(...)`,
`chooseWithEffectExplanations(...)`, or
`continueStoryWithEffectExplanations()` when a debugger needs authored
before/operation/after attribution. Successful calls return committed/no-op
records. If a diagnostic transaction fails, the ordinary engine exception still
throws and `StoryEngine.lastEffectExplanations` retains rejected/rolled-back
records for inspection.

Stage 9C5 adds `StoryNarrativeDebugAdapter` for hosts that want these
explanations as one opt-in orchestration debug stream. Pass `debugAdapter:` to
`StoryNarrativeRuntime` or `StoryNarrativeRuntime.restore(...)`. The adapter
receives entry eligibility/resolution, choice availability at committed pauses,
and effect batches captured by the same execution paths described above.
Adapter failures are isolated and the adapter is not persisted in runtime
snapshots.

Stage 9C6 locks the neutrality boundary with paired diagnostics-off/on
integration tests. Equivalent runs must preserve aggregate snapshot state,
entry/session and host-action identities, authoritative lifecycle observations,
and exception behavior. Use
`benchmark/stage9c6_explainability_overhead.dart` for same-machine measurement
of the opt-in diagnostics cost; portable CI does not use wall-clock thresholds.

These values are observational only. The existing minimal condition, choice,
entry-resolution, and engine execution APIs remain diagnostics-off when no
debug adapter is attached. Hosts must not treat explanation data as narrative
authority.

See [Narrative Explainability — Contract Revision 1](NARRATIVE_EXPLAINABILITY_V1.md) for the structured-data and stability boundary.

## Transitions

Transitions own navigation:

- `StoryEventTransition` — direct destination.
- `StoryConditionalTransition` — first matching ordered branch plus mandatory
  fallback.
- `StoryWeightedTransition` — positive integer weighted alternatives using the
  engine's deterministic RNG.
- `StoryTerminalTransition` — explicit story termination.

Conditional branches use `StoryConditionalTransitionBranch`; weighted
alternatives use `StoryWeightedTransitionOption`.

## Runtime

Construct and start:

```dart
final engine = StoryEngine(project: project)..start();
```

Key runtime observations/actions:

- `engine.status`
- `engine.currentEvent`
- `engine.state`
- `engine.history`
- `engine.availableChoices`
- `engine.choose(choiceId)`
- `engine.continueStory()`
- `engine.createSnapshot()`

`StoryEngineStatus` is one of `notStarted`, `awaitingChoice`,
`awaitingContinue`, or `terminated`.

The default random seed is deterministic. Pass `randomSeed:` for an explicit
sequence. Exact cross-runtime seeded sampling is specified separately in
[Deterministic Randomness — `story_engine.lcg32` Version 1](DETERMINISTIC_RANDOM_V1.md). Automatic traversal has a guard controlled by
`maxAutomaticTransitions`.

### Runtime transaction behavior

`start`, `choose`, and `continueStory` commit only after the complete scalar
transaction succeeds. Failed operations do not partially apply state/history or
advance RNG state.

### Runtime history

`StoryRuntimeHistory` stores canonical ordered runtime steps:

- `StoryEventEnteredStep`
- `StoryChoiceSelectedStep`
- `StoryEventContinuedStep`

Use this for inspection/debugging/derived views rather than maintaining parallel
visited/choice lists inside the engine.

## Host-driven orchestration

`StoryNarrativeRuntime` is the higher-level host-driven layer for projects where
world navigation chooses when local narrative should run. It does not replace
`StoryEngine`; every `StoryNarrativeSession` uses the same core runtime semantics
for local traversal.

The host can start a named `StoryEntryPointId` directly or ask the runtime to
resolve among `StoryEntryPoint` declarations using:

1. core StoryCondition eligibility;
2. explicit `StoryHostContext` Boolean facts for host-owned conditions;
3. regular before fallback entries;
4. highest priority;
5. deterministic authored-order weighted tie-breaking.

`StoryHostConditionRequirement` identifies the Extension-Schema-oriented
namespace/condition/arguments to which a host result belongs. It contains no
callback or executable implementation.

Current scalar `StoryState` persists across sessions. Current event/status,
core `StoryRuntimeHistory`, and the local random stream remain session-scoped.
`StoryNarrativeRuntimeHistory` preserves those session boundaries while also
offering a flattened route convenience view.

Stage 8J permits multiple unfinished sessions in one `StoryNarrativeRuntime`.
Use `activeSessions` for the deterministic active set and `sessionByIndex(...)`
for stable session lookup. Shared-state operations are serialized in explicit
host-authority order; successful commits propagate atomically to sibling active
sessions, and `persistentStateRevision` advances only when global state changes.

For UI-neutral or server-authoritative execution, submit `StoryNarrativeInput`
objects through `applyInput(...)`. Choice/continue and host-action outcomes use
stable session/request/choice IDs rather than widget callbacks or wall-clock
ordering. See [SESSION_EXECUTION_V1.md](SESSION_EXECUTION_V1.md).

`StoryEngine.startAt(eventId)` is the lower-level activation primitive when a
host already has an event identity. It does not mutate
`StoryProject.entryEventId`.

See [OPEN_WORLD_ORCHESTRATION_V1.md](OPEN_WORLD_ORCHESTRATION_V1.md) for the
normative Stage 8G behavior and forward boundary.

## Suspendable host actions

Stage 8I adds a data-only suspend/resume protocol for external host work. A
`StoryNarrativeSession` can emit one `StoryHostActionRequest` from a committed
choice/continue pause. Its composite `sessionStatus` becomes
`StoryNarrativeSessionStatus.awaitingHost` while the underlying `StoryEngine`
remains at the same committed core pause.

Requests identify an Extension-Schema-style namespace/action, carry portable
scalar arguments, and use deterministic `StoryHostActionRequestId` correlation
identity. `StoryHostActionValueType` describes an optional successful result.
The host later supplies exactly one typed completion, failure, or cancellation.
Choice/continue input and a second request are rejected while the request is
pending.

`StoryHostActionProtocolSnapshot` plus the existing `StoryRuntimeSnapshot` form
the logical suspend checkpoint. `StoryNarrativeSession.createSnapshot()`
returns both. `StoryHostActionProtocolSnapshotCodec` persists the protocol side
without host-engine objects. Restoring a pending protocol snapshot never
redispatches external work automatically; the host reconciles the stable
request ID first.

See [HOST_ACTION_PROTOCOL_V1.md](HOST_ACTION_PROTOCOL_V1.md) for the normative
Stage 8I contract. For an executable pending-request restore/reconciliation
walkthrough, run
`dart run example/story_narrative_modular_host_action_restore_example.dart`.

## Aggregate narrative snapshot persistence

A `StoryNarrativeRuntime` is one shared execution authority, so its durable
resume path is aggregate. Do not restore retained sessions manually and then
attempt to reassemble the runtime: per-session checkpoints do not preserve the
orchestration RNG, shared persistent-state authority/revision, next-session
allocation, observation cursor, retained ordering, or cross-session invariants.

A standalone `StoryEngine` still uses the core `StoryRuntimeSnapshot` path. The
following lifecycle applies when execution is owned by `StoryNarrativeRuntime`.

### Save

Capture only at a completed serialized-operation boundary:

```dart
final aggregateSnapshot = runtime.createSnapshot();

final contentBinding = StorySaveContentBinding.fromRetainedSessionSnapshots(
  projectId: aggregateSnapshot.projectId,
  snapshots: aggregateSnapshot.sessions.map(
    (session) => session.runtimeSnapshot,
  ),
  index: projectIndex,
  release: contentRelease,
);

final snapshotJson = StoryNarrativeRuntimeSnapshotCodec().encodeJson(
  aggregateSnapshot,
);
final bindingJson = const StorySaveContentBindingCodec().encode(contentBinding);
```

The host persists `snapshotJson` and `bindingJson` atomically as one logical
save revision. The package intentionally leaves file/database/cloud transaction
mechanics to the host. Inside the aggregate checkpoint, each retained session's
core runtime snapshot and host-action protocol snapshot are likewise one
logical checkpoint and must not be mixed from different moments.

If the integration does not use Stage 8L content-release binding, the aggregate
snapshot path is unchanged; the host must still guarantee that the project and
entry-point configuration supplied on load are the intended compatible authored
configuration.

### Load and content preflight

Read one matching logical save revision first. When a content binding is stored,
decode and evaluate it before aggregate restore:

```dart
final binding = const StorySaveContentBindingCodec().decode(bindingJson);
final compatibility = const StorySaveContentCompatibilityEvaluator().evaluate(
  binding: binding,
  target: contentRelease,
);
```

Only `StorySaveCompatibilityStatus.exact` and
`StorySaveCompatibilityStatus.compatible` enter the ordinary aggregate-resume
path. `migrationRequired`, `fallbackRequired`, and `incompatible` stop it.
Revision 1 does not expose a one-call aggregate migration API; migration must
produce a coherent aggregate checkpoint and matching binding before normal
aggregate restore resumes. Fallback starts a host-selected recovery/new run and
must not be presented as restoration of the old checkpoint.

Decode/validate and restore:

```dart
final decodedSnapshot = StoryNarrativeRuntimeSnapshotCodec().decodeJson(
  snapshotJson,
  project: project,
  entryPoints: entryPoints,
);

final restored = StoryNarrativeRuntime.restore(
  project: project,
  entryPoints: entryPoints,
  snapshot: decodedSnapshot,
  observers: [observer],
);
```

`StoryNarrativeRuntimeSnapshotCodec.decodeJson(...)` performs aggregate
validation before returning. `StoryNarrativeRuntime.restore(...)` validates
again before publishing the reconstructed runtime, restores retained core
engines and host-action protocols directly, preserves orchestration RNG and
session/observation cursors, and does not replay entry effects, choices,
transitions, random draws, observations, or host-action dispatch.

### Pending host actions after restore

A restored pending request is already committed protocol state. Inspect
`StoryNarrativeSession.pendingHostAction`, reconcile its stable request ID with
the host's external system, and later submit exactly one
`completeHostAction(...)`, `failHostAction(...)`, or `cancelHostAction(...)`
input. If the external outcome is unknown, keep the session in `awaitingHost`;
do not issue a replacement request and treat it as the same operation.

### Failure boundary

The aggregate path fails closed:

- capture during an in-progress serialized operation throws
  `StoryNarrativeOperationException`;
- malformed aggregate data throws
  `StoryNarrativeRuntimeSnapshotFormatException`;
- well-formed but incompatible aggregate data throws
  `StoryNarrativeRuntimeSnapshotCompatibilityException`;
- malformed content binding throws `StoryContentContractFormatException`;
- non-resumable content compatibility statuses stop before ordinary aggregate
  restore;
- failed decode/validation/restore never authorizes a partial runtime or host
  action redispatch.

See [AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)
for the consumer-facing sequence and
[NARRATIVE_RUNTIME_PERSISTENCE_V1.md](NARRATIVE_RUNTIME_PERSISTENCE_V1.md) for
the normative persistence invariants. Example 3 executes the pending-host-action
branch of this lifecycle:
`dart run example/story_narrative_modular_host_action_restore_example.dart`.

## Modular/indexed loading

Large projects can keep a lightweight `StoryProjectIndex` resident instead of
materializing every event body. `StoryEventIndexEntry` maps stable event IDs to
`StoryModuleId` ownership and records outbound event references;
`StoryModuleIndexEntry` declares dependency modules. Stage 8G entry points are
also available from the index before event bodies are loaded.

Hosts implement `StoryModuleLoader` for their own storage technology.
`StoryModuleCache` verifies loaded `StoryNarrativeModule` bodies against the
index, provides bounded caching/prefetch/eviction, and can materialize only the
dependency closure needed by an event or entry point as an ordinary
`StoryProject` slice.

Use `StoryModuleValidator.validateIndex(index)` for whole-project identity and
cross-module reference checks without loading bodies. Cache loading also checks
that a module's event set and outbound-reference summaries still match the
index. After materialization, normal `StoryValidator` and `StoryEngine` APIs
remain the semantic reference.

See [MODULAR_PROJECT_LOADING_V1.md](MODULAR_PROJECT_LOADING_V1.md) for the
normative Stage 8H loading/cache/validation contract.

## Runtime capability compatibility

Stage 8M keeps target compatibility explicit and separate from package/version
heuristics. A project/export declares `StoryRuntimeCapabilityProfile`
requirements; a target reports `StoryRuntimeCapabilities`; the evaluator returns
structured deterministic issues without rewriting either side.

```dart
final profile = StoryRuntimeCapabilityProfile(
  profileId: 'example_rpg',
  profileVersion: 1,
  requiredFeatures: [
    StoryRuntimeFeatureRequirement(
      featureId: StoryRuntimeFeatureId.hostActions,
      minimumRevision: 1,
    ),
  ],
  requiredExtensions: [
    StoryExtensionSchemaRequirement(
      namespace: 'com.example.combat',
      minimumSchemaVersion: 2,
      maximumSchemaVersion: 4,
    ),
  ],
);

final target = StoryRuntimeCapabilities(
  runtimeId: 'example_runtime',
  runtimeVersion: '2.4.0',
  features: [
    StoryRuntimeFeatureCapability(
      featureId: StoryRuntimeFeatureId.hostActions,
      revision: 1,
    ),
  ],
  extensions: [
    StoryRuntimeExtensionCapability(
      namespace: 'com.example.combat',
      schemaVersion: 3,
    ),
  ],
);

final compatibility = StoryRuntimeCompatibilityEvaluator.evaluate(
  profile: profile,
  capabilities: target,
);
```

Use `compatibility.issues` for target/export diagnostics, or
`StoryRuntimeCompatibilityEvaluator.requireCompatible(...)` when an operation
must fail rather than proceed against an incompatible target. Runtime version
strings are diagnostic metadata only.

See [RUNTIME_CAPABILITIES_V1.md](RUNTIME_CAPABILITIES_V1.md) for the normative
feature/extension range semantics and no-silent-downgrade rule.

## Validation

Validate without execution:

```dart
final report = StoryValidator.validate(project);
```

Host-driven projects can add independent orchestration roots for graph analysis
without changing the project itself:

```dart
final report = StoryValidator.validate(
  project,
  additionalEntryEventIds: entryPoints.map((entry) => entry.eventId),
);
```

`StoryValidationReport` contains canonically ordered `StoryDiagnostic` values.
A diagnostic exposes:

- `StoryDiagnosticCode`
- `StoryDiagnosticSeverity`
- `StoryDiagnosticLocation`
- `StoryDiagnosticReference`
- related locations/references
- human-readable message/suggestion helpers

Machine integrations should use code + structured location/reference identity,
not formatted text.

Useful convenience APIs include:

```dart
report.hasErrors;
report.hasWarnings;
report.errorCount;
report.summary;
report.diagnosticsFor(code);
report.format();
```

## Runtime snapshots

Capture:

```dart
final snapshot = engine.createSnapshot();
```

Serialize:

```dart
final codec = StoryRuntimeSnapshotCodec();
final json = codec.encodeJson(snapshot);
```

Decode/restore:

```dart
final decoded = codec.decodeJson(json, project: project);
final restored = StoryEngine.restore(project: project, snapshot: decoded);
```

`StoryRuntimeSnapshot` records committed runtime state. Its metadata and random
state are versioned independently. `StoryRuntimeSnapshotValidator` can validate
snapshot/project compatibility explicitly before restoration when a host needs
that operation separately.

## Story Format v1

### Runtime-only projection

Use convenience methods when authored source is exactly the executable project:

```dart
const codec = StoryFormatCodec();
final bundle = codec.encodeProject(project);
final decoded = codec.decodeProject(bundle);
```

### Lossless authored document

Editors/tools should retain `StoryFormatDocument` so runtime-neutral
organization and opaque extension metadata survive a round trip:

```dart
final document = StoryFormatDocument(project: project);
final bundle = codec.encode(document);
final decoded = codec.decode(bundle);
```

### Logical bundle boundary

`StoryFormatBundle` is a path-to-JSON-text value. `StoryFormatBundleLayout`
defines canonical logical paths. Neither type performs filesystem I/O.

The package deliberately leaves directory/archive/database/network policy to the
host.

### Organization

`StoryFormatOrganization`, `StoryFormatGroup`, and `StoryFormatTag` are
runtime-neutral authoring metadata. Group/tag IDs are stable format identities.
They are not runtime chapter/section semantics.

### Extensions

`StoryFormatExtensionAttachment`, `StoryFormatExtensionNamespace`,
`StoryFormatExtensionPayload`, and the `StoryFormatExtensionTarget` hierarchy
provide explicit opaque namespaced metadata. Unknown core semantics are not
silently accepted as extensions.

See [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) for the normative wire-format
contract.

### Extension schemas

Extension Schema v1 is a separate ecosystem contract for declaring host-owned
semantic capabilities without embedding host code. `StoryExtensionSchema`, its
definition/value types, and `StoryExtensionSchemaCodec` parse and validate that
portable data. They do not register callbacks or make Story Format v1 opaque
extensions executable.

See [EXTENSION_SCHEMA_V1.md](EXTENSION_SCHEMA_V1.md) for the normative schema
wire/data contract.

## Error contracts

### Runtime

`StoryEngineException` is the common runtime error base. Public subclasses:

- `StoryEngineConfigurationException`
- `StoryEngineOperationException`
- `StoryEngineExecutionException`

Failures may carry `operation`, `eventId`, `choiceId`, `cause`, and `suggestion`
context. Treat the typed/context fields as programmatic data; `toString()` is
for humans/logs.

### Host-driven orchestration

`StoryNarrativeRuntimeException` is the common orchestration error base. Public
subclasses distinguish configuration, invalid operation, entry-resolution, and
local-session execution failures:

- `StoryNarrativeConfigurationException`
- `StoryNarrativeOperationException`
- `StoryNarrativeResolutionException`
- `StoryNarrativeExecutionException`

### Suspendable host-action protocol

- `StoryHostActionProtocolException`: invalid request/re-entry/resolution input.
- `StoryHostActionProtocolSnapshotFormatException`: malformed or unsupported
  protocol-snapshot JSON.

### Story Format

- `StoryFormatCodecException`: malformed/invalid current-format bundle data.
- `StoryFormatCompatibilityException`: format identity/version incompatibility.
- `StoryFormatCompatibilityIssue`: machine-readable compatibility category.

### Extension Schema

- `StoryExtensionSchemaFormatException`: malformed, unsupported, or invalid
  Extension Schema v1 data.

### Runtime capability compatibility

- `StoryRuntimeCapabilityFormatException`: malformed/unsupported capability
  profile or runtime-report JSON.
- `StoryRuntimeCompatibilityException`: a caller explicitly required a
  compatible target but the deterministic report contains one or more issues.
- `StoryRuntimeCompatibilityIssueCode`: stable missing/too-low/too-high
  diagnostic category.

### Runtime snapshot persistence

- `StoryRuntimeSnapshotFormatException`: malformed snapshot representation.
- `StoryRuntimeSnapshotCompatibilityException`: well-formed incompatible
  snapshot.
- `StoryRuntimeSnapshotCompatibilityIssue`: machine-readable compatibility
  category.

### Aggregate narrative snapshot persistence

- `StoryNarrativeRuntimeSnapshotFormatException`: malformed aggregate snapshot
  representation, including path-prefixed nested representation failures.
- `StoryNarrativeRuntimeSnapshotCompatibilityException`: well-formed aggregate
  checkpoint/configuration incompatibility.
- `StoryNarrativeRuntimeSnapshotCompatibilityIssue`: machine-readable
  aggregate compatibility category.

## Stage 8N production foundations

Stable presentation-unit identity is defined by
`StoryPresentationIdentityCatalog` and its deterministic sidecar codec. The
identity remains independent from visible source text and frozen Story Format
v1; `sourceRevision` is explicit monotonic production metadata rather than a
clock-derived timestamp.

`StoryNarrativeRuntime` can receive non-authoritative `StoryNarrativeObserver`
instances. Observations expose deterministic runtime-local sequence order and
stable narrative IDs for debugger, QA, or host telemetry adapters. Observer
failures do not alter narrative state, RNG, route selection, or host-action
semantics. See `PRESENTATION_IDENTITY_V1.md` and
`RUNTIME_IMPLEMENTER_CONTRACT_V1.md`.

## Public API index

The following is the complete top-level public inventory exposed by
`package:story_engine/story_engine.dart`. Member-level methods, constructors,
fields, and enum values are documented in Dartdoc.

<!-- PUBLIC_API_INDEX_START -->
<!-- Generated from lib/story_engine.dart; keep symbol coverage synchronized. -->
### Identity

- `StoryAlias`
- `StoryChoiceId`
- `StoryContentReleaseId`
- `StoryEntryPointId`
- `StoryEventId`
- `StoryHostActionRequestId`
- `StoryModuleId`
- `StoryModuleVersion`
- `StoryPresentationUnitId`
- `StoryProjectId`
- `StoryVariableId`

### Authored model

- `StoryChoice`
- `StoryEvent`
- `StoryProject`

### Presentation

- `StoryChoicePresentation`
- `StoryEventPresentation`
- `StoryText`

### Presentation identity

- `StoryPresentationUnitKind`
- `StoryPresentationUnitLocation`
- `StoryPresentationUnitRecord`
- `StoryPresentationIdentityCatalog`
- `StoryPresentationIdentityCatalogCodec`
- `StoryPresentationIdentityFormatException`

### State

- `StoryState`
- `StoryStateSchema`
- `StoryValue`
- `StoryBooleanValue`
- `StoryIntegerValue`
- `StoryNumberValue`
- `StoryStringValue`
- `StoryValueType`
- `StoryVariableDefinition`

### Conditions

- `StoryCondition`
- `StoryAllCondition`
- `StoryAnyCondition`
- `StoryNotCondition`
- `StoryVariableIsSetCondition`
- `StoryVariableIsUnsetCondition`
- `StoryComparisonOperator`
- `StoryVariableComparisonCondition`
- `StoryConditionContext`
- `StoryConditionEvaluator`
- `StoryConditionEvaluationException`

### Effects

- `StoryEffect`
- `StorySetVariableEffect`
- `StoryUnsetVariableEffect`
- `StoryIncrementVariableEffect`
- `StoryDecrementVariableEffect`

### Narrative explainability

- `StoryConditionExplanationKind`
- `StoryConditionExplanation`
- `StoryAllConditionExplanation`
- `StoryAnyConditionExplanation`
- `StoryNotConditionExplanation`
- `StoryVariableIsSetConditionExplanation`
- `StoryVariableIsUnsetConditionExplanation`
- `StoryVariableComparisonConditionExplanation`
- `StoryChoiceExplanation`
- `StoryHostConditionExplanationStatus`
- `StoryHostConditionExplanation`
- `StoryEntryPointCandidateStatus`
- `StoryEntryPointExplanation`
- `StoryEntryPointSelectionMethod`
- `StoryEntryPointFinalistExplanation`
- `StoryEntryPointResolutionExplanation`
- `StoryEffectOperation`
- `StoryEffectOutcome`
- `StoryEffectOwnerKind`
- `StoryEffectSource`
- `StoryEffectExplanation`

### Runtime execution and shared-state explanations

- `StoryRuntimeExecutionOutcome`
- `StoryRuntimeEventFlow`
- `StoryRuntimeExplanationStep`
- `StoryEventAvailabilityExplanation`
- `StoryEventTraversalExplanation`
- `StoryRuntimeChoiceExplanation`
- `StoryRuntimeEffectExplanation`
- `StoryAutomaticTraversalExplanation`
- `StoryTransitionBranchExplanation`
- `StoryConditionalTransitionExplanation`
- `StoryWeightedTransitionExplanation`
- `StoryEventTransitionExplanation`
- `StoryTerminalTransitionExplanation`
- `StoryRuntimeExecutionExplanation`
- `StoryPersistentVariableChange`
- `StoryPersistentStateCommitExplanation`

### Transitions

- `StoryTransition`
- `StoryEventTransition`
- `StoryConditionalTransitionBranch`
- `StoryConditionalTransition`
- `StoryWeightedTransitionOption`
- `StoryWeightedTransition`
- `StoryTerminalTransition`

### Runtime

- `StoryEngine`
- `StoryEngineException`
- `StoryEngineConfigurationException`
- `StoryEngineOperationException`
- `StoryEngineExecutionException`
- `StoryEngineStatus`
- `StoryRuntimeStep`
- `StoryEventEnteredStep`
- `StoryEventContinuedStep`
- `StoryChoiceSelectedStep`
- `StoryRuntimeHistory`
- `StoryRuntimeSnapshotMetadata`
- `StoryRuntimeRandomState`
- `StoryRuntimeSnapshot`
- `StoryRuntimeSnapshotCompatibilityIssue`
- `StoryRuntimeSnapshotCompatibilityException`
- `StoryRuntimeSnapshotValidator`

### Suspendable host actions

- `StoryHostActionValueKind`
- `StoryHostActionValueType`
- `StoryHostActionRequest`
- `StoryHostActionOutcome`
- `StoryHostActionCompleted`
- `StoryHostActionFailed`
- `StoryHostActionCancelled`
- `StoryHostActionProtocolStatus`
- `StoryHostActionProtocolSnapshot`
- `StoryHostActionProtocol`
- `StoryHostActionProtocolException`
- `StoryHostActionProtocolSnapshotCodec`
- `StoryHostActionProtocolSnapshotFormatException`

### Runtime snapshot persistence

- `StoryRuntimeSnapshotFormatException`
- `StoryRuntimeSnapshotCodec`

### Modular/indexed loading

- `StoryModuleIndexEntry`
- `StoryEventIndexEntry`
- `StoryProjectIndex`
- `StoryNarrativeModule`
- `StoryModuleLoader`
- `StoryModuleLoadException`
- `StoryModuleValidationCode`
- `StoryModuleValidationIssue`
- `StoryModuleValidationReport`
- `StoryModuleValidator`
- `StoryModuleCache`

### Host-driven orchestration

- `StoryNarrativeInput`
- `StoryNarrativeChoiceInput`
- `StoryNarrativeContinueInput`
- `StoryNarrativeHostActionCompletedInput`
- `StoryNarrativeHostActionFailedInput`
- `StoryNarrativeHostActionCancelledInput`
- `StoryHostConditionKey`
- `StoryHostConditionRequirement`
- `StoryHostContext`
- `StoryEntryPoint`
- `StoryNarrativeRuntime`
- `StoryNarrativeRuntimeSnapshotMetadata`
- `StoryNarrativeRuntimeSnapshot`
- `StoryNarrativeRuntimeSnapshotCodec`
- `StoryNarrativeRuntimeSnapshotFormatException`
- `StoryNarrativeRuntimeSnapshotCompatibilityIssue`
- `StoryNarrativeRuntimeSnapshotCompatibilityException`
- `StoryNarrativeRuntimeSnapshotValidator`
- `StoryNarrativeSessionStatus`
- `StoryNarrativeSessionSnapshot`
- `StoryNarrativeSession`
- `StoryNarrativeSessionHistory`
- `StoryNarrativeRuntimeHistory`
- `StoryNarrativeRuntimeException`
- `StoryNarrativeConfigurationException`
- `StoryNarrativeOperationException`
- `StoryNarrativeResolutionException`
- `StoryNarrativeExecutionException`

### Runtime observability

- `StoryNarrativeDebugAdapter`
- `StoryNarrativeObserver`
- `StoryNarrativeObservation`
- `StoryNarrativeSessionStarted`
- `StoryNarrativeEventEntered`
- `StoryNarrativeChoicePresented`
- `StoryNarrativeChoiceSelected`
- `StoryNarrativeHostActionRequested`
- `StoryNarrativeHostActionResolution`
- `StoryNarrativeHostActionCompleted`
- `StoryNarrativeSessionEnded`
- `StoryNarrativeErrorCategory`
- `StoryNarrativeError`

### Runtime bundle builds

- `StoryContentHash`
- `StoryRuntimeArtifactDescriptor`
- `StoryRuntimeModuleArtifactDescriptor`
- `StoryRuntimeBundleManifest`
- `StoryRuntimeBundleManifestCodec`
- `StoryRuntimeBundleManifestFormatException`
- `StoryRuntimeBundleLayout`
- `StoryRuntimeBundle`
- `StoryRuntimeBundleBuilder`
- `StoryRuntimeBundleBuildException`

### Content versioning and save compatibility

`StorySaveContentBinding.fromSnapshot(...)` binds one core runtime checkpoint.
For a Stage 9A aggregate narrative checkpoint, use
`StorySaveContentBinding.fromRetainedSessionSnapshots(...)` with
`snapshot.projectId` and the retained sessions' core snapshots in retained
order. The resulting companion binding is encoded with the existing
`StorySaveContentBindingCodec` and evaluated with the existing explicit
compatibility categories before aggregate restore.

- `StoryModuleRevisionReference`
- `StoryContentModuleRevision`
- `StoryContentReleaseManifest`
- `StoryContentReleaseManifestCodec`
- `StoryContentPatchOperationKind`
- `StoryContentPatchOperation`
- `StoryContentPatchManifest`
- `StoryContentPatchPlanner`
- `StoryContentPatchManifestCodec`
- `StorySaveContentBinding`
- `StorySaveContentBindingCodec`
- `StoryContentMigrationPlan`
- `StoryContentMigrationPlanCodec`
- `StorySaveCompatibilityStatus`
- `StorySaveCompatibilityResult`
- `StorySaveContentCompatibilityEvaluator`
- `StoryContentMigrationException`
- `StoryRuntimeSnapshotContentMigrator`
- `StoryContentContractFormatException`

### Runtime capability and extension compatibility

- `StoryRuntimeFeatureId`
- `StoryRuntimeFeatureRequirement`
- `StoryExtensionSchemaRequirement`
- `StoryRuntimeCapabilityProfile`
- `StoryRuntimeFeatureCapability`
- `StoryRuntimeExtensionCapability`
- `StoryRuntimeCapabilities`
- `StoryRuntimeCapabilityProfileCodec`
- `StoryRuntimeCapabilitiesCodec`
- `StoryRuntimeCapabilityFormatException`
- `StoryRuntimeCompatibilityIssueCode`
- `StoryRuntimeCompatibilityIssue`
- `StoryRuntimeCompatibilityReport`
- `StoryRuntimeCompatibilityException`
- `StoryRuntimeCompatibilityEvaluator`

### Validation

- `StoryDiagnosticIdentity`
- `StoryDiagnostic`
- `StoryDiagnosticCode`
- `StoryDiagnosticLocationKind`
- `StoryDiagnosticPathSegment`
- `StoryDiagnosticFieldPathSegment`
- `StoryDiagnosticIndexPathSegment`
- `StoryDiagnosticLocation`
- `StoryDiagnosticReferenceKind`
- `StoryDiagnosticReference`
- `StoryDiagnosticSeverity`
- `StoryValidationReport`
- `StoryValidator`

### Story Format v1

- `StoryFormatBundle`
- `StoryFormatBundleLayout`
- `StoryFormatCodec`
- `StoryFormatCodecException`
- `StoryFormatCompatibilityIssue`
- `StoryFormatCompatibilityException`
- `StoryFormatDocument`
- `StoryFormatExtensionAttachment`
- `StoryFormatExtensionNamespace`
- `StoryFormatExtensionPayload`
- `StoryFormatExtensionTarget`
- `StoryFormatProjectExtensionTarget`
- `StoryFormatEventExtensionTarget`
- `StoryFormatChoiceExtensionTarget`
- `StoryFormatVariableExtensionTarget`
- `StoryFormatGroupExtensionTarget`
- `StoryFormatTagExtensionTarget`
- `StoryFormatGroup`
- `StoryFormatGroupId`
- `StoryFormatMetadata`
- `StoryFormatOrganization`
- `StoryFormatTag`
- `StoryFormatTagId`

### Extension Schema v1

- `StoryExtensionSchema`
- `StoryExtensionSchemaMetadata`
- `StoryExtensionActionDefinition`
- `StoryExtensionConditionDefinition`
- `StoryExtensionEnumDefinition`
- `StoryExtensionEnumValueDefinition`
- `StoryExtensionReferenceTypeDefinition`
- `StoryExtensionParameterTypeKind`
- `StoryExtensionParameterType`
- `StoryExtensionParameterDefinition`
- `StoryExtensionSchemaCodec`
- `StoryExtensionSchemaFormatException`
- `StoryProjectAnalysis`
- `StoryEventReference`
- `StoryAnalysisFlowKind`
- `StoryVariableUse`
- `StoryVariableUseKind`
- `StoryGraphAnalysis`
- `StoryGraphCycle`
- `StoryValidationContext`
- `StoryValidationMode`
<!-- PUBLIC_API_INDEX_END -->

## Deliberately not public

The package keeps these implementation concerns behind `lib/src/`:

- state mutation machinery;
- effect executors;
- transition resolution objects;
- seeded RNG implementation;
- Story Format/runtime-snapshot migration pipelines;
- the old draft serialization codec;
- individual validation rule-family implementations;
- provisional section vocabulary.

Do not build consumer integrations around those internals.

## Where to go next

Follow the same onboarding order used by the README and Quick Start:

- [QUICK_START.md](QUICK_START.md) for the first validated `StoryEngine`
  integration.
- [../example/README.md](../example/README.md) for the executable Pure-Dart core
  walkthrough and all four examples, including commands and expected results.
- [NARRATIVE_WALKTHROUGH.md](NARRATIVE_WALKTHROUGH.md) for the player-facing
  Forest Gate story mapped to runtime behavior.
- [INTEGRATION_PATH.md](INTEGRATION_PATH.md) for the canonical documentation map
  and the point at which an integration should move from `StoryEngine` to
  `StoryNarrativeRuntime`.
- [ABSTRACTION_GUIDE.md](ABSTRACTION_GUIDE.md) for the compact "which
  abstraction do I need?" relationship map before opening narrower contracts.
- [AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)
  before implementing durable save/load for `StoryNarrativeRuntime`.
- A source-repository checkout's `example/flutter_story_app/` for a downstream
  Flutter host using the same core public API; the nested app is not included in
  the pub.dev archive and is not an orchestration example.
- [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) for authored format interoperability.
- [EXTENSION_SCHEMA_V1.md](EXTENSION_SCHEMA_V1.md) for portable host-capability
  schema declarations.
- [OPEN_WORLD_ORCHESTRATION_V1.md](OPEN_WORLD_ORCHESTRATION_V1.md) and
  [SESSION_EXECUTION_V1.md](SESSION_EXECUTION_V1.md) for host-driven entry
  resolution and current multi-session authority semantics.
- [HOST_ACTION_PROTOCOL_V1.md](HOST_ACTION_PROTOCOL_V1.md) for suspendable host
  interactions and restored pending-request behavior.
- [MODULAR_PROJECT_LOADING_V1.md](MODULAR_PROJECT_LOADING_V1.md) for indexed
  module loading, verification, caching, and project-slice semantics.
- [RUNTIME_BUNDLE_BUILD_V1.md](RUNTIME_BUNDLE_BUILD_V1.md) for deterministic
  compiled-artifact packaging, hashes, manifests, and bundle identity.
- [CONTENT_VERSIONING_V1.md](CONTENT_VERSIONING_V1.md) for release/module
  revision identity, patch manifests, save bindings, and migration/fallback
  policy.
- [RUNTIME_CAPABILITIES_V1.md](RUNTIME_CAPABILITIES_V1.md) for project capability
  profiles, runtime reports, extension-version negotiation, and target
  diagnostics.
- [PERFORMANCE_BASELINES.md](PERFORMANCE_BASELINES.md) for reproducible scale
  workloads and same-machine performance comparison.
- Generated Dart API documentation for exact member signatures.

## Complete execution explanations

Use `StoryEngine.startWithExplanations`, `startAtWithExplanations`,
`chooseWithExplanations`, or `continueStoryWithExplanations` to execute once and
receive a `StoryRuntimeExecutionExplanation`. Do not execute an ordinary input
first and then execute the explanation-returning input to inspect it: that would
submit a second input. When an input throws, inspect `lastExecutionExplanation`
for its completed causal prefix; the original exception remains authoritative.
Ordinary inputs and the existing effect-only APIs clear that retained trace.

The immutable `steps` list records event availability, selected-choice
availability, effect attempts, event traversal, automatic guard checks,
conditional branch results/fallback selection, weighted samples, and concrete
transition outcomes in actual execution order. Transition locations reuse
`StoryDiagnosticLocation` data with full authored field/index paths; these
runtime records are separate from static `StoryDiagnostic` validation findings.

For orchestration, override the optional adapter's `onExecutionExplanation`
and `onPersistentStateCommitExplanation` callbacks. Execution callbacks reflect
the aggregate outcome, including rollback after core execution succeeds. Shared
commit callbacks identify the source session, old/new revision, net variable
changes in schema order, and propagated sibling session indexes in active order.
They occur only after successful changed-state commits. Callback order is effect
batch, execution trace, optional shared commit, then ordinary session progress.
Every callback runs under serialized authority and is exception-isolated.

Neither diagnostic channel changes lifecycle sequence numbers, Story Format v1,
snapshots, RNG consumption, host-action identity, or restore behavior. Restore
attaches a new adapter for future input and never replays old traces/commits.

## Reusable authored analysis and validation contexts

`StoryProjectAnalysis.analyze(project)` builds immutable incoming/outgoing
transition references and variable readers/writers with typed authored locations.
Use `analysis.graphFrom(entryEventIds)` for structural reachability, cyclic regions,
possible terminal paths, and incomplete boundaries. Every authored alternative
is considered; these results do not predict state-dependent runtime reachability.

`StoryValidator.validate(project)` retains standalone validation by default.
Pass `StoryValidationContext.orchestration(entryEventIds: roots)` for host-driven
activations or `StoryValidationContext.moduleSlice(knownExternalEventIds: ids,
entryEventIds: roots)` for partial module bodies. The latter accepts only explicitly
known external destinations. Shared-state contexts assume each variable can be
set or unset on activation, rather than assuming its initial value still applies.

See [Authored analysis and validation](AUTHORED_ANALYSIS_AND_VALIDATION.md)
and the runnable `example/authored_analysis_and_validation.dart`.
