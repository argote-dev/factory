import 'package:factory_provider/factory_provider.dart';
import 'package:factory_example/composition/factories.dart';
import 'package:factory_example/composition/registry.factory.dart' as generated;
import 'package:factory_example/composition/modules.dart' as manual;
import 'package:factory_example/domain/profile_flow_monitor.dart';
import 'package:factory_example/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manual and generated modules preserve behavior and internal visibility',
    () async {
      for (final module in [manual.appModule, generated.appModule]) {
        final borrowedSession = Session('Ada');
        final borrowedMonitor = ProfileFlowMonitor();
        final container = FactoryContainer(
          modules: [module],
          overrides: [
            session.overrideWithValue(borrowedSession),
            profileFlowMonitor.overrideWithValue(borrowedMonitor),
          ],
        );
        expect(container.exposedFactories, [userRepository]);
        expect(
          await container.read(userRepository).loadProfileName(),
          'Ada profile',
        );
        final ownedClient = container.read(profileClient);
        await container.close();
        expect(ownedClient.isClosed, isTrue);
        borrowedSession.dispose();
        borrowedMonitor.dispose();
      }
    },
  );
}
