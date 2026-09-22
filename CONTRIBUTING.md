# Contributing

Thank you for considering a contribution to Factory.

## Before opening a change

- Search existing issues and pull requests to avoid duplicate work.
- Open an issue before making a substantial API or architecture change.
- Keep changes focused and include tests for behavior changes.
- Do not include generated build output, local configuration, credentials, or
  editor files.

## Development setup

Factory is a small monorepo containing the Flutter adapter, a standalone Dart
core, an optional generator, and a Flutter example.

```sh
flutter pub get
(cd packages/factory_core && dart pub get)
(cd packages/factory_generator && dart pub get)
(cd example && flutter pub get)
```

Use an SDK version supported by [the compatibility matrix](docs/support.md).

## Validation

Run the checks relevant to your change. Before opening a pull request, the full
suite should pass:

```sh
(cd packages/factory_core && dart test && dart analyze)
(cd packages/factory_generator && dart test && dart analyze)
flutter test
flutter analyze lib test
(cd example && dart run build_runner build)
git diff --exit-code -- example/lib/composition/registry.factory.dart
(cd example && flutter test && flutter analyze)
```

Run `dart format .` for changed Dart files. Generated files must be committed
and must match the generator output.

## Pull requests

In the pull request description, explain the problem, the chosen approach, and
how the change was verified. Link the related issue when one exists. By
submitting a contribution, you agree that it may be distributed under the
project's license.
