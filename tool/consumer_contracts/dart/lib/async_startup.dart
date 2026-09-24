import 'package:factory_core/factory_core.dart';

// Application recipe, not an addition to the Factory API.
class Resource {
  Resource(this.name, this.events);
  final String name;
  final List<String> events;

  Future<void> close() async => events.add(name);
}

class StartupFailure implements Exception {
  StartupFailure(this.cause, this.stackTrace, this.cleanupErrors);
  final Object cause;
  final StackTrace stackTrace;
  final List<Object> cleanupErrors;
}

class Application {
  Application(this.container, this.greeting, this.resources);
  final FactoryContainer container;
  final String greeting;
  final List<Resource> resources;
  Future<void>? _closing;

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    final errors = <Object>[];
    try {
      await container.close();
    } catch (error) {
      errors.add(error);
    }
    for (final resource in resources.reversed) {
      try {
        await resource.close();
      } catch (error) {
        errors.add(error);
      }
    }
    if (errors.isNotEmpty) throw FactoryCleanupException(errors);
  }
}

Future<Application> startApplication({
  required Future<Resource> Function() openDatabase,
  required Future<Resource> Function() openSession,
  required List<String> events,
}) async {
  final database = await openDatabase();
  late final Resource session;
  try {
    session = await openSession();
  } catch (error, stack) {
    try {
      await database.close();
    } catch (cleanupError) {
      throw StartupFailure(error, stack, [cleanupError]);
    }
    rethrow;
  }
  final databaseDeclaration = Factory<Resource>.external();
  final sessionDeclaration = Factory<Resource>.external();
  final dependent = Factory<String>(
    (ref) => '${ref.read(databaseDeclaration).name}/'
        '${ref.read(sessionDeclaration).name}',
    dispose: (_) async => events.add('dependent'),
  );
  final container = FactoryContainer(
    modules: [
      FactoryModule(
          factories: [databaseDeclaration, sessionDeclaration, dependent]),
    ],
    overrides: [
      databaseDeclaration.overrideWithValue(database),
      sessionDeclaration.overrideWithValue(session),
    ],
  );
  return Application(container, container.read(dependent), [database, session]);
}
