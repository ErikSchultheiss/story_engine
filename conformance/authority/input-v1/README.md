# Explicit host-input conformance vector v1

This Stage 8N vector pressures the Stage 8G/8J rule that mutable external facts
must be explicit inputs. `environmentNoise` is harness metadata and MUST NOT be
read by a conforming narrative runtime. Cases with the same `explicitResult`
must resolve identically even when the wall-clock and hidden-global noise differ.
Changing the explicit host fact is allowed to change narrative resolution.
