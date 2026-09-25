import 'package:factory_provider/factory_provider.dart';

import 'factories.dart' as declarations;

// Register the same declarations used by the manual example.
@Register(module: 'app')
final session = declarations.session;

@Register(module: 'app')
final profileFlowMonitor = declarations.profileFlowMonitor;

@Register(module: 'app')
final profileClient = declarations.profileClient;

@Register(module: 'app', expose: true)
final userRepository = declarations.userRepository;

@Register(module: 'profile', expose: true)
final profileController = declarations.profileController;
