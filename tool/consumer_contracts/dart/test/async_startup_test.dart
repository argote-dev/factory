import 'package:factory_dart_consumer/async_startup.dart';
import 'package:test/test.dart';
import 'package:factory_core/factory_core.dart';

class FailingResource extends Resource {
  FailingResource(super.name, super.events, this.failure);
  final Object failure;

  @override
  Future<void> close() async {
    await super.close();
    throw failure;
  }
}

void main() {
  test('normal exit attempts every resource despite cleanup errors', () async {
    final events = <String>[];
    final failure = StateError('session close failed');
    final application = await startApplication(
      openDatabase: () async => Resource('database', events),
      openSession: () async => FailingResource('session', events, failure),
      events: events,
    );
    await expectLater(
        application.close(),
        throwsA(
          isA<FactoryCleanupException>()
              .having((e) => e.errors, 'errors', [failure]),
        ));
    expect(events, ['dependent', 'session', 'database']);
  });

  test('startup and cleanup failures remain observable together', () async {
    final events = <String>[];
    final startup = StateError('session unavailable');
    final cleanup = StateError('database close failed');
    await expectLater(
      startApplication(
        openDatabase: () async => FailingResource('database', events, cleanup),
        openSession: () async => throw startup,
        events: events,
      ),
      throwsA(isA<StartupFailure>()
          .having((error) => error.cause, 'cause', same(startup))
          .having((error) => error.cleanupErrors, 'cleanupErrors', [cleanup])),
    );
    expect(events, ['database']);
  });

  test('partial startup closes acquired resources and preserves failure',
      () async {
    final events = <String>[];
    final failure = StateError('session unavailable');
    await expectLater(
      startApplication(
        openDatabase: () async => Resource('database', events),
        openSession: () async => throw failure,
        events: events,
      ),
      throwsA(same(failure)),
    );
    expect(events, ['database']);
  });

  test('ready resources are borrowed and normal exit awaits every owner',
      () async {
    final events = <String>[];
    final application = await startApplication(
      openDatabase: () async => Resource('database', events),
      openSession: () async => Resource('session', events),
      events: events,
    );
    expect(application.greeting, 'database/session');
    await application.close();
    await application.close();
    expect(events, ['dependent', 'session', 'database']);
  });
}
