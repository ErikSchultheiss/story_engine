# story_engine

Source repository: <https://github.com/ErikSchultheiss/story_engine>

`story_engine` is a pure-Dart engine for declarative interactive narratives and
event systems. It provides authored story models, deterministic traversal,
scalar state, conditions/effects, validation, save/restore, and the versioned
Story Format v1 data contract without depending on Flutter or a storage layer.

The package is designed to be usable from Flutter applications, command-line
tools, tests, server-side Dart, and independent authoring/runtime tooling.

> **Status:** early public alpha. Story Format v1 is frozen, while the Dart API
> remains pre-1.0 and can still evolve between prereleases.

## What it does

- Runs stories made from `StoryProject`, `StoryEvent`, and `StoryChoice`.
- Supports direct, conditional, weighted, and terminal transitions.
- Supports typed scalar variables (`bool`, `int`, `double`, `String`).
- Evaluates declarative conditions and applies declarative effects.
- Uses deterministic seeded randomness for reproducible weighted transitions.
- Validates authored projects without executing them.
- Captures/restores deterministic runtime snapshots.
- Encodes/decodes the portable, versioned Story Format v1 logical bundle.
- Keeps Flutter, filesystem I/O, databases, preferences, and UI policy outside
  the engine.

## Requirements

- Dart SDK `>=3.11.0 <4.0.0`
- No Flutter dependency

Add the public alpha package normally:

```yaml
dependencies:
  story_engine: 0.1.0-alpha.1
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

A minimal story can be authored and run entirely in Dart:

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

For a guided explanation, including state, validation, Story Format, and
save/restore, see **[Quick Start](doc/QUICK_START.md)**.

## Runnable Pure-Dart example

A complete scripted consumer example lives in the standard package `example/`
directory:

```text
dart run example/story_engine_example.dart
```

It uses only `package:story_engine/story_engine.dart` and demonstrates Story
Format loading, validation, runtime presentation/choice handling, a scalar-state
effect, snapshot JSON, restore, and continuation to termination. See
**[example/README.md](example/README.md)** for the walkthrough scope.

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
specification is **[Story Format v1](doc/STORY_FORMAT_V1.md)**.

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
restarting from the original seed.

## Error handling

The package distinguishes common failure domains:

- `StoryEngineException` and its subclasses: runtime/configuration/operation
  failures.
- `StoryFormatCodecException`: malformed current Story Format data.
- `StoryFormatCompatibilityException`: unsupported Story Format identity or
  version.
- `StoryRuntimeSnapshotFormatException`: malformed persisted runtime snapshot.
- `StoryRuntimeSnapshotCompatibilityException`: well-formed but incompatible
  runtime snapshot.

These exceptions expose context/recovery information intended for logs and
developer-facing error UI.

## Documentation

- **[Pure-Dart example](example/README.md)** — executable end-to-end consumer
  walkthrough using only the public root import.
- **Repository-only Flutter developer example** — the source checkout's
  `example/flutter_story_app/` demonstrates UI, choice input, validation
  display, and in-memory snapshot save/restore without making Flutter a package
  dependency.
- **[Quick Start](doc/QUICK_START.md)** — first working story, validation,
  runtime control, state, save/restore, and Story Format.
- **[API Guide](doc/API_GUIDE.md)** — public concepts, workflows, error
  contracts, and complete top-level API index.
- **[Story Format v1](doc/STORY_FORMAT_V1.md)** — normative portable authored
  format specification.
- **[Performance baselines](doc/PERFORMANCE_BASELINES.md)** — reproducible
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

Use `--stress-events=5000` for an opt-in larger deterministic workload. See
**[Performance baselines](doc/PERFORMANCE_BASELINES.md)** for the measurement
and comparison contract.

## License

`story_engine` is released under the **BSD 3-Clause License**. See
[LICENSE](LICENSE).
