## 1.0.0

- Stabilize the existing 0.3 public API as Factory 1.0.0.
- Define the 1.x API, behavior, deprecation and runtime SDK stability policy.
- Verify public consumers, historical generated output and isolated Pub artifacts.
- Keep synchronous construction, asynchronous cleanup and the optional generator.

## 0.3.0

- Add optional `FactoryChangeNotifier` with constructor-supplied dependency
  access through `resolve(factory)`, including disposal and scope guards.
- Add `FactoryRef.resolver` and `FactoryResolver` for non-reactive reads after
  construction, preserving scoped/unique lifetimes and dependency cleanup order.
- Reject cycles introduced by late dependency reads and preserve resolver
  identity when an instance is replaced. Field injection annotations remain
  outside this feature's scope.

## 0.2.0

- Rename the Flutter/Provider package to `factory_provider` so it can be
  published independently on pub.dev.
- Let generated Flutter modules import the public `factory_provider` facade so
  consumers no longer declare `factory_core` directly.
- Make common composition failures actionable and document public contracts,
  lifecycle profiling with a measured macOS baseline, the executable example,
  and behavior diagrams.

## 0.1.0

- Add a standalone scoped DI container with lazy/eager creation, unique values,
  explicit overrides and dependency observation, and asynchronous cleanup.
- Integrate with Provider through FactoryScope and declared ChangeNotifier types.
- Generate modules from annotations on composition declarations.
- Include a runnable example with equivalent Factory and Provider-only setups.
