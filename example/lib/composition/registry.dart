import 'package:factory_provider/factory_provider.dart';

/// Entrypoint scanned by `factory_generator`.
@FactoryRegistry(
  include: ['lib/composition/annotations.dart'],
  runtime: FactoryRuntime.flutter,
)
void configureFactories() {}
