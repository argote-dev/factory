import 'dart:async';

import 'package:factory_provider/factory_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('resolves in constructor, late fields and methods without widgets',
      () async {
    final repository = Factory<_Repository>((_) => _Repository());
    final controller = Factory<_Controller>(
      (ref) => _Controller(ref.resolver, repository),
      dispose: (value) => value.dispose(),
    );
    final fake = _Repository();
    final container = FactoryContainer(
      local: [repository, controller],
      overrides: [repository.overrideWithValue(fake)],
    );
    final instance = container.read(controller);
    expect(instance.initial, same(fake));
    expect(instance.saved, same(fake));
    expect(instance.readRepository(), same(fake));

    final next = _Repository();
    container.setOverrides([repository.overrideWithValue(next)]);
    expect(instance.readRepository(), same(next));
    expect(instance.saved, same(fake));
    expect(container.read(controller), same(instance));
    await container.close();
    expect(instance.disposeCalls, 1);
    expect(fake.disposeCalls, 0);
    expect(next.disposeCalls, 0);
    fake.dispose();
    next.dispose();
  });

  test('manual disposal rejects reads without disposing dependencies or scope',
      () async {
    final repository = Factory<_Repository>(
      (_) => _Repository(),
      dispose: (value) => value.dispose(),
    );
    // This test owns the controller; the scope owns only its repository.
    final controller = Factory<_Controller>(
      (ref) => _Controller(ref.resolver, repository),
    );
    final container = FactoryContainer(local: [repository, controller]);
    final instance = container.read(controller);
    final dependency = instance.readRepository();
    instance.dispose();

    expect(instance.readRepository, throwsStateError);
    expect(dependency.disposeCalls, 0);
    expect(container.read(repository), same(dependency));
    await container.close();
    expect(instance.disposeCalls, 1);
    expect(dependency.disposeCalls, 1);
  });

  test('rejects resolution from an async continuation after scope closure',
      () async {
    final gate = Completer<void>();
    final repository = Factory<_Repository>(
      (_) => _Repository(),
      dispose: (value) => value.dispose(),
    );
    final controller = Factory<_Controller>(
      (ref) => _Controller(ref.resolver, repository),
      dispose: (value) => value.dispose(),
    );
    final container = FactoryContainer(local: [repository, controller]);
    final pending = container.read(controller).readAfter(gate.future);
    final assertion = expectLater(pending, throwsStateError);
    await container.close();
    gate.complete();
    await assertion;
  });

  testWidgets('Provider observes the notifier and cleanup runs exactly once',
      (tester) async {
    final events = <String>[];
    final repository = Factory<_Repository>(
      (_) => _Repository(),
      dispose: (value) {
        value.dispose();
        events.add('repository');
      },
    );
    final controller = Factory<_Controller>(
      (ref) => _Controller(ref.resolver, repository),
      dispose: (value) {
        value.dispose();
        events.add('controller');
      },
    );
    late _Controller instance;
    Future<void>? closing;
    await tester.pumpWidget(FactoryScope(
      modules: [
        FactoryModule(
          factories: [repository, controller],
          expose: [controller],
        ),
      ],
      onClose: (future) => closing = future,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          instance = context.watch<_Controller>();
          return Text('calls:${instance.calls}');
        }),
      ),
    ));
    expect(find.text('calls:0'), findsOneWidget);
    final dependency = instance.readRepository();
    expect(dependency.isObserved, isFalse);
    instance.run();
    await tester.pump();
    expect(find.text('calls:1'), findsOneWidget);
    expect(instance.listenerAdds, 1);

    await tester.pumpWidget(const SizedBox());
    await closing;
    expect(instance.listenerRemoves, 1);
    expect(instance.disposeCalls, 1);
    expect(dependency.disposeCalls, 1);
    expect(events, ['controller', 'repository']);
    expect(instance.readRepository, throwsStateError);
  });
}

class _Repository extends ChangeNotifier {
  int disposeCalls = 0;
  bool get isObserved => hasListeners;

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}

class _Controller extends FactoryChangeNotifier {
  _Controller(super.resolver, this.repository) {
    initial = resolve(repository);
  }

  final Factory<_Repository> repository;
  late final _Repository initial;
  late final _Repository saved = resolve(repository);
  int calls = 0;
  int disposeCalls = 0;
  int listenerAdds = 0;
  int listenerRemoves = 0;

  _Repository readRepository() => resolve(repository);

  Future<_Repository> readAfter(Future<void> gate) async {
    await gate;
    return resolve(repository);
  }

  void run() {
    resolve(repository);
    calls++;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    listenerAdds++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerRemoves++;
    super.removeListener(listener);
  }

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}
