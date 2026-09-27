# Published dependency canary

The [canary workflow](../.github/workflows/canary.yml) runs every Tuesday at
09:23 UTC and supports manual dispatch. It uses the latest stable Flutter SDK,
the original 1.0 consumers and **published Factory packages within `^1.0.0`**.
It is informational: it has no release-workflow dependency, does not run on
pull requests, and its job uses `continue-on-error`. Inspect its evidence even
when the overall workflow is green. It never builds or publishes Factory.

Each run starts without a lockfile in an isolated temporary directory/cache,
sets `PUB_HOSTED_URL=https://pub.dev`, and uses
[`pub upgrade`](https://dart.dev/tools/pub/cmd/pub-upgrade) to resolve the newest
compatible direct and transitive dependencies. No `--major-versions`, path/Git
dependencies, local overrides or widened third-party constraints are used.
“Newest” means the newest set Pub can solve under all package and SDK bounds,
not every package's absolute latest release. The three consumers can resolve
different sets; each resolution is recorded separately.

Manual Dart (including public interface implementers), generated Dart and
Flutter run analysis and tests against frozen output before regeneration, then
analysis/tests after regeneration. Generated drift is a signal to investigate,
not proof of an API break. The separately authored `tool/canary_contracts/provider`
control tests Provider observation without Factory. It uses the Flutter
consumer's resolved Provider version when available; otherwise it resolves its
declared range. It is not claimed as an original 1.0 release fixture.

## Evidence and triage

Every run uploads `published-canary-<run-id>-<attempt>` for 30 days, including:

- `evidence.json`: commit/worktree state, timestamps, exact Dart/Flutter SDKs,
  original fixture provenance, commands, exit codes and per-consumer results.
- `consumers/`: executed sources, pubspecs and **complete lockfiles**, including
  hosted URLs, resolved versions and archive SHA-256 values. File hashes and
  generated-output hashes are recorded in the report.
- Numbered command logs, `summary.md`, and workflow step outcomes. Setup failures
  or interrupted runs receive an infrastructure report when the runner can still
  execute the final reporting step. Total runner loss can prevent artifact upload.

Consumers continue independently after a failed check. Categories identify the
failing boundary; they do not establish root cause:

| Area | Signal / first investigation |
| --- | --- |
| `factory` | Frozen Dart Factory consumer analysis/test failed before regeneration; compare its lockfile and the pinned stage A baseline. |
| `factory-provider-integration` | Flutter Factory consumer analysis/test failed before regeneration. The fault is not attributed to either library; inspect both its resolution and the Provider control. |
| `provider` | Provider-only control failed; compare the Provider version and Flutter SDK with the Factory consumer. A passing control does not rule out a Provider integration bug. |
| `sdk` | SDK command failure or explicit SDK constraint/pin conflict during resolution; inspect SDK output and solver log. |
| `generation` | Builder, regenerated analysis/test or output drift; inspect generator/analyzer/build/source_gen versions and saved output. |
| `infrastructure` | Missing tools, network, permissions, timeout, fixture integrity, setup or evidence failure; restore infrastructure before interpreting compatibility. |
| `dependency-resolution` | Solver failed without a recognized SDK/network cause; inspect constraints before attributing it to Factory, Provider or generation. |

## Reproduction and maintenance

Install `tool/requirements.txt` in a Python virtual environment, then run:

```sh
python tool/verify_canary.py --output build/canary-local-001
```

Use a **new output directory** each time. The CLI exits nonzero for any failed
consumer/setup; only the scheduled workflow treats that as informational.
To repeat an exact saved resolution, use the SDK/revision recorded in the report,
copy the desired `consumers/<name>` outside this checkout, and in that directory:

```sh
export PUB_HOSTED_URL=https://pub.dev
export PUB_CACHE="$(mktemp -d)"
dart pub get --enforce-lockfile
dart analyze
dart test
```

Use `flutter` for Flutter/Provider consumers. `--enforce-lockfile` checks the
recorded versions and hashes ([Pub documentation](https://dart.dev/tools/pub/cmd/pub-get#enforce-lockfile)).
For generation failures, restore the frozen `*.factory.dart` from
`tool/consumer_contracts/historical/1.0.0/<kind>` at the evidence commit before
testing old output, then replay the recorded build command and analysis/tests.
Keep the saved pubspec/lockfile. Rerunning `pub upgrade` is a new canary resolution,
not reproduction of the old one.

Archive relevant evidence before retention expires. Reproduce a failure, compare
it with `verify_release.py --published-baseline`, and reduce it before filing a
Factory/Provider/SDK/generator issue. Keep the release-gating workflow separate.
Changing schedule, tracked SDK channel or Factory major range requires an
explicit maintenance decision; never alter the frozen fixtures to obtain green.
Only add combinations to `support.md` after a completed verified run with an
evidence link. A scheduled run or a green informational job alone adds no support
claim. Stage A's pinned archives and minimum-SDK policy remain authoritative.
