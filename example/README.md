# Factory example

One profile flow, three ways to wire it:

| Variant | Entrypoint | Module setup |
| --- | --- | --- |
| Manual usage | `lib/main.dart` | Explicit `FactoryModule` values |
| Annotations | `lib/main_annotations.dart` | Modules generated from `@Register` |
| Provider only | `lib/main_provider.dart` | Direct Provider composition |

All variants share the same business classes and widgets. Start with manual
usage; annotations only automate the module lists.

## 1. Manual usage

From this directory:

```sh
flutter pub get
flutter run -t lib/main.dart
```

Read these files in order:

1. [composition/factories.dart](lib/composition/factories.dart) declares how dependencies are created and disposed.
2. [composition/modules.dart](lib/composition/modules.dart) groups them and exposes the values widgets need.
3. [main.dart](lib/main.dart) passes the manual modules to the shared app.
4. [composition/factory_example_app.dart](lib/composition/factory_example_app.dart) installs the root and profile scopes.

For example, the profile module contains one declaration:

```dart
final profileModule = FactoryModule(
  factories: [profileController],
  expose: [profileController],
);
```

The manual entrypoint needs no annotations or generated files. In your own app,
add `factory_provider` and `provider`; `factory_generator` and `build_runner`
are only needed for the next variant. This repository includes both as development
dependencies so you can run either example.

## 2. With annotations

The annotation variant reuses the manual declarations and replaces the module lists:

1. [composition/annotations.dart](lib/composition/annotations.dart) registers each declaration through an annotated alias.
2. [composition/registry.dart](lib/composition/registry.dart) selects the input file and Flutter runtime.
3. [composition/registry.factory.dart](lib/composition/registry.factory.dart) contains the generated modules.
4. [main_annotations.dart](lib/main_annotations.dart) passes them to the shared app.

```dart
import 'package:factory_provider/factory_provider.dart';
import 'factories.dart' as declarations;

@Register(module: 'profile', expose: true)
final profileController = declarations.profileController;
```

Aliases preserve the same `Factory` identities in both variants. In your own
app, you can instead put `@Register` directly on a `final Factory<T>` declaration.
Keep business classes free of annotations.

```sh
dart run build_runner build
flutter run -t lib/main_annotations.dart
```

Generation requires Dart 3.11+. Run the build again after changing registrations;
never edit `.factory.dart` files by hand.

## Try the flow

1. The home screen shows **Ada Lovelace**.
2. Tap **Open profile**, then **Load local profile**: the child flow loads
   **Grace Hopper profile**.
3. Go back: the home screen still shows Ada and **Closed profile flows: 1**.

Provider owns the root session and flow monitor; Factory borrows them through
`overrideWithValue`. The child scope owns a replacement session and controller.
`local: [userRepository]` rebuilds the repository against the child session.
Closing the flow disposes its owned values; closing the app scope closes its client.

## 3. Provider only

```sh
flutter run -t lib/main_provider.dart
```

[main_provider.dart](lib/main_provider.dart) wires the same flow directly with
Provider. Compare the compositions to see how to adopt or remove Factory without
changing the domain classes or widgets.

## Verify

```sh
dart run build_runner build
flutter analyze
flutter test
```

The tests check the user flow in all three variants and compare manual and
generated module resolution, exposure, and cleanup.

For memory profiling, use the separate `lib/memory_profile.dart` entrypoint and
follow the [profiling playbook](../docs/memory-profiling.md).
