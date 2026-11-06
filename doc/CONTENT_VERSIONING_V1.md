# Content Versioning, Patching, and Save Compatibility — Revision 1

Stage 8L defines how deterministic runtime bundles can evolve across patches,
DLC, and content updates without turning Story Format into a shipping manifest
or silently guessing whether an old save is safe.

## 1. Contract boundary

The contracts remain distinct:

```text
Story Format v1
  human-readable authored source of truth
        |
        v
Runtime Bundle Contract v1
  deterministic compiled/indexed artifacts + exact hashes
        |
        v
Content Release Contract v1
  release ID + module versions + compatibility metadata
        |
        +--> Content Patch Contract v1
        |      add / replace / remove module revisions
        |
        +--> Save Content Binding v1
               exact content revisions relevant to one save
```

Stage 8L does not modify frozen Story Format v1 or Runtime Bundle Contract v1.
It adds a versioning/compatibility layer above the deterministic artifacts
established by Stage 8K.

## 2. Stable module identity and module version

A `StoryModuleId` remains the stable identity of one independently loadable
module. Moving through content releases does not allocate a new module ID merely
because the module's bytes change.

Each release assigns that module an opaque `StoryModuleVersion` plus the exact
SHA-256 `StoryContentHash` of its compiled runtime artifact.

Version labels are not compatibility logic. Runtimes MUST NOT infer save
compatibility from semantic-version ordering, lexical ordering, or a larger
numeric-looking version. Exact hashes and explicit compatibility metadata are
authoritative.

## 3. Content Release Contract Revision 1

Wire identity:

```text
contract: open_story.content_release
contractVersion: 1
```

A release records:

- `releaseId` — opaque release identity;
- `projectId` — stable logical Story Project identity;
- `bundleId` — exact Stage 8K runtime-bundle identity;
- ordered module revisions;
- each module's stable ID, version, SHA-256 hash, and dependencies;
- exact older module revisions explicitly declared save-compatible.

A release ID MUST identify one exact runtime-bundle identity. Reusing the same
release ID for different bundle bytes is invalid rather than a compatibility
shortcut.

A byte-identical target hash is intrinsically safe for the same stable module
ID. Otherwise a target module may accept an older source revision only through
explicit module ID + version + content-hash compatibility metadata. Version
alone is insufficient.

## 4. Patch and DLC manifests

Wire identity:

```text
contract: open_story.content_patch
contractVersion: 1
```

A patch manifest compares two complete content releases of the same project and
describes deterministic module-level operations:

- `add` — a target release introduces a module;
- `replace` — a stable module ID receives a new exact revision;
- `remove` — a source module is no longer present.

Adds and replacements follow target release order. Removals follow source
release order after target operations.

These operations describe module-artifact revision changes. Activating the
target release also requires the matching Stage 8K runtime manifest/index named
by `toBundleId`; the patch manifest is not a complete transport-payload list.

The patch manifest is transport-neutral. It MUST NOT contain CDN URLs, download
credentials, store package IDs, HTTP policy, compression/encryption policy, or
platform patch-delivery technology. Those remain host/platform concerns.

A DLC is not a special core runtime concept. A content release that adds
independently addressable modules naturally produces `add` operations; host
entitlement/install policy remains outside `story_engine`.

## 5. Save Content Binding Revision 1

Wire identity:

```text
contract: open_story.save_content_binding
contractVersion: 1
```

`StoryRuntimeSnapshot` remains the runtime execution snapshot. Stage 8L does not
change its frozen wire representation.

A save that must survive content updates stores a separate
`StorySaveContentBinding` containing:

- project ID;
- content release ID;
- runtime-bundle ID;
- exact module revisions relevant to the committed runtime history/current
  event plus their declared Stage 8H dependency closure.

Large projects therefore do not need every unrelated DLC/location/dialogue
module written into every save merely because the global project index knows
about it.

Stage 9A6 applies the same Revision 1 binding to an aggregate narrative-runtime
checkpoint through `StorySaveContentBinding.fromRetainedSessionSnapshots(...)`.
The host supplies the retained sessions' core `StoryRuntimeSnapshot` values in
retained-session order. The resulting binding contains the deterministic
first-reference union of every retained session's current/history modules plus
their declared dependency closure. Completed sessions remain included because
their retained history is still part of the durable checkpoint. A runtime with
no retained sessions produces an empty module list while still binding project,
release, and bundle identity.

The aggregate `StoryNarrativeRuntimeSnapshot` does not gain release, bundle, or
module-revision fields. Snapshot bytes and content identity remain separate
companion save objects, and the host persists them atomically as one logical
save revision. Aggregate bindings use the same `exact`, `compatible`,
`migrationRequired`, `fallbackRequired`, and `incompatible` evaluation rules as
single-runtime bindings; migration and fallback are never inferred or applied
automatically. For the public Stage 9A lifecycle, only `exact` and `compatible`
continue to ordinary aggregate decode/restore. The other statuses stop that
path until an explicit migration/recovery decision is completed; they never
authorize manual per-session restoration. See
`AGGREGATE_SAVE_LOAD_LIFECYCLE_V1.md`.

## 6. Compatibility categories

A deterministic compatibility check produces one of five categories:

- `exact` — release/bundle and all bound module revisions are unchanged;
- `compatible` — changed target modules explicitly accept every bound source
  revision without structural snapshot migration;
- `migrationRequired` — an explicit migration plan is required;
- `fallbackRequired` — the old run cannot resume, but an explicit safe fallback
  entry point exists;
- `incompatible` — no declared safe path exists.

Unknown or newer-looking content MUST NOT be treated as compatible by default.
A `compatible` content result is a revision preflight, not permission to bypass
ordinary `StoryRuntimeSnapshot` validation against the actual target project.
The final restore MUST still validate current-event, history, state-value/type,
RNG, and runtime-contract compatibility.

## 7. Declarative migration plan

Wire identity:

```text
contract: open_story.content_migration
contractVersion: 1
```

Revision 1 is bound to one `projectId` and may declare:

- old event ID -> replacement event ID redirects;
- old choice ID -> replacement choice ID redirects;
- an optional safe fallback entry-point ID.

The reference migrator applies redirects to current-event/history identities,
preserves deterministic RNG/runtime metadata, rebuilds state only when the
target state schema retains the same stable variable-ID/type shape, and then
runs the ordinary runtime-snapshot validator against the target project.

No executable migration callback is embedded in the plan. Arbitrary state-value
transformations are deliberately not invented in Stage 8L.

## 8. Redirect versus fallback semantics

A redirect means: "this stable old authored identity has an explicit structural
replacement in the target content." It does not mean fuzzy matching by alias,
visible text, position, or similarity.

A fallback means: "normal restoration is not safe; the host may deliberately
start fresh narrative content at this declared entry point." A fallback MUST
NOT be applied automatically while pretending the old snapshot resumed. The
host must surface/own that recovery policy.

If a migrated snapshot still fails ordinary runtime-snapshot validation, the
migration fails. The runtime MUST NOT silently discard history, rewrite state,
or choose another destination to make restoration appear successful.

## 9. Patch/save safety rules

- Stable IDs are preferred over redirects; redirects are explicit compatibility
  tools for deliberate authored changes.
- A changed module hash is not automatically incompatible, but compatibility
  must be declared or migrated explicitly.
- Removing a module referenced by a save requires migration/fallback or a hard
  incompatibility result.
- Adding unrelated modules does not invalidate a save bound only to other
  revisions.
- Dependency/version/hash metadata belongs to release manifests, not hidden
  runtime globals.
- Content compatibility does not depend on wall-clock release date.

## 10. Separation from patch transport

Stage 8L freezes content identity and compatibility semantics only. It does not
specify:

- CDN or HTTP protocols;
- Steam/console/mobile patch packaging;
- differential binary algorithms;
- entitlement/download ownership;
- encryption/signing infrastructure;
- hot-reload/live-service deployment technology.

Those can consume the deterministic manifests without becoming Story Format or
runtime semantics.

## 11. Next boundary

Stage 8M now defines runtime capability profiles and extension-schema version
compatibility in `RUNTIME_CAPABILITIES_V1.md`. Stage 8N now adds production
identity/source-control/observability foundations, followed by the independent
Stage 8O C# conformance spike and Stage 8P migration/adoption architecture before
Stage 9.
