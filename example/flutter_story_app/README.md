# Flutter developer example

This is a deliberately small Flutter application that consumes the sibling
pure-Dart `story_engine` package exactly as a normal application would.

It demonstrates that Flutter remains a **host** around the engine rather than a
dependency of the engine itself.

## Run it

From `story_engine/example/flutter_story_app/`:

```text
flutter pub get
flutter run -d chrome
```

A minimal `web/` runner is committed so the sample can be launched without
generating Android/iOS/desktop runner boilerplate. The Dart/Flutter integration
itself is platform-neutral; add other Flutter platform runners with the normal
Flutter tooling if you want to run the sample elsewhere.

Run its widget test with:

```text
flutter test
```

The example has its own `pubspec.yaml` and depends on the package through:

```yaml
story_engine:
  path: ../..
```

A published consumer would replace that path dependency with the normal
`story_engine` package dependency/version.

## What the example demonstrates

The app follows the same public workflow as the Pure-Dart example, but maps it
to Flutter widgets:

1. build/load a `StoryProject` through `StoryFormatCodec`;
2. validate with `StoryValidator.validate(project)`;
3. start `StoryEngine` only when validation has no errors;
4. render `currentEvent` presentation in ordinary Flutter widgets;
5. turn `availableChoices` into buttons and select choices by stable ID;
6. render an `awaitingContinue` event with an explicit Continue button;
7. inspect immutable story state (`lantern_lit`);
8. encode a committed runtime snapshot to JSON;
9. restore the snapshot without replaying earlier effects; and
10. restart with a fresh engine instance.

The saved snapshot is intentionally kept **in memory**. That is the host-policy
boundary: a real Flutter app can put the JSON in preferences, a file, a local
database, cloud storage, or another persistence system without changing the
engine contract.

## File responsibilities

```text
lib/example_story.dart
  Pure-Dart authored project. No Flutter import.

lib/main.dart
  Flutter presentation, input, validation display, and in-memory save policy.

test/example_story_contract_test.dart
  Public-API regression for validation and save/restore of the authored story.

test/story_player_screen_test.dart
  Widget regression for play -> save -> finish -> restore -> restart.
```

Both Dart source files import the engine only through:

```dart
import 'package:story_engine/story_engine.dart';
```

Do not import `package:story_engine/src/...` from Flutter application code.

## Deliberately not shown yet

This example is not an application framework and does not prescribe:

- Riverpod/Bloc/Provider or another state-management package;
- filesystem/preferences/database plugins;
- navigation architecture;
- localization or theming architecture;
- custom engine actions/conditions;
- editor/authoring-tool UI.

Those are host/application decisions or later roadmap stages. The purpose of
this example is to make the package boundary and basic Flutter integration
obvious for a downstream Flutter integration.
