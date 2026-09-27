# Observed graph diagnostic experiment

Issue [#49](https://github.com/argote-dev/factory/issues/49). Decision: **adjust**.
An on-demand, redacted snapshot helps explain local visibility, override ownership
and retained generations. Keep it as an unpublished tool until a separate API
design addresses stable session identifiers and failed-edge provenance. It does
not reconstruct arbitrary Dart construction logic or replace existing errors.

## Run the isolated prototype

From the repository root, after installing the supported Dart SDK:

```sh
python3 tool/diagnostics/run.py test
python3 tool/diagnostics/run.py benchmark --output build/diagnostics-benchmark.json
```

The runner copies the current `packages/factory_core/lib` into an ignored package
under `.dart_tool/diagnostics_prototype`, appends the experimental part, resolves
dependencies and analyzes that package. Tests and the AOT benchmark use this copy.
Production packages, implementable interfaces, ownership and propagation remain
unchanged. Do not import this experimental function in applications. Re-run the
runner after changing the core; the generated copy is not a maintained fork.
Remove `tool/diagnostics`, this document and its evidence to roll back the
experiment independently of the English contribution convention.

The only opt-in is calling `captureFactoryGraph(container)`. There are no new
resolution hooks or global registries. Capture walks existing runtime bookkeeping
synchronously and returns an immutable `String`; temporary identity maps disappear
when capture returns. It does not call constructors, update/dispose callbacks,
selectors, observers, value/error `toString`, or instantiate lazy dependencies.
Use normal Factory declarations: malicious subclasses overriding metadata getters
are outside this experiment's no-callback guarantee.

## Experimental schema v0

Output is line-oriented text, starting with
`factory-graph-v0 ids=capture-local`. IDs use insertion order and root-first child
traversal. A capture made from a child includes its connected root and descendants.
Repeated captures of unchanged bookkeeping produce byte-identical text. IDs are
stable **only inside one capture**, not across mutations, closure, sessions or
processes. No timestamps, addresses, identity hashes or value representations
appear. Capture cost and output size grow with retained history, not just active
nodes. Call at a quiescent application boundary for the clearest interpretation;
a capture inside construction or cleanup can describe a transitional state.

| Row | Fields and interpretation |
| --- | --- |
| `scope` | Capture-local ID, parent ID or `none`, open/closed state. Closed children detach after awaited cleanup. |
| `declaration` | Declaration identity, installing scope, local internal/exposed visibility, local effective override (`none`, `borrowed`, `constructor`), lifetime, redacted or escaped name. The same declaration can appear in multiple scopes. |
| `generation` | Record identity, declaration, owning scope, active/retired state, value/error presence, cleanup callback ownership (`scope` or `none`), retained resolver presence. |
| `edge` | Consumer to dependency generation, coarse relation, whether the edge orders cleanup and whether replacement observation is active. `unknown` means the target was not in captured bookkeeping. |

An inherited declaration is shown at its installing ancestor, not duplicated in
children. Resolution searches locally first, then parents; a child's override
creates a local declaration. Exposure is **local module exposure**, not proof that
an arbitrary widget can read a type through Provider. `cleanup=none` does not mean
borrowed: an owned value may have no callback. The declaration override and
record callback fields together explain current ownership; old override provenance
is not retained for retired records. The owner is the scope responsible for any
registered cleanup, not the caller that initiated a read.

`active` describes a current record, including failed/empty records; it does not
promise a live value. A retired generation stays until scope close because an
unobserved consumer may still reference it, even if no tracked incoming edge
remains. Cleanup edges order consumers before dependencies at close. In-place
updates preserve a generation, while recreation retains the previous record.

### What relations are actually known?

- `watch-or-select`: membership in the runtime watch set. `select` uses `watch`
  internally, so their origins cannot be separated. A failed watch can have
  `observed=true` and `cleanup=false`.
- `read-or-resolve-or-retired-watch`: a cleanup dependency without a current watch.
  It can originate from `read`, a retained resolver, or historical observation.
  Stop-watching clears watch membership, so reporting every such edge as `read`
  would be misleading. Dependencies can accumulate across in-place updates.
- Top-level reads, arbitrary references captured by user closures, Provider
  subscriptions and unresolved lazy dependencies are not described. Direct
  cleanup-free unique reads can already have left bookkeeping.
- Rejected cycle edges and error payloads are absent. The current error is the
  authority for a cycle path. The snapshot is not a complete static graph, an
  event trace, a liveness oracle or a proof that an absent edge never existed.

### Sensitive data and lifetime

Names are redacted by default, and types, values, errors, stacks and arbitrary
metadata are omitted. `includeNames: true` exposes explicit names as UTF-16
`\uXXXX` sequences, including newlines, so one name cannot inject additional rows.
Escaping is **not anonymization**: names can contain tenant IDs or secrets. Review
opt-in exports before sharing. Even redacted topology can reveal application
structure. No value is serialized, including borrowed overrides and selector
results. A test value throws from `toString` to catch accidental serialization.

Snapshots retain strings only, never containers, declarations, instances,
callbacks or weak-reference registries. Lifecycle tests keep snapshots across
close and verify disposal, subscription cancellation and resolver invalidation.
A separate VM-service test forces collections after close and verifies weak
references to both container and instance clear while the snapshot remains usable.
It tests collection eligibility, not production GC timing or resident memory.

## Three diagnostic examples

The executable scenarios are in `tool/diagnostics/snapshot_test.dart`.

1. **Internal declaration not exposed:** the module installs a named secret and
   exposes only an integer declaration. Before any resolution the snapshot shows
   `visibility=internal` versus `visibility=exposed`, with no generation rows and
   no creation calls. Core reads of installed internal declarations succeed;
   a missing Provider lookup reports a missing type but does not explain module
   visibility. The snapshot adds useful composition context without creating it.
2. **Child override:** the parent installs a declaration and the child borrows an
   override. `d1` appears in both scopes; the child's row says `override=borrowed`
   and its resolved generation says `owner=s2 cleanup=none`. Current successful
   reads emit no ownership explanation. This is useful additional information.
3. **Cycle:** named `a` reads `b`, which reads `a`. The existing message is
   `Dependency cycle: a -> b -> a`. Snapshot rows show `value=absent error=present`
   but no rejected dependency edges. It identifies affected scope/records without
   retrying construction, but is less useful than the existing path for diagnosis.

## Cost experiment

This uses the [#48 baseline](propagation-profiling.md)'s source-first declarations,
leaf-first construction, chain sizes 10/100/1,000, ten discarded warmup waves,
40 measured waves, and retained recreation history. Each measured wave replaces
the borrowed source. Both modes check leaf values, build and notification counts,
zero premature cleanup and exact cleanup counts after close. Capturing mode also
materializes one redacted text snapshot after each wave, retaining the most recent
snapshot across close. Noncapturing mode does not call capture. Both share counters
and stopwatch overhead; this does not claim literally zero instrumentation cost.

The runner compiles once to a Dart AOT executable and runs three fresh processes,
reversing off/on order in process two. `wallUs` includes propagation plus capture
when enabled, while `captureUs` measures capture alone. Snapshot encoding is part
of capture; close, checks and initial construction are outside the interval.
P50/P95 use nearest rank. This is a wall-time experiment, **not CPU attribution**.
AOT CLI results must not be compared numerically to the historical Flutter profile
baseline as if they were the same execution environment. The paired off/on runs
are the estimate of capture perturbation; historical baseline reuse is of workload
and invariants. No timing threshold is installed in CI.

### Local results: 2026-09-27

[Raw samples and source hashes](acceptance/evidence/diagnostics/benchmark.json)
were captured on Apple M5, macOS 27.0 (26A428), Dart 3.13.2 arm64. No test/build
jobs ran concurrently with the measurements; power, thermals and unrelated OS
activity were not controlled. Three distinct process IDs are recorded. These
are local observations, not confidence intervals or portable performance budgets.
Times below are wall microseconds; the relative column is `100 × (on/off - 1)`.

| Run | Nodes | Off p50 / p95 (µs) | On p50 / p95 (µs) | Relative p50 / p95 |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 10 | 58.3 / 93.1 | 189.2 / 285.0 | +224.3% / +206.0% |
| 1 | 100 | 4067.1 / 6524.5 | 6010.4 / 9203.1 | +47.8% / +41.1% |
| 1 | 1,000 | 451493.4 / 718714.5 | 477816.3 / 736775.7 | +5.8% / +2.5% |
| 2 | 10 | 45.8 / 74.6 | 201.5 / 299.4 | +340.4% / +301.4% |
| 2 | 100 | 4407.2 / 6787.7 | 5643.9 / 8884.5 | +28.1% / +30.9% |
| 2 | 1,000 | 451025.0 / 705937.7 | 465175.7 / 728363.8 | +3.1% / +3.2% |
| 3 | 10 | 51.0 / 73.7 | 188.2 / 288.0 | +269.0% / +290.7% |
| 3 | 100 | 4350.4 / 6603.4 | 6101.9 / 9477.1 | +40.3% / +43.5% |
| 3 | 1,000 | 443235.1 / 715769.3 | 473593.4 / 749302.7 | +6.8% / +4.7% |

All 18 cases passed their lifecycle/value checks. At sizes 10/100/1,000 the
build/cleanup counts were 459/5,049/50,949 and notification counts 500/5,000/50,000.
The raw `captureUs` samples separate snapshot work from the total wave, but
allocation and GC can perturb later propagation too. Negative paired estimates
reflect noise/order effects, not evidence that capture accelerates propagation.
The historical CPU evidence remains useful for prioritizing core propagation
investigation, but no new CPU attribution claim follows from these stopwatch data.

**Decision:** adjust. Use on-demand captures during debugging, not a snapshot on
every propagation. Text capture has a measurable allocation/traversal cost and
retained history makes repeated output large. Before proposing a stable API,
design session IDs, optional event provenance for failed edges, a bounded output
policy, and a separate Provider visibility story. Do not add event hooks merely
to call this a complete graph. This issue's prototype can close without shipping
a public API or changing cleanup policy.

## Verification

Local verification on 2026-09-27:

- `python3 tool/diagnostics/run.py test`: six focused tests, analyzer clean, and
  forced-GC collection of the closed scope and instance with a retained snapshot.
- Core: 37 tests; generator: 16; Flutter adapter: 20; example: four. All associated
  analyzers passed. Example regeneration left the committed output unchanged.
- `bash tool/verify_consumers.sh`: passed all consumer contracts.
- Python tool suite: 15 tests passed after installing `tool/requirements.txt` in
  an ignored virtual environment; the system Python initially lacked PyYAML.
- All recorded benchmark source hashes match the checked-out sources; all 18
  benchmark scenarios passed value, notification and cleanup checks.

The CI package matrix now runs the prototype tests and collection check. Timing
measurements remain an explicit local experiment. This change is one cohesive
prototype with its tests, runner and decision report (roughly 600 authored lines,
plus generated measurement evidence); it exceeds a 400-line review slice rather
than separating tests or the decision from the behavior they validate.

## Standards

An independent read-only review of `547b544...8e4b001` found no documented-standard
violations or reportable code smells. It checked the contribution conventions,
English content, focused behavior tests, and separation of measurement evidence
from ignored build output. Tool-enforced rules were covered by the analyzers.

## Spec

A separate independent review against issue #49 found no missing, partial,
incorrect or unrequested behavior. It confirmed the schema and uncertainty
boundaries, lifecycle/collection evidence, three scenarios, paired baseline
workload, and the decision to adjust before designing a public API.

Standards: zero findings. Spec: zero findings. No unresolved review items.
