## 1.0.0

- Stabilize the existing 0.3 public API as Factory 1.0.0.
- Define the 1.x API, behavior, deprecation and runtime SDK stability policy.
- Verify public consumers, historical generated output and isolated Pub artifacts.
- Keep synchronous construction, asynchronous cleanup and the optional generator.

## 0.3.0

- Add `FactoryRef.resolver` and `FactoryResolver.resolve` for retained scoped
  dependency access without observation or an extra cache.
- Track late dependencies for cleanup, reject dependency cycles and keep
  retained resolvers associated with their original instances after replacement.
- Custom implementations of `FactoryRef` must implement its new `resolver`
  getter; existing construction callbacks do not need changes.

## 0.2.0

- Add an explicit Dart/Flutter generation target to `FactoryRegistry`.
- Improve missing declaration, external override, and duplicate exposure
  diagnostics with corrective actions.
- Add repeated lifecycle and ownership contract coverage.

## 0.1.0

- Add typed factory declarations and modules.
- Add scoped and unique resolution with explicit overrides.
- Add dependency observation, deterministic ownership, and asynchronous cleanup.
