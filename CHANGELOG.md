## Unreleased

- Let generated Flutter modules import the public `factory` facade so consumers
  no longer declare `factory_core` directly.
- Make common composition failures actionable and document public contracts,
  lifecycle profiling with a measured macOS baseline, the executable example,
  and behavior diagrams.

## 0.1.0

- Add a standalone scoped DI container with lazy/eager creation, unique values,
  explicit overrides and dependency observation, and asynchronous cleanup.
- Integrate with Provider through FactoryScope and declared ChangeNotifier types.
- Generate modules from annotations on composition declarations.
- Include a runnable example with equivalent Factory and Provider-only setups.
