# story_engine

Run branching stories, dialogue and event-driven narratives in Dart. Define
events and choices, track typed story state, and let `story_engine` apply
conditions, effects and transitions.

The same project, explicit inputs and seed produce reproducible outcomes.
Save/restore resumes committed state, history and randomness without applying
committed effects again. Your host owns the UI, player input, external actions
and storage; the package has no Flutter dependency.

> **Status:** 0.9.1, pre-1.0. Story Format v1 is frozen; the Dart API can still
> evolve before 1.0. See the [release baseline](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RELEASE_0_9_0.md)
> for 0.9.0 and the [0.9.1 patch notes](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/CHANGELOG.md).
> For earlier versions, see the [0.9.0 upgrade notes](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/UPGRADING_TO_0_9_0.md).

Requires Dart SDK `>=3.11.0 <4.0.0`. Licensed under
[BSD 3-Clause](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/LICENSE).
[Source repository](https://github.com/ErikSchultheiss/story_engine).

## Start here: canonical integration path

Read the [Quick Start](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/QUICK_START.md)
and run the first example from a checkout of this package:

```sh
dart pub get
dart run example/story_engine_example.dart
```

It validates a small Forest Gate story, lights a lantern, performs snapshot JSON encode/decode,
restores the paused run and finishes it. The output includes
`Restored lantern_lit = true` and `Finished status: terminated`.
The [minimal program below](#quick-start) is the starting point for your own
Dart or Flutter host.

For a story-led explanation of the same example, follow
[A lantern at the Forest Gate](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/NARRATIVE_WALKTHROUGH.md):
passages and choices, conditions and effects, then saving and resuming inside
the tunnel.

### Choose the execution authority

| Your host needs | Start with | Save and restore |
| --- | --- | --- |
| One local story run | `StoryEngine` | `StoryRuntimeSnapshot` and `StoryEngine.restore(...)` |
| Named/resolved entry points, several unfinished sessions, shared persistent state or suspendable host actions | `StoryNarrativeRuntime` | One complete `StoryNarrativeRuntimeSnapshot`; restore the aggregate authority |

Start with the core example to learn the event/choice model. If orchestration
fits your host, follow the [API Guide](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/API_GUIDE.md)
and the shared-state example below. Before implementing durable orchestration
persistence, read the [Aggregate Save/Load Lifecycle](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md).
Retained session snapshots are components of the aggregate checkpoint; do not
restore them independently and reassemble the runtime.

Use the [Abstraction Guide](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/ABSTRACTION_GUIDE.md)
for the roles of projects, bundles, modules and sessions, or the
[Integration Path](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/INTEGRATION_PATH.md)
for the complete reading order. Add advanced contracts as your host needs them.

## What it does

- Runs authored events and choices with typed scalar state, conditions, effects
  and direct, conditional, weighted or terminal transitions.
- Uses seeded randomness and transactional execution for repeatable runs and
  atomic rollback when an operation fails.
- Validates authored content and exposes immutable reference, variable-use and
  structural graph analysis without running the story.
- Saves and restores standalone runs or complete multi-session narrative
  authority, including pending host-action identities.
- Supports optional modular loading, verified caching, structured observations
  and explanations through the same public package boundary.
- Reads and writes portable Story Format v1 bundles and declarative Extension
  Schema v1 data. The host supplies trusted external implementations.

## Requirements

- Dart SDK `>=3.11.0 <4.0.0`
- No Flutter dependency

For a host using the published 0.9.1 release:

```yaml
dependencies:
  story_engine: 0.9.1
```

For a repository checkout during development, a local path dependency remains
useful:

```yaml
dependencies:
  story_engine:
    path: ../story_engine
```

Consumer code should import only the package root:

```dart
import 'package:story_engine/story_engine.dart';
```

Anything under `package:story_engine/src/` is implementation detail and is not
supported consumer API.

## Quick start

After adding the dependency to your own Dart project, save this program as
`bin/first_story.dart`. It uses the supported public import and runs one choice
to completion:

```dart
import 'package:story_engine/story_engine.dart';

void main() {
  final startId = StoryEventId('start');
  final leaveId = StoryChoiceId('leave');

  final project = StoryProject(
    id: StoryProjectId('tiny_adventure'),
    entryEventId: startId,
    events: [
      StoryEvent(
        id: startId,
        presentation: StoryEventPresentation(
          body: const StoryText('You stand at the forest gate.'),
        ),
        choices: [
          StoryChoice(
            id: leaveId,
            presentation: const StoryChoicePresentation(
              text: StoryText('Turn back'),
            ),
            transition: const StoryTerminalTransition(),
          ),
        ],
      ),
    ],
  );

  final report = StoryValidator.validate(project);
  if (report.hasErrors) {
    throw StateError(report.format());
  }

  final engine = StoryEngine(project: project)..start();

  print(engine.currentEvent?.presentation?.body?.value);
  for (final choice in engine.availableChoices) {
    print('- ${choice.presentation?.text.value}');
  }

  engine.choose(leaveId);
  print(engine.status); // StoryEngineStatus.terminated
}
```

Run it from that host project's root:

```sh
dart run bin/first_story.dart
```

Expected output:

```text
You stand at the forest gate.
- Turn back
StoryEngineStatus.terminated
```

Continue with the [Quick Start](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/QUICK_START.md)
for scalar state, validation and save/restore.

## Four runnable Pure-Dart examples

Run these commands from the package checkout root after `dart pub get`.
Each example imports only `package:story_engine/story_engine.dart`.

| Example | Run command | What you will see |
| --- | --- | --- |
| [Core story and save/load](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/example/story_engine_example.dart) | `dart run example/story_engine_example.dart` | A branching lantern story, a committed snapshot, restoration and termination. |
| [Shared-state orchestration example](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/example/story_narrative_shared_state_example.dart) | `dart run example/story_narrative_shared_state_example.dart` | Opening a gate in one session updates the choices of another unfinished session. |
| [Modular host-action restoration](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/example/story_narrative_modular_host_action_restore_example.dart) | `dart run example/story_narrative_modular_host_action_restore_example.dart` | A pending host request survives aggregate restore and is reconciled without redispatch. |
| [Authored analysis and validation](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/example/authored_analysis_and_validation.dart) | `dart run example/authored_analysis_and_validation.dart` | A module validates with a known external destination while graph analysis reports its incomplete local boundary. |

The core example keeps authored Story Format serialization separate from saving
a runtime playthrough. The shared-state example focuses on execution authority;
the modular example adds aggregate persistence and host-action reconciliation.
See [example/README.md](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/example/README.md)
for the purpose and walkthrough of each example, then
[authored analysis and validation](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/AUTHORED_ANALYSIS_AND_VALIDATION.md)
for module-slice policy.

All four canonical Pure-Dart examples are executed by the package test suite
through `test/example/stage9b6_public_examples_ci_test.dart`. The examples are
scripted and reproducible; your host chooses how to present choices and collect
player input.

## Flutter developer example

The source-repository checkout also contains a downstream Flutter app at
`example/flutter_story_app/`. It is intentionally excluded from the pub.dev
archive so that publishing this Pure-Dart package does not bundle a nested
Flutter package. In a repository checkout, run from that directory:

```text
flutter pub get
flutter run -d chrome
```

The app shows how Flutter owns widgets, input, error presentation, and
persistence policy around the same public root API. It includes widget tests;
snapshot JSON is kept in memory so the example does not prescribe a storage
plugin.

## Core workflow

The normal application workflow is deliberately small:

```dart
final report = StoryValidator.validate(project);
if (report.hasErrors) {
  print(report.format());
  return;
}

final engine = StoryEngine(project: project)..start();

while (engine.status == StoryEngineStatus.awaitingChoice) {
  final choices = engine.availableChoices;
  // Present choices in your UI, then select by stable ID.
  engine.choose(choices.first.id);
}
```

A host-visible event with no choice uses `StoryEngineStatus.awaitingContinue`
and `engine.continueStory()`. Automatic events are resolved synchronously by the
engine until it reaches a choice, a continue point, or termination.

## Validation

Validation is static and does not mutate or execute the project:

```dart
final report = StoryValidator.validate(project);

print(report.summary);
for (final diagnostic in report.diagnostics) {
  print(diagnostic.format());
}
```

Use structured fields such as diagnostic code, location, references, and
severity for tooling. `message`, `suggestion`, and `format()` are developer-facing
presentation helpers rather than compatibility identity.

## Save and restore

Runtime snapshots preserve committed state, traversal history, deterministic RNG
state, and execution-affecting runtime configuration:

```dart
final snapshotCodec = StoryRuntimeSnapshotCodec();
final saveJson = snapshotCodec.encodeJson(engine.createSnapshot());

final snapshot = snapshotCodec.decodeJson(
  saveJson,
  project: project,
);
final restored = StoryEngine.restore(
  project: project,
  snapshot: snapshot,
);
```

The host application decides where that JSON is stored. `story_engine` does not
own files, preferences, databases, or cloud synchronization.

## Story Format v1

For executable-project-only workflows:

```dart
const codec = StoryFormatCodec();
final bundle = codec.encodeProject(project);
final decodedProject = codec.decodeProject(bundle);
```

For editors or round-trip tooling that must preserve organization and opaque
extension metadata, use `StoryFormatDocument` with `StoryFormatCodec.encode()` /
`decode()` instead.

`StoryFormatBundle` is a logical map of portable relative paths to JSON text; it
intentionally does not perform filesystem/archive I/O. The normative format
specification is **[Story Format v1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/STORY_FORMAT_V1.md)**.

## Extension Schema v1

Host/game integrations can describe custom actions, conditions, enums, and
reference types as portable data without embedding implementation code:

```dart
const schemaCodec = StoryExtensionSchemaCodec();
final schema = schemaCodec.decodeJson(schemaJson);

print(schema.namespace);
print(schema.actions.map((action) => action.id));
```

Parsing a schema does not register or execute host callbacks. The normative
contract and safe unknown-extension behavior are specified in **[Extension
Schema — Contract Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/EXTENSION_SCHEMA_V1.md)**.

## Host-driven narrative sessions

Open-world/game hosts can activate independent local narrative flows without
connecting every dialogue into one global graph:

```dart
final questDone = StoryHostConditionKey('quest_done');
final runtime = StoryNarrativeRuntime(
  project: project,
  entryPoints: [
    StoryEntryPoint(
      id: StoryEntryPointId('entry_blacksmith'),
      eventId: StoryEventId('evt_blacksmith'),
      hostConditions: [
        StoryHostConditionRequirement(
          key: questDone,
          schemaNamespace: 'com.example.world',
          conditionId: 'quest_completed',
          arguments: const {'quest': 'dragon_hunt'},
        ),
      ],
    ),
  ],
);

final session = runtime.resolveAndStartSession(
  hostContext: StoryHostContext(
    conditionResults: {questDone: true},
  ),
);
```

The host owns world traversal; `StoryNarrativeRuntime` owns deterministic
entry-point resolution, persistent scalar narrative state, and local
`StoryNarrativeSession` execution. Stage 8J now permits multiple unfinished
sessions while serializing shared-state operations in explicit authority input
order. A session waiting on host work does not block unrelated sessions.

For static graph analysis, pass the entry-point destination IDs through
`StoryValidator.validate(..., additionalEntryEventIds: ...)` so intentionally
host-activated dialogue roots are not mislabeled unreachable.

See **[Open-World Narrative Orchestration — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/OPEN_WORLD_ORCHESTRATION_V1.md)** for priority/fallback/weighted resolution,
explicit host facts, session history, and RNG-scope semantics.

The complete orchestration runtime has one supported durable-resume path:
checkpoint the aggregate authority, persist any companion content binding in the
same logical save revision, preflight content compatibility, decode/validate the
aggregate checkpoint, then restore the authority directly.

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
// Persist snapshotJson + bindingJson atomically as one host-owned save revision.
```

On load, content `exact`/`compatible` results may proceed to aggregate decode and
`StoryNarrativeRuntime.restore(...)`. `migrationRequired`, `fallbackRequired`,
and `incompatible` stop the ordinary aggregate-resume path. Restoring a pending
host action never redispatches external work; the host reconciles the stable
request ID after restore and supplies one explicit resolution.

Do not rebuild a `StoryNarrativeRuntime` by restoring retained sessions
independently. Per-session snapshots are components of the aggregate checkpoint
and do not carry the orchestration RNG, shared-state authority, allocation
cursors, observation cursor, sibling membership, or aggregate invariants.

See **[Aggregate Narrative Save/Load Lifecycle — Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)** for the supported host sequence and
failure handling, and **[Narrative Runtime Persistence — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/NARRATIVE_RUNTIME_PERSISTENCE_V1.md)** for the normative checkpoint
semantics.

## Deterministic runtime bundles

Large shipping projects can keep Story Format as readable authored source while
producing separate indexed/module-oriented runtime artifacts:

```dart
final bundle = const StoryRuntimeBundleBuilder().build(
  index: projectIndex,
  compiledIndexBytes: compiledIndexBytes,
  compiledModuleBytes: compiledModuleBytes,
  buildProfile: 'my-runtime-profile-v1',
  builderId: 'my-narrative-builder',
  builderVersion: '1.0.0',
);
```

The Stage 8K reference packager does not define a production compiler. It takes
already-compiled deterministic bytes, verifies the Stage 8H module set, hashes
artifacts with SHA-256, emits a canonical manifest, and derives a reproducible
bundle identity. Story Format remains the editable source of truth.

See **[Runtime Bundle Build Pipeline — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RUNTIME_BUNDLE_BUILD_V1.md)**.

## Content releases, patches, and save compatibility

Stage 8L layers explicit content revision identity over deterministic runtime
bundles without changing Story Format or the core runtime-snapshot wire format.
A `StoryContentReleaseManifest` records opaque release/module version labels,
exact module SHA-256 hashes, dependencies, and exact older revisions explicitly
declared safe for unchanged save restoration.

`StoryContentPatchPlanner` derives transport-neutral module add/replace/remove
operations between releases. A `StorySaveContentBinding` can be stored beside a
`StoryRuntimeSnapshot` to name only the module revisions the committed route
actually references. Compatibility is exact or explicitly declared; version
ordering is never guessed.

When stable authored IDs must change, `StoryContentMigrationPlan` can declare
event/choice redirects and an explicit safe fallback entry point. Fallback is
host-owned and is never silently treated as successful restoration.

See **[Content Versioning, Patching, and Save Compatibility — Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/CONTENT_VERSIONING_V1.md)**.

## Determinism and randomness

`StoryEngine(project: project)` uses the deterministic default random seed `0`.
Pass an explicit `randomSeed` when you want a specific run sequence:

```dart
final engine = StoryEngine(
  project: project,
  randomSeed: 12345,
)..start();
```

A restored engine resumes from the RNG state stored in its snapshot, not by
restarting from the original seed. The exact cross-runtime algorithm, bounded
sampling rules, and reference vectors are specified in
**[Deterministic Randomness — `story_engine.lcg32` Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/DETERMINISTIC_RANDOM_V1.md)**.

## Error handling

The package distinguishes common failure domains:

- `StoryEngineException` and its subclasses: runtime/configuration/operation
  failures.
- `StoryFormatCodecException`: malformed current Story Format data.
- `StoryFormatCompatibilityException`: unsupported Story Format identity or
  version.
- `StoryExtensionSchemaFormatException`: malformed, unsupported, or invalid
  Extension Schema v1 data.
- `StoryNarrativeRuntimeException` and its subclasses: host-driven entry
  configuration, operation, resolution, or local-session execution failures.
- `StoryRuntimeSnapshotFormatException`: malformed persisted runtime snapshot.
- `StoryRuntimeSnapshotCompatibilityException`: well-formed but incompatible
  runtime snapshot.
- `StoryNarrativeRuntimeSnapshotFormatException`: malformed aggregate narrative
  runtime checkpoint data.
- `StoryNarrativeRuntimeSnapshotCompatibilityException`: well-formed but
  incompatible aggregate narrative checkpoint.
- `StoryRuntimeBundleManifestFormatException`: malformed or self-inconsistent
  runtime-bundle manifest data.
- `StoryRuntimeBundleBuildException`: deterministic packaging or artifact
  integrity failures.
- `StoryContentContractFormatException`: malformed release/patch/save-binding/
  migration contract data.
- `StoryContentMigrationException`: explicit structural save migration could not
  produce a target-valid snapshot.
- `StoryRuntimeCapabilityFormatException`: malformed capability-profile/runtime-
  report data.
- `StoryRuntimeCompatibilityException`: a caller required semantic compatibility
  but the target runtime is missing or outside a required feature/extension
  revision range.

These exceptions expose context/recovery information intended for logs and
developer-facing error UI.

## Documentation

- **[Pure-Dart examples](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/example/README.md)** — four executable integrations,
  with run commands, expected results and next reading links.
- **[A lantern at the Forest Gate](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/NARRATIVE_WALKTHROUGH.md)** — story-to-runtime tour
  of passages, choices, conditions, effects and committed save/restore.
- **Repository-only Flutter developer example** — the source checkout's
  `example/flutter_story_app/` demonstrates UI, choice input, validation
  display, and in-memory snapshot save/restore without making Flutter a package
  dependency.
- **[Integration Path](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/INTEGRATION_PATH.md)** — canonical onboarding order
  and the responsibility of each public guide/example surface.
- **[Abstraction Guide](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/ABSTRACTION_GUIDE.md)** — compact "which abstraction
  do I need?" map for project/document/bundle/module/entry-point/session/
  capability/content-release/host-action relationships.
- **[Quick Start](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/QUICK_START.md)** — first working story, validation,
  runtime control, state, save/restore, and Story Format.
- **[API Guide](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/API_GUIDE.md)** — public concepts, workflows, error
  contracts, and complete top-level API index.
- **[Authored analysis and validation](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/AUTHORED_ANALYSIS_AND_VALIDATION.md)** — reusable authored-tree
  analysis and standalone/orchestration/module validation contexts.
- **[Story Format v1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/STORY_FORMAT_V1.md)** — normative portable authored
  format specification.
- **[Runtime Semantics — Core Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RUNTIME_SEMANTICS_V1.md)** —
  implementation-independent execution behavior.
- **[Deterministic Randomness — `story_engine.lcg32` Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/DETERMINISTIC_RANDOM_V1.md)** — exact cross-runtime seeded sampling and
  weighted-route profile.
- **[Runtime Conformance Fixtures — Foundation Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/CONFORMANCE_FIXTURES_V1.md)** — shared whole-runtime input/expected-output
  vectors and conformance-report contract.
- **[Independent C# Runtime Spike — Stage 8O Proof](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/INDEPENDENT_CSHARP_RUNTIME_SPIKE.md)** — scope, independence rules, and
  hard-gate interpretation for the second-runtime conformance proof.
- **[Extension Schema — Contract Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/EXTENSION_SCHEMA_V1.md)** —
  language-neutral custom action/condition declarations, enums, references,
  metadata, and unknown-extension safety rules.
- **[Open-World Narrative Orchestration — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/OPEN_WORLD_ORCHESTRATION_V1.md)** — host-driven entry activation,
  persistent/session state ownership, explicit host facts, and deterministic
  resolver/session RNG scope.
- **[Modular/Indexed Project Loading — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/MODULAR_PROJECT_LOADING_V1.md)** — lightweight project indexing,
  storage-neutral module loading, verification, caching, prefetch/eviction, and
  bounded project-slice materialization.
- **[Suspendable Host Interaction — Protocol Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/HOST_ACTION_PROTOCOL_V1.md)** — stable data-only asynchronous host-action
  suspension, typed outcomes, and pending-request persistence.
- **[Narrative Session Execution — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/SESSION_EXECUTION_V1.md)** — serialized multi-session state authority,
  atomic shared-state commits, explicit host inputs, and server-neutral
  execution ordering.
- **[Aggregate Narrative Save/Load Lifecycle — Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)** — canonical aggregate
  orchestration save/load order, atomic host persistence expectations, content
  preflight, pending-action reconciliation, and failure handling.
- **[Runtime Bundle Build Pipeline — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RUNTIME_BUNDLE_BUILD_V1.md)** — deterministic derived shipping bundles,
  SHA-256 artifact identities, canonical manifests, and reproducible build IDs.
- **[Content Versioning, Patching, and Save Compatibility — Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/CONTENT_VERSIONING_V1.md)** — release/module revisions, patch manifests,
  save-content bindings, and explicit migration/fallback policy.
- **[Runtime Capability and Extension Compatibility — Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RUNTIME_CAPABILITIES_V1.md)** — project capability profiles, runtime
  reports, extension-schema version negotiation, and deterministic target
  diagnostics.
- **[Performance baselines](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/PERFORMANCE_BASELINES.md)** — reproducible
  100/500/1,000-event measurement workloads plus opt-in larger stress runs.
- `dart doc` / generated API pages — member-level Dartdoc from the public
  package source.

## Important boundaries

- `StoryEvent` is the generic executable unit; it is not restricted to prose
  scenes.
- Stable typed IDs are machine identity. Visible text and aliases are not.
- `StoryProject` is authored semantic data, not a running playthrough.
- `StoryState` is immutable to consumers; effects evolve state through the
  engine.
- Conditions are side-effect free; effects do not navigate; transitions own
  navigation.
- Incomplete authored work can be representable even when it is not runnable;
  validate before execution.
- Story Format and runtime snapshots are separate versioned contracts.
- Story Format organization/extensions are runtime-neutral and stay outside
  `StoryProject` semantics.
- Storage and UI policy belong to the host application.

## Engine-neutral ecosystem boundary

Story Format is the portable authored-project boundary for the wider ecosystem.
`story_engine` remains its Dart reference runtime and reference codec; future
conforming runtimes may implement the same contract natively in other languages
without embedding Dart.

Stage 8A audited frozen Story Format v1 for hidden Dart assumptions. The authored
data contract passed without a v1 representation change. See
**[Story Format platform-neutrality audit](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/STORY_FORMAT_PLATFORM_NEUTRALITY.md)**.

Stage 8B now specifies the executable core independently of Dart API types,
including state/unset behavior, event modes and ordering, conditions/effects,
transitions, history, termination, failure categories, and transactional
rollback. See **[Runtime Semantics — Core Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RUNTIME_SEMANTICS_V1.md)**.

Stage 8C now freezes exact seeded random-route parity through
**[Deterministic Randomness — `story_engine.lcg32` Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/DETERMINISTIC_RANDOM_V1.md)**. The same deterministic narrative inputs and
explicit seed must produce the same weighted selections across conforming
runtimes.

Stage 8D adds the first language-neutral whole-runtime conformance corpus and a
versioned report contract. See **[Runtime Conformance Fixtures — Foundation
Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/CONFORMANCE_FIXTURES_V1.md)**. The Dart runtime is the first
implementation required to pass every `runtime-core-v1` fixture.

Stage 8E adds a separate **[Extension Schema — Contract Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/EXTENSION_SCHEMA_V1.md)** for declarative custom actions, conditions,
enums, reference types, and editor metadata. Schemas are data only; trusted host
implementations remain outside project/schema files and Story Format v1 remains
unchanged.

Stage 8G defines host-driven entry resolution and local narrative sessions.
Stage 8H adds **[Modular/Indexed Project Loading — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/MODULAR_PROJECT_LOADING_V1.md)** so large projects can keep a lightweight
global index resident while loading, verifying, caching, and evicting event
modules on demand without changing runtime semantics.

Stage 8I adds **[Suspendable Host Interaction — Protocol Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/HOST_ACTION_PROTOCOL_V1.md)**. Narrative sessions can now pause on a
stable data-only host-action request, reject unsafe re-entry, accept exactly one
typed completion/failure/cancellation, and preserve a pending request across
snapshot/restore without serializing host-engine objects.

Stage 8J adds **[Narrative Session Execution — Contract Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/SESSION_EXECUTION_V1.md)**. Multiple sessions may remain logically active
while one serialized narrative authority owns atomic persistent-state commits,
explicit input ordering, re-entry/thread-confinement rules, and UI-neutral or
server-authoritative input submission.

Stage 8N adds **[Presentation Unit Identity — Contract Version 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/PRESENTATION_IDENTITY_V1.md)** and the **[Runtime Implementer Contract —
Revision 1](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/RUNTIME_IMPLEMENTER_CONTRACT_V1.md)**. Stable production units
can carry source revisions without keying localization/voice assets to mutable
visible text, while structured runtime observations remain timestamp-free,
non-authoritative, and host-owned rather than embedding analytics.

Stage 8O adds an **[Independent C# Runtime Spike — Stage 8O Proof](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/INDEPENDENT_CSHARP_RUNTIME_SPIKE.md)**. A deliberately small, Unity-
independent C# implementation consumes the same `runtime-core-v1` fixture set
as the Dart reference runtime and must reproduce all six foundation cases from
the written language-neutral contracts rather than private Dart source.

## Development

From `story_engine/`:

```text
dart analyze
dart test
```

The package has extensive regression coverage for runtime semantics, validation,
Story Format determinism/compatibility, snapshots, scale, and public package
boundaries. The scale suite also chains those subsystems through a mandatory
1,000-event public-workflow regression.

For repeatable performance observations without machine-specific test
thresholds:

```text
dart run benchmark/performance_baseline.dart
```

Use `--stress-events=5000` for an opt-in larger deterministic workload. For
Stage 9C explainability overhead, compare diagnostics disabled/enabled on the
same machine with:

```text
dart run benchmark/stage9c6_explainability_overhead.dart --samples=11 --sessions=200
```

Stage 9D uses a stronger reusable profiling harness for deterministic core and
multi-session workloads:

```text
dart run benchmark/stage9d1_benchmark_harness.dart
```

Stage 9D2 applies that harness to the complete session/history-retention matrix:

```text
dart run benchmark/stage9d2_session_history_retention.dart
```

Stage 9D3 isolates shared persistent-state propagation and the validated sibling-engine rebuild unit across growing project/history/session scales:

```text
dart run benchmark/stage9d3_shared_state_propagation.dart
```

Stage 9D4 hardens modular loading with instance-local single-flight: overlapping
requests for the same uncached module share one load and verification operation,
while different module IDs remain independently asynchronous. Failures are not
retained and later requests may retry; eviction/clear affect completed bodies
only and do not cancel pending host I/O.

Stage 9D5 uses one frozen before/after gate for targeted production
optimizations:

```text
dart run benchmark/stage9d5_optimization_baseline.dart
```

The first unoptimized run is retained as `stage9d5-before.json`. The first
measured production candidate now reuses exact-project event/choice preparation
during validated restore and sibling shared-state propagation without weakening
snapshot validation. Rerun the unchanged benchmark after that patch as:

```text
dart run benchmark/stage9d5_optimization_baseline.dart --json > stage9d5-after-project-preparation.json
```

The project-preparation optimization is accepted by same-machine before/after
evidence. The second history optimization is also accepted after same-revision
fresh-process isolation: normal narrative execution now uses a lazy O(1)
pre-operation checkpoint plus indexed committed-history suffix access. If an
operation actually changes shared persistent state and sibling propagation is
required, the old immutable rollback snapshot is materialized only immediately
before sibling preparation; failures still restore through validated
`StoryEngine.restore(...)`. Ordinary unchanged-state operations therefore do not
pay full-history rollback preparation merely because other sessions are active.

The repository retains the Stage 9D5 A/B runner as diagnostic evidence tooling.
A/B/C/D/H reproduce the explored controls, while E is the accepted selective
policy used by normal runtime construction:

```text
dart run benchmark/stage9d5_history_ab_isolation.dart --variant=E
.\tool\stage9d5\run_history_selective_followup.ps1 -Rounds 6
```

Use `--json` with either runner for machine-readable raw samples, summary
statistics, semantic fingerprints, structural metrics, and environment metadata.

Stage 9D6 turns the final Stage 9D evidence into portable regression budgets without freezing one machine's microsecond values into tests. The 9D6A hardening keeps all 46 frozen Stage 9D5 cases and adds 36 versioned workloads for multi-session unchanged-state history and prewarmed 1/10/50-session propagation. Session scaling now uses only comparable prewarmed conditions, and semantic/report/timing-contract identities are explicit:

```text
dart run benchmark/stage9d6_performance_regression_gate.dart
.\tool\stage9d6\run_performance_regression_gate.ps1
```

Use `--output=<path>` to write UTF-8 JSON directly. The gate returns PASS, FAIL, or INCONCLUSIVE: unusable timing evidence or a ratio range crossing its threshold requires a repeat rather than being mislabeled as a regression. Dispersion and possible mixed timing regimes remain visible as advisories. Small denominator floors are documented as conditional absolute influences, not as perfectly machine-speed-invariant ratios. Ordinary `dart test` coverage exercises the budget logic with synthetic timings rather than wall-clock assertions.

Stage 9D6B adds the final production-path assurance: direct behavior tests use
the normal selective runtime, inject propagation failure only after a real
sibling replacement has already been prepared, prove exact source/sibling/shared
authority rollback, and deliberately feed an incompatible rollback snapshot to
prove validated `StoryEngine.restore(...)` remains on the exceptional path. The
retained A/B/C/D/E/H strategies are also checked for successful-commit and
rollback semantic parity. Their fault/probe seam is internal, absent from the
package barrel, and active only under Dart assertions. The final semantic-baseline follow-up pins exact accepted fingerprints for all
six `unchanged_history_*` workloads. On 21 September 2026 the exact follow-up
revision passed `dart analyze`, all 1,056 ordinary tests, and the 21-sample /
5-warm-up Stage 9D6 live gate. The semantic/contract baseline and all 25
relative/growth-shape budget checks passed. Stage 9D6B, Stage 9D6, and Stage 9D
are therefore complete / accepted.

See **[Performance baselines](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/PERFORMANCE_BASELINES.md)** for the measurement
and comparison contract.

### Conformance and complete aggregate load verification

Run the six foundation cases and the ten finalization hardening cases using the
standalone public-facade runner:

```sh
dart run tool/conformance/run_conformance.dart
dart run tool/conformance/run_conformance.dart --fixture-set=conformance/fixtures/runtime-finalization-v1/fixture-set.json
dart run benchmark/finalization_stage4_load_path.dart --samples=5 --warmups=2 --output=build/aggregate-load.json
```

See [Runtime finalization conformance](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/CONFORMANCE_HARDENING_V1.md) for exact
profile coverage and failure reports, and
[Aggregate load-path benchmark](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/doc/AGGREGATE_LOAD_PATH_BENCHMARK.md) for retained
session workloads, timing boundaries and measured preparation reuse. Both tools
are included with their data in the public package.

## License

`story_engine` is released under the **BSD 3-Clause License**. See
[LICENSE](https://github.com/ErikSchultheiss/story_engine/blob/HEAD/LICENSE).
