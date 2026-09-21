# Implementation review

Baseline: `cd34272` (approved design). Initial implementation: `ba211c3`.
Follow-up corrections: `110937b` and `f04ae41`. Two independent reviewers examined
standards and specification compliance, then rechecked their findings.

## Standards

No documented-standard breaches were found. One robustness heuristic was raised:
`FactoryScope` compared caller-owned override lists by identity, allowing in-place
list changes to leave stale overrides; it also applied overrides before validating
module/local changes.

Resolved in `f04ae41`: the state snapshots the installed module/local lists,
validates them before mutations, and always passes overrides to the container's
identity-aware comparison. Two widget regressions cover reused mutable lists and
rejection before a replacement can alter the live container. Targeted re-review
found no remaining issue. No structural split of the container was requested:
registration, resolution, propagation and teardown form one scope lifecycle.

## Spec

Two findings were raised against the approved lifetime/ownership contract:

1. Historical unique records were reconstructed when an override changed, despite
   the contract requiring a new instance per resolution. Resolved in `f04ae41`:
   those records retire as snapshots; new resolutions use the current override.
   Explicit watchers are still invalidated and callbacks are deduplicated per
   declaration. Regression tests verify no unsolicited construction and exactly
   one cleanup per owned instance.
2. Direct unique reads without cleanup were retained unnecessarily. Resolved in
   `f04ae41`: cleanup-free, unobserved direct resolutions leave container
   bookkeeping. Internal graph reads retain dependency edges, and owned unique
   resources with cleanup remain scope-managed. A VM-service forced-GC diagnostic
   confirmed collection before scope close after 10,001 direct resolutions.

Targeted re-review accepted both fixes. No other confirmed gaps were reported in
scopes, observation/error recovery, cleanup, the Provider bridge, generation or
the example. Platform build limitations remain explicit in `support.md`.

Standards: one heuristic resolved, none pending. Spec: two findings resolved,
none pending; the most consequential was unsolicited unique reconstruction.
