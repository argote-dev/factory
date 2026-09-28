# Compatibility and validation

Factory contains a standalone Dart core, a Flutter adapter for Provider, and an
optional generator. Runtime applications do not need to install the generator.

## SDK and dependency matrix

| Consumer | Minimum SDK | Dependencies |
| --- | --- | --- |
| Manual Dart runtime | Dart 3.3.0 | `factory_core` |
| Flutter runtime, including existing generated modules | Flutter 3.19.0 / Dart 3.3.0 | `factory_provider`, `factory_core`, Provider 6.1.5+1 |
| Optional generation | Dart 3.11.0 | Coordinated `factory_generator` and `factory_core` versions |

Runtime minimums are retained throughout 1.x. Generator SDK changes follow the
[compatibility policy](compatibility-policy.md). Dependency minimums and SDK
minimums are separate: the runtime verification job fixes Provider to its lower
bound, while generator verification records the resolved build dependencies.

Flutter 3.41.0 cannot resolve the current generator: its `meta 1.17.0` SDK pin
conflicts with analyzer 10.2 requiring `meta >=1.18.0`. Runtime-only applications
can keep existing generated output without installing the generator. Do not use
dependency overrides to bypass this conflict.

## Automated verification

The [Verify workflow](../.github/workflows/verify.yml) configures:

- Package tests, analysis, generation drift checks, and external consumers on
  Linux, macOS, and Windows with Flutter 3.47.2.
- Web example compilation on all three hosts and native example compilation on
  macOS and Windows.
- Isolated Pub archive checks with current and frozen 0.3/1.0 consumers.
- Runtime checks on Flutter 3.19.0 and generator checks on Dart 3.11.0, using the
  same archives produced by the current-SDK job.

A configured job is not proof of a passing run. Check the
[workflow results](https://github.com/argote-dev/factory/actions/workflows/verify.yml)
for the commit being evaluated. Release tags must reference a commit whose own
Verify run passed. CI uploads reports containing commands, SDKs, dependency
versions, archive hashes, and results; generated reports are not versioned.

See [contributing](../CONTRIBUTING.md) for local checks and
[release verification](publishing.md#candidate-acceptance-without-publication)
for isolated artifact testing. The separate
[dependency canary](dependency-canary.md) checks published packages against newer
allowed dependencies; it is informational and does not expand the support matrix.

## Platform coverage

VM and widget tests, compilation, and device execution are separate checks.
The workflow does not establish browser or native device execution, and it does
not build the Linux native example.

Use the [runtime verification guide](example-runtime.md) to run the shared
manual, generated, and Provider-only example flow on Chrome, Android, or iOS.
Record the commit, SDK, target, and build mode with each result. Emulator or
simulator results do not establish physical-device coverage. For performance
investigations, use the [memory](memory-profiling.md) and
[propagation](propagation-profiling.md) guides.
