import 'package:factory_provider/factory_provider.dart';

@Register(module: 'app', expose: true)
final greeting = Factory<String>((_) => 'hello');
