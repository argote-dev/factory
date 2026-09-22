import 'package:factory_core/factory_core.dart';
import 'package:test/test.dart';

void main() {
  test('manual Dart consumer resolves and awaits public cleanup', () async {
    var closed = false;
    final message = Factory<String>((_) => 'ready', dispose: (_) {
      closed = true;
    });
    final module = FactoryModule(factories: [message]);
    final container = FactoryContainer(modules: [module]);

    expect(container.read(message), 'ready');
    await container.close();
    expect(closed, isTrue);
  });
}
