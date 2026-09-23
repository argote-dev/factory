# Factory executable quick start

This app demonstrates incremental adoption of `factory_provider` in an existing Provider
application. Business and presentation code use ordinary constructors and
Provider APIs; only `lib/composition/` knows about Factory.

## Generated route

The example's only runtime DI dependency is `factory_provider`; `factory_generator` and
`build_runner` are optional development dependencies. Read these files in order:

```yaml
dependencies:
  factory_provider: ^0.3.0
  provider: ^6.1.5+1
dev_dependencies:
  build_runner: ^2.15.1
  factory_generator: ^0.3.0
```

```dart
final greeting = Factory<String>((_) => 'hello');
final manualModule = FactoryModule(
  factories: [greeting],
  expose: [greeting],
);

@FactoryRegistry(runtime: FactoryRuntime.flutter)
void configureFactories() {}

FactoryScope(
  modules: [appModule], // or manualModule without generation
  child: Builder(
    builder: (context) => Text(context.watch<String>()),
  ),
);
```

1. `lib/domain/` and `lib/presentation/` — Factory-free business and UI code.
2. `lib/composition/factories.dart` — declarations, ownership and exposure.
3. `lib/composition/registry.dart` — Flutter runtime selection and scan entrypoint.
4. `lib/composition/registry.factory.dart` — deterministic generated modules.
5. `lib/main.dart` — root and flow scope installation.
6. `test/modules_test.dart` and `test/example_flow_test.dart` — public contracts.

From this directory:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- lib/composition/registry.factory.dart
flutter analyze
flutter test
flutter run
```

`@FactoryRegistry(runtime: FactoryRuntime.flutter)` makes generated output import
the public Flutter facade. The root entrypoint borrows an existing `Session`,
installs `appModule`, and creates a child scope for the profile flow. Dependencies
remain lazy until the profile is loaded.

The equivalent manual module is exercised beside `appModule` in
`test/modules_test.dart`: construct `FactoryModule(factories: [...], expose:
[...])` and pass it to the same `FactoryScope`. No generator is required.

## Adoption, nested scope, and ownership

The root scope borrows the Provider-owned `Session` with `overrideWithValue`;
Factory never disposes it. The profile route installs a child module. Its
controller and the root client are Factory-owned because their declarations
construct them with cleanup callbacks. Closing the route completes `onClose`,
releases the controller, and reports failures through `onError`; closing the root
later releases the client.

The profile route also replaces `session` with an owned `Grace Hopper` session
and lists `userRepository` in `local`. The child repository therefore resolves
the replacement while the root still displays `Ada Lovelace`; leaving the route
disposes the replacement and restores the unchanged parent view. The route's
`onClose` callback explicitly observes successful completion, and `onError`
reports an aggregated failure with route context.

Use `overrides` for a local value or constructor. Add an inherited dependent to
`local` when it must be rebuilt against that child override; the parent remains
unchanged. Keep only dependencies needed by widgets in `expose`; internal
dependencies stay inside composition. For repeated navigation and asynchronous
cleanup investigations, follow the
[memory profiling playbook](../docs/memory-profiling.md).

The dedicated `lib/memory_profile.dart` entrypoint exposes deterministic runtime,
scope, `unique`, replacement, and propagation scenarios through the VM Service.
It is intentionally separate from the tutorial UI and is run in profile mode as
documented by the playbook.

## Removal route

`lib/main_provider.dart` wires the same domain and presentation directly with
Provider and does not import Factory:

```sh
flutter run -t lib/main_provider.dart
flutter test
```

The shared behavior test proves that removing Factory changes composition only,
not widgets or business classes.

## Troubleshooting

- **Declaration is not installed:** install it through a module or `local` in
  the scope that owns the dependent.
- **External declaration needs an override:** supply `overrideWithValue` for a
  borrowed instance or `overrideWith` for a Factory-owned constructor.
- **Duplicate exposed type:** expose only one declaration of that type in a
  scope; keep the other internal or expose it in another scope.
- **Generated file missing:** run `dart run build_runner build
  --delete-conflicting-outputs` and import `registry.factory.dart`.
- **Wrong generated facade:** select `FactoryRuntime.flutter` for Flutter or
  `FactoryRuntime.dart` for standalone Dart. Keep one registry per library.
