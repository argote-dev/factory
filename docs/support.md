# Compatibility and validation

This is a development release. Package constraints and tested environments are
recorded separately from deployment-platform targets.

## SDKs

| Component | Declared minimum | Validation |
| --- | --- | --- |
| `factory_core` | Dart 3.3.0 | Unit tests and analysis pass on Dart 3.3.0 and 3.12.0. |
| `factory` Flutter adapter | Flutter 3.19.0 / Dart 3.3.0 | Widget tests and analysis pass on Flutter 3.19.0 and 3.44.0. |
| `factory_generator` | Dart 3.11.0 | Builder tests and analysis pass on Dart 3.11.0 and 3.12.0. |
| `example` | Dart 3.11.0 | Both composition flows and analysis pass on Flutter 3.44.0. |

The minimum SDK checks use clean temporary copies and independent dependency
resolution. The optional generator does not increase the runtime's SDK minimum.
Provider was resolved at 6.1.5+1. Generator dependencies use analyzer 10.2.0,
source_gen 4.2.4 and build_runner 2.15.1; analyzer 14 requires a newer `meta`
version than Flutter 3.44.0's SDK pin permits.

The CI workflow repeats package checks on Linux, macOS and Windows, separately
checks the runtime minimum, and checks regenerated example output for drift.
A committed workflow is not evidence that hosted CI has already run.

## Platforms

| Target | Evidence in this environment |
| --- | --- |
| Web | `flutter build web` succeeds on Flutter 3.44.0, including its Wasm dry run. |
| macOS | VM/widget tests pass on Apple Silicon. Native build remains unverified; see below. |
| Android, iOS, Linux, Windows | Example scaffolding exists; native builds and device behavior have not been validated locally. |

Native macOS builds encountered environment/toolchain failures: release framework
verification reports `lipo -verify_arch requires exactly one input file` for the
multi-architecture framework. The debug attempt additionally encountered Xcode
Swift Package Manager dependency resolution failure. The example deployment target
is macOS 12, matching the installed Xcode's supported range. These failures do not
establish native-platform support and are not hidden by the passing widget tests.

Flutter SDK versions were obtained from the
[official SDK archive](https://docs.flutter.dev/install/archive).

## Reproduction

Run the commands in the root README. For runtime-only minimum checks, use
`flutter pub get --no-example` so the optional generator/example SDK constraints
are not included. Regenerate modules with `dart run build_runner build` in
`example`; `watch` provides the same builder during development.

The example has two launch entrypoints. Its widget tests exercise the same flow
with both, including ChangeNotifier-driven rendering and cleanup after navigation.
Business classes and presentation widgets do not import Factory.
