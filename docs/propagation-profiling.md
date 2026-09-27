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
SDK, hardware and OS. Raw artifacts stay outside the checkout: `environment.json`,
`baseline.json`, per-run `results.json`, launch logs and compressed CPU/timeline
exports. Do not publish launch logs containing VM Service authentication URLs.
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
