# factory_core

The standalone Dart resolution engine for Factory. No Flutter dependency.

Declare `Factory<T>` values, group them in `FactoryModule`, then resolve with
`FactoryContainer.read`. Construction is synchronous and lazy by default;
`close()` awaits cleanup. Values supplied through `overrideWithValue` are borrowed.

Pass `FactoryRef.resolver` to a constructed instance when it needs to resolve
dependencies from later methods. `FactoryResolver.resolve(factory)` preserves
scoped/unique lifetimes and cleanup order without subscribing to changes or
caching results. It stays bound to the original instance through replacements,
and throws `StateError` after scope closure or for dependency cycles.

See the repository README for scopes, overrides, explicit observation and cleanup
contracts. Flutter applications usually import the `factory_provider` adapter
instead.
