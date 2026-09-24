# Public API decision guide

This guide is an inventory and decision matrix for the Factory 1.0 candidate. Its terms
follow [the project glossary](../CONTEXT.md), and every behavior is exercised by
the public-API tests linked below.

## Resolution and observation

| Operation | Reads the current value | Reacts to replacement | Reacts to selected state | Required policy | Evidence |
| --- | --- | --- | --- | --- | --- |
| `ref.read(factory)` | Yes | No | No | None | [`changes_test.dart`](../packages/factory_core/test/changes_test.dart) |
| `ref.resolver.resolve(factory)` / notifier `resolve(factory)` | Yes | No | No | None | [`resolver_test.dart`](../packages/factory_core/test/resolver_test.dart) |
| `ref.watch(factory)` | Yes | Yes | No | `recreate` or `update` | [`changes_test.dart`](../packages/factory_core/test/changes_test.dart) |
| `ref.select(factory, selector)` | Yes | Yes | Only when selection changes | `recreate` or `update` plus an observer adapter | [`changes_test.dart`](../packages/factory_core/test/changes_test.dart) |

`recreate` builds a new instance; `update` mutates the current instance through
its declared callback. See
[`changes_test.dart`](../packages/factory_core/test/changes_test.dart).

`FactoryRef` is for construction and update callbacks. Pass its `resolver` to
instances that need access later: `FactoryResolver` retains the original
consumer's identity, tracks cleanup dependencies and rejects cycles even when
both values already exist. It resolves declarations using the consumer's owner
scope and rejects access as soon as that scope starts closing.

The Flutter `FactoryChangeNotifier` base receives this resolver by constructor,
provides protected `resolve` access and rejects it after `dispose`. It adds no
subscriptions or cache and does not dispose resolved dependencies. Register
notifier cleanup in the owning `Factory` declaration, and call `super.dispose()`
in overrides. An explicit `late final` field retains its first result; an
ordinary method call to `resolve` reads the current value each time. See
[`factory_change_notifier_test.dart`](../test/factory_change_notifier_test.dart).

This opt-in base couples its consumers to Factory. The existing constructor
injection path preserves removal by changing composition alone. Field injection
annotations are outside this API's scope.

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
| `FactoryChangeNotifier` | Optional resolution within a notifier with explicit ownership and lifetime guards | [`factory_change_notifier_test.dart`](../test/factory_change_notifier_test.dart) |

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

## Stable surface for 1.x

The candidate retains the 0.3 names, including `Lifetime.scoped`,
`ChangePolicy`, `Register` and `FactoryRegistry`. No rename or runtime API
migration is required. Stability covers signatures **and documented behavior**.
See [the evolution policy](compatibility-policy.md).

| Public entrypoint / surface | Supported use | Contract evidence |
| --- | --- | --- |
| `factory_core.dart`: `Factory` (including external, overrides, type visitor), `Lifetime`, `ChangePolicy`, `FactoryOverride` | Construct declarations; obtain overrides from declarations | [container tests](../packages/factory_core/test/container_test.dart), [external interfaces](../tool/consumer_contracts/dart/test/interfaces_test.dart) |
| `FactoryModule`: factories, expose | Construct modules; lists are immutable | [Dart consumer](../tool/consumer_contracts/dart/test/public_contract_test.dart), [Flutter consumer](../tool/consumer_contracts/flutter/test/public_contract_test.dart) |
| `FactoryContainer`: constructor, parent, read, exposedFactories, setOverrides, addListener, close | Install, resolve, observe invalidations and await closure | [container](../packages/factory_core/test/container_test.dart), [changes](../packages/factory_core/test/changes_test.dart) |
| `FactoryRef`, `FactoryResolver`, `FactoryVisitor<R>` | **External implementation supported**; all members are part of the compatibility contract | [external interfaces](../tool/consumer_contracts/dart/test/interfaces_test.dart), [resolver](../packages/factory_core/test/resolver_test.dart) |
| `FactoryObserver`; create, update, dispose and unsubscribe callbacks | Supply callbacks with the declared synchronous / FutureOr signatures | [changes](../packages/factory_core/test/changes_test.dart), [cleanup](../packages/factory_core/test/container_test.dart) |
| `FactoryInitializationException`: error, stackTrace, cleanup; `FactoryCleanupException`: errors | Inspect original errors and await cleanup; message text is diagnostic, not stable | [container](../packages/factory_core/test/container_test.dart) |
| `Register`, `FactoryRegistry`, `FactoryRuntime` (also exported by `src/annotations.dart`) | Annotate composition; select Dart or Flutter generation | [generator](../packages/factory_generator/test/factory_module_builder_test.dart) |
| `factory_provider.dart`: all core exports plus `FactoryScope` | Construct scopes, use of/maybeOf, modules/local/overrides, onClose/onError | [scope](../test/factory_scope_test.dart), [Flutter consumer](../tool/consumer_contracts/flutter/test/public_contract_test.dart) |
| `FactoryChangeNotifier`: constructor, protected resolve, dispose | **Subclassing supported**; call super.dispose; Factory coupling is opt-in | [notifier](../test/factory_change_notifier_test.dart) |
| `factory_generator.dart`: `FactoryModuleBuilder`; `builder.dart`: `factoryModuleBuilder` | Construct/configure the builder; consume generated modules | [generator](../packages/factory_generator/test/factory_module_builder_test.dart) |

Only the three abstract interfaces above promise third-party implementations;
`FactoryChangeNotifier` is the supported extension point. Other concrete classes
are consumed via their documented constructors and members; implementing or
subclassing them is not a supported customization mechanism. Imports under
`src/` are internal, except the already exported annotation declarations; prefer
the package entrypoints. Generated module names, runtime imports and semantics
are contractual; formatting and internal builder implementation are not.

Public composition failures use `StateError` / `ArgumentError`; no exact message
text is promised. Two declarations of one type retain separate identities inside
Factory, but only one can be exposed per type in a scope. `unique` means each
Factory resolution, not each Provider read. Owned replaced generations remain
alive until closure. Construction is synchronous; cleanup can be asynchronous.
