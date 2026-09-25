# factory_generator

Optional code generation for Factory modules. Annotate factory declarations and
let `build_runner` assemble the module lists. Constructors, lifetimes, and cleanup
remain in your declarations. Requires Dart 3.11+.

## Manual usage: no generator needed

Use `factory_core` for Dart or `factory_provider` for Flutter. You can always
write modules directly:

```dart
final greeting = Factory<String>((_) => 'Hello, Ada!');
final appModule = FactoryModule(
  factories: [greeting],
  expose: [greeting],
);
```

Choose annotations below when you want to generate those lists.

## With annotations

### 1. Add dependencies

For a standalone Dart app:

```yaml
dependencies:
  factory_core: ^1.0.0

dev_dependencies:
  factory_generator: ^1.0.0
  build_runner: ^2.15.1
```

For Flutter, replace `factory_core` with `factory_provider`. Use its import in
both files below and select `FactoryRuntime.flutter` in the registry.

### 2. Register declarations

Create `lib/composition/factories.dart`:

```dart
import 'package:factory_core/factory_core.dart';

@Register(module: 'app', expose: true)
final greeting = Factory<String>((_) => 'Hello, Ada!');
```

`module: 'app'` produces `appModule`. `expose: true` makes the value available
through Provider in Flutter; it is optional for Dart container reads. Annotate
public top-level `final Factory<T>` values, including aliases of existing
factories. Business classes need no annotations.

### 3. Define the registry

Create `lib/composition/registry.dart`:

```dart
import 'package:factory_core/factory_core.dart';

@FactoryRegistry(
  include: ['lib/composition/**.dart'],
  runtime: FactoryRuntime.dart,
)
void configureFactories() {}
```

### 4. Generate and use the module

```sh
dart run build_runner build
```

This creates `lib/composition/registry.factory.dart`. Use it from `bin/main.dart`:

```dart
import 'package:factory_core/factory_core.dart';
import '../lib/composition/factories.dart';
import '../lib/composition/registry.factory.dart';

Future<void> main() async {
  final container = FactoryContainer(modules: [appModule]);
  try {
    print(container.read(greeting));
  } finally {
    await container.close();
  }
}
```

In Flutter, install the generated module with
`FactoryScope(modules: [appModule], child: const MyApp())`, then consume exposed
values with Provider. Use `dart run build_runner watch` to regenerate while editing.

## Rules

- `include` accepts globs inside the current package's `lib/` directory.
- Generated `.factory.dart` files are excluded from scanning.
- Each registry library has one annotated top-level function and an explicit runtime.
- A module cannot expose two declarations with the same resolved type.
- Generated modules include internal declarations as well as the exposed subset.

See the [runnable Flutter example](https://github.com/argote-dev/factory/tree/main/example)
for separate manual and annotated entrypoints using the same profile flow.
