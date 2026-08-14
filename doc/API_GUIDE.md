# story_engine API Guide

This guide describes the supported public package surface for the current alpha
release. Member-level signatures and details live in Dartdoc; this document
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

```text
Authored semantic model
  StoryProject / StoryEvent / StoryChoice
  state schema / conditions / effects / transitions
                |
                v
Static validation ----------------------+
  StoryValidator                        |
                |                       |
                v                       |
Runtime                                 |
  StoryEngine -> immutable StoryState   |
                |                       |
                +-> StoryRuntimeSnapshot|
                                        |
Story Format v1                         |
  StoryFormatDocument / Bundle / Codec -+
```

Story Format persists authored data. Runtime snapshots persist one playthrough.
They are separate contracts and must not be treated as interchangeable.

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
sequence. Automatic traversal has a guard controlled by
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

## Validation

Validate without execution:

```dart
final report = StoryValidator.validate(project);
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

## Error contracts

### Runtime

`StoryEngineException` is the common runtime error base. Public subclasses:

- `StoryEngineConfigurationException`
- `StoryEngineOperationException`
- `StoryEngineExecutionException`

Failures may carry `operation`, `eventId`, `choiceId`, `cause`, and `suggestion`
context. Treat the typed/context fields as programmatic data; `toString()` is
for humans/logs.

### Story Format

- `StoryFormatCodecException`: malformed/invalid current-format bundle data.
- `StoryFormatCompatibilityException`: format identity/version incompatibility.
- `StoryFormatCompatibilityIssue`: machine-readable compatibility category.

### Runtime snapshot persistence

- `StoryRuntimeSnapshotFormatException`: malformed snapshot representation.
- `StoryRuntimeSnapshotCompatibilityException`: well-formed incompatible
  snapshot.
- `StoryRuntimeSnapshotCompatibilityIssue`: machine-readable compatibility
  category.

## Public API index

The following is the complete top-level public inventory exposed by
`package:story_engine/story_engine.dart`. Member-level methods, constructors,
fields, and enum values are documented in Dartdoc.

<!-- PUBLIC_API_INDEX_START -->
<!-- Generated from lib/story_engine.dart; keep symbol coverage synchronized. -->
### Identity

- `StoryAlias`
- `StoryChoiceId`
- `StoryEventId`
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

### Runtime snapshot persistence

- `StoryRuntimeSnapshotFormatException`
- `StoryRuntimeSnapshotCodec`

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

- [../example/README.md](../example/README.md) for the executable Pure-Dart
  consumer walkthrough.
- A source-repository checkout's `example/flutter_story_app/` for a downstream
  Flutter host using the same public API; the nested app is not included in the
  pub.dev archive.
- [QUICK_START.md](QUICK_START.md) for a guided first integration.
- [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) for authored format interoperability.
- [PERFORMANCE_BASELINES.md](PERFORMANCE_BASELINES.md) for reproducible scale
  workloads and same-machine performance comparison.
- Generated Dart API documentation for exact member signatures.
