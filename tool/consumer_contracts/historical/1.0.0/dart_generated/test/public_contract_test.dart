import 'package:factory_core/factory_core.dart';
import 'package:factory_generated_dart_consumer/dependencies.dart';
import 'package:factory_generated_dart_consumer/registry.factory.dart';
import 'package:test/test.dart';

void main() {
  for (final module in [
    FactoryModule(factories: [greeting], expose: [greeting]),
    appModule,
  ]) {
    test('Dart generated and manual modules resolve the public declaration',
        () async {
      final container = FactoryContainer(modules: [module]);
      expect(container.read(greeting), 'hello');
      expect(container.exposedFactories, [greeting]);
      await container.close();
    });
  }
}
