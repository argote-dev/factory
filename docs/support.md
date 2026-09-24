# Compatibility and validation

Factory — Maneja tus dependencias sin barreras. This repository prepares an
unpublished 1.0 candidate. Support claims are scoped to the checks below; a
configured workflow, platform scaffold or successful dry-run is not a release.

## SDK and dependency matrix

| Consumer | SDK | Packages / dependencies | Verification |
| --- | --- | --- | --- |
| Manual Dart runtime | Dart 3.3.0 | Candidate core; no Flutter or generator | Packaged core tests, analysis, current/historical consumers |
| Provider runtime, including already generated modules | Flutter 3.19.0 / Dart 3.3.0 | Candidate core + adapter; Provider **6.1.5+1** fixed; no generator installed | Packaged runtime tests, analysis, manual/generated and historical consumers |
| Optional Dart generation | Dart 3.11.0 | Coordinated candidate generator/core | Packaged builder tests, analysis, generated Dart consumer and regeneration |
| Current Dart/Flutter composition and generation | Flutter 3.47.2 / Dart 3.13.2 | Coordinated candidate packages; exact dependency resolutions in evidence.json | All packaged tests, current and 0.3 consumers, existing output, regeneration and drift |

The runtime minimums are retained throughout 1.x. Generator SDK increases follow
the [advance-notice policy](compatibility-policy.md) and never change the runtime
minimum. SDK minimums are distinct from dependency minimums: Provider 6.1.5+1 is
tested explicitly; build tooling resolves within its declared bounds and the
report records exact versions. We do not promise every historical combination of
analyzer/build/source_gen or every combination of Factory minor releases.

Historical 0.3 generated output is tested on the candidate runtime before
regeneration. Regeneration is supported with the coordinated candidate generator
on Dart 3.11 and the fixed current SDK. A runtime-only application can retain
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
in the candidate report; the older 54-test validation record applied to an earlier
implementation and is not evidence for 1.0.

## Platform scope

VM and widget tests exercise the Dart/Flutter behavior. Web/native compilation
and device execution are separate checks, never inferred from widget tests.

| Target | Candidate validation scope |
| --- | --- |
| macOS arm64 | Local VM/widget tests and analysis on the minimum and current SDKs; native build/run status must be read from the candidate acceptance report |
| Linux, Windows | CI has package/consumer tests; support requires a completed run for the candidate, not just the job definition |
| Web | Example has a build job; an actual candidate build is recorded separately |
| Android, iOS | Scaffolding exists; no claim of native build or device execution from this verification |

The example's shared widget flow validates both Factory and Provider-only
composition, child substitution, parent isolation and visible closure. It does
not establish native device behavior. SDK distributions come from the
[official Flutter archive](https://docs.flutter.dev/install/archive).
