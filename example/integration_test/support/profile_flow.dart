import 'package:factory_example/composition/modules.dart' as manual;
import 'package:factory_example/composition/registry.factory.dart' as generated;
import 'package:factory_example/composition/factory_example_app.dart';
import 'package:factory_example/main_provider.dart' as provider_app;
import 'package:factory_example/domain/session.dart';
import 'package:factory_example/domain/profile_flow_monitor.dart';
import 'package:factory_example/domain/user_repository.dart';
import 'package:factory_example/presentation/app.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';

void profileFlowTests() {
  for (final example in <({String name, Widget app})>[
    (
      name: 'Manual Factory composition',
      app: FactoryExampleApp(
        appModule: manual.appModule,
        profileModule: manual.profileModule,
      ),
    ),
    (
      name: 'Annotated Factory composition',
      app: FactoryExampleApp(
        appModule: generated.appModule,
        profileModule: generated.profileModule,
      ),
    ),
    (
      name: 'Provider-only composition',
      app: const provider_app.ProviderExampleApp(),
    ),
  ]) {
    testWidgets('${example.name} preserves the Provider user flow', (
      tester,
    ) async {
      await tester.pumpWidget(example.app);

      expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
      expect(find.text('Closed profile flows: 0'), findsOneWidget);
      expect(find.byKey(const Key('load-profile')), findsNothing);

      final parentContext = tester.element(find.byType(ExampleHome));
      final parentSession = parentContext.read<Session>();
      final parentMonitor = parentContext.read<ProfileFlowMonitor>();
      final parentRepository = parentContext.read<UserRepository>();

      // Reopening exercises borrowed values after the first child is gone.
      for (var closedFlows = 1; closedFlows <= 2; closedFlows++) {
        await tester.tap(find.byKey(const Key('open-profile')));
        await tester.pumpAndSettle();
        expect(find.text('Profile flow'), findsOneWidget);

        await tester.tap(find.byKey(const Key('load-profile')));
        await tester.pumpAndSettle();
        expect(find.text('Profile: Grace Hopper profile'), findsOneWidget);
        expect(parentSession.displayName, 'Ada Lovelace');
        expect(parentMonitor.closedFlows, closedFlows - 1);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
        expect(find.text('Closed profile flows: $closedFlows'), findsOneWidget);
        expect(find.byKey(const Key('load-profile')), findsNothing);
        expect(parentContext.read<Session>(), same(parentSession));
        expect(parentContext.read<ProfileFlowMonitor>(), same(parentMonitor));
        expect(
          await parentRepository.loadProfileName(),
          'Ada Lovelace profile',
        );

        // A disposed borrowed ChangeNotifier rejects new listeners in debug.
        void listener() {}
        parentSession.addListener(listener);
        parentSession.removeListener(listener);
        parentMonitor.addListener(listener);
        parentMonitor.removeListener(listener);
        await tester.pumpAndSettle();
        expect(parentMonitor.closedFlows, closedFlows);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
