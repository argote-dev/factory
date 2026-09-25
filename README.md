<p align="center">
  <img src="https://raw.githubusercontent.com/argote-dev/factory/main/docs/assets/factory-logo.png" alt="Factory logo" width="180">
</p>

# Factory — Manage your dependencies without barriers

Dependency injection for Flutter with Provider. Adopt it gradually, test your composition, and keep the freedom to remove it.

[![CI verification](https://github.com/argote-dev/factory/actions/workflows/verify.yml/badge.svg)](https://github.com/argote-dev/factory/actions/workflows/verify.yml)

Dependency injection for Flutter apps that already use Provider. Declare how
objects are built, install a module, and keep using `context.read`,
`context.watch`, `context.select`, and `Consumer`.

Factory 1.0 defines a stable public API with verified compatibility from 0.3. The optional generator
collects declarations; it does not annotate your business classes or infer their
constructors.

## Connect — manual usage

### 1. Add the dependencies

The Flutter runtime requires Flutter 3.19+ and Dart 3.3+. Add these entries to
an existing Flutter application's `pubspec.yaml`, then run `flutter pub get`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  factory_provider: ^1.0.0
  provider: ^6.1.5+1
```

Keep `provider` as a direct dependency when your widgets import it. Manual setup
needs no annotations or code generation. For standalone Dart, use
[`factory_core`](https://github.com/argote-dev/factory/blob/main/packages/factory_core/README.md) with `FactoryContainer` instead.

### 2. Declare, expose, and install a dependency

This complete `lib/main.dart` example creates a counter, exposes it to Provider,
and installs its module above the widgets that consume it:

```dart
import 'package:factory_provider/factory_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Counter extends ChangeNotifier {
  int _value = 0;
  int get value => _value;

  void increment() {
    _value++;
    notifyListeners();
  }
}

final counter = Factory<Counter>(
  (_) => Counter(),
  dispose: (value) => value.dispose(),
);

final counterModule = FactoryModule(
  factories: [counter],
  expose: [counter],
);

void main() {
  runApp(
    FactoryScope(
      modules: [counterModule],
      child: const MaterialApp(home: CounterPage()),
    ),
  );
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final value = context.watch<Counter>().value;
    return Scaffold(
      appBar: AppBar(title: const Text('Factory counter')),
      body: Center(child: Text('Count: $value')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<Counter>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Keep declarations and modules stable, outside widget `build` methods. If you
also import `package:flutter/foundation.dart`, use `hide Factory` on that import
to avoid a name collision with Flutter's own `Factory` class.

### 3. Run and integrate into your app

Run `flutter run`. The screen starts at `Count: 0`; tapping **+** increments it.
`context.watch` rebuilds the widget when the counter notifies listeners, while
`context.read` accesses it from the button callback without subscribing.
Factory creates the counter on first use and disposes it when its scope closes.

In an existing app, put `FactoryScope` above the subtree that needs the
module's exposed types. Keep using `context.read`, `context.watch`,
`context.select`, and `Consumer` in your widgets. Move construction into Factory
declarations and register cleanup callbacks for resources they own. To reuse an
instance already owned by Provider, follow
[existing dependencies and nested flows](#replace--existing-dependencies-and-nested-flows).

See the [runnable example](https://github.com/argote-dev/factory/blob/main/example/README.md) for repositories, nested scopes,
and separate manual, annotated, and Provider-only entrypoints.

## How Factory fits together

- **`Factory<T>`** declares how to construct a dependency and manage its lifetime.
- **`FactoryModule`** groups declarations; `expose` selects those available to widgets.
- **`FactoryScope`** installs modules and owns their container for a Flutter subtree.
- **`FactoryContainer`** resolves dependencies and manages their cleanup, including
  in Dart tests without widgets.

Dependencies resolve lazily. Only `expose` entries cross the Provider bridge;
internal dependencies remain available to other factories through `FactoryRef`.

## Compose dependencies

```dart
import 'package:factory_provider/factory_provider.dart';
import 'package:flutter/material.dart';

final client = Factory<ApiClient>(
  (_) => ApiClient(),
  dispose: (value) => value.close(),
);
final repository = Factory<UserRepository>(
  (ref) => UserRepository(ref.read(client)),
);
final appModule = FactoryModule(
  factories: [client, repository],
  expose: [repository],
);

// Around the existing application:
FactoryScope(modules: [appModule], child: const MyApp());
```

Only `expose` entries become Provider values. Every declaration belongs to the
scope where it is installed; registration order does not matter. Separate
`Factory<T>` objects can represent different dependencies with the same type.
Exposing two different declarations of the same type in one scope is an error.

## Lazy creation and lifetimes

The default is lazy creation and `Lifetime.scoped`: one value per owning scope.
`lazy: false` creates the value when that scope opens. `Lifetime.unique` creates
a value for every container resolution. Provider caches its exposed value, so
reading it through a widget does not repeatedly resolve a unique declaration.
Construction is synchronous; initialize asynchronous services outside Factory
and supply their ready instances. The [async startup recipe](https://github.com/argote-dev/factory/blob/main/docs/async-startup.md)
executes successful startup, partial failure and awaited shutdown with explicit owners.

## Replace — existing dependencies and nested flows

```dart
final session = Factory<Session>.external();

// Under an existing Provider<Session>; install session in appModule too.
FactoryScope(
  modules: [appModule],
  overrides: [session.overrideWithValue(context.watch<Session>())],
  child: const MyApp(),
);

// A nested flow with a local replacement and explicitly local dependent:
FactoryScope(
  modules: [profileModule],
  overrides: [client.overrideWithValue(previewClient)],
  local: [repository],
  child: const ProfilePage(),
);
```

Borrowed values are never disposed by Factory. `overrideWith` replaces a
constructor and accepts its own `dispose` callback for an owned value. A child
inherits the parent's instances unless declarations are installed locally.
`local` reconnects selected dependents without changing the parent's graph.
Expose local values through a local module when widgets need to consume them.

## Explicit observation

- `ref.read(factory)` connects without subscribing.
- `ref.watch(factory)` also observes instance replacement.
- `ref.select(factory, selector)` also observes selected state changes. Flutter
  supplies `Listenable` support; pure Dart containers accept an `observe` adapter.

A declaration using observation must choose a response:

```dart
final account = Factory<AccountRepository>(
  (ref) => AccountRepository(ref.select(session, (value) => value.userId)),
  onChange: ChangePolicy.recreate,
  dispose: (value) => value.close(),
);

final controller = Factory<ProfileController>(
  (ref) => ProfileController(ref.watch(repository)),
  onChange: ChangePolicy.update,
  update: (ref, value) => value.setRepository(ref.watch(repository)),
  dispose: (value) => value.dispose(),
);
```

`update` mutates the existing instance and must re-declare its observations.
A failed recreation is reported by subsequent resolution; Factory does not
serve the old value as a fallback. A later observed change can retry the graph.
An in-place update cannot promise rollback of mutations. Use pure constructors,
selectors and updates; they must not change the graph while it is being resolved.

Declared `ChangeNotifier` types automatically forward their notifications to
Provider. Register their `dispose` callback explicitly; Provider does not own
these objects. Declaring a notifier merely as `Object` does not opt into this
adapter.

## Optional dependency access inside notifiers

Use `FactoryChangeNotifier` when a notifier should resolve its own dependencies.
Pass `ref.resolver` through its constructor and request a typed declaration:

```dart
class ProfileController extends FactoryChangeNotifier {
  ProfileController(super.resolver);

  late final UserRepository repository = resolve(userRepository);

  Future<void> load() async {
    await repository.loadProfileName();
  }
}

final profileController = Factory<ProfileController>(
  (ref) => ProfileController(ref.resolver),
  dispose: (controller) => controller.dispose(),
);
```

Here `userRepository` is an installed `Factory<UserRepository>` declaration.
`resolve` works in constructor bodies, `late` initializers and later methods.
Each call respects `scoped`/`unique`; storing a result in a field explicitly
retains that instance. Reads do not subscribe to replacements or state changes.

Resolution uses the notifier's owning scope, including its overrides and parent
scopes. Dependencies keep their existing cleanup owner, including those first
resolved from a later method. Calls after notifier disposal or scope closure,
and reads that introduce dependency cycles, throw `StateError`. Subclasses that
override `dispose` must call `super.dispose()`; asynchronous work and its
cancellation remain the application's responsibility.

This API is optional and couples the notifier to Factory. Constructor injection
of concrete dependencies remains available for classes that must support removing
Factory by changing composition alone. No field annotations or code generation
are needed.

## Test — cleanup and tests without widgets

```dart
final container = FactoryContainer(
  modules: [appModule],
  overrides: [client.overrideWithValue(fakeClient)],
);
try {
  final value = container.read(repository);
  // Exercise the real wiring.
} finally {
  await container.close();
}
```

Closing rejects new resolutions immediately, closes children first and releases
dependents before dependencies. Every cleanup is attempted. Failures are reported
as `FactoryCleanupException`; repeated `close()` calls return the same future.
A failed eager initialization throws `FactoryInitializationException` with the
original error and an awaitable `cleanup` future.

Owned unique values with cleanup and replaced scoped generations remain alive
until their scope closes, because previously returned references may still be in
use. Direct unique resolutions without cleanup, observation or a retained resolver
are not retained. Use short scopes for short-lived resources. `FactoryScope.onClose` exposes the close future;
`onError` handles cleanup failures (the default reports through FlutterError).
Unmounting starts cleanup without waiting. For an explicitly awaited close, use
`FactoryScope.of(context).close()` before leaving a flow. Dispose callbacks should
not resolve more dependencies or await the scope's own closing future.

## Remove — preserve widgets and business classes

The example runs the same profile flow with manual Factory, annotated Factory,
and Provider-only compositions:

```sh
cd example
flutter run -t lib/main.dart
dart run build_runner build
flutter run -t lib/main_annotations.dart
flutter run -t lib/main_provider.dart
flutter test test/example_flow_test.dart
```

All three start with Ada, open a child flow using Grace, load `Grace Hopper profile`,
then return to Ada and record one closed flow. Existing Provider owns the root
session and monitor; Factory borrows them. The child composition owns its local
session. Replacing Factory with Provider changes composition only: the domain
classes receive collaborators by constructor and the widgets keep normal
Provider APIs. See [the example entrypoints](https://github.com/argote-dev/factory/blob/main/example/README.md).

This guarantee excludes the opt-in `FactoryChangeNotifier` and retained
`FactoryResolver`: removing Factory from those classes requires replacing their
internal resolution with constructor-injected collaborators and, for the base
class, extending `ChangeNotifier` directly. Choose that coupling explicitly.

## With annotations (optional)

Annotations replace the manual module lists. Keep the same factories,
`FactoryScope`, and Provider widgets. Add these development dependencies to the
manual setup above (generation requires Dart 3.11+):

```yaml
dev_dependencies:
  factory_generator: ^1.0.0
  build_runner: ^2.15.1
```

Declare an annotated factory in `lib/composition/factories.dart`:

```dart
import 'package:factory_provider/factory_provider.dart';

@Register(module: 'app', expose: true)
final greeting = Factory<String>((_) => 'Hello, Ada!');
```

Create `lib/composition/registry.dart`:

```dart
import 'package:factory_provider/factory_provider.dart';

@FactoryRegistry(
  include: ['lib/composition/**.dart'],
  runtime: FactoryRuntime.flutter,
)
void configureFactories() {}
```

Run `dart run build_runner build`, then import
`composition/registry.factory.dart` to install its generated `appModule`:

```dart
FactoryScope(
  modules: [appModule],
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(child: Text(context.watch<String>())),
      ),
    ),
  ),
);
```

Only `expose: true` values are available through Provider. The generated module
also includes internal declarations. Use `dart run build_runner watch` to
regenerate while editing. See the [generator guide](https://pub.dev/packages/factory_generator)
for standalone Dart and registration rules.

The [runnable example](https://github.com/argote-dev/factory/blob/main/example/README.md) keeps manual modules in
`composition/modules.dart` and registrations in `composition/annotations.dart`.
Run `lib/main.dart` for manual usage or `lib/main_annotations.dart` for annotations.

## Further reading

- [Runnable integration example](https://github.com/argote-dev/factory/blob/main/example/README.md): incremental adoption,
  manual and generated modules, nested scopes, and validation.
- [1.x compatibility policy](https://github.com/argote-dev/factory/blob/main/docs/compatibility-policy.md): stability and SDK evolution.
- [Public API guide](https://github.com/argote-dev/factory/blob/main/docs/api-guide.md): declarations, scopes, and lifecycle contracts.
- [Memory profiling playbook](https://github.com/argote-dev/factory/blob/main/docs/memory-profiling.md): cleanup and repeated navigation.
- [Compatibility and validation](https://github.com/argote-dev/factory/blob/main/docs/support.md): SDK requirements and platform evidence.

## Repository development

This repository contains the Flutter adapter at the root, a standalone Dart core
in `packages/factory_core`, and the optional `packages/factory_generator`. Local
`dependency_overrides` connect the packages before publication.

```sh
flutter pub get
(cd packages/factory_core && dart pub get && dart test && dart analyze)
(cd packages/factory_generator && dart pub get && dart test && dart analyze)
flutter test
flutter analyze lib test
(cd example && dart run build_runner build && flutter test && flutter analyze)
./tool/verify_consumers.sh
```

See [the runnable example](https://github.com/argote-dev/factory/blob/main/example/README.md) for manual, annotated, and Provider-only
entrypoints using the same business classes and widgets, and
[compatibility and validation](https://github.com/argote-dev/factory/blob/main/docs/support.md) for tested SDKs and platforms.

Contributions are welcome. Read [the contribution guide](https://github.com/argote-dev/factory/blob/main/CONTRIBUTING.md) before
opening a pull request. Please report vulnerabilities according to the
[security policy](https://github.com/argote-dev/factory/blob/main/SECURITY.md), not through a public issue.

Factory is available under the [MIT License](https://github.com/argote-dev/factory/blob/main/LICENSE).
