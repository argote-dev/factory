import 'package:factory_core/factory_core.dart';

@Register(module: 'app', expose: true)
final greeting = Factory<String>((_) => 'hello');
