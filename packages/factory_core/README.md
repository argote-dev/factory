# factory_core

Typed dependency injection for Dart, with scoped lifetimes and explicit cleanup.
No Flutter dependency. Requires Dart 3.3+.

For Flutter widgets, use
[factory_provider](https://pub.dev/packages/factory_provider).

## Manual usage

Add the runtime to `pubspec.yaml`:

```yaml
dependencies:
  factory_core: ^1.0.0
```

Declare a factory, install a module, and resolve the value:

```dart
import 'package:factory_core/factory_core.dart';

class Greeting {
  String greet(String name) => 'Hello, $name!';
}

final greeting = Factory<Greeting>((_) => Greeting());
final appModule = FactoryModule(factories: [greeting]);

Future<void> main() async {
  final container = FactoryContainer(modules: [appModule]);
  try {
    print(container.read(greeting).greet('Ada'));
  } finally {
    await container.close();
  }
}
```

Use `ref.read(otherFactory)` inside a constructor callback to resolve a dependency.
Pure Dart containers do not need `expose`; that list selects values for the
Flutter Provider bridge.

## Lifetimes and ownership

- Factories are lazy and `Lifetime.scoped` by default: one value per owning scope.
- `Lifetime.unique` creates a value on each container resolution.
- `dispose: (value) => value.close()` registers cleanup for an owned value.
- `factory.overrideWithValue(value)` supplies a borrowed value; Factory never disposes it.
- `await container.close()` closes children first, then dependents before their dependencies.

Construction is synchronous. Initialize asynchronous services before installing
them as ready values. A child scope inherits parent instances; use local
declarations when dependents must resolve against child overrides.

## With annotations (optional)

Keep the same runtime and add development dependencies:

```yaml
dev_dependencies:
  factory_generator: ^1.0.0
  build_runner: ^2.15.1
```

Annotate declarations with `@Register` and create a
`@FactoryRegistry(runtime: FactoryRuntime.dart)` entrypoint. The generator creates
module lists; construction and resolution stay the same. Generation requires
Dart 3.11+.

See the [complete generator setup](https://pub.dev/packages/factory_generator).

## Observation and deferred resolution

`ref.watch(factory)` observes instance replacement. `ref.select(factory, selector)`
observes selected state when the container has an `observe` adapter. Declarations
that observe changes must choose `ChangePolicy.recreate` or `ChangePolicy.update`.

Pass `ref.resolver` to an instance that needs to resolve dependencies later.
`FactoryResolver.resolve(factory)` follows the same lifetimes and cleanup ownership,
without subscribing or caching. It rejects resolution after scope closure and
rejects dependency cycles.

See the [API guide](https://github.com/argote-dev/factory/blob/main/docs/api-guide.md)
for scopes, overrides, observation, and cleanup contracts.
