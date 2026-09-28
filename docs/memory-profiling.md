# Reproducible memory profiling

For propagation wall-time percentiles and CPU/timeline evidence, use the
[latency companion](propagation-profiling.md). Memory and latency baselines
answer different questions.

Use this playbook to distinguish contractual retention from a regression. A
frequent GC or one high sample is not evidence of a leak: require sustained
growth in three comparable runs and inspect the retaining path.

## Reference environment and capture protocol

Record the commit, OS, architecture, Dart/Flutter versions, build mode and
device. Use the same environment for all three runs.

1. Resolve dependencies from a clean checkout and run the full tests.
2. Start the scenario in profile mode and connect Dart DevTools Memory.
3. Warm up with 10% of the measured iterations, then discard those values.
4. Force GC twice, wait for asynchronous cleanup, and capture the baseline.
5. Run the measured iterations, force GC twice, and capture the result.
6. Export heap and external-memory CSV, record RSS, and save before/after heap
   snapshots. If retained size grows, use Diff, Trace Instances and the retaining
   path for `FactoryContainer`, the dependency value, and observer callbacks.
7. Restart the process and repeat twice. Never reuse one process as three runs.

Store artifacts under an ignored external directory named with commit, scenario
and run; do not commit potentially sensitive snapshots. Attach the numeric summary
to the regression issue.

## Scenarios

| Scenario | Measured iterations | Observable completion |
| --- | ---: | --- |
| Container lifecycle | 100 | Close future completes; observer subscriptions balance |
| Flutter scope navigation | 100 | `onClose` completes; listeners and owned cleanup balance |
| Cleanup-free `unique` | 1,000 | Every resolution is distinct; no scope cleanup required |
| Owned `unique` | 1,000 | Every instance is released exactly once on close |
| Scoped replacements | 100 | Retired generations close after dependents |
| Propagation graph | 100 waves at 10, 100 and 1,000 nodes | One coherent notification per declaration per wave |

The first four functional counters are permanently covered by
[`container_test.dart`](../packages/factory_core/test/container_test.dart) and
[`factory_scope_test.dart`](../test/factory_scope_test.dart). Profiling adds
heap, retained size, external memory and RSS; unit tests intentionally do not
assert fragile byte thresholds.

## Recording baselines

Do not set an absolute byte budget until every scenario has three comparable
runs. Record `before`, `after GC`, delta, peak RSS, external-memory delta,
snapshot/CSV paths, and retaining-path conclusion for runs 1–3. Classify each
result as:

- **Contractual retention:** owned cleanup values or retired scoped generations
  remain reachable until the owning scope closes.
- **Temporary pressure:** peak grows but post-GC retained size returns to the
  baseline range.
- **Suspected leak:** post-GC retained size grows with iterations in all three
  fresh-process runs and a retaining path survives expected closure.

Only the last classification opens a regression. Use the repository's memory
regression issue form and attach the evidence paths or sanitized artifacts.

## Run the profiling harness

```sh
cd example
flutter run -d macos --profile -t lib/memory_profile.dart
```

Invoke `ext.factory.runMemoryScenario` through the VM Service with one of
`containerLifecycle`, `flutterScopeLifecycle`, `uniqueWithoutCleanup`,
`uniqueWithCleanup`, `scopedReplacements`, or `propagationGraphs`.
Compare fresh captures from the same environment using the protocol above.
