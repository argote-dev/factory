import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Retrospective canary control, not an original Factory 1.0 release fixture.
void main() {
  testWidgets('Provider observes updates without Factory', (tester) async {
    final value = ValueNotifier('first');
    addTearDown(value.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ValueNotifier<String>>.value(
        value: value,
        child: Builder(
          builder: (context) => Text(
            context.watch<ValueNotifier<String>>().value,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    expect(find.text('first'), findsOneWidget);
    value.value = 'second';
    await tester.pump();
    expect(find.text('second'), findsOneWidget);
  });
}
