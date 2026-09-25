# Factory 1.0 candidate acceptance

Candidate: `5f9cac4087a1ef4093dbd54da6a25890c01b1595`. This is an
unpublished candidate, not a pub.dev release. The acceptance was executed in a
clean detached checkout, separate from pre-existing local edits.

## Release preparation update

The report below preserves the original local acceptance of `5f9cac4`.
Subsequent example and documentation changes were integrated through PRs #43
and #44. [Hosted Verify run 36080342683](https://github.com/argote-dev/factory/actions/runs/36080342683)
passed all six jobs on `ea16bb17298d42185d3047fecd800ac66e23f0c9`, including
packaged current/historical consumers, SDK minimums, three operating systems,
web compilation and native macOS/Windows compilation. The historical archive
hashes below identify the original candidate, not the final release archives.
The 1.0.0 release notes link the final commit and its own completed Verify run;
that run supplies the release artifact hashes and logs. Device/browser execution
and Android/iOS builds remain outside the verified scope.

## Decision

**Ready as a locally verified 1.0 candidate within the support matrix below.**
All required local acceptance gates passed on the same clean commit. This is
not authorization to publish and does not claim hosted CI or native execution.
The later documentation-only commit stores this report without changing the
candidate's package contents.

| Gate | Result | Retained evidence |
| --- | --- | --- |
| Current packages, consumers, regeneration and three expected regressions | Passed; all restorations passed | [50 commands](evidence/current/evidence.json) |
| Actual 0.3 release baseline, original historical consumers and explicit retrospective probes | Passed | [43 commands](evidence/baseline/evidence.json) |
| Runtime minimum, Provider lower bound, no generator | Passed | [29 commands](evidence/minimum/evidence.json) |
| Generator Dart minimum, frozen previous output and regeneration | Passed | [14 commands](evidence/generator-minimum/evidence.json) |
| Example equivalence, drift, analysis, web compilation and clean current consumers | Passed | [Commands/logs](evidence/example/evidence.json) |
| Flutter 3.41 + generator | Unsupported combination: resolution failure retained | [Failure log](evidence/unsupported-flutter-3.41/005-flutter.log) |

The current run's only nonzero exits are the three deliberate regressions.
Every evidence command references its adjacent log. ANSI terminal codes and
trailing spaces were removed for readable diffs; all output lines and results
are preserved. [Log digests](evidence/log-digests.json) record raw and stored SHA-256. Minimum/current
reports have identical archive hashes; the baseline instead uses artifacts
built from the actual 0.3 release commit.

## Scope and requirements audit

| Ticket / requirements | Implementation and direct evidence |
| --- | --- |
| #34: stable surface, exports, implementers, errors/callbacks, policy, SDKs, coordinated versions, no gratuitous migration | [API inventory](../api-guide.md), [policy](../compatibility-policy.md), current and frozen external-interface consumers. `check_versions` checks all manifests/changelog heads/core constraints/runtime independence. Runtime public code retains 0.3 signatures and names. |
| #35: identity, partial adoption, equivalent removal, scope replacement and ownership, limits | README follows conectar/sustituir/probar/retirar and the approved Spanish identity. `example_flow_test.dart` now requires the same Grace child flow and Ada parent after return in both compositions, with one visible closure. Domain and presentation files are unchanged. Scope tests verify borrowed notifiers survive and owned notifiers close once. Optional notifier/resolver coupling and removal changes are explicit. |
| #36: public current consumers, generated equivalence/drift, lifecycle/observation/failure contracts, CI sensitivity | Current Dart, generated Dart and Flutter fixtures; packaged `container_test`, `changes_test`, `resolver_test`, `factory_scope_test`, `factory_change_notifier_test`. The lifecycle probe removes immediate closure rejection, reaches a failing assertion, restores the installed cache, then passes all resolver tests. The same consumers run in CI. |
| #37: executable two-resource async startup, synchronous dependent, failure/normal cleanup | `dart/lib/async_startup.dart`, executable `bin/async_startup.dart`, four public tests: success/idempotent closure, partial acquisition failure, startup+cleanup error preservation and remaining cleanup after a close failure. Local futures only; no network/timers. Borrowed resources close after Factory dependents. [Recipe](../async-startup.md). |
| #38: immutable historical consumers, provenance, actual baseline and upgrade, previous output/regeneration, interfaces, real migration | Original `v0.3.0` Dart/Flutter consumers compare directly with `git show` from release `71fe8a4dd6a6d62cae4a072354c5852c89151ff2` and recorded hashes. Baseline run builds that commit with Pub. Candidate run changes only isolated resolution metadata, not consumer Dart. Retrospective interface and generated-Dart probes are clearly labelled; frozen Dart output must match the real 0.3 generator and candidate. Removing `FactoryRef.resolver` from an implementer fails analysis and restoration passes. [Migration](../migration-0.3-to-1.0.md) and future real-1.0 baseline instructions. |
| #39: Pub artifacts/dry-run, isolated hosted install, all public consumer paths, version gates, missing-file probe, CI | Three archives produced with Pub, separately dry-run validated after extraction, served by a read-only loopback server. Fresh cache, no overrides, and package-config guards reject checkout Factory dependencies. Omitting `lib/factory_core.dart` causes the installed consumer to fail; restoration passes. Archive hashes identify the same artifacts consumed by minimum/current jobs. This is test hosting, not publication. |
| #40: runtime/generator minimum separation, Provider minimum, fixed current combination, prior generation, truthful platform claims | Runtime Flutter 3.19/Dart 3.3 with Provider 6.1.5+1 and no generator. Pure Dart generation on 3.11. Current Flutter 3.47.2/Dart 3.13.2. Historical Flutter generation runs only on a compatible Flutter host; Flutter 3.41 + generator was found incompatible and is excluded explicitly. [Matrix](../support.md). |
| #41: same candidate, integrated execution, docs/gates, report, no publication or parent closure | Clean commit and exact archives in the evidence records; logs and commands retained below. No packages uploaded, release tags created, or issue bodies/states changed. Hosted CI/native execution remain distinct from local verification. |

The user stories in #33 map to these gates: 1–5 → #35; 6–18 → #34/#36;
19–20 → #37; 21–24 and 27 → #34/#38; 25–26 and 28–31 → #39/#40;
32 → this report. No deferred runtime features were added.

## Environments and commands

Local host: macOS arm64. Python verification environment uses PyYAML 6.0.3.
SDK versions, full candidate commit, individual commands, resolved dependencies,
exit codes and archive hashes are recorded in each `evidence.json`.

```sh
python tool/verify_release.py --output <results>/current
python tool/verify_release.py --baseline-release --output <results>/baseline
# PATH: Flutter 3.19.0 / Dart 3.3.0
python tool/verify_release.py --archives <results>/current/archives --runtime-only --lower-dependencies --output <results>/minimum
# PATH: standalone Dart 3.11.0
python tool/verify_release.py --archives <results>/current/archives --generator-only --output <results>/generator-minimum
```

The example additionally ran `flutter pub get`, `dart run build_runner build`,
`git diff --exit-code -- lib/composition/registry.factory.dart`, `flutter test`,
`flutter analyze`, and `flutter build web`. `bash tool/verify_consumers.sh`
checked clean path consumers and generation separately. These commands exited
successfully; their complete logs are retained with the example evidence.

## Platform limits

Local VM/widget tests and analysis are verified on macOS arm64. Web compilation
is verified; browser execution is not. Native macOS, Linux, Windows, Android and
iOS builds/device execution were not validated by this acceptance. The workflow
configures Linux/macOS/Windows checks, but hosted CI was not run by this local
session. No universal platform compatibility is claimed.

Flutter 3.41.0 + candidate generator failed dependency resolution: the Flutter
SDK pins `meta 1.17.0`, while analyzer 10.2 requires `meta >=1.18.0`. This is an
unsupported combination, not a runtime-minimum failure. Generator-only Dart
3.11 and current Flutter generation are separate supported combinations.

## Review

### Standards

The independent standards reviewer found no documented-standard violations or
actionable heuristic smells. Frozen fixture duplication is deliberate provenance.

### Spec

The independent spec reviewer found two verification gaps: hashes alone did not
prove release origin, and the minimum generator gate lacked prior generated
output. Both were corrected. The first attempted Flutter 3.41 gate exposed the
SDK pin conflict above; the final matrix uses a frozen retrospective Dart output
for the pure-Dart minimum and original historical Flutter output on its compatible
host. The reviewer confirmed the final scope at `5f9cac4` with no remaining
findings. Final test execution and evidence inspection remained the main agent's
responsibility.

## Candidate artifact SHA-256

| Pub archive | SHA-256 |
| --- | --- |
| `factory_generator.tar.gz` | `893df9b1a9d574a32a5b94e1bd07e3dc2a5f7ef115a87ea4e97d1e13d634e91b` |
| `factory_provider.tar.gz` | `de015709af06cc3354308f89a8747420b5751e910da1f69b7964e628d8048aa8` |
| `factory_core.tar.gz` | `e5da2de6b553964dd491a038c74e2b429b15e929941b8c91b7e308c0212b6bdd` |
