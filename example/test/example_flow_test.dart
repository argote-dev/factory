import 'package:factory_example/main.dart' as factory_app;
import 'package:factory_example/main_provider.dart' as provider_app;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final example in <({String name, Widget app})>[
    (name: 'Factory composition', app: const factory_app.FactoryExampleApp()),
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

      await tester.tap(find.byKey(const Key('open-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Profile flow'), findsOneWidget);

      await tester.tap(find.byKey(const Key('load-profile')));
      await tester.pumpAndSettle();
      final profileName = example.name == 'Factory composition'
          ? 'Grace Hopper profile'
          : 'Ada Lovelace profile';
      expect(find.text('Profile: $profileName'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Signed in as Ada Lovelace'), findsOneWidget);
      expect(find.text('Closed profile flows: 1'), findsOneWidget);
    });
  }
}
