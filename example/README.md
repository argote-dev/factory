# Factory example

This app demonstrates an incremental adoption of `factory` in an existing
Provider application. The client, repository, controller, and widgets use
ordinary constructors and Provider APIs. Only `lib/composition/` knows about
Factory.

The default entrypoint (`lib/main.dart`) borrows an existing `Session` from
Provider, installs the generated app module, and creates a child Factory scope
for the profile flow. Dependencies are lazy: opening the app does not construct
the local profile client or repository. Opening and loading the profile resolves
them through the controller. Closing the profile scope releases the controller;
the root client remains available until the app scope closes.

Generate the modules while developing:

```sh
dart run build_runner watch
```

Then run the Factory composition:

```sh
flutter run
```

The removal path is executable too. `lib/main_provider.dart` wires the same
domain and presentation directly with Provider and does not import Factory:

```sh
flutter run -t lib/main_provider.dart
```

Run its shared behavior test with:

```sh
flutter test
```
