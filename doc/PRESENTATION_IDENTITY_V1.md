# Presentation Unit Identity — Contract Version 1

Stage 8N defines stable identity below the event/choice level before advanced
localization, subtitle, and voice-production workflows depend on mutable visible
text.

The portable sidecar contract is:

```json
{"contract":"open_story.presentation_identity_catalog","contractVersion":1}
```

## 1. Core rule

A presentation unit has a stable `unitId` that is independent from its visible
source wording and independent from its current authored location. Rewriting a
line, retitling an event, or moving a choice MUST NOT require a new identity.
Creating a semantically new unit may intentionally allocate a new ID.

Each unit also has a positive exact portable `sourceRevision`. A producer MUST
increase that revision when the source-language content changes in a way that
should cause downstream translations/recordings/review state to be reconsidered.
The revision is not a timestamp and does not encode wall-clock time.

## 2. Revision 1 locations

Revision 1 can identify the presentation slots already present in the reference
model:

- `event_title` — event ID;
- `event_body` — event ID;
- `choice_text` — event ID plus choice ID.

Location is not identity. A stable `unitId` may later point at a different
location after a refactor.

One current source location may be occupied by at most one presentation unit.
Unit IDs are globally unique within the catalog.

## 3. What the catalog does not contain

Revision 1 deliberately contains no:

- translated text;
- audio asset path;
- speaker/actor object;
- subtitle timing;
- facial-animation/lip-sync data;
- review workflow;
- filesystem or engine object;
- executable code.

Those systems may reference the stable unit ID later.

## 4. Source revision semantics

`sourceRevision` is a producer-managed positive integer in `1..2^53-1`.
It is monotonic per unit. It MUST NOT be generated from local clock time.

Changing only location while preserving the same source content does not, by
itself, require a revision increase. Changing source wording/meaning in a way
that affects downstream production does.

## 5. Story Format v1 remains frozen

Story Format v1 has no field for presentation-unit identity. Contract v1 is a
separate portable sidecar foundation and MUST NOT be interpreted as hidden
fields inside existing v1 presentation strings.

If stable presentation identity is later incorporated into the authored source
of truth, that is explicit Story Format evolution or another explicitly
versioned project-side contract. It is not a reinterpretation of frozen v1.

## 6. Determinism and source control

Catalog encoding is deterministic and canonically ordered by `unitId`. Stable
identity avoids tying translation/voice assets to mutable visible text and
reduces unnecessary churn when author-facing names or locations change.

## 7. Stage boundary

Stage 8N freezes identity/revision semantics only. Full localization and voice
production workflows remain later authoring-tool work.
