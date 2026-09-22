# Reproducible memory profiling

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
and run; do not commit potentially sensitive snapshots. Add the numeric summary
to the table below or to the regression issue.

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

## Reference baseline: macOS profile

Collected on 2026-09-21 with Flutter/Dart 3.13.2 stable, macOS arm64 on Apple
M5, using `example/lib/memory_profile.dart` in profile mode. Harness SHA-256:
`038f344dbd320d75c42ee444a028008e106eec3a8222db066d63ef944307e3e7`.
Each run used a fresh process and the same scenario order. Before and after each
scenario, `getAllocationProfile(gc: true)` forced GC; `getMemoryUsage` supplied
heap/external values and `getProcessMemoryUsage` supplied RSS.

Run the harness with:

```sh
cd example
flutter run -d macos --profile -t lib/memory_profile.dart
```

Invoke `ext.factory.runMemoryScenario` through the VM Service with one of
`containerLifecycle`, `flutterScopeLifecycle`, `uniqueWithoutCleanup`,
`uniqueWithCleanup`, `scopedReplacements`, or `propagationGraphs`.

All values below are post-GC deltas in bytes (`after - before`). External memory
was unchanged in every sample.

| Scenario | Heap run 1 | Heap run 2 | Heap run 3 | RSS run 1 | RSS run 2 | RSS run 3 | Classification |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 100 container cycles | 14,816 | 14,816 | 14,816 | 2,670,592 | 2,736,128 | 2,736,128 | Stable runtime metadata |
| 100 Flutter scope cycles | 15,376 | 15,376 | 15,376 | 5,275,648 | 5,619,712 | 5,259,264 | Stable framework/runtime metadata |
| 1,000 `unique`, no cleanup | 0 | 0 | 0 | 606,208 | 638,976 | 622,592 | No retained Dart heap |
| 1,000 owned `unique` | 0 | 0 | 0 | 901,120 | 131,072 | 901,120 | No retained Dart heap |
| 100 scoped replacements | 160 | 160 | 160 | 98,304 | 376,832 | 507,904 | Stable runtime metadata |
| Graphs 10/100/1,000 × 100 waves | 192 | 192 | 192 | 47,235,072 | 46,858,240 | 42,991,616 | Temporary VM capacity pressure |

<details>
<summary>Raw post-GC measurements (before → after)</summary>

| Scenario | Run | Heap usage | Heap capacity | External | RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Container cycles | 1 | 5,704,064 → 5,718,880 | 6,242,304 → 7,815,168 | 416 → 416 | 145,686,528 → 148,357,120 |
| Container cycles | 2 | 5,704,064 → 5,718,880 | 6,914,048 → 7,815,168 | 416 → 416 | 145,342,464 → 148,078,592 |
| Container cycles | 3 | 5,704,064 → 5,718,880 | 6,242,304 → 7,815,168 | 416 → 416 | 145,408,000 → 148,144,128 |
| Flutter scope cycles | 1 | 5,718,880 → 5,734,256 | 7,290,880 → 7,815,168 | 416 → 416 | 148,471,808 → 153,747,456 |
| Flutter scope cycles | 2 | 5,718,880 → 5,734,256 | 7,815,168 → 8,339,456 | 416 → 416 | 148,193,280 → 153,812,992 |
| Flutter scope cycles | 3 | 5,718,880 → 5,734,256 | 7,290,880 → 8,339,456 | 416 → 416 | 148,242,432 → 153,501,696 |
| `unique`, no cleanup | 1 | 5,734,256 → 5,734,256 | 8,339,456 → 8,339,456 | 416 → 416 | 155,631,616 → 156,237,824 |
| `unique`, no cleanup | 2 | 5,734,256 → 5,734,256 | 7,815,168 → 8,339,456 | 416 → 416 | 155,697,152 → 156,336,128 |
| `unique`, no cleanup | 3 | 5,734,256 → 5,734,256 | 8,339,456 → 8,863,744 | 416 → 416 | 155,435,008 → 156,057,600 |
| Owned `unique` | 1 | 5,734,256 → 5,734,256 | 8,863,744 → 7,290,880 | 416 → 416 | 156,303,360 → 157,204,480 |
| Owned `unique` | 2 | 5,734,256 → 5,734,256 | 8,863,744 → 7,290,880 | 416 → 416 | 156,385,280 → 156,516,352 |
| Owned `unique` | 3 | 5,734,256 → 5,734,256 | 8,863,744 → 7,815,168 | 416 → 416 | 156,073,984 → 156,975,104 |
| Scoped replacements | 1 | 5,734,256 → 5,734,416 | 7,815,168 → 8,339,456 | 416 → 416 | 157,220,864 → 157,319,168 |
| Scoped replacements | 2 | 5,734,256 → 5,734,416 | 7,815,168 → 7,815,168 | 416 → 416 | 156,532,736 → 156,909,568 |
| Scoped replacements | 3 | 5,734,256 → 5,734,416 | 7,290,880 → 8,339,456 | 416 → 416 | 156,975,104 → 157,483,008 |
| Propagation graphs | 1 | 5,734,416 → 5,734,608 | 8,339,456 → 66,404,352 | 416 → 416 | 157,319,168 → 204,554,240 |
| Propagation graphs | 2 | 5,734,416 → 5,734,608 | 8,339,456 → 65,388,544 | 416 → 416 | 156,942,336 → 203,800,576 |
| Propagation graphs | 3 | 5,734,416 → 5,734,608 | 8,339,456 → 65,355,776 | 416 → 416 | 157,515,776 → 200,507,392 |

</details>

The functional counters also matched on all three runs: container subscriptions
and cancellations were 100/100; Flutter listener adds/removes were 100/100; the
owned cycle released 100 values; owned `unique` released 1,000 values; scoped
replacement released all 101 generations; and each graph run performed 111,807
builds. The propagation scenario expanded heap capacity by roughly 57–58 MB,
while post-GC used heap grew only 192 bytes. RSS therefore reflects retained VM
arenas, not a growing reachable graph.

No absolute byte budget is established from this first machine. Treat these
numbers as a comparison baseline for the same environment. Per the current
scope decision, snapshot/CSV export was not captured; use DevTools or a VM
Service stream client only when a future run exceeds this baseline or needs a
retaining-path investigation.
