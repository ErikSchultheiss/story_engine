# Runtime Bundle Build Pipeline — Contract Revision 1

This document defines the Stage 8K contract that separates open authoring source
from deterministic shipping/runtime artifacts. It builds on Story Format v1,
Stage 8H modular/indexed loading, and the language-neutral runtime semantics.

The central rule is:

```text
OPEN STORY FORMAT
human-readable authored source of truth
        |
        v
VALIDATION / BUILD INPUT
        |
        v
DETERMINISTIC COMPILER
project index + independently loadable module bytes
        |
        v
RUNTIME BUNDLE PACKAGER
hashes + canonical manifest + stable bundle identity
        |
        v
SHIPPING RUNTIME BUNDLE
compact/indexed/module-oriented representation
```

The runtime bundle is derived output. It MUST NOT become the only editable or
canonical representation of an authored project.

## 1. Scope

Revision 1 freezes:

- separation between authored Story Format and shipping/runtime bundles;
- a deterministic byte-oriented bundle layout;
- SHA-256 content hashes for compiled index/module artifacts;
- a canonical manifest identity and deterministic bundle ID;
- build-profile and builder identity/version participation in reproducibility;
- alignment with Stage 8H module IDs, dependency order, and project identity;
- integrity verification of the exact shipping artifact set;
- the rule that build/storage optimization cannot change narrative semantics.

Revision 1 does **not** freeze:

- a final binary encoding for compiled event/module bodies;
- compression technology;
- archive/container format;
- a production compiler implementation;
- platform asset packaging such as Unity Addressables or Unreal pak files;
- patch/DLC compatibility rules (Stage 8L);
- runtime capability negotiation, now defined by `RUNTIME_CAPABILITIES_V1.md`;
- CDN/update transport.

The Dart `StoryRuntimeBundleBuilder` is therefore a deterministic **reference
packager**, not a claim that the first authoring-tool release already contains a
production narrative compiler.

## 2. Authoring source remains canonical

Story Format remains the source-of-truth authoring contract. Source-control,
review, editing, migrations, and long-term project ownership operate on the open
Story Format project and its associated portable authoring data.

A runtime bundle MAY be compact, indexed, transformed, or binary. It is allowed
to optimize for startup and bounded loading because it is reproducible derived
output.

A tool MUST NOT require authors to edit compiled module bytes or a runtime-bundle
manifest directly.

Deleting generated runtime bundles MUST NOT destroy the authored project.

## 3. Compiler versus packager

Stage 8K distinguishes two responsibilities.

### 3.1 Compiler

A compiler transforms validated authored/project data into deterministic runtime
artifacts:

- one lightweight compiled/index artifact;
- one compiled artifact per Stage 8H module.

The exact bytes are build-profile specific and are intentionally not frozen in
Revision 1.

For identical semantic source, build profile, builder/tool version, and build
configuration, the compiler MUST emit identical artifact bytes.

### 3.2 Packager

The packager receives the already-compiled byte artifacts plus the validated
Stage 8H `StoryProjectIndex`. It:

1. verifies the module artifact set exactly matches the indexed module set;
2. assigns canonical portable paths;
3. hashes every artifact byte-for-byte using SHA-256;
4. emits a canonical runtime-bundle manifest;
5. derives a stable bundle ID from the canonical unsigned manifest identity;
6. verifies the final bundle file set and content hashes.

This split lets the contract stabilize before a final optimized compiler exists.

## 4. Runtime Bundle Contract Revision 1

Manifest identity:

```text
contract: open_story.runtime_bundle
contractVersion: 1
sourceStoryFormatVersion: 1
```

The manifest records:

- project ID;
- build profile;
- builder/tool ID and version;
- compiled index path, byte length, and content hash;
- each Stage 8H module ID;
- each compiled module path, byte length, content hash, and dependency list;
- the complete bundle ID.

No machine-local absolute paths, timestamps, usernames, temporary directories,
thread IDs, filesystem inode data, or wall-clock build times may participate in
bundle identity.

## 5. Canonical layout

Revision 1 uses portable logical paths:

```text
runtime-manifest.json
index.runtime
modules/<portable-module-token>.runtime
```

Module filenames are derived reversibly from the stable ASCII `StoryModuleId`
using lower-case RFC 4648 Base32 without padding. Mutable titles or source file
locations never participate in shipping paths.

A physical host may later place these logical files inside an archive, asset
bundle, database, package, CDN object set, or other storage technology. That
outer transport is not part of narrative semantics.

## 6. Content hashing

Every compiled index/module artifact uses SHA-256 over its exact byte sequence.
The canonical wire value is:

```text
sha256:<64 lower-case hexadecimal digits>
```

A content hash identifies bytes. It does not by itself mean that two artifacts
are semantically compatible.

Changing one byte MUST change the expected content hash. Runtime consumers or
build tools MUST reject an artifact whose byte count or SHA-256 digest does not
match its manifest descriptor. Manifest byte lengths are non-negative integers
within the portable exact-integer range `0..9007199254740991`.

## 7. Bundle identity

The bundle ID is also a SHA-256 content hash. It is computed over UTF-8 bytes of
the canonical **unsigned manifest identity payload**.

That payload contains, in this exact logical field order:

1. `contract`;
2. `contractVersion`;
3. `projectId`;
4. `sourceStoryFormatVersion`;
5. `buildProfile`;
6. `builder` (`id`, then `version`);
7. `index` (`path`, `contentHash`, `byteLength`);
8. `modules` in Stage 8H module declaration order.

Each module contains:

1. `moduleId`;
2. `path`;
3. `contentHash`;
4. `byteLength`;
5. `dependencies` in Stage 8H declaration order.

The payload uses two-space-indented JSON, LF newlines, and one final LF. The
`bundleId` field itself is excluded from the hashed payload to avoid recursive
identity.

The final manifest then adds the resulting `bundleId` while preserving the same
canonical deterministic encoding rules.

Therefore identical source/build inputs and tool versions produce the same
artifact hashes and bundle ID. A module-byte change, index-byte change,
build-profile change, or builder-version change produces a different bundle
identity.

## 8. Stage 8H alignment

A runtime bundle represents one logical Stage 8H project index.

The compiled module set MUST contain exactly one artifact for every indexed
module ID and no unindexed module artifacts.

Manifest dependency lists MUST preserve each `StoryModuleIndexEntry.dependencies`
sequence. The packager does not infer a new dependency graph from compiled
bytes.

Event IDs remain globally stable and are not replaced by module-local offsets as
public semantic identity. An optimized compiler may internally use tables or
offsets, but external/debug/conformance behavior remains defined by stable IDs.

## 9. Determinism rules

A conforming deterministic build MUST NOT incorporate:

- filesystem enumeration order;
- map/hash-table iteration order not fixed by the contract;
- wall-clock time;
- locale;
- operating-system path separators;
- random UUIDs/nonces;
- process IDs;
- scheduler timing;
- machine-specific absolute paths.

Module descriptors are emitted in Stage 8H index order. Physical bundle file
order is canonical manifest, index, then modules in that descriptor order.

Parallel compilation is permitted, but its completion order MUST NOT change the
resulting bytes, manifest ordering, or bundle identity.

## 10. Semantic equivalence

Compilation is an optimization boundary, not a new narrative language.

A compiled runtime bundle targeting Runtime Semantics Core Revision 1 MUST
preserve the same observable behavior as the validated authored project for all
supported capabilities:

- state/unset semantics;
- event and effect ordering;
- choice availability;
- transitions;
- exact Stage 8C deterministic randomness;
- runtime history;
- termination;
- host-action/session behavior when that profile supports it.

A compiler MUST fail rather than silently transform unsupported semantics into a
different story.

## 11. Integrity verification

Before trusting a bundle, a consumer or build verification step SHOULD:

1. parse the strict manifest;
2. recompute and verify its bundle ID;
3. require the exact manifest-declared artifact file set;
4. verify every declared byte length;
5. verify every SHA-256 content hash.

The Dart reference `StoryRuntimeBundleBuilder.verifyIntegrity(...)` performs
this packaging-level verification. It does not replace semantic validation of
authored source or Stage 8H index/body verification before compilation.

## 12. Reproducibility proof

Stage 8K regression coverage proves:

- the standard SHA-256 `abc` vector;
- a canonical lower-case Base32 module-path vector;
- map input order does not affect the bundle;
- identical build inputs produce byte-identical logical bundle files;
- changing one compiled module changes that module hash and the bundle ID;
- changing builder version changes bundle identity;
- missing/extra module artifacts are rejected;
- tampered bytes fail integrity verification;
- a 100-module bundle remains an indexed module artifact set rather than one
  monolithic compiled payload.

These tests establish the packaging contract. Later large-corpus performance
benchmarks remain a Stage 21 responsibility.

## 13. Story Format v1 remains frozen

Stage 8K does not add runtime-bundle fields to Story Format v1. In particular,
Story Format v1 receives no:

```text
bundleId
contentHash
compiledPath
builderVersion
runtimeArtifact
```

The relationship is one-way:

```text
Story Format source -> deterministic derived runtime bundle
```

A runtime bundle MUST NOT be round-tripped back and saved as though it were the
authored Story Format project.

## 14. Next boundary

Stage 8L now defines module/content versioning, patch/DLC manifests, and save
compatibility across content revisions. It may build on the stable content
hashes and module identities defined here, but transport/CDN/platform update
technology remains outside the core narrative contracts.

Stage 8O now independently pressure-tests the language-neutral semantics
using a small C# runtime spike before serious Stage 9 Studio work begins.
