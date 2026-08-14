# story_engine Quick Start

This guide takes the shortest supported path from authored Dart objects to a
running story. It uses only:

```dart
import 'package:story_engine/story_engine.dart';
```

Do not import `package:story_engine/src/...`; those libraries are implementation
detail.

## 1. Add the dependency

For the public alpha release:

```yaml
dependencies:
  story_engine: 0.1.0-alpha.1
```

For a repository checkout or local engine development, a path dependency is also supported:

```yaml
dependencies:
  story_engine:
    path: ../story_engine
```

Then run your normal `dart pub get` or `flutter pub get` command.

## 2. Build a minimal story

A runnable event must use exactly one flow mode:

1. one or more choices;
2. a continuation transition; or
3. an automatic transition.

The smallest interactive story is one event with one choice that terminates:

```dart
import 'package:story_engine/story_engine.dart';

final startId = StoryEventId('start');
final leaveId = StoryChoiceId('leave');

final project = StoryProject(
  id: StoryProjectId('quick_start'),
  entryEventId: startId,
  events: [
    StoryEvent(
      id: startId,
      presentation: StoryEventPresentation(
        title: const StoryText('Forest Gate'),
        body: const StoryText('An old path disappears into the trees.'),
      ),
      choices: [
        StoryChoice(
          id: leaveId,
          presentation: const StoryChoicePresentation(
            text: StoryText('Go home'),
          ),
          transition: const StoryTerminalTransition(),
        ),
      ],
    ),
  ],
);
```

IDs are stable machine identity. Do not derive persistence or references from
visible titles/choice text.

## 3. Validate before running

`StoryValidator` is a static, read-only authoring service:

```dart
final report = StoryValidator.validate(project);

if (report.hasErrors) {
  print(report.format());
  return;
}
```

Warnings and informational diagnostics do not make `report.isValid` false.
For tools and editors, use the structured diagnostic fields rather than parsing
formatted strings:

```dart
for (final diagnostic in report.diagnostics) {
  print(diagnostic.code.value);
  print(diagnostic.severity);
  print(diagnostic.location.displayString);
  print(diagnostic.references);
  print(diagnostic.suggestion);
}
```

## 4. Start the engine

```dart
final engine = StoryEngine(project: project);
engine.start();
```

The default RNG seed is deterministic (`StoryEngine.defaultRandomSeed == 0`).
Pass `randomSeed:` explicitly if a run needs a specific weighted-transition
sequence.

After start, inspect the lifecycle state:

```dart
print(engine.status);
print(engine.currentEvent);
print(engine.state);
print(engine.history);
```

For the minimal story above, the engine is waiting for a choice:

```dart
if (engine.status == StoryEngineStatus.awaitingChoice) {
  for (final choice in engine.availableChoices) {
    print(choice.presentation?.text.value);
  }
}
```

Select using the stable `StoryChoiceId`:

```dart
engine.choose(leaveId);
```

The choice terminates the sample story, so `engine.status` becomes
`StoryEngineStatus.terminated`.

## 5. Understand the three runtime flow modes

### Interactive choice

An event with choices pauses at `awaitingChoice`:

```dart
StoryEvent(
  id: StoryEventId('crossroads'),
  choices: [
    StoryChoice(
      id: StoryChoiceId('left'),
      transition: StoryEventTransition(
        destinationEventId: StoryEventId('left_path'),
      ),
    ),
  ],
)
```

Call `engine.choose(choiceId)` with one ID currently returned by
`engine.availableChoices`.

### Explicit continue

A host-visible no-choice event uses `continuationTransition`:

```dart
StoryEvent(
  id: StoryEventId('interlude'),
  presentation: StoryEventPresentation(
    body: const StoryText('Night falls.'),
  ),
  continuationTransition: StoryEventTransition(
    destinationEventId: StoryEventId('morning'),
  ),
)
```

The engine pauses at `StoryEngineStatus.awaitingContinue`; call:

```dart
engine.continueStory();
```

### Automatic flow

An event with `automaticTransition` does not pause:

```dart
StoryEvent(
  id: StoryEventId('bookkeeping'),
  automaticTransition: StoryEventTransition(
    destinationEventId: StoryEventId('next_visible_event'),
  ),
)
```

Automatic events resolve synchronously until the engine reaches a choice,
continue point, or terminal transition. The runtime guard prevents accidental
unbounded automatic loops.

## 6. Add typed scalar state

Declare variables in the project schema:

```dart
final trustId = StoryVariableId('trust');

final projectWithState = StoryProject(
  id: StoryProjectId('state_example'),
  stateSchema: StoryStateSchema(
    variables: [
      StoryVariableDefinition(
        id: trustId,
        type: StoryValueType.integer,
        initialValue: StoryIntegerValue(0),
      ),
    ],
  ),
);
```

For host/test setup, ordinary Dart scalars can be bridged through
`StoryState.fromRawValues`:

```dart
final initialState = StoryState.fromRawValues(
  schema: projectWithState.stateSchema,
  values: {trustId: 10},
);

print(initialState.rawValueOf(trustId)); // 10
```

The scalar domains are intentionally strict:

- `bool` → `StoryBooleanValue`
- `int` → `StoryIntegerValue`
- `double` → `StoryNumberValue`
- `String` → `StoryStringValue`

There is no implicit numeric coercion between integer and number variables.
Unset is distinct from false, zero, and an empty string.

## 7. Conditions and effects

Conditions control availability/branching and do not mutate state. Effects
change state and do not navigate.

Example: show a choice only when `trust >= 10`:

```dart
StoryVariableComparisonCondition(
  variableId: trustId,
  operator: StoryComparisonOperator.greaterThanOrEqual,
  value: StoryIntegerValue(10),
)
```

Example: increment `trust` by 1 when the choice is selected:

```dart
StoryIncrementVariableEffect(
  variableId: trustId,
  amount: StoryIntegerValue(1),
)
```

Use `StoryAllCondition`, `StoryAnyCondition`, and `StoryNotCondition` to compose
condition trees. Run `StoryValidator.validate(project)` after authoring changes;
it catches missing references, type mismatches, unset-state hazards, graph
problems, and presentation-quality findings without executing the story.

## 8. Save and restore a run

Capture only committed runtime state:

```dart
final snapshot = engine.createSnapshot();
```

Encode it with the runtime-snapshot codec:

```dart
final snapshotCodec = StoryRuntimeSnapshotCodec();
final json = snapshotCodec.encodeJson(snapshot);
```

Decode against the authored project and restore:

```dart
final decodedSnapshot = snapshotCodec.decodeJson(
  json,
  project: project,
);

final restored = StoryEngine.restore(
  project: project,
  snapshot: decodedSnapshot,
);
```

A restored run keeps lifecycle state, scalar state, current event, canonical
history, deterministic RNG state, and the automatic-transition guard. It does
not replay entry effects or previous choices.

`story_engine` does not decide where the JSON lives. Store it in a file,
database, preferences system, cloud service, or another host-owned persistence
layer.

## 9. Encode authored projects with Story Format v1

For a project that needs only executable/validation semantics:

```dart
const storyFormat = StoryFormatCodec();
final bundle = storyFormat.encodeProject(project);

for (final entry in bundle.files.entries) {
  print('${entry.key}: ${entry.value.length} characters');
}

final decodedProject = storyFormat.decodeProject(bundle);
```

For editor/tooling workflows that must preserve runtime-neutral organization and
opaque extension metadata, keep the full document:

```dart
final document = StoryFormatDocument(project: project);
final bundle = storyFormat.encode(document);
final decodedDocument = storyFormat.decode(bundle);
```

`StoryFormatBundle` contains logical relative paths and JSON strings only. The
host owns directory/archive/database/network storage.

See [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) for the normative third-party
format specification.

## 10. Handle failures by domain

Runtime operations can throw `StoryEngineException` subclasses. They carry
operation/entity context when available:

```dart
try {
  engine.choose(StoryChoiceId('not_available'));
} on StoryEngineException catch (error) {
  print(error);
  print(error.operation);
  print(error.eventId);
  print(error.choiceId);
  print(error.suggestion);
}
```

Story Format and snapshot decoding distinguish malformed input from compatible
shape/version problems. See [API_GUIDE.md](API_GUIDE.md) for the complete error
contract.

## Next steps

- Run `dart run example/story_engine_example.dart` from the package root for the
  complete scripted Pure-Dart walkthrough; see
  [example/README.md](../example/README.md).
- In a source-repository checkout, run the repository-only
  `example/flutter_story_app/` host to see the same runtime mapped to widgets,
  choice input, validation display, and host-owned snapshot persistence policy.
  The nested Flutter app is intentionally excluded from the pub.dev archive.
- Read [API_GUIDE.md](API_GUIDE.md) for the public concepts and complete
  top-level API index.
- Read [STORY_FORMAT_V1.md](STORY_FORMAT_V1.md) before implementing a
  third-party Story Format reader/writer.
- Use [PERFORMANCE_BASELINES.md](PERFORMANCE_BASELINES.md) when measuring
  validation/runtime/persistence performance or running larger stress fixtures.
- Use generated Dart API documentation for member-level signatures and Dartdoc.
- Keep all consumer imports on `package:story_engine/story_engine.dart`.
