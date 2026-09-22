// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:factory_provider/factory_provider.dart';
import 'package:factory_example/composition/factories.dart' as factory0;

final appModule = FactoryModule(
  factories: [factory0.profileClient, factory0.profileFlowMonitor, factory0.session, factory0.userRepository],
  expose: [factory0.userRepository],
);

final profileModule = FactoryModule(
  factories: [factory0.profileController],
  expose: [factory0.profileController],
);
