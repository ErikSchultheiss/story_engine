# Authored analysis and validation

These read-only APIs inspect immutable `StoryProject` data through the supported
`package:story_engine/story_engine.dart` import. They never execute conditions,
effects, transitions, host callbacks or random-number generation.

## Reference and variable-use indexes

```dart
final analysis = StoryProjectAnalysis.analyze(project);
final outgoing = analysis.outgoingReferences(eventId);
final incoming = analysis.incomingReferences(eventId);
final readers = analysis.readersOf(variableId);
final writers = analysis.writersOf(variableId);
```

`eventReferences` contains direct transition destinations from every choice,
continuation and automatic transition, including nested branches, fallbacks and
weighted options. Repeated references and missing targets remain in authored
order. The default entry is a graph root rather than a transition reference.
Each `StoryEventReference` has a source ID, destination ID, authored flow mode,
and `StoryDiagnosticLocation` ending at `destinationEventId`. Structured path
segments and owner IDs can be used directly for navigation.

`variableUses` and `usesOf` retain each authored use, including undeclared IDs.
Presence guards and scalar comparisons are separate kinds. Set, unset,
increment and decrement are writers; numeric adjustments are also value
readers. Every use location ends at `variableId`. `readersOf` includes both
presence readers and value readers. The existing “written but never read”
validation warning still means never observed by an authored **condition**;
read-modify-write effects alone do not silence it.

All returned lists and sets are immutable. Indexes represent one authored
snapshot; build a new analysis after editing the project. Duplicate source IDs
retain each occurrence's location, and ID-based lookups combine those occurrences.

## Structural graph queries

```dart
final graph = analysis.graphFrom([entryEventId, anotherEntryEventId]);
final reachable = graph.reachableEventIds;
final possiblyTerminating = graph.canReachTerminationEventIds;
final cycles = graph.cycles;
```

The roots are explicit. Unknown roots are available in `unknownEntryEventIds`;
an empty root list yields empty reachability and cycle results. Known results
follow project event order. Graph data is reused for subsequent queries against
the same analysis; each query returns independently owned immutable results.

Every authored alternative is structurally possible, including contradictory
conditions and branches that would be skipped at runtime. A path to a terminal
transition means **possible** termination, not inevitable termination. These
results cannot determine whether a particular playthrough can reach an event.

`cycles` contains full strongly connected cyclic regions, including self-loops.
Each `StoryGraphCycle` contains its event IDs and internal flow kinds.
`automaticCycles` and `continuationCycles` also expose subcycles that can exist
inside a larger mixed-flow region. Discovery is iterative, avoiding recursion
along long event chains or cycles.

`canReachIncompleteBoundaryEventIds` identifies reachable events with paths to
missing destinations, incomplete choices, or invalid/missing flow modes.
Cross-module destinations without local bodies remain such boundaries even
when their IDs are known globally. Absence of a terminal path through a boundary
does not establish non-termination. Malformed source flow participates in
reachability but is excluded from cycle claims, preserving existing validation
semantics.

If event IDs are duplicated, `isUnambiguous` is false and graph claims are empty.
The analysis's `duplicateEventIds` and reference/variable inventories remain
available. Validate identity before relying on graph results.

## Validation contexts

| Context | Default entry | Entry state | External event destinations |
| --- | --- | --- | --- |
| `StoryValidationContext.standalone()` | Required | Fresh schema initial values | Must have local bodies |
| `StoryValidationContext.orchestration(entryEventIds: roots)` | Optional; checked when present | Each declared variable may be set or unset | Must have local bodies |
| `StoryValidationContext.moduleSlice(knownExternalEventIds: ids, entryEventIds: roots)` | Optional; may resolve externally | Each declared variable may be set or unset | Explicitly known IDs accepted |

All modes run the same identity, flow, reference, type, state-use, graph and
presentation rule families. No mode authorizes invalid flow, undeclared state,
or type mismatches. Contexts own their roots and external-ID collections.

```dart
final report = StoryValidator.validate(
  project,
  context: StoryValidationContext.orchestration(
    entryEventIds: hostEntryPoints.map((entry) => entry.eventId),
  ),
);
```

The project's declared default, when present, joins the context roots. Unknown
context roots produce `structure.validation_entry_not_found`, including a typed
event reference and repair suggestion. Module contexts may include globally
known roots/defaults outside the slice; graph and presence analysis begin only
at roots with local bodies. With no local roots, path-based findings are omitted,
while structural, reference, semantic, usage and presentation checks still run.

For module validation, supply the project-global state schema and known global
event IDs from a separately validated index. A caller-supplied external ID set
asserts identity knowledge; it does not verify external event bodies or metadata.
Keep using `StoryModuleValidator` for module ownership, dependencies and index
summary checks, and validate the assembled project for whole-project flow claims.

Orchestration and module entry-state analysis does not assume schema initial
values survive earlier activations or host edits. Presence guards and authored
writes can still establish safe reads within the analyzed paths. Global “read
without initialization” warnings are omitted in these contexts because an
external initializer may exist; local “read may be unset” and numeric-target
warnings remain. This can reveal warnings that fresh-state validation omits.

`StoryValidator.validate(project)` keeps the previous standalone behavior.
`additionalEntryEventIds` retains its legacy graph-only behavior, including
ignoring unresolved extra roots; it does not seed presence analysis. Prefer
context roots for new orchestration/module integrations, where roots are checked
and also seed state-use analysis.

## Consumer reuse and compatibility

Reference, variable-use and graph validation share the authored analysis index.
Module outbound-summary verification uses the same reference traversal. Studio's
reference-runtime bridge projects outgoing IDs from the public analysis rather
than recursively decoding transitions itself; its sorted neighbor IDs and UI
behavior are preserved.

The API is additive. Story Format v1, package dependencies, runtime execution,
RNG consumption, snapshots and save formats are unchanged. The existing public
validation report ordering and default diagnostic behavior remain intact.
See `example/authored_analysis_and_validation.dart` for a runnable example.
