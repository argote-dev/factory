# factory_generator

Optional `build_runner` support for assembling `Factory` declarations into
`FactoryModule` values. It never constructs dependencies: the generated file
only imports existing declarations and groups their references.

For standalone Dart, add the core runtime and generator packages:

```yaml
dependencies:
  factory_core: ^1.0.0

dev_dependencies:
  build_runner: ^2.15.1
  factory_generator: ^1.0.0
```

Create one composition entrypoint and keep declarations in `lib/`:

```dart
// lib/composition/registry.dart
import 'package:factory_core/factory_core.dart';

@FactoryRegistry(
  include: ['lib/composition/**.dart'],
  runtime: FactoryRuntime.dart,
)
void configureFactories() {}
```

```dart
// lib/composition/services.dart
import 'package:factory_core/factory_core.dart';

@Register(module: 'app')
final apiClient = Factory<ApiClient>((ref) => ApiClient());

@Register(module: 'app', expose: true)
final repository = Factory<Repository>(
  (ref) => Repository(ref.read(apiClient)),
);
```

Run `dart run build_runner watch`. This writes
`lib/composition/registry.factory.dart`, which exposes `appModule`:

```dart
import 'registry.factory.dart';

final modules = [appModule];
```

`include` accepts current-package `lib/` globs only. The generator ignores
existing `.factory.dart` files so generated output never becomes an input.
Each library may contain one `@FactoryRegistry` top-level function. `@Register`
is valid only on public top-level `final Factory<T>` declarations. A module
cannot expose two declarations with the same resolved `T` type.

For Flutter, depend on `factory_provider` instead of `factory_core`, import
`package:factory_provider/factory_provider.dart`, and select
`FactoryRuntime.flutter`. The generated module then imports the public Flutter
facade, avoiding a direct transitive core dependency. Generation is optional for
both targets, and each registry library must explicitly select exactly one
target.
