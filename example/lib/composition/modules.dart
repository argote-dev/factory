import 'package:factory_provider/factory_provider.dart';

import 'factories.dart';

final appModule = FactoryModule(
  factories: [session, profileFlowMonitor, profileClient, userRepository],
  expose: [userRepository],
);

final profileModule = FactoryModule(
  factories: [profileController],
  expose: [profileController],
);
