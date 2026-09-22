# factory_core

The standalone Dart resolution engine for Factory. No Flutter dependency.

Declare `Factory<T>` values, group them in `FactoryModule`, then resolve with
`FactoryContainer.read`. Construction is synchronous and lazy by default;
`close()` awaits cleanup. Values supplied through `overrideWithValue` are borrowed.

See the repository README for scopes, overrides, explicit observation and cleanup
contracts. Flutter applications usually import the `factory_provider` adapter
instead.
