# Deterministic Randomness — `story_engine.lcg32` Version 1

Status: normative cross-runtime deterministic-random profile for Runtime
Semantics Core Revision 1.

This document specifies the pseudo-random algorithm and bounded-integer
sampling behavior required for **exact seeded random-route parity** across
conforming runtimes.

A conforming implementation given the same authored project, runtime-relevant
initial state, input trace, algorithm/version, and seed MUST produce the same
bounded samples and therefore the same weighted selections as every other
conforming implementation.

This is an interoperability algorithm, not a cryptographic random-number
generator. Hosts that need nondeterministic runs may choose seeds from their own
entropy source, but once a seed is selected the narrative runtime behavior
defined here is deterministic.

## 1. Compatibility identity

The profile identity is:

```text
algorithmId:      story_engine.lcg32
algorithmVersion: 1
```

The algorithm ID/version is independent from:

- Story Format version;
- Runtime Semantics Core Revision;
- runtime-snapshot format version;
- package/SDK version.

An implementation MUST NOT change the sequence produced by
`story_engine.lcg32` version 1 while continuing to advertise this identity.
Any incompatible algorithm, state-layout, candidate-construction, or bounded-
sampling change requires a new algorithm ID or algorithm version.

## 2. Integer domains and constants

All values in this profile are non-negative integers. The following constants
are normative:

```text
UINT32_RANGE   = 4294967296       # 2^32
UINT32_MAX     = 4294967295       # 2^32 - 1
MULTIPLIER     = 1664525
INCREMENT      = 1013904223
HIGH21_RANGE   = 2097152          # 2^21
EXACT53_RANGE  = 9007199254740992 # 2^53
MAX_BOUND      = 9007199254740991 # 2^53 - 1
```

The largest intermediate in one LCG update is:

```text
MULTIPLIER * UINT32_MAX + INCREMENT
= 7149081450614098
```

which is below `2^53`. The largest exact-53 candidate is `2^53 - 1`.
Implementations may use wider native integer types, unsigned arithmetic, or
other exact integer machinery, but they MUST produce the mathematical results
specified here. Signed overflow, floating-point rounding, platform default RNG
behavior, or implementation-defined integer overflow MUST NOT influence the
sequence.

## 3. Seed domain and initialization

A seed is an integer in the inclusive range:

```text
0 <= seed <= 4294967295
```

There is **no seed hashing, mixing, remapping, zero substitution, or signed
reinterpretation** in version 1.

Initialization is exactly:

```text
initialSeed = seed
state       = seed
```

Seeds outside the allowed range are invalid inputs to this profile.

A host API may define how a seed is chosen when the caller omits one. That host
policy is outside this algorithm. Cross-runtime conformance vectors always make
the seed explicit.

## 4. 32-bit LCG state transition

One underlying state advance is:

```text
state = (MULTIPLIER * state + INCREMENT) mod UINT32_RANGE
output = state
```

Equivalently:

```text
state[n + 1] = (1664525 * state[n] + 1013904223) mod 4294967296
```

`nextUint32()` returns the updated state, not the previous state.

The state is therefore always in `0..4294967295`.

### 4.1 Reference state sequences

The first eight `nextUint32()` outputs are:

| seed | outputs |
|---:|---|
| 0 | `1013904223, 1196435762, 3519870697, 2868466484, 1649599747, 2670642822, 1476291629, 2748932008` |
| 1 | `1015568748, 1586005467, 2165703038, 3027450565, 217083232, 1587069247, 3327581586, 2388811721` |
| 42 | `1083814273, 378494188, 2479403867, 955863294, 1613448261, 110225632, 1921058495, 508781842` |
| 4294967295 | `1012239698, 806866057, 579071060, 2709482403, 3082116262, 3754216397, 3919968968, 3109052295` |

## 5. Exact 53-bit candidate construction

One candidate consumes **two** consecutive LCG state advances.

Given:

```text
first  = nextUint32()
second = nextUint32()
```

construct:

```text
high21    = first mod HIGH21_RANGE
candidate = high21 * UINT32_RANGE + second
```

Therefore:

```text
0 <= candidate < 2^53
```

This deliberately uses the low 21 bits of the first 32-bit output and all 32
bits of the second output. An implementation MUST NOT substitute a platform
53-bit random primitive, concatenate a different bit range, reverse the draws,
or reuse one underlying draw.

For seed `42`, the first five candidates are:

| candidate | first draw | second draw | exact-53 value |
|---:|---:|---:|---:|
| 1 | 1083814273 | 378494188 | 7232042405158124 |
| 2 | 2479403867 | 955863294 | 2449004192944382 |
| 3 | 1613448261 | 110225632 | 3171287997475040 |
| 4 | 1921058495 | 508781842 | 288892894012690 |
| 5 | 3753001289 | 4271921684 | 5138335641131540 |

## 6. Bounded integer sampling

The narrative runtime requires a bounded integer operation:

```text
nextInt(maxExclusive)
```

The valid bound domain is:

```text
1 <= maxExclusive <= 9007199254740991
```

The result MUST satisfy:

```text
0 <= result < maxExclusive
```

### 6.1 Rejection-sampling algorithm

For a valid `maxExclusive`, compute once for that call:

```text
acceptanceLimit = EXACT53_RANGE
                  - (EXACT53_RANGE mod maxExclusive)
```

Then repeat:

```text
candidate = nextExact53()

if candidate < acceptanceLimit:
    return candidate mod maxExclusive

# otherwise reject candidate and try again
```

The comparison is strictly `<`. A candidate equal to `acceptanceLimit` is
rejected.

This rule prevents modulo bias. One logical `nextInt` call normally consumes
two LCG state advances but may consume four, six, or more when candidates are
rejected.

A bound of `1` still consumes one accepted exact-53 candidate and returns `0`.
Narrative implementations MUST NOT optimize that case by skipping RNG
consumption, because doing so would shift every later weighted selection.

### 6.2 Sequential bounded reference vector

Starting from seed `42`, call `nextInt` in this exact bound order:

```text
1
2
3
7
10
65537
4294967295
9007199254740991
```

The required results are:

```text
0
0
2
2
0
52948
3701641493
5135024634160890
```

After the final accepted sample, the current LCG state MUST be:

```text
389768954
```

### 6.3 Rejection reference vector

Starting from seed `3`, call:

```text
nextInt(4503599627370497)
```

The acceptance limit is exactly:

```text
4503599627370497
```

Attempt 1 constructs:

```text
first draw:   1018897798
second draw:  2365144877
candidate:    7641084192177965
```

This candidate is rejected because it is not below the acceptance limit.

Attempt 2 constructs:

```text
first draw:   3752335016
second draw:  3345418727
candidate:    2276713969420775
```

This candidate is accepted, so the required return value is:

```text
2276713969420775
```

and the current LCG state is:

```text
3345418727
```

This vector is important: a conforming snapshot cannot persist only the seed
plus a logical bounded-draw count, because one bounded draw may consume a
variable number of underlying state advances.

## 7. Weighted-transition integration

Runtime Semantics Core Revision 1 defines when a weighted node consumes a draw
and how the result maps to authored options. This document supplies the exact
bounded sample used by that rule.

For authored positive integer weights:

```text
weights = [w0, w1, ..., wn]
total   = w0 + w1 + ... + wn
sample  = nextInt(total)
```

Options own authored-order half-open intervals:

```text
option 0: [0, w0)
option 1: [w0, w0 + w1)
...
```

Exactly one bounded draw is requested for each weighted node actually reached.
If the selected option contains another weighted node, that nested node requests
its own bounded draw.

### 7.1 Weighted route reference vector

For weights:

```text
[1, 3, 2]
```

the intervals are:

```text
option 0: [0, 1)
option 1: [1, 4)
option 2: [4, 6)
```

Twelve consecutive weighted selections must produce these option indexes:

| seed | selected option indexes |
|---:|---|
| 0 | `0, 2, 2, 2, 2, 1, 1, 0, 1, 0, 0, 2` |
| 1 | `1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1` |
| 42 | `1, 1, 1, 2, 1, 2, 1, 0, 0, 1, 0, 2` |
| 4294967295 | `2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1` |

The machine-readable source for these Stage 8C algorithm vectors is
`test/fixtures/rng_v1_reference_vectors.json` in the source repository.
Stage 8D may wrap such vectors in a broader runtime-conformance fixture format;
it must not reinterpret this algorithm.

## 8. Snapshot state and restoration

For `story_engine.lcg32` version 1, the persisted algorithm-owned state is:

```text
stateWords[0] = original seed
stateWords[1] = current 32-bit LCG state
```

Both words are integers in `0..4294967295`.

Restoration is exactly:

```text
initialSeed = stateWords[0]
state       = stateWords[1]
```

No LCG advance occurs merely because a snapshot is restored. The next bounded
sample continues from the persisted `state`.

Application consumers should continue treating `stateWords` as opaque
persistence data. This section is normative for runtime implementers that claim
support for the algorithm ID/version.

## 9. Transactional RNG behavior

Runtime Semantics Core Revision 1 makes `start`, choice selection, and continue
transactional across narrative state, history, lifecycle, current event, and
random-stream state.

Consequently, if an operation consumes one or more random candidates and later
fails, the operation does not commit the advanced RNG state. A retry from the
same committed runtime state therefore observes the same future random stream.

This is a runtime transaction rule layered on top of the generator algorithm;
it does not alter the LCG recurrence itself.

## 10. Cross-language implementation requirements

A runtime claiming exact seeded-route conformance MUST:

1. advertise or internally bind to `story_engine.lcg32` version 1 for these
   vectors;
2. accept the exact seed domain in Section 3;
3. initialize state without seed transformation;
4. implement the exact LCG recurrence in Section 4;
5. build candidates from two draws exactly as Section 5 specifies;
6. implement the exact rejection loop and strict acceptance comparison in
   Section 6;
7. preserve every consumed underlying state advance, including rejected
   candidates;
8. use Runtime Semantics Core Revision 1 weighted-node draw consumption and
   authored-order interval mapping;
9. restore the exact current state from compatible snapshots;
10. pass the normative reference vectors in this document and the corresponding
    machine-readable Stage 8C vector file.

Using `System.Random`, C++ standard-library engines, Godot's platform RNG,
`dart:math Random`, or any other host-default generator is non-conforming even
when initialized with the same numeric seed.

## 11. What this profile does not specify

This profile does not define:

- cryptographic security;
- host entropy collection;
- how a game chooses a new seed;
- multiplayer seed negotiation;
- Story Format representation of RNG configuration;
- caller-selectable authored RNG algorithms;
- probability syntax beyond positive integer transition weights;
- the Stage 8D general conformance-fixture/report format.

Story Format v1 remains unchanged. Weighted authored data continues to store
positive integer weights only; the runtime deterministic-random profile remains
an execution/conformance concern.

## 12. Version-1 invariants

For `story_engine.lcg32` version 1, the following are frozen:

1. seed range `0..2^32-1`;
2. initial LCG state equals the seed exactly;
3. multiplier `1664525`;
4. increment `1013904223`;
5. modulus `2^32`;
6. `nextUint32` advances before returning;
7. exact-53 candidates use the low 21 bits of the first draw and all 32 bits of
   the second draw;
8. bounded sampling uses the `2^53` rejection limit formula in Section 6;
9. candidate acceptance uses strict `<`;
10. accepted output is `candidate mod maxExclusive`;
11. bound `1` still consumes a candidate;
12. rejected candidates consume and retain their underlying state advances;
13. snapshot state words are `[originalSeed, currentState]`;
14. weighted selection consumes and maps bounded samples according to Runtime
    Semantics Core Revision 1;
15. the same explicit seed and same deterministic narrative inputs produce the
    exact same weighted route across conforming runtimes.
