import 'package:factory/factory.dart';

/// Entrypoint scanned by `factory_generator`.
@FactoryRegistry(
  include: ['lib/composition/**.dart'],
  runtime: FactoryRuntime.flutter,
)
void configureFactories() {}
