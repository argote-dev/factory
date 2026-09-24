import 'package:factory_dart_consumer/async_startup.dart';

Future<void> main() async {
  final events = <String>[];
  final application = await startApplication(
    openDatabase: () async => Resource('database', events),
    openSession: () async => Resource('session', events),
    events: events,
  );
  try {
    print(application.greeting);
  } finally {
    await application.close();
    print(events.join(' -> '));
  }
}
