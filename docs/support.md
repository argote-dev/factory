# Compatibility and validation

Factory — Maneja tus dependencias sin barreras. Factory 1.0 support claims are scoped to the completed checks below.
A platform scaffold or successful compilation does not establish device execution.

## SDK and dependency matrix

| Consumer | SDK | Packages / dependencies | Verification |
| --- | --- | --- | --- |
| Manual Dart runtime | Dart 3.3.0 | Candidate core; no Flutter or generator | Packaged core tests, analysis, current/historical consumers |
| Provider runtime, including already generated modules | Flutter 3.19.0 / Dart 3.3.0 | Candidate core + adapter; Provider **6.1.5+1** fixed; no generator installed | Packaged runtime tests, analysis, manual/generated and historical consumers |
| Optional generation | Dart 3.11.0, without Flutter | Coordinated candidate generator/core | Packaged builder tests, analysis, current Dart consumer and frozen 0.3-generated Dart output/regeneration |
| Current Dart/Flutter composition and generation | Flutter 3.47.2 / Dart 3.13.2 | Coordinated candidate packages; exact dependency resolutions in evidence.json | All packaged tests, current and 0.3 consumers, existing output, regeneration and drift |

The runtime minimums are retained throughout 1.x. Generator SDK increases follow
the [advance-notice policy](compatibility-policy.md) and never change the runtime
minimum. SDK minimums are distinct from dependency minimums: Provider 6.1.5+1 is
tested explicitly; build tooling resolves within its declared bounds and the
report records exact versions. We do not promise every historical combination of
analyzer/build/source_gen or every combination of Factory minor releases.

Historical 0.3 generated output is tested on the candidate runtime before
regeneration. Regeneration is supported with the coordinated candidate generator
on Dart 3.11 for pure Dart and on the fixed current Flutter SDK for Flutter.
Flutter 3.41.0 with the generator is unsupported: its `meta 1.17.0` SDK pin
conflicts with analyzer 10.2 requiring `meta >=1.18.0`. This does not affect
the runtime-only Flutter 3.19 minimum. No overrides are used to bypass that conflict. A runtime-only application can retain
existing generated output without installing the generator.

## Evidence and reproduction

[Candidate verification](publishing.md#candidate-acceptance-without-publication)
explains the commands. `tool/verify_release.py` records commit, SDKs, command
outputs, resolved dependencies and archive hashes. All SDK jobs consume the same
three Pub archives, not independently modified checkouts. It checks actual
hosted package resolution without local overrides. Expected failures verify
interface, lifecycle and omitted-file detection, followed by passing restorations.

The [Verify workflow](https://github.com/argote-dev/factory/actions/workflows/verify.yml)
uploads `current-evidence`, `runtime-minimum-evidence`,
`generator-minimum-evidence` and `baseline-evidence`. Those artifacts are evidence
only for the commit in a completed run. Local acceptance is recorded separately
in the [candidate report](acceptance/factory-1.0.md); the older 54-test validation record applied to an earlier
implementation and is not evidence for 1.0.

## Completed hosted verification

[Verify run 36080342683](https://github.com/argote-dev/factory/actions/runs/36080342683)
passed all six jobs for `ea16bb17298d42185d3047fecd800ac66e23f0c9`: Linux,
macOS and Windows package/consumer checks, distributable artifacts, runtime
minimum and generator minimum. The package jobs also compiled the web example,
and the respective macOS and Windows jobs compiled native examples. This
supplements the historical local candidate report; it does not establish
browser or native device execution. Release tags must reference a commit whose
own Verify run has completed successfully.

## Platform scope

VM and widget tests exercise the Dart/Flutter behavior. Web/native compilation
and device execution are separate checks, never inferred from widget tests.

| Target | Candidate validation scope |
| --- | --- |
| macOS arm64 | Local VM/widget tests and analysis on minimum/current SDKs; hosted macOS compilation passed; native execution not verified |
| Linux, Windows | Hosted package/consumer tests passed on both; Windows example compilation passed; Linux native build and device execution not verified |
| Web | Example compilation passed locally and in hosted CI; browser execution not verified |
| Android, iOS | Scaffolding exists; no claim of native build or device execution from this verification |

The example's shared widget flow validates both Factory and Provider-only
composition, child substitution, parent isolation and visible closure. It does
not establish native device behavior. SDK distributions come from the
[official Flutter archive](https://docs.flutter.dev/install/archive).
