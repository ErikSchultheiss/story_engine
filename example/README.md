# Pure-Dart example

Run the package's complete public-API walkthrough from the `story_engine/`
directory:

```text
dart run example/story_engine_example.dart
```

The example deliberately has no Flutter dependency and imports only:

```dart
import 'package:story_engine/story_engine.dart';
```

It demonstrates one compact end-to-end path:

1. construct a tiny authored `StoryProject`;
2. encode/decode it through Story Format v1's logical bundle API;
3. validate it with `StoryValidator.validate`;
4. start a deterministic `StoryEngine`;
5. display an event and its available choices;
6. select a choice that changes scalar story state;
7. pause on a continuation event;
8. encode a committed runtime snapshot as JSON;
9. decode and restore that snapshot; and
10. continue the restored run to termination.

The walkthrough is scripted rather than stdin-interactive so its output is
reproducible and the same source can be compiled/exercised by the package test
suite. A real CLI, server, Flutter app, or game chooses how to present choices,
collect input, and persist the logical Story Format files/snapshot JSON.

## Flutter counterpart

For the same public engine workflow mapped to widgets, user input, validation
presentation, and host-owned save policy, a source-repository checkout contains
`flutter_story_app/`. The Flutter example remains downstream of this Pure-Dart
package and is intentionally excluded from the pub.dev archive; it does not move
Flutter into `story_engine`.
