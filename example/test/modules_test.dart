import 'package:factory/factory.dart';
import 'package:factory_example/composition/factories.dart';
import 'package:factory_example/composition/registry.factory.dart';
import 'package:factory_example/domain/profile_flow_monitor.dart';
import 'package:factory_example/domain/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manual and generated modules preserve behavior and internal visibility',
    () async {
      final manual = FactoryModule(
        factories: [session, profileClient, userRepository, profileFlowMonitor],
        expose: [userRepository],
      );
      for (final module in [manual, appModule]) {
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
