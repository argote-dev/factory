import 'package:factory/factory.dart';

@Register(module: 'app', expose: true)
final greeting = Factory<String>((_) => 'hello');
