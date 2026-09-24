## 1.0.0

- Prepare an unpublished 1.0 candidate with the existing 0.3 public API.
- Define the 1.x API, behavior, deprecation and runtime SDK stability policy.
- Verify public consumers, historical generated output and isolated Pub artifacts.
- Keep synchronous construction, asynchronous cleanup and the optional generator.

## 0.3.0

- Align the generator with factory_core 0.3.0 and the coordinated Factory release.
- Continue generating composition modules; field injection annotations remain
  outside the generator's scope.

## 0.2.0

- Generate against either the standalone Dart runtime or the public Flutter
  facade according to `FactoryRegistry.runtime`.

## 0.1.0

- Add optional `build_runner` generation of factory modules.
- Discover explicitly annotated declarations through package-local include globs.
- Validate declaration shape, duplicate registries, and conflicting exposed types.
