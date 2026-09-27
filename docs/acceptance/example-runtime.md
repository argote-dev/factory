# Example runtime acceptance — issue #47

Executed September 26, 2026 (America/Bogota; September 27 UTC) against commit
`dc9e4b176b24657b3952a8c30b6fc9e758f61545`. Later changes only publish this evidence
and documentation. Flutter **3.47.2**, framework `d3b14c8769`, Dart **3.13.2**;
macOS 27.0 arm64 host, debug mode throughout. Exact timestamps and SDK revisions
are in each evidence directory. Documentation edits and local tooling may appear
in status logs; the runtime source diffs are empty.

| Target | Actual execution target | Result and evidence |
| --- | --- | --- |
| Chrome | Chrome / ChromeDriver 154.0.8037.57, visible browser window controlled by ChromeDriver | [Commands and metadata](runtime-evidence/chrome/evidence.json), [execution log](runtime-evidence/chrome/run.log) |
| Android | `Medium_Phone` AVD, `emulator-5554`, Android 17 / API 37, arm64; emulator 37.1.11 | [Commands and metadata](runtime-evidence/android/evidence.json), [execution log](runtime-evidence/android/run.log) |
| iOS | iPhone 17 Pro, iOS 26.5 simulator `6677DC35-96FA-4F74-A9B5-B87C7F1C63AD`; Xcode 27.0 (27A266a) | [Commands and metadata](runtime-evidence/ios/evidence.json), [execution log](runtime-evidence/ios/run.log) |

These mobile destinations were selected because their system images were already
installed locally. iOS was the first mobile execution; Android was then verified
independently. No physical phone was used. The example scaffold now targets iOS
15 because Flutter 3.47.2 automatically migrates its older iOS 13 setting during
build; this does not change the Factory package runtime SDK minimums.

All three destinations passed the manual, annotated and Provider-only flows,
with **two child open/load/back cycles per composition**. The structured
`Verified profile flows` record contains only compositions that reached the end
of their assertions. Each child shows Grace, each return shows Ada, closure
counts advance 0 → 1 → 2, and borrowed parent session/monitor plus the parent
repository remain usable. This verifies the controller disposal count, not heap
profiling or network behavior. The fourth native test entry is framework teardown.

## Reproduction and earlier attempts

Follow the [runtime walkthrough](../example-runtime.md). The checked-in runner
records commands and exit codes without replacing earlier evidence. The accepted
runs use the same committed source. Chrome uses `web-server` with
`--browser-name=chrome --no-headless`, which launches and tests in Chrome rather
than merely compiling or serving the app.

The first Chrome attempt failed compilation because its shared helper was outside
the web target root ([log](runtime-evidence/chrome-initial/run.log)). Moving it
under `integration_test/support` fixed that error. A subsequent `-d chrome`
attempt stalled before executing tests and was interrupted; its zero exit code
was not accepted. The runner now additionally requires completed-flow data.

Regression checks passed: core 37 tests, generator 16, adapter 20, example 4,
Python tooling 14; analysis for all Dart/Flutter packages; generated module drift
check; and `tool/verify_consumers.sh`. The existing generator warns that the SDK
language version is newer than its analyzer; generation and subsequent analysis
still pass. Standards/spec review found no blocking findings.

## Remaining limits

Physical Android/iOS devices, release/profile builds, other browser/OS versions,
background/restore and network integration remain unverified. The local profile
client does no network I/O. These are local execution results for this commit,
not CI or nightly coverage, and no mandatory gate was added.
