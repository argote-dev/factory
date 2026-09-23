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
