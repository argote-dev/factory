# Prepare async resources before installing Factory

Lazy means synchronous construction on first resolution. It does not mean
asynchronous initialization. Prepare services before creating a container or
mounting `FactoryScope`. Factory adds no startup states, cancellation or retry.

The [executable recipe](../tool/consumer_contracts/dart/lib/async_startup.dart)
acquires a database and then a session through injected asynchronous functions.
Both resources belong to the application; Factory receives them through
`overrideWithValue`. A dependent is constructed synchronously from the ready
resources and its disposal belongs to Factory.

```sh
cd tool/consumer_contracts/dart
dart pub get
dart run bin/async_startup.dart
dart test test/async_startup_test.dart
```

Normal output is `database/session`, followed by
`dependent -> session -> database`. Await application closure on normal exit:
first Factory's dependents, then the borrowed resources in reverse acquisition
order. Repeated application closure returns the same future. Every cleanup is
attempted even if an earlier one fails; the caller observes aggregated errors.

If session acquisition fails, database cleanup completes before the startup
future fails. If cleanup also fails, the recipe's `StartupFailure` exposes the
original cause, stack trace and cleanup errors. Nothing runs in an unobserved
background task. The acquisition function itself owns cleanup of partially
acquired state if it throws before returning a resource.

The tests use local resources and futures, with no network or timing delays.
This recipe is application code, not a new Factory API. A Flutter application
can await the same startup before `runApp`, supply the ready instances to its
composition, and explicitly await scope closure before releasing borrowed
services. Unmounting a widget starts closure but does not await it.
