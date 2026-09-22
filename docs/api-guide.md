# Public API decision guide

This guide is an inventory and decision matrix for Factory 0.1.x. Its terms
follow [the project glossary](../CONTEXT.md), and every behavior is exercised by
the public-API tests linked below.

## Resolution and observation

| Operation | Reads the current value | Reacts to replacement | Reacts to selected state | Required policy | Evidence |
| --- | --- | --- | --- | --- | --- |
| `ref.read(factory)` | Yes | No | No | None | [`changes_test.dart`](../packages/factory_core/test/changes_test.dart) |
| `ref.watch(factory)` | Yes | Yes | No | `recreate` or `update` | [`changes_test.dart`](../packages/factory_core/test/changes_test.dart) |
| `ref.select(factory, selector)` | Yes | Yes | Only when selection changes | `recreate` or `update` plus an observer adapter | [`changes_test.dart`](../packages/factory_core/test/changes_test.dart) |

`recreate` builds a new instance; `update` mutates the current instance through
its declared callback. See
[`changes_test.dart`](../packages/factory_core/test/changes_test.dart).

## Creation, reuse, and ownership

| Decision | Meaning | Cleanup owner | Evidence |
| --- | --- | --- | --- |
| `lazy: true` | Build at first resolution | Independent of ownership | [`container_test.dart`](../packages/factory_core/test/container_test.dart) |
| `Lifetime.scoped` | Reuse one instance in its owning Factory scope | Factory when it constructed the instance | [`container_test.dart`](../packages/factory_core/test/container_test.dart) |
| `Lifetime.unique` | Build on every container resolution | Factory only when a cleanup callback was declared | [`container_test.dart`](../packages/factory_core/test/container_test.dart) |
| `overrideWithValue(value)` | Borrow an existing instance | Caller | [`factory_scope_test.dart`](../test/factory_scope_test.dart) |
| `overrideWith(create, dispose:)` | Construct a replacement | Factory | [`container_test.dart`](../packages/factory_core/test/container_test.dart) |

Creation timing and reuse are separate decisions. Factory retains owned values
that require cleanup, including retired generations, until scope closure so a
previously returned reference is never invalidated early. See
[`container_test.dart`](../packages/factory_core/test/container_test.dart).

## Composition and visibility

| Tool | Use it for | Evidence |
| --- | --- | --- |
| `Factory<T>` / `FactoryModule` | Typed lifecycle declarations and installation groups | [Dart consumer](../tool/consumer_contracts/dart/test/public_contract_test.dart) |
| `factories` / `expose` | Internal composition and the subset visible to Provider | [Flutter consumer](../tool/consumer_contracts/flutter/test/public_contract_test.dart) |
| `overrides` / `local` | Replace values and reconnect inherited dependents in one scope | [`factory_scope_test.dart`](../test/factory_scope_test.dart) |
| `FactoryContainer` | Pure-Dart resolution and explicit closure | [Dart consumer](../tool/consumer_contracts/dart/test/public_contract_test.dart) |
| `FactoryScope` | Flutter lifecycle, callbacks and Provider integration | [Flutter consumer](../tool/consumer_contracts/flutter/test/public_contract_test.dart) |

The optional annotations are `@Register` and `@FactoryRegistry`. A registry
selects `FactoryRuntime.dart` for a standalone consumer or
`FactoryRuntime.flutter` for the Flutter facade. Generated and manual modules
have the same runtime behavior; generation is never required. The
[generator contracts](../packages/factory_generator/test/factory_module_builder_test.dart)
cover target selection and actionable invalid configuration.

Public errors are `StateError`/`ArgumentError` for invalid composition,
`FactoryInitializationException` for eager creation failures (with an awaitable
cleanup future), and `FactoryCleanupException` for aggregated cleanup failures.
Flutter closure is observable with `onClose` and failures with `onError`.
