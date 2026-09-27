import 'package:factory_provider/factory_provider.dart';
import 'package:factory_flutter_consumer/dependencies.dart';
import 'package:factory_flutter_consumer/registry.factory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final module in [
    FactoryModule(factories: [greeting], expose: [greeting]),
    appModule,
  ]) {
    testWidgets(
      'consumer reads ${identical(module, appModule) ? 'generated' : 'manual'} module',
      (tester) async {
        await tester.pumpWidget(
          FactoryScope(
            modules: [module],
            child: Builder(
              builder: (context) => Text(
                context.watch<String>(),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        );
        expect(find.text('hello'), findsOneWidget);
      },
    );
  }
}
