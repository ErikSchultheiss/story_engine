# Runtime conformance corpus

This directory contains language-neutral behavioral fixtures for independent
runtime implementations.

Start with:

- `../doc/CONFORMANCE_FIXTURES_V1.md` — normative fixture/report contract;
- `fixtures/runtime-core-v1/fixture-set.json` — foundation fixture manifest;
- `fixtures/runtime-core-v1/lantern-mystery/` — self-contained Story Format v1
  project and six deterministic input/output cases;
- `report-example-v1.json` — example machine-readable result document.

The corpus is data-only. It contains no Dart source and does not require the
Dart reference runtime to interpret its project or expectation files.

A runtime runner should load each case independently, execute the declared input
trace, compare every expected observation plus final state/history, and emit an
`open_story.conformance_report` version 1 document.

The conformance files are not part of Story Format v1 and do not alter the
frozen authored-project contract.

## Extension Schema reference data

`extensions/schema-v1/` contains portable reference data for Extension Schema
contract version 1. It is not a `runtime-core-v1` execution fixture and does not
add semantic extension nodes to Story Format v1. It exists so independent tools
and runtimes can compare schema parsing/validation against the same data-only
contract.

## Runtime capability reference data

`capabilities/profile-v1/` contains Stage 8M project-requirement and target-
runtime capability documents plus a frozen incompatible-diagnostic sequence.
These vectors are separate from `runtime-core-v1` execution traces and can be
consumed by independent runtimes without Dart implementation knowledge.

## Production identity and explicit-input reference data

`presentation/identity-v1/` contains the Stage 8N stable presentation-unit and
source-revision sidecar vector. `authority/input-v1/` contains an explicit host-
fact vector whose harness-only wall-clock/global noise must not affect narrative
resolution. Both are language-neutral data contracts for later independent
runtime/tool implementations.

## Independent second-runtime proof

Stage 8O uses this exact corpus from a standalone C# console spike outside the
Dart package. The spike does not maintain C#-specific expected outputs; it reads
the same `runtime-core-v1-foundation` manifest and all six committed cases.
Passing therefore means independent observable agreement with the existing
golden vectors, not agreement with a translated copy of Dart behavior.

See `../doc/INDEPENDENT_CSHARP_RUNTIME_SPIKE.md` for the proof boundary.

## Finalization hardening and reference runner

`fixtures/runtime-finalization-v1/` adds ten separate core/aggregate cases for
rollback, malformed conditions, restore-and-continue, nested transitions, host
suspension and shared-state propagation. Read
[Runtime finalization conformance](../doc/CONFORMANCE_HARDENING_V1.md) for the
input/observation contract and commands.

The standalone Dart runner is `tool/conformance/run_conformance.dart` in the
package root. Tools, portable tests and fixtures ship together in the public
source and Pub package. The independent C# proof remains limited to the original
six foundation cases.
