# Runtime capability profile v1 reference vectors

These files exercise Stage 8M independently of any host programming language.
`project-requirements.json` is compatible with `runtime-supported.json` and is
incompatible with `runtime-unsupported.json` for the ordered reasons frozen in
`expected-unsupported-issues.json`.

A runtime version of `99.0.0` is intentionally used by the unsupported fixture
to prove that package/runtime version ordering is not capability logic.
