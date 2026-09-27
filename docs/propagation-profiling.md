# Propagation latency and CPU baseline

This companion to the [memory playbook](memory-profiling.md) measures a fixed
history of propagations before proposing an optimization. It changes neither
the graph implementation nor the public API. High RSS is not evidence of a leak.

## Reproduce on macOS

Use the supported Flutter SDK, Xcode and the same physical machine, power mode
and background workload for all three runs. Close unrelated CPU-heavy tasks.
From the repository root:

```sh
(cd example && flutter pub get)
python3 tool/profile_propagation.py "$HOME/factory-propagation-capture"
```

The destination must not exist. The runner starts and stops three independent
`flutter run -d macos --profile --no-dds -t lib/propagation_profile.dart`
processes. It records their distinct VM PIDs, commands, commit, source hashes,
SDK, hardware and OS. Live capture artifacts go outside the checkout: `environment.json`,
`baseline.json`, per-run `results.json`, launch logs and compressed CPU/timeline
exports. Selected baseline/CPU/timeline evidence is versioned below; launch logs
and service URLs are excluded. Historical commands retain their original local
output paths. Do not publish launch logs containing VM Service authentication URLs.
Decompress timeline JSON to load it in a Chrome trace-compatible viewer; CPU
JSON is the VM Service `CpuSamples` response, including its stack/function table.

## Workload and measurement boundaries

Each process runs chains of 10, 100 and 1,000 nodes, including one external
source. Node i watches node i-1 and produces its integer value plus one, with
`ChangePolicy.recreate`. There are N-1 directed edges, mean in-degree
(N-1)/N and directed density 1/N (edges / N(N-1)). Declarations are registered
source-first, but reading only the leaf creates records leaf-first. This order
is deliberate and may be less favorable than source-first resolution.

Each chain gets a fresh container, one initial construction, 10 discarded warmup
waves and 40 measured waves, then awaited close. Each wave replaces the borrowed
source integer through `setOverrides`. Only that synchronous call is timed,
including counter callbacks and, in traced runs, the timeline wrapper. Override
allocation, leaf verification, initial construction, JSON encoding and close are
outside the interval. `constructionUs` is separate; close is awaited but not timed.
No GC is forced inside the sequence. Sample order is retained in `wallUs`.

All N-1 owned nodes have a trivial cleanup callback. Retired generations stay
until close: this is a finite-history workload, **not a stationary steady-state
benchmark**. At every wave, the harness checks the leaf value, cumulative builds,
exactly N notifications per wave and zero early cleanup. After close, cleanup
must equal builds: (N-1) × 51. Each chain must report N × 50 notifications.
Checks throw in profile mode; they do not rely on disabled assertions.

The baseline phase uses only `Stopwatch` and counters, with timeline streams off.
The traced phase enables the Dart stream and wraps every wave in
`factory.propagate`. Runs 1 and 3 use baseline then trace; run 2 reverses that
order. Both phases repeat identical fresh-container workloads. This estimates
the incremental tracing/capture perturbation, including order/GC noise, not
the unobservable cost of completely instrumentation-free execution. Counter
and stopwatch costs are shared by both phases. CPU sampling is the profile VM's
default in both phases; no sampling-rate change is made.

Percentiles use nearest rank: sorted element ceil(p × 40), one-based. Wall time
includes scheduling and GC; it is **not CPU time**. CPU samples attribute on-CPU
stacks statistically, not an exact duration for a method. The representative
CPU capture covers construction, warmup, measured waves and close for the traced
1,000-node scenario. Timeline event arguments distinguish warmup from measured
waves; check the export has all 50 complete events before using it.

## Contract and review checks

Run `dart test test/changes_test.dart` in `packages/factory_core` for
`read/watch/select`, overrides, coherent diamonds and retired generations.
The full core suite additionally checks dependency cleanup order. The benchmark
uses a chain only; its results do not characterize every topology or a Flutter
frame. No timing thresholds are installed in CI. Follow
[CONTRIBUTING](../CONTRIBUTING.md) for the full suite before accepting a change.

Revert the harness, runner and this companion document together to remove this
measurement workflow; the core implementation and memory workflow are independent.

Profile-mode rationale: [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance).

## Reference baseline: 2026-09-27

There is enough evidence to investigate this long-chain recreation workload.
There is not yet evidence that any particular graph rewrite is the right fix.
Keep production changes in a separate issue with these counters as constraints.

Captured commit: `d951bffe9190e55c7adf6c70f37a982caee48ace`, clean tracked tree.
Flutter 3.47.2 (`d3b14c8769`), Dart 3.13.2, macOS 27.0 (`26A428`), Apple M5
arm64, 10 cores, 16 GiB RAM. Battery power, low-power mode off, 58% at start;
no test/build jobs ran concurrently with measurement. Thermal state and unrelated
OS activity were not controlled. Treat this as a local reference, not a universal
M5 budget. The subsequent collector completeness check does not alter the harness.

The [raw baseline](acceptance/evidence/propagation/baseline.json) contains each
ordered sample, exact commands, both source hashes and full environment metadata.
VM PIDs were 30973, 33556 and 36145. Initial construction and close are excluded
from the following **wall-time microseconds**, rounded to one decimal:

| Nodes | Run 1 p50 / p95 | Run 2 p50 / p95 | Run 3 p50 / p95 |
| ---: | ---: | ---: | ---: |
| 10 | 46.8 / 79.1 | 44.9 / 75.5 | 51.2 / 71.4 |
| 100 | 4,134.1 / 6,553.9 | 4,376.9 / 6,862.3 | 4,254.2 / 6,585.8 |
| 1,000 | 442,749.9 / 726,125.0 | 514,703.3 / 787,997.6 | 455,953.9 / 731,316.4 |

For 1,000 nodes, median of the first ten measured waves versus the last ten was
243.1→675.9 ms, 274.9→743.3 ms and 249.1→689.0 ms. Retained generations and
history matter; do not compare this p95 against a workload with a different wave
count or container reset policy. The approximately 100-fold p50 change from 100
to 1,000 nodes is evidence of poor scaling for this topology/order/history, not
proof of a general complexity bound or a memory leak.

All six cases per process passed the value and counter checks. For sizes
10/100/1,000, builds and cleanup were respectively 459/5,049/50,949; notifications
were 500/5,000/50,000. No cleanup occurred before close. Core contract tests also
passed, including diamonds, selectors, unobserved reads and cleanup order.

### Instrumentation and CPU evidence

Relative tracing perturbation is `100 × (traced / baseline - 1)` for each
percentile. This paired estimate includes noise and order effects:

| Nodes | Run 1 p50 / p95 | Run 2 p50 / p95 | Run 3 p50 / p95 |
| ---: | ---: | ---: | ---: |
| 10 | +1.69% / -0.48% | +6.96% / +4.86% | -8.55% / +13.95% |
| 100 | +8.17% / +5.61% | -2.95% / -1.11% | +5.83% / +3.45% |
| 1,000 | +2.75% / -0.61% | -3.41% / +4.57% | +1.07% / +0.30% |

Negative estimates mean tracing overhead cannot be isolated from this noise;
they do not mean tracing makes propagation faster. Shared counters and timing
costs are not subtracted. Do not use these estimates as the cost of a future
observer/diagnostic feature: measure that feature separately with the same workload.

Each [evidence directory](acceptance/evidence/propagation) CPU export has a matching
timeline and checksums. All timelines contain 50 begin/end pairs (10 warmup,
40 measured). Sampling period is 1,000 µs with maximum stack depth 128.
To reproduce attribution, select samples whose timestamp is inside a measured
`factory.propagate` begin/end interval, and count each function index at most once
per sample stack; resolve indices through `functions`. Percentages below are
inclusive membership, overlap, and must not be added:

| Run | All CPU samples | Measured samples | Truncated measured stacks | `_propagate` | `_build` |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 12,950 | 12,156 | 492 | 96.09% | 92.45% |
| 2 | 14,349 | 13,525 | 582 | 95.82% | 91.98% |
| 3 | 13,168 | 12,349 | 574 | 95.40% | 91.85% |

These samples support investigating replacement/build work first, including
retired-record traversal and edge redirection. They do not isolate either loop's
cost: inlining, truncated recursive stacks and shared callees limit attribution.
CPU sample count × sampling period is not an exact process CPU duration, nor
should it be equated to the stopwatch wall time.

### Relative follow-up threshold

Across the three untraced processes, max/min p50 spread was 14.0%, 5.9% and
16.3% for the three sizes; p95 spread was 10.8%, 4.7% and 8.5%. After observing
that variability, propose **+30% above the median of this baseline's three runs**
in p50 or p95 as a manual investigation trigger, only if reproduced in all three
new comparable processes with identical counters, topology and wave history.
This is provisional, not statistical significance, a CI gate or an absolute
performance budget. Repeat the baseline after changing SDK, power mode or hardware.

Validation on this checkout: core 37 tests, generator 16, Flutter adapter 20,
example 4; all associated analyzers passed. Regeneration left the example output
unchanged and `./tool/verify_consumers.sh` passed. With `tool/requirements.txt`
installed, `python -m unittest discover -s tool -p 'test_*.py'` passed 15 tests,
including the local HTTP collector contract. All seven evidence checksums passed.
