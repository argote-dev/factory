import 'package:factory_provider/factory_provider.dart';

import '../domain/profile_client.dart';
import '../domain/profile_flow_monitor.dart';
import '../domain/session.dart';
import '../domain/user_repository.dart';
import '../presentation/profile_controller.dart';

/// An application-owned dependency. Factory borrows this value from Provider.
final session = Factory<Session>.external(name: 'session');

final profileFlowMonitor = Factory<ProfileFlowMonitor>.external(
  name: 'profileFlowMonitor',
);

final profileClient = Factory<LocalProfileClient>(
  (_) => LocalProfileClient(),
  name: 'profileClient',
  dispose: (client) => client.close(),
);

final userRepository = Factory<UserRepository>(
  (ref) => UserRepository(ref.read(profileClient), ref.read(session)),
  name: 'userRepository',
);

/// This declaration is installed only by the profile flow's child scope.
final profileController = Factory<ProfileController>(
  (ref) =>
      ProfileController(ref.read(userRepository), ref.read(profileFlowMonitor)),
  name: 'profileController',
  dispose: (controller) => controller.dispose(),
);
