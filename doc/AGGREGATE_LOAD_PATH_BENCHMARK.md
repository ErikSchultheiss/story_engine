# Aggregate JSON load-path verification

Run from the package root:

```sh
dart run benchmark/finalization_stage4_load_path.dart --samples=5 --warmups=2 --output=build/aggregate-load.json
```

Use `--scenario=compact`, `retained_history` or `large_retained_history` to select
one workload. All three run by default. Measurements are diagnostic; ordinary
tests do not assert machine-dependent timing thresholds.

The project and entry configuration are already available. Separate timers cover
JSON parsing, parsed-tree typed decode with validation, typed aggregate restore,
and the complete JSON-decode-to-aggregate-restore path. The complete timer calls
both public decode and restore, including their production validation. Timers
exclude fixture creation, verification, content revision/preflight, storage I/O,
project decoding/loading and observer dispatch. Phase medians come from separate
samples and must not be added to predict the complete-path median.

Each workload retains active, terminated and host-suspended sessions, nested
conditional/weighted transitions, histories with repeated entries, and multiple
state variables. A final shared commit leaves terminated sessions with their
historical state while updating unfinished sessions. Verification outside the
timers compares the entire serialized aggregate to the saved bytes, then compares
a future weighted input to direct typed restoration. Raw timings and future
checkpoint SHA-256 fingerprints appear in the report.

## Measured preparation reuse

Stage 4 measured the accepted Stage 3 runtime before changing production code.
Immutable event/choice lookup preparation was rebuilt for each retained session
inside aggregate validation and again inside aggregate reconstruction. The change
reuses those lookups within each aggregate pass, bound to the exact project
instance. The first session preserves preflight/error precedence; later sessions
still receive all snapshot-specific checks. Public codec and restore validation
remain in place, including history, RNG, state, pause mode, originating entry,
host protocol and cross-session invariants. Empty aggregate behavior is preserved.
No public API, authored format or checkpoint representation changed.

Reference results are in `benchmark/reference/finalization_stage4_load_before.json`
and `finalization_stage4_load_after.json`. These are one Linux x64 / Dart 3.13.1
JIT comparison using five samples and two warm-ups per phase:

| Scenario | Retained sessions | History steps | JSON bytes | Complete path before (ms) | After (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Compact | 10 | 175 | 25,737 | 3.005 | 3.071 |
| Retained history | 50 | 12,865 | 916,729 | 133.050 | 71.814 |
| Large retained history | 200 | 102,652 | 8,727,548 | 2,083.220 | 772.503 |

The largest measured full path decreased by about 63%; typed restoration alone
fell from 588.888 to 112.964 ms. Saved bytes and future fingerprints agreed before
and after in every scenario. The compact result demonstrates that this is not a
universal latency improvement. JIT, GC and host load affect these diagnostic
measurements; rerun for your target and content rather than treating them as an SLA.

This benchmark complements the existing Stage 9D6 regression gate. Its frozen
semantic baseline and 25 accepted budgets are unchanged. It introduces no history
compaction, codec bypass, migration or save-content compatibility shortcut.
