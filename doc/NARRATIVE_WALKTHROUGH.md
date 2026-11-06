# A lantern at the Forest Gate

A player stands outside an old watchtower. They can turn back, or light a
lantern and investigate the tunnel. Inside, fresh footprints invite them to
continue. This tour follows the checked-in
[core example](../example/story_engine_example.dart), including saving inside
the tunnel and resuming there.

Your application presents the passages, collects the player's choice and stores
the save data. `story_engine` applies the authored rules and keeps the run's
state. This example uses one `StoryEngine`; the optional orchestration concepts
at the end are not needed to follow it.

## Run the story

From the package checkout root:

```sh
dart pub get
dart run example/story_engine_example.dart
```

The script chooses the lantern branch automatically so its output is
reproducible. It does not ask for terminal input.

The Dart blocks below are exact excerpts from that tested file, not separate
standalone programs. Keep them in their original context to run them. The file
uses the public import and defines these local IDs:

```dart
import 'package:story_engine/story_engine.dart';

final _lanternLitId = StoryVariableId('lantern_lit');
final _gateId = StoryEventId('forest_gate');
final _tunnelId = StoryEventId('old_tunnel');
final _lightLanternId = StoryChoiceId('light_lantern');
```

The leading underscores belong to this example's local Dart declarations;
the engine types come from the supported package root.

## 1. Arrive at the gate

The player sees:

```text
Forest Gate
A narrow tunnel disappears beneath the old watchtower.
- light_lantern: Light the lantern and enter
- leave: Turn back
```

`forest_gate` is the project's entry event. Starting the engine enters that
event and pauses at `awaitingChoice`. Both choices are available; neither has a
choice availability condition. The host uses their stable IDs to submit a
selection, rather than matching the visible text.

The authored state schema gives the lantern a boolean value, initially false:

```dart
StoryVariableDefinition(
  id: _lanternLitId,
  type: StoryValueType.boolean,
  initialValue: const StoryBooleanValue(false),
),
```

This is story state. Drawing a lantern icon or playing an animation remains
the host application's decision.

## 2. Light the lantern and enter

The selected choice connects three different ideas: what the player reads,
what changes in the world, and where the story goes:

```dart
StoryChoice(
  id: _lightLanternId,
  presentation: const StoryChoicePresentation(
    text: StoryText('Light the lantern and enter'),
  ),
  effects: [
    StorySetVariableEffect(
      variableId: _lanternLitId,
      value: const StoryBooleanValue(true),
    ),
  ],
  transition: StoryEventTransition(destinationEventId: _tunnelId),
),
```

The script finds that available choice and submits its ID:

```dart
final lightLantern = engine.availableChoices.singleWhere(
  (choice) => choice.id == _lightLanternId,
);
write('Selecting: ${_choiceText(lightLantern)}');
engine.choose(lightLantern.id);
```

The effect changes `lantern_lit` from false to true. The transition then leads
to `old_tunnel`. That destination has the following condition and continuation:

```dart
availabilityCondition: StoryVariableComparisonCondition(
  variableId: _lanternLitId,
  operator: StoryComparisonOperator.equal,
  value: const StoryBooleanValue(true),
),
continuationTransition: const StoryTerminalTransition(),
```

The tunnel checks the state after the choice's effect, so its condition passes.
The condition reads state; it does not light the lantern itself. The transition
changes location; the effect changes state.

The next passage is:

```text
Old Tunnel
The lantern catches fresh footprints in the dust.
[continue]
```

The engine is now at `awaitingContinue`. The host can display a Continue button;
the engine waits for an explicit call instead of finishing immediately.

| Player or host action | Authored rule | Result |
| --- | --- | --- |
| Start | Entry event is `forest_gate`; no event condition | Lantern false; gate shown; `awaitingChoice` |
| Choose `light_lantern` | No choice condition; set lantern true; transition to tunnel; tunnel requires lantern true | Lantern false → true; tunnel shown; `awaitingContinue` |
| Alternatively, choose `leave` at the gate | No choice condition or effects; terminal transition | Lantern stays false; run terminates; tunnel is not entered |
| Continue from the tunnel | No further effects; terminal continuation | Lantern stays true; run terminates |

The scripted run follows the lantern branch. The Turn back row describes the
other authored branch, not an extra step after entering the tunnel.

## 3. Save inside the tunnel

The example takes its checkpoint after the choice has committed. It encodes
the runtime snapshot as JSON, decodes it against the same authored project,
and creates a restored engine:

```dart
final snapshot = engine.createSnapshot();
final snapshotCodec = StoryRuntimeSnapshotCodec();
final saveJson = snapshotCodec.encodeJson(snapshot);
write('Saved runtime snapshot: ${saveJson.length} JSON characters.');

final decodedSnapshot = snapshotCodec.decodeJson(saveJson, project: project);
final restored = StoryEngine.restore(
  project: project,
  snapshot: decodedSnapshot,
);
write('Restored status: ${restored.status.name}');
write('Restored lantern_lit = ${restored.state?.rawValueOf(_lanternLitId)}');

restored.continueStory();
write('Finished status: ${restored.status.name}');
```

Restoration resumes inside the tunnel, still waiting for Continue, with the
lantern already lit. It preserves committed state and history rather than
starting the story again or replaying the selected choice and its effects.
Only the explicit `restored.continueStory()` advances the restored run to its
terminal transition.

The core example's test compares the restored snapshot with the original
checkpoint, not just the displayed boolean. Separately, the existing
[snapshot restoration tests](../test/runtime/story_engine_snapshot_restoration_test.dart)
use an incrementing entry effect to check that restoration keeps its committed
value of 2 instead of applying it again to produce 3.

A runtime snapshot describes a playthrough. It does not replace the authored
project: the restore call still supplies `project`. Portable authored content
uses the separate [Story Format v1](STORY_FORMAT_V1.md) contract. This example
keeps JSON in memory; a real host chooses its storage backend.

## 4. Compare the outcome

The run prints this transcript, with only the snapshot-size line omitted. That
line reports the encoded JSON length, which is not a save compatibility rule.

```text
Validation: 0 errors, 0 warnings, 0 information

Forest Gate
A narrow tunnel disappears beneath the old watchtower.
- light_lantern: Light the lantern and enter
- leave: Turn back
Selecting: Light the lantern and enter
lantern_lit = true

Old Tunnel
The lantern catches fresh footprints in the dust.
[continue]
Restored status: awaitingContinue
Restored lantern_lit = true
Finished status: terminated
```

The [core example tests](../test/documentation/stage9b2_branching_core_save_load_example_test.dart)
exercise validation, both initial choices, the scripted progression and exact
checkpoint restoration. The [example CI gate](../test/example/stage9b6_public_examples_ci_test.dart)
also executes the real `main()` entry point.

## Small glossary

| Term | Meaning in this tour |
| --- | --- |
| Event | An authored point in the story with a flow mode; here, a passage at the gate or tunnel. |
| Choice | A selectable authored action, identified by a stable ID. |
| Condition | A read-only rule, such as the tunnel requiring a lit lantern. |
| Effect | A state change, such as setting `lantern_lit` to true. |
| Transition | The next destination or termination after a choice, continuation or automatic step. |
| Snapshot | A checkpoint of committed execution state, used to resume a playthrough. |
| Session — optional | One activation's retained local run under `StoryNarrativeRuntime`, with its own identity and execution history. |
| Aggregate — optional | The complete orchestration checkpoint, including shared state, retained sessions and authority state, restored together. |
| Host action — optional | A stable data request for external work the host owns; a pending request can survive aggregate restore without redispatching that work. |

## Where to go next

Use the [Quick Start](QUICK_START.md) to author your own project, and the
[Abstraction Guide](ABSTRACTION_GUIDE.md) when choosing additional concepts.
For several unfinished conversations sharing world state, see the shared-state
example in [the example index](../example/README.md). If orchestration owns
execution, follow the [Aggregate Save/Load Lifecycle](AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md)
instead of assembling separately restored sessions. The modular host-action
example then shows pending external work and reconciliation.
